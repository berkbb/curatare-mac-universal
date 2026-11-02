// SPDX-License-Identifier: GPL-3.0-or-later
import CoreServices
import Darwin
import Foundation
import os
import Synchronization

/// İş parçacığı güvenli tarama iptal belirteci; hem atomik bayrağı hem de `Task.isCancelled` durumunu denetler.
public final class ScanCancellationToken: Sendable {
    private let cancelledFlag = OSAllocatedUnfairLock(initialState: false)

    public init() {}

    public var isCancelled: Bool {
        cancelledFlag.withLock { $0 } || Task.isCancelled
    }

    public func cancel() {
        cancelledFlag.withLock { $0 = true }
    }
}

extension Int64 {
    /// Taşma yerine sınırda duran toplama: bozuk ya da uydurma boyutlar çökmeye yol açmasın.
    public func saturatingAdding(_ other: Int64) -> Int64 {
        let (sum, overflow) = addingReportingOverflow(other)
        guard overflow else { return sum }
        return other > 0 ? .max : .min
    }
}

extension Sequence where Element == Int64 {
    public func saturatingSum() -> Int64 { reduce(0) { $0.saturatingAdding($1) } }
}

/// Dosya boyutu hesaplama, birim ayrıştırma ve boş alan yardımcıları.
public enum DiskSpace {
    public static let reserve: Int64 = 1 << 30

    public static func availableCapacity(at url: URL = URL(fileURLWithPath: "/"), fileManager: FileManager = .default) -> Int64? {
        let anchor = existingAncestor(of: url, fileManager: fileManager)
        let values = try? anchor.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        if let important = values?.volumeAvailableCapacityForImportantUsage, important > 0 { return important }
        return values?.volumeAvailableCapacity.map(Int64.init)
    }

    public static func totalCapacity(at url: URL = URL(fileURLWithPath: "/"), fileManager: FileManager = .default) -> Int64? {
        let anchor = existingAncestor(of: url, fileManager: fileManager)
        return (try? anchor.resourceValues(forKeys: [.volumeTotalCapacityKey]))?.volumeTotalCapacity.map(Int64.init)
    }

    /// Dosya veya klasörün diskteki toplam mantıksal boyutu (sembolik bağlantılar izlenmez, gerçek disk boyutu).
    public static func size(of url: URL, isCancelled: () -> Bool = { false }) -> Int64 {
        totalSize(of: [url], isCancelled: isCancelled)
    }

    public static func totalSize(of urls: [URL], isCancelled: () -> Bool = { false }) -> Int64 {
        var total: Int64 = 0
        for url in urls {
            guard !isCancelled() else { return 0 }
            var info = stat()
            guard lstat(url.path, &info) == 0 else { continue }
            switch info.st_mode & S_IFMT {
            case S_IFREG:
                total = total.saturatingAdding(max(0, Int64(info.st_size)))
            case S_IFDIR:
                total = total.saturatingAdding(regularFileBytes(below: url.path, isCancelled: isCancelled))
            default:
                break
            }
        }
        return total
    }

