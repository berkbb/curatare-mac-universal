// SPDX-License-Identifier: GPL-3.0-or-later
import CryptoKit
import Foundation

/// Curatare uygulama güncellemelerinin kontrolü ve Ed25519 imza doğrulaması.
public struct AppRelease: Sendable, Equatable {
    public let version: String
    public let tag: String
    public let htmlURL: URL
    public let dmgURL: URL?
    public let dmgDigest: String?
    public let signatureURL: URL?
    public let notes: String

    public init(
        version: String,
        tag: String,
        htmlURL: URL,
        dmgURL: URL?,
        dmgDigest: String? = nil,
        signatureURL: URL? = nil,
        notes: String
    ) {
        self.version = version
        self.tag = tag
        self.htmlURL = htmlURL
        self.dmgURL = dmgURL
        self.dmgDigest = dmgDigest
        self.signatureURL = signatureURL
        self.notes = notes
    }
}

public enum AppUpdateResult: Sendable, Equatable {
    case upToDate(current: String)
    case updateAvailable(current: String, latest: AppRelease)
    case noReleases(repo: String)
    case unconfigured
}

public enum AppUpdateError: Error, Sendable, Equatable {
    case badResponse(Int)
    case invalidPayload
    case noDownloadAsset
    case downloadFailed
    case checksumMismatch
    case missingSignature
    case invalidSignature
    case mountFailed
    case appNotFoundInImage
    case codeSignatureInvalid
    case installFailed(String)
}

// MARK: - Ed25519 Update Signatures

public enum UpdateSignature {
    public static let publicKeyInfoKey = "CuratareUpdatePublicEDKey"

    /// The base64 Ed25519 public key that release DMGs must be signed with.
    public static var bundledPublicKey: String? {
        Bundle.main.object(forInfoDictionaryKey: publicKeyInfoKey) as? String
    }

