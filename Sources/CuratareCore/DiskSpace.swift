// SPDX-License-Identifier: GPL-3.0-or-later
import CoreServices
import Darwin
import Foundation
import os

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

    static func regularFileBytes(below path: String, isCancelled: () -> Bool) -> Int64 {
        guard !isCancelled() else { return 0 }
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
                total = total.saturatingAdding(regularFileBytes(below: child, isCancelled: isCancelled))
            } else {
                // DT_UNKNOWN vb. dosya sistemlerinde lstat ile kesin tür kontrolü
                var info = stat()
                if lstat(child, &info) == 0 {
                    let mode = info.st_mode & S_IFMT
                    if mode == S_IFREG {
                        total = total.saturatingAdding(max(0, Int64(info.st_size)))
                    } else if mode == S_IFDIR {
                        total = total.saturatingAdding(regularFileBytes(below: child, isCancelled: isCancelled))
                    }
                }
            }
        }
        return total
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
