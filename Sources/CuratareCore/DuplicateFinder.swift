// SPDX-License-Identifier: GPL-3.0-or-later
import CryptoKit
import Darwin
import Foundation

/// Aynı içerikli bir dosyanın diskte ayrı yer kaplayan tek kopyası.
/// Aynı APFS klon kimliğini ya da aynı inode'u (sabit bağlantı) paylaşan yollar tek kopya sayılır:
/// biri Çöp'e taşınsa da veri bloğu diğerinde kaldığı için yer açılmaz.
public struct DuplicateFileCopy: Sendable, Identifiable, Equatable {
    /// Kopyanın en eski yolu; satırda bu gösterilir.
    public let url: URL
    /// Aynı veriyi paylaşan diğer yollar (APFS klonları, sabit bağlantılar). Kopya taşınırken bunlar da taşınır.
    public let sharedURLs: [URL]
    public let createdAt: Date
    public var isSelected: Bool

    public var id: String { url.path }
    public var allURLs: [URL] { [url] + sharedURLs }

    public init(url: URL, sharedURLs: [URL] = [], createdAt: Date, isSelected: Bool = false) {
        self.url = url
        self.sharedURLs = sharedURLs
        self.createdAt = createdAt
        self.isSelected = isSelected
    }
}

/// SHA-256 özeti aynı olan, en az iki ayrı kopyası bulunan dosya grubu. `copies[0]` en eski kopyadır.
public struct DuplicateFileGroup: Sendable, Identifiable, Equatable {
    public let sha256: String
    public let fileSize: Int64
    public var copies: [DuplicateFileCopy]

    public var id: String { sha256 }

    public init(sha256: String, fileSize: Int64, copies: [DuplicateFileCopy]) {
        self.sha256 = sha256
        self.fileSize = fileSize
        self.copies = copies
    }

    /// Tek kopya bırakıldığında açılacak alan.
    public var reclaimableBytes: Int64 { fileSize(times: copies.count - 1) }

    public var selectedBytes: Int64 { fileSize(times: copies.filter(\.isSelected).count) }

    private func fileSize(times count: Int) -> Int64 {
        let (product, overflow) = fileSize.multipliedReportingOverflow(by: Int64(max(0, count)))
        return overflow ? .max : product
    }
}

public struct DuplicateScanResult: Sendable, Equatable {
    public var groups: [DuplicateFileGroup]
    /// Boyut eşiğini geçen ve incelenen dosya sayısı.
    public let examinedFileCount: Int
    /// Klasör okunamadı (macOS İndirilenler izni verilmedi).
    public let accessDenied: Bool

    public init(groups: [DuplicateFileGroup], examinedFileCount: Int, accessDenied: Bool) {
        self.groups = groups
        self.examinedFileCount = examinedFileCount
        self.accessDenied = accessDenied
    }
}

/// Bir klasördeki aynı içerikli büyük dosyaları bulur; salt okunurdur, hiçbir dosyayı değiştirmez.
///
/// 1. Boyut eşiğinin altındaki, gizli, yarım kalmış ve iCloud'da bekleyen (dataless) dosyalar atlanır; paketlerin içine girilmez.
/// 2. Dosyalar boyuta göre gruplanır; boyutu eşsiz olanlar hiç okunmaz.
/// 3. Aynı APFS klon kimliğini (`ATTR_CMNEXT_CLONEID`) ya da inode'u paylaşan yollar tek kopya sayılır ve bir kez okunur.
/// 4. Kalan adaylar SHA-256 ile doğrulanır; en az iki ayrı kopyası olan özetler grup olur.
public struct DuplicateFileFinder: Sendable {
    public static let defaultMinimumFileSize: Int64 = 1 << 20
    static let partialDownloadExtensions: Set<String> = ["download", "crdownload", "part", "opdownload"]

    public let minimumFileSize: Int64

    public init(minimumFileSize: Int64 = DuplicateFileFinder.defaultMinimumFileSize) {
        self.minimumFileSize = minimumFileSize
    }

