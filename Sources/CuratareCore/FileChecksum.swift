// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import CryptoKit

/// Dosya sağlama toplamı (Checksum / Hash) sonucu.
public struct FileChecksumResult: Sendable, Codable, Equatable {
    public let fileName: String
    public let fileSize: Int64
    public let md5: String
    public let sha1: String
    public let sha256: String

    public init(fileName: String, fileSize: Int64, md5: String, sha1: String, sha256: String) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.md5 = md5
        self.sha1 = sha1
        self.sha256 = sha256
    }

    /// Verilen beklenen özet dizesini MD5, SHA-1 veya SHA-256 ile karşılaştırır.
    public func verify(expected: String) -> (isMatch: Bool, matchedAlgorithm: String?) {
        let clean = expected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return (false, nil) }

        if clean == md5.lowercased() {
            return (true, "MD5")
        }
        if clean == sha1.lowercased() {
            return (true, "SHA-1")
        }
        if clean == sha256.lowercased() {
            return (true, "SHA-256")
        }
        return (false, nil)
    }
}

/// Belleği şişirmeden 1 MB'lık parçalarla akışkan MD5, SHA-1 ve SHA-256 özetleri hesaplayan motor.
public enum FileChecksumCalculator {
    public static func computeHashes(for fileURL: URL) throws -> FileChecksumResult {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var md5 = Insecure.MD5()
        var sha1 = Insecure.SHA1()
        var sha256 = SHA256()

        let bufferSize = 1024 * 1024 // 1 MB tampon
        var totalBytes: Int64 = 0

        while let chunk = try handle.read(upToCount: bufferSize), !chunk.isEmpty {
            md5.update(data: chunk)
            sha1.update(data: chunk)
            sha256.update(data: chunk)
            totalBytes += Int64(chunk.count)
        }

        let md5Hex = md5.finalize().map { String(format: "%02x", $0) }.joined()
        let sha1Hex = sha1.finalize().map { String(format: "%02x", $0) }.joined()
        let sha256Hex = sha256.finalize().map { String(format: "%02x", $0) }.joined()

        return FileChecksumResult(
            fileName: fileURL.lastPathComponent,
            fileSize: totalBytes,
            md5: md5Hex,
            sha1: sha1Hex,
            sha256: sha256Hex
        )
    }
}