    /// Her kök için `size(of:)` ile aynı değeri döndürür; dizinleri tüm çekirdeklere dağıtarak paralel gezer.
    /// On binlerce dosyalı önbelleklerde (`~/.gradle/caches`, `~/.pub-cache`, `Cellar`) süre, dosya başına `lstat` gecikmesinden ötürü
    /// çekirdek sayısına yakın oranda kısalır. `isCancelled` yalnızca çağıran iş parçacığında ~50 ms aralıkla sorgulanır.
    public static func sizes(of urls: [URL], isCancelled: () -> Bool = { false }) -> [Int64] {
        var totals = [Int64](repeating: 0, count: urls.count)
        var directories: [ParallelWalk.Job] = []
        for (index, url) in urls.enumerated() {
            guard !isCancelled() else { return totals }
            var info = stat()
            guard lstat(url.path, &info) == 0 else { continue }
            switch info.st_mode & S_IFMT {
            case S_IFREG:
                totals[index] = max(0, Int64(info.st_size))
            case S_IFDIR:
                directories.append(ParallelWalk.Job(root: index, path: url.path))
            default:
                break
            }
        }
        guard !directories.isEmpty else { return totals }

        let walk = ParallelWalk(jobs: directories, rootCount: urls.count)
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: DispatchQoS.QoSClass(rawValue: qos_class_self()) ?? .userInitiated)
        for _ in 0..<min(max(1, ProcessInfo.processInfo.activeProcessorCount), 16) {
            queue.async(group: group) { walk.work() }
        }
        // İşçiler paylaşılan durdurma bayrağını izler; böylece `isCancelled` iş parçacığı güvenli olmak zorunda kalmaz.
        while group.wait(timeout: .now() + .milliseconds(50)) == .timedOut {
            if isCancelled() { walk.stop() }
        }
        for (index, bytes) in walk.result().enumerated() {
            totals[index] = totals[index].saturatingAdding(bytes)
        }
        return totals
    }

    /// Tek bir dizindeki düzenli dosyaların boyutunu toplar; alt dizinleri kendisi gezmek yerine `subdirectory` ile bildirir.
    /// Sıralı (`regularFileBytes(below:)`) ve paralel (`sizes(of:)`) gezinti aynı girdi kurallarını bu işlev üzerinden paylaşır.
    static func regularFileBytes(in path: String, isCancelled: () -> Bool, subdirectory: (String) -> Void) -> Int64 {
        guard let directory = opendir(path) else { return 0 }
        defer { closedir(directory) }

        var total: Int64 = 0
        while let entry = readdir(directory) {
            guard !isCancelled() else { return total }

            // '.' ve '..' dizinlerini doğrudan bayt karşılaştırmasıyla atla (string tahsis etmez)
            if entry.pointee.d_name.0 == 46 { // '.'
                if entry.pointee.d_name.1 == 0 { continue } // "."
                if entry.pointee.d_name.1 == 46 && entry.pointee.d_name.2 == 0 { continue } // ".."
            }

            let dType = entry.pointee.d_type
            if dType == DT_LNK { continue } // Sembolik bağlantıları izleme

            let name = withUnsafePointer(to: entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            let child = (path as NSString).appendingPathComponent(name)

            if dType == DT_REG {
                var info = stat()
                if lstat(child, &info) == 0 {
                    total = total.saturatingAdding(max(0, Int64(info.st_size)))
                }
            } else if dType == DT_DIR {
                subdirectory(child)
            } else {
                // DT_UNKNOWN vb. dosya sistemlerinde lstat ile kesin tür kontrolü
                var info = stat()
                if lstat(child, &info) == 0 {
                    let mode = info.st_mode & S_IFMT
                    if mode == S_IFREG {
                        total = total.saturatingAdding(max(0, Int64(info.st_size)))
                    } else if mode == S_IFDIR {
                        subdirectory(child)
                    }
                }
            }
        }
        return total
    }

    static func regularFileBytes(below path: String, isCancelled: () -> Bool) -> Int64 {
        guard !isCancelled() else { return 0 }
        var nested: Int64 = 0
        let own = regularFileBytes(in: path, isCancelled: isCancelled) { child in
            nested = nested.saturatingAdding(regularFileBytes(below: child, isCancelled: isCancelled))
        }
        return own.saturatingAdding(nested)
    }

    public static func entries(ofDirectory path: String) throws -> [String] {
        guard let directory = opendir(path) else { throw CocoaError(.fileReadNoPermission) }
        defer { closedir(directory) }
        var names: [String] = []
        while let entry = readdir(directory) {
            let name = withUnsafePointer(to: entry.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            if name != "." && name != ".." { names.append(name) }
        }
        return names
    }

    /// Mole ya da `ollama list` çıktılarındaki `"477.5MB"`, `"2.11 GB"`, `"156KB"`, `"4.2 GiB"` gibi dizgileri bayta çevirir.
    public static func parseHumanSize(_ text: String) -> Int64 {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return 0 }
        let pattern = #"^([0-9]+(?:[.,][0-9]+)?)\s*([KMGTPE]?I?B?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let numRange = Range(match.range(at: 1), in: trimmed),
              let unitRange = Range(match.range(at: 2), in: trimmed) else {
            return Int64(trimmed) ?? 0
        }
        let numberString = trimmed[numRange].replacingOccurrences(of: ",", with: ".")
        guard let value = Double(numberString), value.isFinite, value >= 0 else { return 0 }
        let unit = String(trimmed[unitRange])
        let multiplier: Double
        switch unit {
        case "", "B": multiplier = 1
        case "K", "KB", "KIB": multiplier = 1024
        case "M", "MB", "MIB": multiplier = 1024 * 1024
        case "G", "GB", "GIB": multiplier = 1024 * 1024 * 1024
        case "T", "TB", "TIB": multiplier = 1024 * 1024 * 1024 * 1024
        case "P", "PB", "PIB": multiplier = 1024 * 1024 * 1024 * 1024 * 1024
        default: multiplier = 1
        }
        let product = value * multiplier
        if product >= Double(Int64.max) { return .max }
        return Int64(product.rounded())
    }

    /// Bayt sayısını okunaklı biçimde ("24,5 MB", "2,11 GB") döndürür.
    public static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }

    static func existingAncestor(of url: URL, fileManager: FileManager) -> URL {
        var current = url
        while !fileManager.fileExists(atPath: current.path), current.pathComponents.count > 1 {
            current = current.deletingLastPathComponent()
        }
        return current
    }
}