    public func scan(directory: URL, isCancelled: () -> Bool = { false }) -> DuplicateScanResult {
        guard let probe = opendir(directory.path) else {
            return DuplicateScanResult(groups: [], examinedFileCount: 0, accessDenied: errno == EPERM || errno == EACCES)
        }
        closedir(probe)

        let files = collectFiles(in: directory, isCancelled: isCancelled)
        let cancelledResult = DuplicateScanResult(groups: [], examinedFileCount: files.count, accessDenied: false)
        var groups: [DuplicateFileGroup] = []
        for (size, sameSize) in Dictionary(grouping: files, by: \.size) where sameSize.count > 1 {
            let copies = Dictionary(grouping: sameSize, by: \.physicalID).values.map(Self.makeCopy)
            guard copies.count > 1 else { continue } // Hepsi birbirinin klonu ya da sabit bağlantısı

            var byDigest: [String: [DuplicateFileCopy]] = [:]
            for copy in copies {
                guard !isCancelled() else { return cancelledResult }
                guard let digest = Self.sha256(of: copy.url, isCancelled: isCancelled) else { continue }
                byDigest[digest, default: []].append(copy)
            }
            for (digest, matching) in byDigest where matching.count > 1 {
                groups.append(DuplicateFileGroup(sha256: digest, fileSize: size, copies: matching.sorted(by: Self.olderFirst)))
            }
        }
        // Son dosyanın özeti iptalle yarıda kaldıysa grup eksik olabilir: yarım sonuç döndürülmez.
        guard !isCancelled() else { return cancelledResult }
        // En çok yer açacak grup üstte; eşitlikte yol sırası sabit kalır.
        groups.sort { lhs, rhs in
            lhs.reclaimableBytes != rhs.reclaimableBytes
                ? lhs.reclaimableBytes > rhs.reclaimableBytes
                : lhs.copies[0].url.path < rhs.copies[0].url.path
        }
        return DuplicateScanResult(groups: groups, examinedFileCount: files.count, accessDenied: false)
    }

    /// Seçili fazla kopyaların Çöp'e taşınacak yolları. Tarama sonrası değişen dosyalar korunur:
    /// grubun seçilmemiş bir kopyası aynı boyutla yerinde değilse grup atlanır; boyutu değişen ya da silinen yollar alınmaz.
    public static func trashCandidates(from groups: [DuplicateFileGroup]) -> (urls: [(url: URL, size: Int64)], skippedCount: Int) {
        var urls: [(url: URL, size: Int64)] = []
        var skipped = 0
        for group in groups {
            let selected = group.copies.filter(\.isSelected)
            guard !selected.isEmpty else { continue }
            let keeperIntact = group.copies.contains { !$0.isSelected && $0.allURLs.contains { regularFileSize(at: $0.path) == group.fileSize } }
            guard keeperIntact else {
                skipped += selected.reduce(0) { $0 + $1.allURLs.count }
                continue
            }
            for copy in selected {
                var counted = false
                for url in copy.allURLs {
                    guard regularFileSize(at: url.path) == group.fileSize else {
                        skipped += 1
                        continue
                    }
                    // Klonlar veriyi paylaşır: açılan alan kopya başına bir kez sayılır.
                    urls.append((url, counted ? 0 : group.fileSize))
                    counted = true
                }
            }
        }
        return (urls, skipped)
    }

