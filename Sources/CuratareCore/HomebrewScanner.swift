// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Homebrew temizlenebilir öğe modeli.
public struct HomebrewItem: Sendable, Codable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Codable, Equatable {
        case cachedDownload
        case oldVersion
        case orphanedDependency
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let details: String
    public let sizeBytes: Int64
    public var isSelected: Bool

    public init(
        id: String,
        kind: Kind,
        title: String,
        details: String,
        sizeBytes: Int64 = 0,
        isSelected: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.details = details
        self.sizeBytes = sizeBytes
        self.isSelected = isSelected
    }
}

/// Homebrew sistem durumu ve temizlik özeti.
public struct HomebrewStatus: Sendable, Equatable {
    public let isInstalled: Bool
    public let executableURL: URL?
    public let version: String?
    public let cacheDirectoryURL: URL?
    public let cacheSizeBytes: Int64
    public let cleanableItems: [HomebrewItem]
    public let unneededDependencies: [String]
    public let estimatedSpaceFreed: String?

    public var totalCleanableBytes: Int64 {
        cacheSizeBytes + cleanableItems.map(\.sizeBytes).reduce(0, +)
    }

    public static let notInstalled = HomebrewStatus(
        isInstalled: false,
        executableURL: nil,
        version: nil,
        cacheDirectoryURL: nil,
        cacheSizeBytes: 0,
        cleanableItems: [],
        unneededDependencies: [],
        estimatedSpaceFreed: nil
    )

    public init(
        isInstalled: Bool,
        executableURL: URL?,
        version: String?,
        cacheDirectoryURL: URL?,
        cacheSizeBytes: Int64,
        cleanableItems: [HomebrewItem],
        unneededDependencies: [String],
        estimatedSpaceFreed: String? = nil
    ) {
        self.isInstalled = isInstalled
        self.executableURL = executableURL
        self.version = version
        self.cacheDirectoryURL = cacheDirectoryURL
        self.cacheSizeBytes = cacheSizeBytes
        self.cleanableItems = cleanableItems
        self.unneededDependencies = unneededDependencies
        self.estimatedSpaceFreed = estimatedSpaceFreed
    }
}

/// Homebrew paket yöneticisi temizlik ve bakım denetleyicisi.
public struct HomebrewScanner: Sendable {
    public let brewPath: String?

    public init(brewPath: String? = nil) {
        if let brewPath {
            self.brewPath = brewPath
        } else {
            self.brewPath = Self.locateBrew()
        }
    }

