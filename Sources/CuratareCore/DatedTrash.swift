// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// `library_clean.md` Kural 1: **Yalnızca Çöp'e taşı, kalıcı silme yapma.**
///
/// Her temizlik ve kaldırma turu için `~/.Trash/Curatare-YYYY-MM-DD-HHmmss/` altında tarihli bir klasör açılır,
/// taşınan her öğenin göreli yolu (`user/Library/...` veya `system/Library/...`) korunur ve `manifest.json` ile
/// kayıt altına alınır. Kullanıcı dilediği turu **Geri Yükle (`restoreBatch`)** ile tek tıkla eski yerine döndürebilir.
public struct TrashedItemRecord: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let originalPath: String
    public let trashedRelativePath: String
    public let sizeBytes: Int64
    public let category: String
    public let bundleID: String?

    public init(
        id: UUID = UUID(),
        originalPath: String,
        trashedRelativePath: String,
        sizeBytes: Int64,
        category: String,
        bundleID: String? = nil
    ) {
        self.id = id
        self.originalPath = originalPath
        self.trashedRelativePath = trashedRelativePath
        self.sizeBytes = sizeBytes
        self.category = category
        self.bundleID = bundleID
    }
}

public struct TrashBatchManifest: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let createdAt: Date
    public let title: String
    public let batchDirectoryPath: String
    public let items: [TrashedItemRecord]
    public let totalBytes: Int64
    public var isRestored: Bool

    public init(
        id: String,
        createdAt: Date,
        title: String,
        batchDirectoryPath: String,
        items: [TrashedItemRecord],
        totalBytes: Int64,
        isRestored: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.batchDirectoryPath = batchDirectoryPath
        self.items = items
        self.totalBytes = totalBytes
        self.isRestored = isRestored
    }
}

public enum DatedTrashError: Error, Sendable, Equatable {
    case protectedTarget(path: String, reason: String)
    case processRunning(name: String, path: String)
    case batchNotFound(String)
    case moveFailed(path: String, reason: String)
    case restoreConflict(path: String)
    case cannotPurgeInvalidLocation(String)
}

/// Tarihli Çöp geçmişi filtre seçenekleri.
public enum TrashHistoryFilterKind: String, Sendable, Codable, CaseIterable {
    case all
    case pendingRestore
    case restored
}

public struct DatedTrashMoveCandidate: Sendable, Equatable {
    public let url: URL
    public let category: String
    public let bundleID: String?
    public let processName: String?
    public let precomputedSize: Int64?

    public init(
        url: URL,
        category: String,
        bundleID: String? = nil,
        processName: String? = nil,
        precomputedSize: Int64? = nil
    ) {
        self.url = url
        self.category = category
        self.bundleID = bundleID
        self.processName = processName
        self.precomputedSize = precomputedSize
    }
}

public struct DatedTrashService: Sendable {
    public let trashRootURL: URL
    public let homeDirectoryURL: URL
    public let registryFileURL: URL

    public init(
        trashRootURL: URL? = nil,
        homeDirectoryURL: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        registryFileURL: URL? = nil
    ) {
        self.homeDirectoryURL = homeDirectoryURL
        self.trashRootURL = trashRootURL ?? homeDirectoryURL.appendingPathComponent(".Trash", isDirectory: true)
        self.registryFileURL = registryFileURL ?? homeDirectoryURL
            .appendingPathComponent("Library/Application Support/Curatare/trash-batches.json")
    }