/// `DiskSpace.sizes(of:)` için paylaşılan dizin kuyruğu: boştaki işçiler, diğerlerinin bulduğu alt dizinleri alır.
final class ParallelWalk: @unchecked Sendable {
    struct Job {
        let root: Int
        let path: String
    }

    private let condition = NSCondition()
    private let stopFlag = Atomic<Bool>(false)
    private let rootCount: Int
    private var pending: [Job]
    private var busyWorkers = 0
    private var totals: [Int64]

    init(jobs: [Job], rootCount: Int) {
        self.rootCount = rootCount
        pending = jobs
        totals = [Int64](repeating: 0, count: rootCount)
    }

    var isStopped: Bool { stopFlag.load(ordering: .relaxed) }

    /// Kuyruk boşalana ya da `stop()` çağrılana dek dizin alıp gezer; kök başına toplamları sonda birleştirir.
    func work() {
        var local = [Int64](repeating: 0, count: rootCount)
        var found: [Job] = []
        var job = next(adding: [], finishedOne: false)
        while let current = job {
            found.removeAll(keepingCapacity: true)
            let bytes = DiskSpace.regularFileBytes(in: current.path, isCancelled: { isStopped }) { subdirectory in
                found.append(Job(root: current.root, path: subdirectory))
            }
            local[current.root] = local[current.root].saturatingAdding(bytes)
            job = next(adding: found, finishedOne: true)
        }
        condition.lock()
        for index in local.indices { totals[index] = totals[index].saturatingAdding(local[index]) }
        condition.unlock()
    }

    /// Bitirilen işin alt dizinlerini kuyruğa ekler ve sıradaki işi verir; iş kalmadıysa ya da durdurulduysa `nil` döner.
    private func next(adding found: [Job], finishedOne: Bool) -> Job? {
        condition.lock()
        defer { condition.unlock() }
        if finishedOne { busyWorkers -= 1 }
        if !isStopped, !found.isEmpty {
            pending.append(contentsOf: found)
            condition.broadcast()
        } else if busyWorkers == 0 {
            condition.broadcast() // Kuyruk boş ve kimse çalışmıyor: bekleyen işçiler çıksın
        }
        while pending.isEmpty, busyWorkers > 0, !isStopped {
            condition.wait()
        }
        guard !isStopped, let job = pending.popLast() else { return nil }
        busyWorkers += 1
        return job
    }

    func stop() {
        stopFlag.store(true, ordering: .relaxed)
        condition.lock()
        pending.removeAll()
        condition.broadcast()
        condition.unlock()
    }

    func result() -> [Int64] {
        condition.lock()
        defer { condition.unlock() }
        return totals
    }
}