    /// APFS klon kimliği; aynı kimliği taşıyan dosyalar birbirinin tam klonudur. Birim desteklemiyorsa `nil`.
    /// `cp -c`, `ditto` ve Finder'ın "Çoğalt" komutu klon üretir; klon değiştirildiğinde kimliği ayrışır.
    public static func cloneID(atPath path: String) -> UInt64? {
        var request = attrlist()
        request.bitmapcount = u_short(ATTR_BIT_MAP_COUNT)
        request.commonattr = attrgroup_t(ATTR_CMN_RETURNED_ATTRS)
        request.forkattr = attrgroup_t(ATTR_CMNEXT_CLONEID)
        // uint32 uzunluk + attribute_set_t (5 × uint32) + uint64 klon kimliği
        var buffer = [UInt8](repeating: 0, count: 64)
        let status = buffer.withUnsafeMutableBytes { raw in
            getattrlist(path, &request, raw.baseAddress, raw.count, UInt32(FSOPT_ATTR_CMN_EXTENDED | FSOPT_NOFOLLOW))
        }
        guard status == 0 else { return nil }
        return buffer.withUnsafeBytes { raw -> UInt64? in
            let returned = raw.loadUnaligned(fromByteOffset: 4, as: attribute_set_t.self)
            guard returned.forkattr & attrgroup_t(ATTR_CMNEXT_CLONEID) != 0 else { return nil }
            return raw.loadUnaligned(fromByteOffset: 4 + MemoryLayout<attribute_set_t>.size, as: UInt64.self)
        }
    }

    /// Dosyayı 1 MB'lık parçalarla okuyup SHA-256 özetini döndürür; iptal edilirse ya da okunamazsa `nil`.
    static func sha256(of url: URL, isCancelled: () -> Bool) -> String? {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        _ = fcntl(descriptor, F_NOCACHE, 1) // Tek geçişlik okuma: GB'lık dosyalar sayfa önbelleğini doldurmasın

        var hasher = SHA256()
        var chunk = [UInt8](repeating: 0, count: 1 << 20)
        while true {
            guard !isCancelled() else { return nil }
            let count = chunk.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
            if count < 0 { return nil }
            if count == 0 { break }
            chunk.withUnsafeBytes { hasher.update(bufferPointer: UnsafeRawBufferPointer(rebasing: $0.prefix(count))) }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Dosya toplama

    struct Candidate {
        let url: URL
        let size: Int64
        let createdAt: Date
        let physicalID: PhysicalID
    }

    /// Aynı veri bloklarını gösteren yolların ortak anahtarı: klon kimliği varsa o, yoksa inode.
    struct PhysicalID: Hashable {
        let device: Int32
        let value: UInt64
        let isCloneID: Bool
    }

    private func collectFiles(in directory: URL, isCancelled: () -> Bool) -> [Candidate] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        var files: [Candidate] = []
        while let url = enumerator.nextObject() as? URL {
            guard !isCancelled() else { return [] }
            var info = stat()
            guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { continue }
            let size = Int64(info.st_size)
            guard size >= minimumFileSize,
                  info.st_flags & UInt32(SF_DATALESS) == 0,
                  !Self.partialDownloadExtensions.contains(url.pathExtension.lowercased()) else { continue }

            let physicalID = Self.cloneID(atPath: url.path)
                .map { PhysicalID(device: info.st_dev, value: $0, isCloneID: true) }
                ?? PhysicalID(device: info.st_dev, value: info.st_ino, isCloneID: false)
            let birth = info.st_birthtimespec
            files.append(Candidate(
                url: url,
                size: size,
                createdAt: Date(timeIntervalSince1970: TimeInterval(birth.tv_sec) + TimeInterval(birth.tv_nsec) / 1_000_000_000),
                physicalID: physicalID
            ))
        }
        return files
    }

    private static func makeCopy(_ sharing: [Candidate]) -> DuplicateFileCopy {
        let ordered = sharing.sorted { ($0.createdAt, $0.url.path) < ($1.createdAt, $1.url.path) }
        return DuplicateFileCopy(url: ordered[0].url, sharedURLs: ordered.dropFirst().map(\.url), createdAt: ordered[0].createdAt)
    }

    private static func olderFirst(_ lhs: DuplicateFileCopy, _ rhs: DuplicateFileCopy) -> Bool {
        (lhs.createdAt, lhs.url.path) < (rhs.createdAt, rhs.url.path)
    }

    private static func regularFileSize(at path: String) -> Int64? {
        var info = stat()
        guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
        return Int64(info.st_size)
    }
}