    private static let folderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        return f
    }()

    /// Yeni bir tarihli Çöp klasörü adı üretir (`Curatare-YYYY-MM-DD-HHmmss`).
    public func makeBatchDirectoryURL(date: Date = Date(), prefix: String = "Curatare") -> (id: String, url: URL) {
        let stamp = Self.folderFormatter.string(from: date)
        var baseName = "\(prefix)-\(stamp)"
        var candidate = trashRootURL.appendingPathComponent(baseName, isDirectory: true)
        var counter = 2
        let fm = FileManager.default
        while fm.fileExists(atPath: candidate.path) {
            baseName = "\(prefix)-\(stamp)-\(counter)"
            candidate = trashRootURL.appendingPathComponent(baseName, isDirectory: true)
            counter += 1
        }
        return (baseName, candidate)
    }

    /// Seçilen öğeleri koruma ve çalışan süreç denetiminden geçirerek tarihli `~/.Trash/Curatare-...` klasörüne taşır.
    public func moveToDatedTrash(
        candidates: [DatedTrashMoveCandidate],
        title: String,
        protectionRules: ProtectionRules = ProtectionRules(),
        verifyRunningProcess: Bool = true,
        runningProcessCheck: ((String?, String?, String?) -> Bool)? = nil,
        date: Date = Date()
    ) throws -> TrashBatchManifest {
        let fm = FileManager.default
        let isRunning = runningProcessCheck ?? { bundleID, procName, execPath in
            ProtectionRules.isProcessRunning(bundleID: bundleID, processName: procName, executablePath: execPath)
        }

        // 1. Ön denetim: koruma listesi ve çalışan süreç kontrolü
        for item in candidates {
            let path = item.url.path
            let decision = protectionRules.evaluate(path: path, candidateIdentifier: item.bundleID)
            if decision.isProtected {
                throw DatedTrashError.protectedTarget(path: path, reason: decision.reason ?? "Protected item")
            }
            if verifyRunningProcess,
               isRunning(item.bundleID, item.processName, path.hasSuffix(".app") ? path : nil) {
                let owner = item.processName ?? item.bundleID ?? item.url.lastPathComponent
                throw DatedTrashError.processRunning(name: owner, path: path)
            }
        }

        let (batchID, batchURL) = makeBatchDirectoryURL(date: date)
        try fm.createDirectory(at: batchURL, withIntermediateDirectories: true)

        var records: [TrashedItemRecord] = []
        var totalBytes: Int64 = 0

        for item in candidates {
            let sourcePath = item.url.path
            guard fm.fileExists(atPath: sourcePath) else { continue }
            let size = item.precomputedSize ?? DiskSpace.size(of: item.url)
            let relPath = relativeStagingPath(for: sourcePath)
            let destURL = batchURL.appendingPathComponent(relPath)
            try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            do {
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try fm.moveItem(at: item.url, to: destURL)
            } catch {
                throw DatedTrashError.moveFailed(path: sourcePath, reason: error.localizedDescription)
            }

            records.append(TrashedItemRecord(
                originalPath: sourcePath,
                trashedRelativePath: relPath,
                sizeBytes: size,
                category: item.category,
                bundleID: item.bundleID
            ))
            totalBytes = totalBytes.saturatingAdding(size)
        }

        let manifest = TrashBatchManifest(
            id: batchID,
            createdAt: date,
            title: title,
            batchDirectoryPath: batchURL.path,
            items: records,
            totalBytes: totalBytes,
            isRestored: false
        )

        try saveManifest(manifest, inBatchDirectory: batchURL)
        return manifest
    }

    /// Tarihli Çöp klasöründeki öğeleri orijinal konumlarına geri yükler (`Geri Yükle`).
    public func restoreBatch(id: String, overwriteExisting: Bool = false) throws -> Int {
        var batches = listBatches()
        guard let index = batches.firstIndex(where: { $0.id == id }) else {
            throw DatedTrashError.batchNotFound(id)
        }
        let manifest = batches[index]
        let batchURL = URL(fileURLWithPath: manifest.batchDirectoryPath, isDirectory: true)
        let fm = FileManager.default
        var restoredCount = 0

        for record in manifest.items {
            let trashedURL = batchURL.appendingPathComponent(record.trashedRelativePath)
            guard fm.fileExists(atPath: trashedURL.path) else { continue }
            let originalURL = URL(fileURLWithPath: record.originalPath)
            if fm.fileExists(atPath: originalURL.path) {
                if overwriteExisting {
                    // Çakışan öğeyi bile kalıcı silmiyoruz; aynı batch içinde `.conflict` yanına alıyoruz.
                    let backupURL = batchURL.appendingPathComponent(record.trashedRelativePath + ".conflict")
                    try? fm.moveItem(at: originalURL, to: backupURL)
                } else {
                    throw DatedTrashError.restoreConflict(path: record.originalPath)
                }
            }
            try fm.createDirectory(at: originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: trashedURL, to: originalURL)
            restoredCount += 1

            // launchd Servis Yönetimi: Geri yüklenen dosya LaunchAgent ise launchd'ye tekrar yükle (bootstrap)
            if originalURL.pathExtension.lowercased() == "plist" && originalURL.path.contains("/LaunchAgents/") {
                LaunchdManager.loadJob(at: originalURL, isUserAgent: true)
            }
        }

        batches[index].isRestored = true
        try writeRegistry(batches)
        let manifestFile = batchURL.appendingPathComponent("manifest.json")
        if let data = try? Self.encoder.encode(batches[index]) {
            try? data.write(to: manifestFile, options: .atomic)
        }
        return restoredCount
    }

    /// Belirtilen Tarihli Çöp turunu `~/.Trash` içerisinden kalıcı olarak temizler ve kayıttan siler.
    @discardableResult
    public func purgeBatch(id: String) throws -> TrashBatchManifest {
        var batches = listBatches()
        guard let index = batches.firstIndex(where: { $0.id == id }) else {
            throw DatedTrashError.batchNotFound(id)
        }
        let manifest = batches[index]
        let batchURL = URL(fileURLWithPath: manifest.batchDirectoryPath, isDirectory: true)

        // Güvenlik: Yalnızca ~/.Trash içindeki ve Curatare- ile başlayan dizinler temizlenebilir
        guard batchURL.path.contains("/.Trash/Curatare-") || batchURL.lastPathComponent.hasPrefix("Curatare-") else {
            throw DatedTrashError.cannotPurgeInvalidLocation(manifest.batchDirectoryPath)
        }

        let fm = FileManager.default
        if fm.fileExists(atPath: batchURL.path) {
            try fm.removeItem(at: batchURL)
        }

        batches.remove(at: index)
        try writeRegistry(batches)
        return manifest
    }

    /// Belirtilen Tarihli Çöp turundaki belirli öğeleri `~/.Trash` içerisinden kalıcı olarak siler ve kaydı günceller.
    @discardableResult
    public func purgeTrashedItems(batchID: String, itemIDs: Set<UUID>) throws -> TrashBatchManifest? {
        guard !itemIDs.isEmpty else { return nil }
        var batches = listBatches()
        guard let index = batches.firstIndex(where: { $0.id == batchID }) else {
            throw DatedTrashError.batchNotFound(batchID)
        }
        let manifest = batches[index]
        let batchURL = URL(fileURLWithPath: manifest.batchDirectoryPath, isDirectory: true)

        guard batchURL.path.contains("/.Trash/Curatare-") || batchURL.lastPathComponent.hasPrefix("Curatare-") else {
            throw DatedTrashError.cannotPurgeInvalidLocation(manifest.batchDirectoryPath)
        }

        let fm = FileManager.default
        var remainingItems: [TrashedItemRecord] = []
        var freedBytes: Int64 = 0

        for item in manifest.items {
            if itemIDs.contains(item.id) {
                let targetURL = batchURL.appendingPathComponent(item.trashedRelativePath)
                let resolvedTarget = targetURL.resolvingSymlinksInPath().path
                let resolvedBatch = batchURL.resolvingSymlinksInPath().path
                // Güvenlik doğrulaması: Hedef dosya gerçekten batchURL içinde mi?
                if resolvedTarget.hasPrefix(resolvedBatch) && fm.fileExists(atPath: targetURL.path) {
                    try? fm.removeItem(at: targetURL)
                }
                freedBytes += item.sizeBytes
            } else {
                remainingItems.append(item)
            }
        }

        if remainingItems.isEmpty {
            // Turdaki tüm dosyalar silindiyse tüm tur klasörünü sil
            if fm.fileExists(atPath: batchURL.path) {
                try? fm.removeItem(at: batchURL)
            }
            batches.remove(at: index)
            try writeRegistry(batches)
            return nil
        } else {
            let updatedManifest = TrashBatchManifest(
                id: manifest.id,
                createdAt: manifest.createdAt,
                title: manifest.title,
                batchDirectoryPath: manifest.batchDirectoryPath,
                items: remainingItems,
                totalBytes: max(0, manifest.totalBytes - freedBytes),
                isRestored: manifest.isRestored
            )
            batches[index] = updatedManifest
            try writeRegistry(batches)
            let manifestFile = batchURL.appendingPathComponent("manifest.json")
            if let data = try? Self.encoder.encode(updatedManifest) {
                try? data.write(to: manifestFile, options: .atomic)
            }
            return updatedManifest
        }
    }

    /// Belirtilen Tarihli Çöp turundaki tek bir öğeyi kalıcı olarak siler.
    @discardableResult
    public func purgeTrashedItem(batchID: String, itemID: UUID) throws -> TrashBatchManifest? {
        try purgeTrashedItems(batchID: batchID, itemIDs: [itemID])
    }

    /// Tüm `~/.Trash/Curatare-*` turlarını kalıcı olarak temizler ve kayıt defterini sıfırlar.
    @discardableResult
    public func purgeAllBatches() throws -> (purgedCount: Int, totalBytes: Int64) {
        let batches = listBatches()
        let fm = FileManager.default
        var count = 0
        var totalBytes: Int64 = 0

        for manifest in batches {
            let batchURL = URL(fileURLWithPath: manifest.batchDirectoryPath, isDirectory: true)
            if (batchURL.path.contains("/.Trash/Curatare-") || batchURL.lastPathComponent.hasPrefix("Curatare-")) &&
               fm.fileExists(atPath: batchURL.path) {
                try? fm.removeItem(at: batchURL)
            }
            count += 1
            totalBytes += manifest.totalBytes
        }

        // Çöp dizininde kayıtlı olmayan yetim Curatare-* dizinlerini de temizle
        if let entries = try? fm.contentsOfDirectory(at: trashRootURL, includingPropertiesForKeys: nil) {
            for entry in entries where entry.lastPathComponent.hasPrefix("Curatare-") {
                try? fm.removeItem(at: entry)
            }
        }

        try writeRegistry([])
        return (count, totalBytes)
    }

    /// Kayıtlı ve `~/.Trash` içinde bulunan tüm `Curatare-*` turlarını yeniden eskiye sıralı döndürür.
    public func listBatches() -> [TrashBatchManifest] {
        var byID: [String: TrashBatchManifest] = [:]
        if let data = try? Data(contentsOf: registryFileURL),
           let decoded = try? Self.decoder.decode([TrashBatchManifest].self, from: data) {
            for b in decoded { byID[b.id] = b }
        }
        if let entries = try? FileManager.default.contentsOfDirectory(at: trashRootURL, includingPropertiesForKeys: nil) {
            for entry in entries where entry.lastPathComponent.hasPrefix("Curatare-") {
                let manifestFile = entry.appendingPathComponent("manifest.json")
                if let data = try? Data(contentsOf: manifestFile),
                   let decoded = try? Self.decoder.decode(TrashBatchManifest.self, from: data) {
                    byID[decoded.id] = decoded
                }
            }
        }
        return byID.values.sorted { $0.createdAt > $1.createdAt }
    }

    /// Kaynağın göreli yolunu (`user/...` veya `system/...`) üretir.
    public func relativeStagingPath(for absolutePath: String) -> String {
        let stdHome = homeDirectoryURL.resolvingSymlinksInPath().standardizedFileURL.path
        let stdPath = URL(fileURLWithPath: absolutePath).resolvingSymlinksInPath().standardizedFileURL.path
        if stdPath.hasPrefix(stdHome + "/") {
            let suffix = String(stdPath.dropFirst(stdHome.count + 1))
            return "user/" + suffix
        }
        let trimmed = stdPath.hasPrefix("/") ? String(stdPath.dropFirst()) : stdPath
        return "system/" + trimmed
    }

    private func saveManifest(_ manifest: TrashBatchManifest, inBatchDirectory batchURL: URL) throws {
        let manifestFile = batchURL.appendingPathComponent("manifest.json")
        let data = try Self.encoder.encode(manifest)
        try data.write(to: manifestFile, options: .atomic)

        var existing = listBatches().filter { $0.id != manifest.id }
        existing.insert(manifest, at: 0)
        try writeRegistry(existing)
    }

    private func writeRegistry(_ batches: [TrashBatchManifest]) throws {
        let dir = registryFileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(batches)
        try data.write(to: registryFileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