    /// Sistemde Homebrew (`brew`) ikilisini bulur (`/opt/homebrew/bin/brew` veya `/usr/local/bin/brew`).
    public static func locateBrew() -> String? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew"
        ]
        for p in candidates where fm.isExecutableFile(atPath: p) {
            return p
        }
        return nil
    }

    /// Homebrew durumunu, önbellek boyutunu ve temizlenebilir adayları tarar.
    public func scan(isCancelled: () -> Bool = { false }) async -> HomebrewStatus {
        guard let path = brewPath, FileManager.default.isExecutableFile(atPath: path) else {
            return .notInstalled
        }
        let brewURL = URL(fileURLWithPath: path)
        let fm = FileManager.default

        let runner = CommandRunner(
            executableURL: brewURL,
            environmentOverrides: [
                "HOMEBREW_NO_AUTO_UPDATE": "1",
                "HOMEBREW_NO_ENV_HINTS": "1",
                "NONINTERACTIVE": "1"
            ]
        )

        // Üç `brew` çağrısı birbirinden bağımsız ve salt okunurdur; hepsi hemen başlar. En yavaşı `cleanup --dry-run`
        // (~7 sn, çoğu önek dizinlerindeki kırık bağlantı taraması) beklenirken diğerleri ve önbellek boyutu onunla birlikte biter.
        async let versionRun = try? runner.run(["--version"], timeout: 4)
        async let cleanupRun = Self.cleanupDryRun(runner)
        async let autoremoveRun = try? runner.run(["autoremove", "--dry-run"], timeout: 12)

        // 1. Önbellek Yolu ve Boyutu (Library/Caches/Homebrew)
        let home = NSHomeDirectory()
        let cacheURL = URL(fileURLWithPath: home).appendingPathComponent("Library/Caches/Homebrew", isDirectory: true)
        var cacheSizeBytes: Int64 = 0
        if fm.fileExists(atPath: cacheURL.path) {
            cacheSizeBytes = DiskSpace.size(of: cacheURL, isCancelled: isCancelled)
        }

        // 2. Sürüm bilgisi
        var version: String?
        if let res = await versionRun, res.exitCode == 0 {
            version = res.stdout.split(whereSeparator: \.isNewline).first.map(String.init)
        }

        // İptalde beklenmeyen `async let` çağrıları kapsamdan çıkarken iptal edilir; `CommandRunner` süreçleri sonlandırır.
        if isCancelled() {
            return HomebrewStatus(
                isInstalled: true,
                executableURL: brewURL,
                version: version,
                cacheDirectoryURL: cacheURL,
                cacheSizeBytes: cacheSizeBytes,
                cleanableItems: [],
                unneededDependencies: [],
                estimatedSpaceFreed: nil
            )
        }

        // 3. `brew cleanup --dry-run --prune=all -s` adayları ve tahmini tasarruf
        var items: [HomebrewItem] = []
        var estimatedSpace: String?
        if let cleanRes = await cleanupRun, cleanRes.exitCode == 0 {
            for line in cleanRes.stdout.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Would remove: ") {
                    let rest = String(trimmed.dropFirst("Would remove: ".count))
                    var pathPart = rest
                    var detailPart = rest

                    if let openParen = rest.lastIndex(of: "("), let closeParen = rest.lastIndex(of: ")"), openParen < closeParen {
                        let sizeStr = String(rest[rest.index(after: openParen)..<closeParen]).trimmingCharacters(in: .whitespaces)
                        pathPart = String(rest[..<openParen]).trimmingCharacters(in: .whitespaces)
                        detailPart = "\(pathPart) (\(sizeStr))"
                    }

                    let title = (pathPart as NSString).lastPathComponent
                    items.append(HomebrewItem(
                        id: pathPart,
                        kind: pathPart.contains("/Cellar/") ? .oldVersion : .cachedDownload,
                        title: title,
                        details: detailPart
                    ))
                } else if trimmed.contains("This operation would free approximately ") {
                    // ==> This operation would free approximately 14.4MB of disk space.
                    let prefix = "This operation would free approximately "
                    if let range = trimmed.range(of: prefix) {
                        let after = trimmed[range.upperBound...]
                        if let ofRange = after.range(of: " of disk space") {
                            estimatedSpace = String(after[..<ofRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                        } else {
                            estimatedSpace = String(after).trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
        }

        // 4. `brew autoremove --dry-run` adayları
        var unneeded: [String] = []
        if !isCancelled(), let autoRes = await autoremoveRun, autoRes.exitCode == 0 {
            for line in autoRes.stdout.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Would uninstall: ") {
                    let raw = String(trimmed.dropFirst("Would uninstall: ".count))
                    for part in raw.split(separator: ",") {
                        let name = part.trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty { unneeded.append(name) }
                    }
                } else if trimmed.hasPrefix("Would uninstall ") {
                    let name = String(trimmed.dropFirst("Would uninstall ".count)).trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { unneeded.append(name) }
                }
            }
        }

        return HomebrewStatus(
            isInstalled: true,
            executableURL: brewURL,
            version: version,
            cacheDirectoryURL: cacheURL,
            cacheSizeBytes: cacheSizeBytes,
            cleanableItems: items,
            unneededDependencies: unneeded,
            estimatedSpaceFreed: estimatedSpace
        )
    }

    /// `cleanup --dry-run --prune=all -s` hata verirse (zaman aşımı, başlatılamama) yalın `cleanup --dry-run` ile yeniden dener.
    private static func cleanupDryRun(_ runner: CommandRunner) async -> ProcessResult? {
        if let res = try? await runner.run(["cleanup", "--dry-run", "--prune=all", "-s"], timeout: 18) {
            return res
        }
        guard !Task.isCancelled else { return nil }
        return try? await runner.run(["cleanup", "--dry-run"], timeout: 12)
    }

    /// `brew cleanup` komutunu parametrelerle çalıştırır (`--prune=all`, `-s` scrub, `--prune-prefix`).
    @discardableResult
    public func executeCleanup(
        pruneAll: Bool = true,
        scrub: Bool = true,
        prunePrefix: Bool = false
    ) async throws -> ProcessResult {
        guard let path = brewPath, FileManager.default.isExecutableFile(atPath: path) else {
            throw EngineError.engineNotFound
        }
        let runner = CommandRunner(
            executableURL: URL(fileURLWithPath: path),
            environmentOverrides: [
                "HOMEBREW_NO_AUTO_UPDATE": "1",
                "HOMEBREW_NO_ENV_HINTS": "1",
                "NONINTERACTIVE": "1"
            ]
        )
        var args = ["cleanup"]
        if pruneAll { args.append("--prune=all") }
        if scrub { args.append("-s") }
        if prunePrefix { args.append("--prune-prefix") }
        return try await runner.run(args, timeout: 90)
    }

    /// `brew autoremove` komutunu çalıştırarak kullanılmayan yetim bağımlılıkları kaldırır.
    @discardableResult
    public func executeAutoremove() async throws -> ProcessResult {
        guard let path = brewPath, FileManager.default.isExecutableFile(atPath: path) else {
            throw EngineError.engineNotFound
        }
        let runner = CommandRunner(
            executableURL: URL(fileURLWithPath: path),
            environmentOverrides: [
                "HOMEBREW_NO_AUTO_UPDATE": "1",
                "HOMEBREW_NO_ENV_HINTS": "1",
                "NONINTERACTIVE": "1"
            ]
        )
        return try await runner.run(["autoremove"], timeout: 90)
    }

    /// `brew services cleanup` komutunu çalıştırarak kullanılmayan/artık servis tanımlarını temizler.
    @discardableResult
    public func executeServicesCleanup() async throws -> ProcessResult {
        guard let path = brewPath, FileManager.default.isExecutableFile(atPath: path) else {
            throw EngineError.engineNotFound
        }
        let runner = CommandRunner(
            executableURL: URL(fileURLWithPath: path),
            environmentOverrides: [
                "HOMEBREW_NO_AUTO_UPDATE": "1",
                "HOMEBREW_NO_ENV_HINTS": "1",
                "NONINTERACTIVE": "1"
            ]
        )
        return try await runner.run(["services", "cleanup"], timeout: 60)
    }

    /// Sistemde kurulu tüm Homebrew formüllerini ve Cask GUI uygulamalarını tarar.
    public func scanPackages(isCancelled: () -> Bool = { false }) async -> [HomebrewPackage] {
        guard let path = brewPath, FileManager.default.isExecutableFile(atPath: path) else {
            return []
        }
        let brewURL = URL(fileURLWithPath: path)
        let fm = FileManager.default

        let binDir = (path as NSString).deletingLastPathComponent
        let baseDir = (binDir as NSString).deletingLastPathComponent
        let cellarPath = "\(baseDir)/Cellar"
        let caskroomPath = "\(baseDir)/Caskroom"

        let runner = CommandRunner(
            executableURL: brewURL,
            environmentOverrides: [
                "HOMEBREW_NO_AUTO_UPDATE": "1",
                "HOMEBREW_NO_ENV_HINTS": "1",
                "NONINTERACTIVE": "1"
            ]
        )

        // 1. `brew info --json=v2 --installed` çalıştırmayı dene
        if let res = try? await runner.run(["info", "--json=v2", "--installed"], timeout: 25), res.exitCode == 0,
           let data = res.stdout.data(using: .utf8),
           let payload = try? JSONDecoder().decode(HomebrewInfoPayload.self, from: data) {

            // Boyutlar paket paket değil, tek bir paralel gezintide hesaplanır: önce her paketin ölçülecek kökleri toplanır.
            var sizing = PackageSizing()

            for f in payload.formulae ?? [] {
                if isCancelled() { break }
                let ver = f.installed?.first?.version ?? "unknown"
                let onReq = f.installed?.first?.installed_on_request ?? true
                let fPath = "\(cellarPath)/\(f.name)/\(ver)"
                let exists = fm.fileExists(atPath: fPath)
                sizing.add(roots: exists ? [fPath] : []) { size in
                    HomebrewPackage(
                        id: f.name,
                        name: f.full_name ?? f.name,
                        kind: .formula,
                        version: ver,
                        description: f.desc ?? "",
                        homepage: f.homepage,
                        path: exists ? fPath : nil,
                        sizeBytes: size,
                        isInstalledOnRequest: onReq,
                        isDependency: !onReq,
                        dependencies: f.dependencies ?? [],
                        dependents: [],
                        caveats: f.caveats
                    )
                }
            }

            for c in payload.casks ?? [] {
                if isCancelled() { break }
                let ver = c.installed ?? c.version ?? "unknown"
                let cName = c.name?.first ?? c.token
                let cPath = "\(caskroomPath)/\(c.token)/\(ver)"
                let exists = fm.fileExists(atPath: cPath)
                var roots = exists ? [cPath] : []

                // Caskroom metadata haricinde, /Applications altındaki asıl GUI uygulamasının gerçek boyutunu ekle/kontrol et
                // (paket boyutu, ölçülen köklerin en büyüğüdür)
                let homeDir = NSHomeDirectory()
                let candidateAppNames = [cName, c.token, cName.replacingOccurrences(of: " ", with: "")]
                for candidate in candidateAppNames {
                    let appPath = "/Applications/\(candidate).app"
                    let userAppPath = "\(homeDir)/Applications/\(candidate).app"
                    if fm.fileExists(atPath: appPath) {
                        roots.append(appPath)
                        break
                    } else if fm.fileExists(atPath: userAppPath) {
                        roots.append(userAppPath)
                        break
                    }
                }

                sizing.add(roots: roots) { size in
                    HomebrewPackage(
                        id: c.token,
                        name: cName,
                        kind: .cask,
                        version: ver,
                        description: c.desc ?? "",
                        homepage: c.homepage,
                        path: exists ? cPath : nil,
                        sizeBytes: size,
                        isInstalledOnRequest: true,
                        isDependency: false,
                        dependencies: [],
                        dependents: [],
                        caveats: c.caveats
                    )
                }
            }

            let result = sizing.packages(isCancelled: isCancelled)
            return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        // 2. Fallback: Cellar ve Caskroom doğrudan dosya sistemi taraması
        var sizing = PackageSizing()
        for (root, kind) in [(cellarPath, HomebrewPackage.Kind.formula), (caskroomPath, .cask)] {
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for item in entries where !item.hasPrefix(".") {
                if isCancelled() { break }
                let itemDir = "\(root)/\(item)"
                let versions = (try? fm.contentsOfDirectory(atPath: itemDir))?.filter { !$0.hasPrefix(".") } ?? []
                let ver = versions.first ?? "unknown"
                let p = "\(itemDir)/\(ver)"
                sizing.add(roots: fm.fileExists(atPath: p) ? [p] : []) { size in
                    HomebrewPackage(
                        id: item,
                        name: item,
                        kind: kind,
                        version: ver,
                        path: p,
                        sizeBytes: size
                    )
                }
            }
        }
        let fallback = sizing.packages(isCancelled: isCancelled)
        return fallback.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Belirtilen Homebrew paketini kaldırır (`brew uninstall [--formula/--cask] [--zap] <id>`).
    @discardableResult
    public func uninstallPackage(id: String, isCask: Bool, zap: Bool = false) async throws -> ProcessResult {
        guard let path = brewPath, FileManager.default.isExecutableFile(atPath: path) else {
            throw EngineError.engineNotFound
        }
        let runner = CommandRunner(
            executableURL: URL(fileURLWithPath: path),
            environmentOverrides: [
                "HOMEBREW_NO_AUTO_UPDATE": "1",
                "HOMEBREW_NO_ENV_HINTS": "1",
                "NONINTERACTIVE": "1"
            ]
        )
        var args = ["uninstall"]
        if isCask {
            args.append("--cask")
            if zap { args.append("--zap") }
        } else {
            args.append("--formula")
        }
        args.append(id)
        return try await runner.run(args, timeout: 120)
    }

    /// Birden fazla Homebrew paketini topluca kaldırır.
    @discardableResult
    public func uninstallPackages(packages: [HomebrewPackage], zapCasks: Bool = false) async throws -> [ProcessResult] {
        guard !packages.isEmpty else { return [] }
        guard let path = brewPath, FileManager.default.isExecutableFile(atPath: path) else {
            throw EngineError.engineNotFound
        }
        let formulae = packages.filter { $0.kind == .formula }.map(\.id)
        let casks = packages.filter { $0.kind == .cask }.map(\.id)
        var results: [ProcessResult] = []

        let runner = CommandRunner(
            executableURL: URL(fileURLWithPath: path),
            environmentOverrides: [
                "HOMEBREW_NO_AUTO_UPDATE": "1",
                "HOMEBREW_NO_ENV_HINTS": "1",
                "NONINTERACTIVE": "1"
            ]
        )

        if !formulae.isEmpty {
            let res = try await runner.run(["uninstall", "--formula"] + formulae, timeout: 180)
            results.append(res)
        }
        for caskID in casks {
            var args = ["uninstall", "--cask"]
            if zapCasks { args.append("--zap") }
            args.append(caskID)
            let res = try await runner.run(args, timeout: 120)
            results.append(res)
        }
        return results
    }
}

// MARK: - Package Sizing

/// Paket taslaklarını biriktirir; tüm kökleri tek `DiskSpace.sizes(of:)` çağrısıyla ölçüp paketleri kurar.
/// Bir paketin boyutu, köklerinin en büyüğüdür (kök yoksa 0).
private struct PackageSizing {
    private var roots: [URL] = []
    private var drafts: [(rootIndices: Range<Int>, make: (Int64) -> HomebrewPackage)] = []

    mutating func add(roots paths: [String], make: @escaping (Int64) -> HomebrewPackage) {
        let first = roots.count
        roots.append(contentsOf: paths.map { URL(fileURLWithPath: $0) })
        drafts.append((first..<roots.count, make))
    }

    func packages(isCancelled: () -> Bool) -> [HomebrewPackage] {
        let sizes = DiskSpace.sizes(of: roots, isCancelled: isCancelled)
        return drafts.map { draft in draft.make(sizes[draft.rootIndices].max() ?? 0) }
    }
}

// MARK: - Homebrew JSON DTO Helpers

private struct HomebrewInfoFormulaInstalled: Decodable {
    let version: String?
    let installed_on_request: Bool?
}

private struct HomebrewInfoFormula: Decodable {
    let name: String
    let full_name: String?
    let desc: String?
    let homepage: String?
    let installed: [HomebrewInfoFormulaInstalled]?
    let dependencies: [String]?
    let caveats: String?
}

private struct HomebrewInfoCask: Decodable {
    let token: String
    let name: [String]?
    let desc: String?
    let homepage: String?
    let version: String?
    let installed: String?
    let caveats: String?
}

private struct HomebrewInfoPayload: Decodable {
    let formulae: [HomebrewInfoFormula]?
    let casks: [HomebrewInfoCask]?
}

// MARK: - Homebrew Package Filter

public enum HomebrewFilterKind: String, Sendable, Codable, Equatable, CaseIterable {
    case all
    case formulae
    case casks
    case orphans
}

/// Homebrew kurulu paket (Formül veya Cask) modeli.
public struct HomebrewPackage: Sendable, Codable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Codable, Equatable, CaseIterable {
        case formula
        case cask
    }

    public let id: String
    public let name: String
    public let kind: Kind
    public let version: String
    public let description: String
    public let homepage: String?
    public let path: String?
    public let sizeBytes: Int64
    public let isInstalledOnRequest: Bool
    public let isDependency: Bool
    public let dependencies: [String]
    public let dependents: [String]
    public let caveats: String?
    public var isSelected: Bool

    public init(
        id: String,
        name: String,
        kind: Kind,
        version: String,
        description: String = "",
        homepage: String? = nil,
        path: String? = nil,
        sizeBytes: Int64 = 0,
        isInstalledOnRequest: Bool = true,
        isDependency: Bool = false,
        dependencies: [String] = [],
        dependents: [String] = [],
        caveats: String? = nil,
        isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.version = version
        self.description = description
        self.homepage = homepage
        self.path = path
        self.sizeBytes = sizeBytes
        self.isInstalledOnRequest = isInstalledOnRequest
        self.isDependency = isDependency
        self.dependencies = dependencies
        self.dependents = dependents
        self.caveats = caveats
        self.isSelected = isSelected
    }
}