    public static func configuredPublicKey(in bundle: Bundle = .main) -> String? {
        if let env = ProcessInfo.processInfo.environment["CURATARE_UPDATE_PUBLIC_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
            return env
        }
        if let key = (bundle.object(forInfoDictionaryKey: publicKeyInfoKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            return key
        }
        return nil
    }

    /// Returns true when `signatureBase64` is a valid Ed25519 signature of the file for `publicKeyBase64`.
    public static func isValid(fileURL: URL, signatureBase64: String, publicKeyBase64: String) throws -> Bool {
        guard
            let signature = Data(base64Encoded: signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
            let publicKeyData = Data(base64Encoded: publicKeyBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
            let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        else {
            return false
        }
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        return publicKey.isValidSignature(signature, for: data)
    }

    public static func verify(file: URL, signatureBase64: String, publicKeyBase64: String) -> Bool {
        (try? isValid(fileURL: file, signatureBase64: signatureBase64, publicKeyBase64: publicKeyBase64)) ?? false
    }

    public static func verify(data: Data, signatureBase64: String, publicKeyBase64: String) -> Bool {
        guard let rawKey = Data(base64Encoded: publicKeyBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
              let sig = Data(base64Encoded: signatureBase64.trimmingCharacters(in: .whitespacesAndNewlines)),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: rawKey) else {
            return false
        }
        return publicKey.isValidSignature(sig, for: data)
    }
}

// MARK: - SHA-256 Checksums

public enum UpdateChecksums {
    /// Parses `shasum -a 256` output into a file name → lowercase hex digest map.
    public static func parse(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2 else { continue }
            let digest = parts[0].lowercased()
            guard digest.count == 64, digest.allSatisfy(\.isHexDigit) else { continue }
            var fileName = parts[1].trimmingCharacters(in: .whitespaces)
            if fileName.hasPrefix("*") {
                fileName.removeFirst()
            }
            result[fileName] = digest
        }
        return result
    }

    /// Streams the file through SHA-256 and returns the lowercase hex digest.
    public static func sha256(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

public enum AppUpdater {
    public static func currentVersion(in bundle: Bundle = .main) -> String {
        (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0.0"
    }

    public static func configuredRepository(in bundle: Bundle = .main) -> String? {
        if let env = ProcessInfo.processInfo.environment["CURATARE_GITHUB_REPO"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           Self.isValidRepository(env) {
            return env
        }
        if let repo = (bundle.object(forInfoDictionaryKey: "CuratareRepository") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           Self.isValidRepository(repo) {
            return repo
        }
        return "berkbb/curatare-mac-universal"
    }

    static func isValidRepository(_ repo: String) -> Bool {
        let parts = repo.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return parts.allSatisfy { $0.unicodeScalars.allSatisfy { allowed.contains($0) } }
    }

    public static func isReleaseURL(_ url: URL, repository: String, download: Bool) -> Bool {
        guard url.scheme?.lowercased() == "https", url.host?.lowercased() == "github.com",
              url.user == nil, url.password == nil, url.port == nil || url.port == 443 else { return false }
        let prefix = "/" + repository.lowercased() + (download ? "/releases/download/" : "/releases/")
        return url.standardized.path.lowercased().hasPrefix(prefix)
    }

    public static func check(
        repository: String? = configuredRepository(),
        currentVersion: String = currentVersion(),
        session: URLSession = .shared
    ) async throws -> AppUpdateResult {
        guard let repo = repository, isValidRepository(repo) else { return .unconfigured }
        let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Curatare-Mac/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 {
                return .noReleases(repo: repo)
            }
            if !(200..<300).contains(http.statusCode) {
                throw AppUpdateError.badResponse(http.statusCode)
            }
        }
        let release = try parseRelease(from: data, repository: repo)
        if isNewer(release.version, than: currentVersion) {
            return .updateAvailable(current: currentVersion, latest: release)
        }
        return .upToDate(current: currentVersion)
    }

    public static func parseRelease(from data: Data, repository: String? = nil) throws -> AppRelease {
        struct Payload: Decodable {
            struct Asset: Decodable {
                let name: String
                let browser_download_url: String
                let digest: String?
            }
            let tag_name: String
            let html_url: String
            let body: String?
            let assets: [Asset]?
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let htmlURL = URL(string: payload.html_url) else {
            throw AppUpdateError.invalidPayload
        }
        if let repo = repository, !isReleaseURL(htmlURL, repository: repo, download: false) {
            throw AppUpdateError.invalidPayload
        }
        let tag = payload.tag_name
        guard !tag.isEmpty else { throw AppUpdateError.invalidPayload }
        let version = normalizeVersion(tag)
        let dmgAsset = payload.assets?.first { $0.name.lowercased().hasSuffix(".dmg") }
        let rawDmgURL = dmgAsset.flatMap { URL(string: $0.browser_download_url) }
        let dmgURL: URL? = {
            guard let url = rawDmgURL else { return nil }
            if let repo = repository, !isReleaseURL(url, repository: repo, download: true) {
                return nil
            }
            return url
        }()
        let sigAsset = dmgAsset.flatMap { dmg in
            payload.assets?.first { $0.name == dmg.name + ".sig" }
        }
        let rawSigURL = sigAsset.flatMap { URL(string: $0.browser_download_url) }
        let sigURL: URL? = {
            guard let url = rawSigURL else { return nil }
            if let repo = repository, !isReleaseURL(url, repository: repo, download: true) {
                return nil
            }
            return url
        }()
        return AppRelease(
            version: version,
            tag: tag,
            htmlURL: htmlURL,
            dmgURL: dmgURL,
            dmgDigest: dmgAsset?.digest,
            signatureURL: sigURL,
            notes: payload.body ?? ""
        )
    }

    public static func normalizeVersion(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        return s
    }

    public static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = normalizeVersion(candidate).split(separator: ".").map { Int($0) ?? 0 }
        let b = normalizeVersion(current).split(separator: ".").map { Int($0) ?? 0 }
        let count = max(a.count, b.count)
        for i in 0..<count {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }
}
