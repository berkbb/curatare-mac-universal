// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// `library_clean.md` içindeki genişletilmiş tarayıcılar:
/// 1. GitHub proje derleme çıktıları (`build`, `.build`, `.gradle`, `.kotlin`, `.cxx`, `app/build`, `dist`)
/// 2. Yapay zekâ araçları ayak izi (`codex-runtime-install-*`, eski `.antigravity`, `CachedExtensionVSIXs`, `Claude-3p`, `Ollama` modelleri)
/// 3. Tarayıcı site verileri (`IndexedDB`, `File System`), eski uygulama/Gradle/Dart önbellekleri, Office kilit dosyaları ve `.dmg`/`.pkg` yükleyicileri
/// 4. Time Machine yerel anlık görüntüleri (`tmutil listlocalsnapshots /` ve `thinlocalsnapshots`)
public struct RepoBuildArtifact: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let repoName: String
    public let repoURL: URL
    public let artifactURL: URL
    public let relativePath: String
    public let sizeBytes: Int64
    public let containsTrackedFiles: Bool
    public var isSelected: Bool

    public init(
        repoName: String,
        repoURL: URL,
        artifactURL: URL,
        relativePath: String,
        sizeBytes: Int64,
        containsTrackedFiles: Bool = false,
        isSelected: Bool? = nil
    ) {
        self.id = artifactURL.path
        self.repoName = repoName
        self.repoURL = repoURL
        self.artifactURL = artifactURL
        self.relativePath = relativePath
        self.sizeBytes = sizeBytes
        self.containsTrackedFiles = containsTrackedFiles
        self.isSelected = isSelected ?? !containsTrackedFiles
    }
}

public struct AIFootprintItem: Sendable, Codable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Codable, Equatable {
        case staleRuntime
        case legacyConfig
        case extensionCache
        case orphanedDesktopData
        case ollamaModel
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let url: URL?
    public let ollamaModelName: String?
    public let sizeBytes: Int64
    public let detail: String
    public let isCloudOnly: Bool
    public var isSelected: Bool

    public init(
        id: String? = nil,
        kind: Kind,
        title: String,
        url: URL? = nil,
        ollamaModelName: String? = nil,
        sizeBytes: Int64,
        detail: String,
        isCloudOnly: Bool = false,
        isSelected: Bool = true
    ) {
        self.id = id ?? url?.path ?? ollamaModelName ?? title
        self.kind = kind
        self.title = title
        self.url = url
        self.ollamaModelName = ollamaModelName
        self.sizeBytes = sizeBytes
        self.detail = detail
        self.isCloudOnly = isCloudOnly
        self.isSelected = isSelected
    }
}

public struct HeavyCacheItem: Sendable, Codable, Equatable, Identifiable {
    public enum Category: String, Sendable, Codable, CaseIterable {
        case browserCache
        case browserSiteData
        case safariTempCookies
        case mailDownloads
        case iosDeviceBackup
        case partialDownload
        case windowsMetadata
        case crashDump
        case shellSessions
        case dynamicWallpaperCache
        case quickTimeAutosave
        case appVersionCache
        case unusedGradleCache
        case dartAnalysisCache
        case officeLockFile
        case diskInstaller
        case audioUnitsCache
        case previousMusicLibraries
        case xcodeArchives
    }

    public enum FilterGroup: String, Sendable, Codable, CaseIterable {
        case all
        case browsers
        case mailAndBackups
        case systemAndLogs
        case mediaAndWallpapers
        case updatesAndInstallers
    }

    public let id: String
    public let category: Category
    public let title: String
    public let ownerApp: String
    public let url: URL
    public let sizeBytes: Int64
    public let explanation: String
    public var isSelected: Bool

    public var filterGroup: FilterGroup {
        switch category {
        case .browserCache, .browserSiteData, .safariTempCookies:
            return .browsers
        case .mailDownloads, .iosDeviceBackup, .partialDownload:
            return .mailAndBackups
        case .windowsMetadata, .crashDump, .shellSessions:
            return .systemAndLogs
        case .dynamicWallpaperCache, .quickTimeAutosave, .audioUnitsCache, .previousMusicLibraries:
            return .mediaAndWallpapers
        case .appVersionCache, .unusedGradleCache, .dartAnalysisCache, .officeLockFile, .diskInstaller, .xcodeArchives:
            return .updatesAndInstallers
        }
    }

    public var categoryLKey: LKey {
        switch category {
        case .browserCache, .browserSiteData, .safariTempCookies:
            return .cachesCategoryBrowser
        case .mailDownloads:
            return .cachesCategoryMailDownloads
        case .iosDeviceBackup:
            return .cachesCategoryIOSBackups
        case .partialDownload:
            return .cachesCategoryPartialDownloads
        case .windowsMetadata:
            return .cachesCategoryWindowsMetadata
        case .crashDump:
            return .cachesCategoryCrashDumps
        case .shellSessions:
            return .cachesCategoryShellSessions
        case .dynamicWallpaperCache:
            return .cachesCategoryWallpapers
        case .quickTimeAutosave:
            return .cachesCategoryQuickTime
        case .appVersionCache:
            return .cachesCategoryAppVersion
        case .unusedGradleCache:
            return .cachesCategoryGradle
        case .dartAnalysisCache:
            return .cachesCategoryDart
        case .officeLockFile:
            return .cachesCategoryLockFiles
        case .diskInstaller:
            return .cachesCategoryInstallers
        case .audioUnitsCache:
            return .cachesCategoryAudioUnits
        case .previousMusicLibraries:
            return .cachesCategoryPreviousMusicLibraries
        case .xcodeArchives:
            return .cachesCategoryXcodeArchives
        }
    }

    public var iconName: String {
        switch category {
        case .browserCache, .browserSiteData, .safariTempCookies:
            return "globe"
        case .mailDownloads:
            return "envelope.badge"
        case .iosDeviceBackup:
            return "iphone.gen3"
        case .partialDownload:
            return "arrow.down.circle"
        case .windowsMetadata:
            return "doc.badge.gearshape"
        case .crashDump:
            return "exclamationmark.triangle"
        case .shellSessions:
            return "terminal"
        case .dynamicWallpaperCache:
            return "display"
        case .quickTimeAutosave:
            return "play.rectangle"
        case .appVersionCache:
            return "clock.arrow.circlepath"
        case .unusedGradleCache, .dartAnalysisCache:
            return "hammer"
        case .officeLockFile:
            return "lock.doc"
        case .diskInstaller:
            return "opticaldisc"
        case .audioUnitsCache:
            return "waveform"
        case .previousMusicLibraries:
            return "music.note.list"
        case .xcodeArchives:
            return "archivebox.circle"
        }
    }

    public var processToVerify: String? {
        switch category {
        case .browserCache, .browserSiteData:
            return ownerApp
        case .mailDownloads:
            return "Mail"
        case .quickTimeAutosave:
            return "QuickTime Player"
        default:
            return nil
        }
    }

    public init(
        category: Category,
        title: String,
        ownerApp: String,
        url: URL,
        sizeBytes: Int64,
        explanation: String,
        isSelected: Bool = true
    ) {
        self.id = url.path
        self.category = category
        self.title = title
        self.ownerApp = ownerApp
        self.url = url
        self.sizeBytes = sizeBytes
        self.explanation = explanation
        self.isSelected = isSelected
    }
}

public struct TimeMachineSnapshot: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let dateStamp: String

    public init(id: String, dateStamp: String) {
        self.id = id
        self.dateStamp = dateStamp
    }
}

/// Dil ve ekosistem paket yöneticisi önbellek öğesi (Python, JS/TS, Rust, Go, Ruby, JVM, .NET, Swift, Sürüm Yöneticileri ve Korumalı macOS Sistem Çalışma Zamanları).
public struct LanguageEcosystemItem: Sendable, Codable, Equatable, Identifiable {
    public enum Ecosystem: String, Sendable, Codable, CaseIterable {
        case macosSystemRuntime
        case python
        case javascriptNode
        case rust
        case goLang
        case ruby
        case php
        case jvm
        case dotnet
        case swift
        case dartFlutter
        case versionManager
        case otherEcosystem

        public var titleTR: String {
            switch self {
            case .macosSystemRuntime: return "macOS Sistem Çalışma Zamanları"
            case .python: return "Python (pip, uv, poetry, conda)"
            case .javascriptNode: return "JavaScript / TypeScript (npm, pnpm, yarn, bun, deno)"
            case .rust: return "Rust (cargo)"
            case .goLang: return "Go (go-build, mod cache)"
            case .ruby: return "Ruby (gem, bundler)"
            case .php: return "PHP (composer)"
            case .jvm: return "JVM / Java / Kotlin / Scala (gradle, maven, coursier)"
            case .dotnet: return ".NET / C# (nuget)"
            case .swift: return "Swift (spm, cocoapods, carthage)"
            case .dartFlutter: return "Dart / Flutter (pub)"
            case .versionManager: return "Sürüm Yöneticileri (mise, asdf, nvm, pyenv, rustup, sdkman)"
            case .otherEcosystem: return "Diğer Ekosistemler (hex, cabal, luarocks, R, cpan)"
            }
        }
    }

    public enum Origin: String, Sendable, Codable, CaseIterable {
        case macosSystem
        case homebrew
        case userStandalone

        public var titleTR: String {
            switch self {
            case .macosSystem: return "macOS Sistem"
            case .homebrew: return "Homebrew"
            case .userStandalone: return "Kullanıcı / Bağımsız"
            }
        }

        public var titleEN: String {
            switch self {
            case .macosSystem: return "macOS System"
            case .homebrew: return "Homebrew"
            case .userStandalone: return "User / Standalone"
            }
        }

        public var titleRO: String {
            switch self {
            case .macosSystem: return "Sistem macOS"
            case .homebrew: return "Homebrew"
            case .userStandalone: return "Utilizator / Independent"
            }
        }
    }

    public let id: String
    public let ecosystem: Ecosystem
    public let origin: Origin
    public let toolName: String
    public let path: String
    public let url: URL
    public let sizeBytes: Int64
    public let explanation: String
    public let isSystemProtected: Bool
    public var isSelected: Bool

    public init(
        id: String? = nil,
        ecosystem: Ecosystem,
        origin: Origin = .userStandalone,
        toolName: String,
        path: String,
        url: URL,
        sizeBytes: Int64,
        explanation: String,
        isSystemProtected: Bool = false,
        isSelected: Bool? = nil
    ) {
        self.id = id ?? url.path
        self.ecosystem = ecosystem
        let effectiveOrigin = (isSystemProtected || ecosystem == .macosSystemRuntime) ? .macosSystem : origin
        self.origin = effectiveOrigin
        self.toolName = toolName
        self.path = path
        self.url = url
        self.sizeBytes = sizeBytes
        self.explanation = explanation
        let protected = (effectiveOrigin == .macosSystem) || isSystemProtected
        self.isSystemProtected = protected
        self.isSelected = isSelected ?? (!protected && sizeBytes > 0)
    }
}

/// Dil ve ekosistem Master-Detail filtre türleri.
public enum LanguageEcosystemFilterKind: String, Sendable, Codable, CaseIterable {
    case all
    case python
    case nodeJS
    case rust
    case goLang
    case ruby
    case jvm
    case dotnet
    case swift
    case dart
    case versionManagers
    case otherEcosystems
    case systemRuntimes
}

/// Önbellek alt dizin / dosya boyutu inceleme modeli.
public struct CacheSubdirectoryInfo: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let sizeBytes: Int64
    public let isDirectory: Bool

    public init(id: String, name: String, sizeBytes: Int64, isDirectory: Bool) {
        self.id = id
        self.name = name
        self.sizeBytes = sizeBytes
        self.isDirectory = isDirectory
    }
}

public struct ExtendedScanners: Sendable {
    /// Kullanıcıya gösterilen açıklama ve gerekçelerin dili; metinler `Localizable.strings` tablolarından gelir.
    public var language: String = "en"

    /// Aynı yapılandırmanın verilen dilde metin üreten kopyası.
    public func localized(to code: String) -> ExtendedScanners {
        var copy = self
        copy.language = code
        return copy
    }

    public let homeDirectoryURL: URL
    public let githubDirectoryURL: URL
    public let applicationsDirectoryURL: URL

    public static let buildDirNames: Set<String> = [
        "build", ".build", ".gradle", ".kotlin", ".cxx", ".deriveddata", "dist", "node_modules", "target",
    ]

    public init(
        homeDirectoryURL: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        githubDirectoryURL: URL? = nil,
        applicationsDirectoryURL: URL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    ) {
        self.homeDirectoryURL = homeDirectoryURL
        self.githubDirectoryURL = githubDirectoryURL ?? homeDirectoryURL.appendingPathComponent("Documents/GitHub", isDirectory: true)
        self.applicationsDirectoryURL = applicationsDirectoryURL
    }

    // MARK: - 1. GitHub Derleme Çıktıları (`library_clean.md` — GitHub Klasörü)

    public func scanGitHubBuildArtifacts(
        excludeRepoPath: String? = nil,
        isCancelled: () -> Bool = { false }
    ) async -> [RepoBuildArtifact] {
        let fm = FileManager.default
        guard let repos = try? fm.contentsOfDirectory(at: githubDirectoryURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var results: [RepoBuildArtifact] = []
        let gitURL = URL(fileURLWithPath: "/usr/bin/git")
        let hasGit = fm.isExecutableFile(atPath: gitURL.path)

        for repo in repos {
            if isCancelled() { break }
            if let excludeRepoPath, repo.standardizedFileURL.path == (excludeRepoPath as NSString).standardizingPath {
                continue
            }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: repo.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let candidateRelPaths = ["build", ".build", "app/build", ".gradle", ".kotlin", "app/.cxx", ".deriveddata", "dist"]
            for rel in candidateRelPaths {
                if isCancelled() { break }
                let artifactURL = repo.appendingPathComponent(rel, isDirectory: true)
                guard fm.fileExists(atPath: artifactURL.path, isDirectory: &isDir), isDir.boolValue else { continue }

                let size = DiskSpace.size(of: artifactURL, isCancelled: isCancelled)
                guard size > 0 else { continue }

                var hasTracked = false
                if hasGit, fm.fileExists(atPath: repo.appendingPathComponent(".git").path) {
                    let runner = CommandRunner(executableURL: gitURL)
                    if let res = try? await runner.run(["-C", repo.path, "ls-files", rel], timeout: 5),
                       res.exitCode == 0,
                       !res.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        hasTracked = true
                    }
                }

                results.append(RepoBuildArtifact(
                    repoName: repo.lastPathComponent,
                    repoURL: repo,
                    artifactURL: artifactURL,
                    relativePath: rel,
                    sizeBytes: size,
                    containsTrackedFiles: hasTracked
                ))
            }
        }

        return results.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// Depolardaki `gradle/wrapper/gradle-wrapper.properties` dosyalarından aktif kullanılan Gradle sürümlerini bulur.
    public func discoverActiveGradleVersions() -> Set<String> {
        let fm = FileManager.default
        var versions: Set<String> = []
        guard let repos = try? fm.contentsOfDirectory(at: githubDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return versions
        }
        let pattern = #"gradle-([0-9]+(?:\.[0-9]+)+)-"#
        let regex = try? NSRegularExpression(pattern: pattern)
        for repo in repos {
            let propURL = repo.appendingPathComponent("gradle/wrapper/gradle-wrapper.properties")
            guard let text = try? String(contentsOf: propURL, encoding: .utf8),
                  let regex else { continue }
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for m in matches {
                if let r = Range(m.range(at: 1), in: text) {
                    versions.insert(String(text[r]))
                }
            }
        }
        return versions
    }

    // MARK: - 2. Yapay Zekâ Araçları Ayak İzi (`library_clean.md` — Yapay Zekâ Araçları)

    public func scanAIFootprint(
        includeOllama: Bool = true,
        isCancelled: () -> Bool = { false }
    ) async -> [AIFootprintItem] {
        let fm = FileManager.default
        var items: [AIFootprintItem] = []

        // a) `~/.cache/codex-runtimes/codex-runtime-install-*` yarım kalmış geçici kurulum klasörleri
        let codexRuntimesDir = homeDirectoryURL.appendingPathComponent(".cache/codex-runtimes", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: codexRuntimesDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where entry.lastPathComponent.hasPrefix("codex-runtime-install-") {
                if isCancelled() { break }
                let size = DiskSpace.size(of: entry, isCancelled: isCancelled)
                items.append(AIFootprintItem(
                    kind: .staleRuntime,
                    title: entry.lastPathComponent,
                    url: entry,
                    sizeBytes: size,
                    detail: "Temporary Codex runtime install staging directory (codex-primary-runtime is preserved)"
                ))
            }
        }

        // b) `~/.antigravity-ide` mevcutken eski `~/.antigravity` klasörü (`library_clean.md`)
        let newAgy = homeDirectoryURL.appendingPathComponent(".antigravity-ide")
        let oldAgy = homeDirectoryURL.appendingPathComponent(".antigravity")
        if fm.fileExists(atPath: newAgy.path), fm.fileExists(atPath: oldAgy.path) {
            let size = DiskSpace.size(of: oldAgy, isCancelled: isCancelled)
            items.append(AIFootprintItem(
                kind: .legacyConfig,
                title: ".antigravity",
                url: oldAgy,
                sizeBytes: size,
                detail: "Legacy .antigravity folder superseded by active .antigravity-ide"
            ))
        }

        // c) `CachedExtensionVSIXs` (kurulmuş eklentilerin `.vsix` kurulum paketleri)
        let vsixCandidates = [
            homeDirectoryURL.appendingPathComponent("Library/Application Support/Antigravity/CachedExtensionVSIXs"),
            homeDirectoryURL.appendingPathComponent("Library/Application Support/Code/CachedExtensionVSIXs"),
            homeDirectoryURL.appendingPathComponent("Library/Application Support/Cursor/CachedExtensionVSIXs"),
        ]
        for vsix in vsixCandidates where fm.fileExists(atPath: vsix.path) {
            let size = DiskSpace.size(of: vsix, isCancelled: isCancelled)
            if size > 0 {
                items.append(AIFootprintItem(
                    kind: .extensionCache,
                    title: "\(vsix.deletingLastPathComponent().lastPathComponent) / CachedExtensionVSIXs",
                    url: vsix,
                    sizeBytes: size,
                    detail: "Downloaded .vsix installer packages of already-installed IDE extensions"
                ))
            }
        }

        // d) `Claude-3p` (`~/Library/Application Support/Claude-3p` ve `~/Library/Caches/Claude-3p` — `library_clean.md`)
        let claude3pCandidates = [
            homeDirectoryURL.appendingPathComponent("Library/Application Support/Claude-3p", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Caches/Claude-3p", isDirectory: true),
        ]
        for claude3p in claude3pCandidates where fm.fileExists(atPath: claude3p.path) {
            let size = DiskSpace.size(of: claude3p, isCancelled: isCancelled)
            if size > 0 {
                items.append(AIFootprintItem(
                    kind: .orphanedDesktopData,
                    title: "\(claude3p.deletingLastPathComponent().lastPathComponent)/Claude-3p",
                    url: claude3p,
                    sizeBytes: size,
                    detail: "Legacy secondary Claude desktop profile and runtime cache"
                ))
            }
        }

        // e) `Codex.app` kurulu değilken `~/Library/Application Support/Codex` masaüstü uygulama artığı (`~/.codex` korunur!)
        let codexApp = applicationsDirectoryURL.appendingPathComponent("Codex.app")
        let codexAppSupport = homeDirectoryURL.appendingPathComponent("Library/Application Support/Codex")
        if !fm.fileExists(atPath: codexApp.path), fm.fileExists(atPath: codexAppSupport.path) {
            let size = DiskSpace.size(of: codexAppSupport, isCancelled: isCancelled)
            items.append(AIFootprintItem(
                kind: .orphanedDesktopData,
                title: "Application Support/Codex",
                url: codexAppSupport,
                sizeBytes: size,
                detail: "Codex desktop app data while Codex.app is uninstalled (~/.codex CLI state is protected)"
            ))
        }

        // f) Bionic / LM Studio artıkları (`library_clean.md`: 5–6 GB; Bionic.app ve LM Studio.app kurulu değilse)
        let bionicApp = applicationsDirectoryURL.appendingPathComponent("Bionic.app")
        let lmStudioApp = applicationsDirectoryURL.appendingPathComponent("LM Studio.app")
        if !fm.fileExists(atPath: bionicApp.path) && !fm.fileExists(atPath: lmStudioApp.path) {
            let bionicCandidates: [(title: String, url: URL, detail: String)] = [
                ("~/.lmstudio", homeDirectoryURL.appendingPathComponent(".lmstudio", isDirectory: true), "LM Studio / Bionic local model weights and runtime library"),
                (".lmstudio-home-pointer", homeDirectoryURL.appendingPathComponent(".lmstudio-home-pointer"), "LM Studio home directory pointer file"),
                ("Application Support/Bionic", homeDirectoryURL.appendingPathComponent("Library/Application Support/Bionic", isDirectory: true), "Bionic desktop application state"),
                ("Application Support/LM Studio", homeDirectoryURL.appendingPathComponent("Library/Application Support/LM Studio", isDirectory: true), "LM Studio desktop application state"),
                ("Caches/ai.elementlabs.bionic", homeDirectoryURL.appendingPathComponent("Library/Caches/ai.elementlabs.bionic", isDirectory: true), "Bionic cache directory"),
                ("Caches/com.electron.lm-studio", homeDirectoryURL.appendingPathComponent("Library/Caches/com.electron.lm-studio", isDirectory: true), "LM Studio cache directory"),
                ("Preferences/ai.elementlabs.bionic.plist", homeDirectoryURL.appendingPathComponent("Library/Preferences/ai.elementlabs.bionic.plist"), "Bionic preferences plist"),
            ]
            for cand in bionicCandidates where fm.fileExists(atPath: cand.url.path) {
                let size = DiskSpace.size(of: cand.url, isCancelled: isCancelled)
                if size > 0 {
                    items.append(AIFootprintItem(
                        kind: .orphanedDesktopData,
                        title: cand.title,
                        url: cand.url,
                        sizeBytes: size,
                        detail: cand.detail
                    ))
                }
            }
        }

        // g) `~/python313_srt` (eski Whisper Python sanal ortamı — `library_clean.md`)
        let pySrt = homeDirectoryURL.appendingPathComponent("python313_srt", isDirectory: true)
        if fm.fileExists(atPath: pySrt.path) {
            let size = DiskSpace.size(of: pySrt, isCancelled: isCancelled)
            if size > 0 {
                items.append(AIFootprintItem(
                    kind: .staleRuntime,
                    title: "python313_srt",
                    url: pySrt,
                    sizeBytes: size,
                    detail: "Legacy Python SRT/Whisper virtual environment (superseded by Homebrew python@3.13)"
                ))
            }
        }

        // h) `~/.local/share/junie` (JetBrains Junie yapay zekâ kod asistanı önbellek artığı — `library_clean.md`)
        let junieDir = homeDirectoryURL.appendingPathComponent(".local/share/junie", isDirectory: true)
        if fm.fileExists(atPath: junieDir.path) {
            let size = DiskSpace.size(of: junieDir, isCancelled: isCancelled)
            if size > 0 {
                items.append(AIFootprintItem(
                    kind: .staleRuntime,
                    title: ".local/share/junie",
                    url: junieDir,
                    sizeBytes: size,
                    detail: "JetBrains Junie AI code completion local engine cache"
                ))
            }
        }

        // f) `ollama list` çıktısı (varsa)
        if includeOllama {
            let ollamaPaths = ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama"]
            if let ollamaBin = ollamaPaths.first(where: { fm.isExecutableFile(atPath: $0) }) {
                let runner = CommandRunner(executableURL: URL(fileURLWithPath: ollamaBin))
                if let res = try? await runner.run(["list"], timeout: 5), res.exitCode == 0 {
                    items.append(contentsOf: Self.parseOllamaList(res.stdout))
                }
            }
        }

        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    /// `ollama list` tablosunu ayrıştırır; `:cloud` modelleri yerel disk kaplamaz (`isCloudOnly = true`, varsayılan seçimsiz).
    public static func parseOllamaList(_ output: String) -> [AIFootprintItem] {
        var results: [AIFootprintItem] = []
        let lines = output.split(whereSeparator: \.isNewline)
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            // Sütunlar en az iki boşlukla ayrılır: NAME  ID  SIZE  MODIFIED
            let columns = Self.splitColumns(trimmed)
            guard columns.count >= 3 else { continue }
            let name = columns[0]
            let sizeStr = columns[2]
            let modified = columns.count >= 4 ? columns[3] : ""
            let isCloud = name.lowercased().contains(":cloud") || sizeStr == "-"
            let bytes = isCloud ? 0 : DiskSpace.parseHumanSize(sizeStr)
            results.append(AIFootprintItem(
                id: "ollama:\(name)",
                kind: .ollamaModel,
                title: "Ollama: \(name)",
                url: nil,
                ollamaModelName: name,
                sizeBytes: bytes,
                detail: isCloud ? "Cloud reference model (\(modified))" : "Local Ollama model (\(sizeStr), \(modified))",
                isCloudOnly: isCloud,
                isSelected: false
            ))
        }
        return results
    }

    private static func splitColumns(_ line: String) -> [String] {
        let pattern = #"\s{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [line] }
        let ns = line as NSString
        var parts: [String] = []
        var lastIndex = 0
        for match in regex.matches(in: line, range: NSRange(location: 0, length: ns.length)) {
            let piece = ns.substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))
                .trimmingCharacters(in: .whitespaces)
            if !piece.isEmpty { parts.append(piece) }
            lastIndex = match.range.location + match.range.length
        }
        if lastIndex < ns.length {
            let tail = ns.substring(from: lastIndex).trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty { parts.append(tail) }
        }
        return parts
    }

    // MARK: - 3. Tarayıcı Site Verileri, Eski Uygulama/Gradle/Dart Önbellekleri ve Yükleyiciler

    public func scanHeavyCachesAndInstallers(
        activeGradleVersions: Set<String>? = nil,
        minimumBrowserOriginBytes: Int64 = 2 * 1024 * 1024,
        language: String = "en",
        isCancelled: () -> Bool = { false }
    ) -> [HeavyCacheItem] {
        let fm = FileManager.default
        let strings = StringTable()
        let activeGradle = activeGradleVersions ?? discoverActiveGradleVersions()
        var items: [HeavyCacheItem] = []

        // a0) Genel Tarayıcı Disk & HTTP Web Önbellekleri (Safari, Chrome, Edge, Firefox, Brave, Arc, Opera, Vivaldi)
        let mainBrowserCaches: [(owner: String, name: String, candidates: [URL])] = [
            ("Safari", "Safari Web Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/com.apple.Safari"),
                homeDirectoryURL.appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Caches"),
                homeDirectoryURL.appendingPathComponent("Library/WebKit/com.apple.Safari"),
            ]),
            ("Google Chrome", "Google Chrome Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/Google/Chrome"),
                homeDirectoryURL.appendingPathComponent("Library/Caches/Google/Chrome-headless"),
            ]),
            ("Microsoft Edge", "Microsoft Edge Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/Microsoft Edge"),
            ]),
            ("Mozilla Firefox", "Firefox Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/Firefox"),
            ]),
            ("Brave Browser", "Brave Browser Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/BraveSoftware/Brave-Browser"),
            ]),
            ("Arc", "Arc Browser Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/company.thebrowser.Browser"),
            ]),
            ("Opera", "Opera Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/com.operasoftware.Opera"),
                homeDirectoryURL.appendingPathComponent("Library/Caches/com.operasoftware.OperaGX"),
            ]),
            ("Vivaldi", "Vivaldi Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/Vivaldi"),
            ]),
            ("Microsoft Teams 2", "Teams 2 EBWebView Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Containers/com.microsoft.teams2/Data/Library/Caches/EBWebView"),
            ]),
            ("Microsoft Copilot", "Copilot Desktop Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/copilot"),
            ]),
            ("Google Gemini", "Gemini macOS Cache", [
                homeDirectoryURL.appendingPathComponent("Library/Caches/com.google.GeminiMacOS"),
            ]),
        ]

        for (owner, label, candidateURLs) in mainBrowserCaches {
            if isCancelled() { break }
            for cacheURL in candidateURLs {
                if isCancelled() { break }
                guard fm.fileExists(atPath: cacheURL.path) else { continue }
                let size = DiskSpace.size(of: cacheURL, isCancelled: isCancelled)
                if size > 100 * 1024 { // > 100 KB
                    items.append(HeavyCacheItem(
                        category: .browserCache,
                        title: "\(owner) (\(cacheURL.lastPathComponent))",
                        ownerApp: owner,
                        url: cacheURL,
                        sizeBytes: size,
                        explanation: StringTable.shared.format(.scanExpDiskHTTPWebCache, language: language, "\(label)")
                    ))
                }
            }
        }

        // a) Tarayıcı `IndexedDB`, `File System` ve `Service Worker/CacheStorage` site önbellekleri (`library_clean.md` — Tarayıcı Site Verileri)
        let browserProfiles: [(owner: String, base: URL)] = [
            ("Google Chrome", homeDirectoryURL.appendingPathComponent("Library/Application Support/Google/Chrome")),
            ("Microsoft Edge", homeDirectoryURL.appendingPathComponent("Library/Application Support/Microsoft Edge")),
            ("Brave Browser", homeDirectoryURL.appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser")),
            ("Arc", homeDirectoryURL.appendingPathComponent("Library/Application Support/Arc/User Data")),
        ]

        for (owner, browserBase) in browserProfiles {
            guard let profiles = try? fm.contentsOfDirectory(at: browserBase, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for profile in profiles {
                let pname = profile.lastPathComponent
                guard pname == "Default" || pname.hasPrefix("Profile ") else { continue }

                // Service Worker CacheStorage
                let swCache = profile.appendingPathComponent("Service Worker/CacheStorage", isDirectory: true)
                if fm.fileExists(atPath: swCache.path) {
                    let swSize = DiskSpace.size(of: swCache, isCancelled: isCancelled)
                    if swSize >= minimumBrowserOriginBytes {
                        items.append(HeavyCacheItem(
                            category: .browserSiteData,
                            title: strings.format(.scanServiceWorkerCache, language: language, owner, pname),
                            ownerApp: owner,
                            url: swCache,
                            sizeBytes: swSize,
                            explanation: StringTable.shared.string(.scanExpOfflineServiceWorkerCacheStorage, language: language)
                        ))
                    }
                }

                for storageKind in ["IndexedDB", "File System"] {
                    let storageURL = profile.appendingPathComponent(storageKind, isDirectory: true)
                    guard let origins = try? fm.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                    for origin in origins {
                        if isCancelled() { break }
                        let size = DiskSpace.size(of: origin, isCancelled: isCancelled)
                        if size >= minimumBrowserOriginBytes {
                            items.append(HeavyCacheItem(
                                category: .browserSiteData,
                                title: "\(owner) (\(pname)) · \(origin.lastPathComponent)",
                                ownerApp: owner,
                                url: origin,
                                sizeBytes: size,
                                explanation: StringTable.shared.format(.scanExpOfflineSiteStorageBlobBrowser, language: language, "\(storageKind)")
                            ))
                        }
                    }
                }
            }
        }

        // b) Safari `Cookies.binarycookies_tmp_*.dat` yarım kalmış geçici çerez dosyaları
        let safariCookiesDir = homeDirectoryURL.appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Cookies")
        if let cookieFiles = try? fm.contentsOfDirectory(at: safariCookiesDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for file in cookieFiles where file.lastPathComponent.hasPrefix("Cookies.binarycookies_tmp_") {
                let size = DiskSpace.size(of: file, isCancelled: isCancelled)
                items.append(HeavyCacheItem(
                    category: .safariTempCookies,
                    title: file.lastPathComponent,
                    ownerApp: "Safari",
                    url: file,
                    sizeBytes: size,
                    explanation: StringTable.shared.string(.scanExpOrphanedSafariTemporaryCookieWrite, language: language)
                ))
            }
        }

        // g) Apple Mail İndirilen Ekleri (`Mail Downloads`)
        let mailDownloadCandidates = [
            homeDirectoryURL.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Mail Downloads", isDirectory: true),
        ]
        for mailDir in mailDownloadCandidates {
            if isCancelled() { break }
            guard fm.fileExists(atPath: mailDir.path) else { continue }
            let size = DiskSpace.size(of: mailDir, isCancelled: isCancelled)
            if size > 0 {
                items.append(HeavyCacheItem(
                    category: .mailDownloads,
                    title: strings.string(.scanAppleMailDownloads, language: language),
                    ownerApp: "Mail",
                    url: mailDir,
                    sizeBytes: size,
                    explanation: StringTable.shared.string(.scanExpCachedAttachmentsOpenedFromApple, language: language)
                ))
            }
        }

        // h) iOS & iPadOS Yerel Cihaz Yedekleri (`MobileSync/Backup`)
        let backupDir = homeDirectoryURL.appendingPathComponent("Library/Application Support/MobileSync/Backup", isDirectory: true)
        if !isCancelled(), let backupEntries = try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in backupEntries {
                if isCancelled() { break }
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else { continue }
                let size = DiskSpace.size(of: entry, isCancelled: isCancelled)
                if size > 0 {
                    let shortName = entry.lastPathComponent.count > 12 ? "\(entry.lastPathComponent.prefix(12))…" : entry.lastPathComponent
                    items.append(HeavyCacheItem(
                        category: .iosDeviceBackup,
                        title: strings.format(.scanIOSBackup, language: language, shortName),
                        ownerApp: "MobileSync",
                        url: entry,
                        sizeBytes: size,
                        explanation: StringTable.shared.string(.scanExpLocalIPhoneIPadDeviceBackup, language: language),
                        isSelected: false // Safe default: requires explicit opt-in
                    ))
                }
            }
        }

        // i) Yarım Kalan ve Kopmuş İndirmeler (`.download`, `.crdownload`, `.part`, `.opdownload`)
        let downloadsDir = homeDirectoryURL.appendingPathComponent("Downloads", isDirectory: true)
        let partialExts: Set<String> = ["download", "crdownload", "part", "opdownload"]
        if !isCancelled(), let dlEntries = try? fm.contentsOfDirectory(at: downloadsDir, includingPropertiesForKeys: nil, options: []) {
            for entry in dlEntries {
                if isCancelled() { break }
                let ext = entry.pathExtension.lowercased()
                if partialExts.contains(ext) {
                    let size = DiskSpace.size(of: entry, isCancelled: isCancelled)
                    if size > 0 {
                        items.append(HeavyCacheItem(
                            category: .partialDownload,
                            title: entry.lastPathComponent,
                            ownerApp: "Downloads",
                            url: entry,
                            sizeBytes: size,
                            explanation: StringTable.shared.string(.scanExpIncompleteOrInterruptedDownloadArtifact, language: language)
                        ))
                    }
                }
            }
        }

        // j) Windows ve Harici Disk Meta Veri Artıkları (`Thumbs.db`, `desktop.ini`, `ZbThumbnail.info`, `._*`)
        let metadataFilenames: Set<String> = ["thumbs.db", "desktop.ini", "zbthumbnail.info", "ehthumbs.db"]
        let scanUserDirs = [
            homeDirectoryURL.appendingPathComponent("Downloads"),
            homeDirectoryURL.appendingPathComponent("Desktop"),
            homeDirectoryURL.appendingPathComponent("Documents"),
        ]
        for uDir in scanUserDirs {
            if isCancelled() { break }
            guard let files = try? fm.contentsOfDirectory(at: uDir, includingPropertiesForKeys: nil, options: []) else { continue }
            for file in files {
                if isCancelled() { break }
                let fname = file.lastPathComponent
                let lowerName = fname.lowercased()
                if metadataFilenames.contains(lowerName) || fname.hasPrefix("._") {
                    let size = DiskSpace.size(of: file, isCancelled: isCancelled)
                    items.append(HeavyCacheItem(
                        category: .windowsMetadata,
                        title: "\(fname) (\(uDir.lastPathComponent))",
                        ownerApp: "Finder",
                        url: file,
                        sizeBytes: size,
                        explanation: StringTable.shared.format(.scanExpExtraneousWindowsMetadataOrAppleDouble, language: language, "\(uDir.lastPathComponent)")
                    ))
                }
            }
        }

        // k) Çökme ve Çekirdek Dökümleri (`/cores/*` ve `~/Library/Logs/DiagnosticReports`)
        let coresDir = URL(fileURLWithPath: "/cores", isDirectory: true)
        if !isCancelled(), let coreEntries = try? fm.contentsOfDirectory(at: coresDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in coreEntries where entry.lastPathComponent.hasPrefix("core.") {
                if isCancelled() { break }
                let size = DiskSpace.size(of: entry, isCancelled: isCancelled)
                if size > 0 {
                    items.append(HeavyCacheItem(
                        category: .crashDump,
                        title: entry.lastPathComponent,
                        ownerApp: "CrashReporter",
                        url: entry,
                        sizeBytes: size,
                        explanation: StringTable.shared.string(.scanExpKernelProcessMemoryCoreDump, language: language)
                    ))
                }
            }
        }

        let diagReportsDir = homeDirectoryURL.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        if !isCancelled(), let diagEntries = try? fm.contentsOfDirectory(at: diagReportsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            let crashExts: Set<String> = ["ips", "crash", "diag", "hang"]
            for entry in diagEntries where crashExts.contains(entry.pathExtension.lowercased()) {
                if isCancelled() { break }
                let size = DiskSpace.size(of: entry, isCancelled: isCancelled)
                if size > 10 * 1024 { // > 10 KB
                    items.append(HeavyCacheItem(
                        category: .crashDump,
                        title: entry.lastPathComponent,
                        ownerApp: "DiagnosticReports",
                        url: entry,
                        sizeBytes: size,
                        explanation: StringTable.shared.string(.scanExpDiagnosticCrashOrHangReport, language: language)
                    ))
                }
            }
        }

        // l) Terminal / Kabuk Oturum Günlükleri (`~/.zsh_sessions` ve `~/.bash_sessions`)
        let sessionDirs = [
            homeDirectoryURL.appendingPathComponent(".zsh_sessions", isDirectory: true),
            homeDirectoryURL.appendingPathComponent(".bash_sessions", isDirectory: true),
        ]
        for sDir in sessionDirs {
            if isCancelled() { break }
            guard fm.fileExists(atPath: sDir.path) else { continue }
            let size = DiskSpace.size(of: sDir, isCancelled: isCancelled)
            if size > 0 {
                items.append(HeavyCacheItem(
                    category: .shellSessions,
                    title: sDir.lastPathComponent,
                    ownerApp: "Terminal",
                    url: sDir,
                    sizeBytes: size,
                    explanation: StringTable.shared.string(.scanExpAccumulatedShellSessionHistoryAnd, language: language)
                ))
            }
        }

        // m) Dinamik Duvar Kağıdı ve Ekran Koruyucu Önbelleği (`Store` ve `Screen Savers`)
        let wallpaperCandidates = [
            homeDirectoryURL.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Screen Savers", isDirectory: true),
        ]
        for wpDir in wallpaperCandidates {
            if isCancelled() { break }
            guard fm.fileExists(atPath: wpDir.path) else { continue }
            let size = DiskSpace.size(of: wpDir, isCancelled: isCancelled)
            if size > 10 * 1024 * 1024 { // > 10 MB
                items.append(HeavyCacheItem(
                    category: .dynamicWallpaperCache,
                    title: "\(wpDir.deletingLastPathComponent().lastPathComponent)/\(wpDir.lastPathComponent)",
                    ownerApp: "Wallpaper",
                    url: wpDir,
                    sizeBytes: size,
                    explanation: StringTable.shared.string(.scanExpDownloaded4K8KAerialWallpaper, language: language)
                ))
            }
        }

        // n) QuickTime Kaydedilmemiş Geçici Kayıtlar (`Autosave Information`)
        let qtAutosaveDir = homeDirectoryURL.appendingPathComponent("Library/Containers/com.apple.QuickTimePlayerX/Data/Library/Autosave Information", isDirectory: true)
        if !isCancelled(), fm.fileExists(atPath: qtAutosaveDir.path) {
            let size = DiskSpace.size(of: qtAutosaveDir, isCancelled: isCancelled)
            if size > 0 {
                items.append(HeavyCacheItem(
                    category: .quickTimeAutosave,
                    title: strings.string(.scanQuickTimeAutosave, language: language),
                    ownerApp: "QuickTime Player",
                    url: qtAutosaveDir,
                    sizeBytes: size,
                    explanation: StringTable.shared.string(.scanExpUnsavedTemporaryScreenOrAudio, language: language)
                ))
            }
        }

        // c) Photoshop `UXP/PluginsStorage/PHSP/<sürüm>` ve `EdgeUpdater/apps/msedge-*/<sürüm>` eski sürümleri
        let versionedDirs: [(owner: String, url: URL)] = [
            ("Adobe Photoshop", homeDirectoryURL.appendingPathComponent("Library/Application Support/Adobe/UXP/PluginsStorage/PHSP")),
            ("Microsoft EdgeUpdater", homeDirectoryURL.appendingPathComponent("Library/Application Support/Microsoft/EdgeUpdater/apps/msedge-stable")),
            ("Microsoft EdgeUpdater (Beta)", homeDirectoryURL.appendingPathComponent("Library/Application Support/Microsoft/EdgeUpdater/apps/msedge-beta")),
            ("Microsoft EdgeUpdater (Dev)", homeDirectoryURL.appendingPathComponent("Library/Application Support/Microsoft/EdgeUpdater/apps/msedge-dev")),
            ("Microsoft EdgeUpdater (Canary)", homeDirectoryURL.appendingPathComponent("Library/Application Support/Microsoft/EdgeUpdater/apps/msedge-canary")),
        ]
        for (owner, parentDir) in versionedDirs {
            if isCancelled() { break }
            guard let subdirs = try? fm.contentsOfDirectory(at: parentDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]),
                  subdirs.count > 1 else { continue }
            let sorted = subdirs.sorted {
                $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending
            }
            for older in sorted.dropFirst() {
                if isCancelled() { break }
                let size = DiskSpace.size(of: older, isCancelled: isCancelled)
                if size > 0 {
                    items.append(HeavyCacheItem(
                        category: .appVersionCache,
                        title: "\(owner) (\(older.lastPathComponent))",
                        ownerApp: owner,
                        url: older,
                        sizeBytes: size,
                        explanation: StringTable.shared.format(.scanExpEskiGuncellemeSurumuGuncelSurum, language: language, "\(sorted[0].lastPathComponent)")
                    ))
                }
            }
        }

        // c2) Uygulama Güncelleme Hazırlık ve İndirme Artıkları (`~/Library/Caches/*.ShipIt`)
        let cachesParentDir = homeDirectoryURL.appendingPathComponent("Library/Caches", isDirectory: true)
        if !isCancelled(), let cacheEntries = try? fm.contentsOfDirectory(at: cachesParentDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in cacheEntries where entry.lastPathComponent.hasSuffix(".ShipIt") {
                if isCancelled() { break }
                let lowerName = entry.lastPathComponent.lowercased()
                if lowerName.contains("curatare") || lowerName.contains("arhivar") || lowerName.contains("copiator") || lowerName.contains("descarcator") || lowerName.contains("antigravity") {
                    continue
                }
                let size = DiskSpace.size(of: entry, isCancelled: isCancelled)
                if size > 50 * 1024 { // > 50 KB
                    let appName = entry.lastPathComponent.replacingOccurrences(of: ".ShipIt", with: "")
                    items.append(HeavyCacheItem(
                        category: .appVersionCache,
                        title: "\(appName) (ShipIt)",
                        ownerApp: appName,
                        url: entry,
                        sizeBytes: size,
                        explanation: StringTable.shared.string(.scanExpEskiUygulamaGuncellemeIndirmeVe, language: language)
                    ))
                }
            }
        }

        // c3) Classic Teams Artıkları (`library_clean.md`: 3,3 GB — `Application Support/Microsoft/Teams` ve `Group Containers/UBF8T346G9.com.microsoft.teams`)
        var hasClassicTeams = fm.fileExists(atPath: applicationsDirectoryURL.appendingPathComponent("Microsoft Teams (classic).app").path)
        if !hasClassicTeams {
            let altTeams = applicationsDirectoryURL.appendingPathComponent("Microsoft Teams.app")
            if fm.fileExists(atPath: altTeams.path),
               let bID = LibraryScanner.readBundleIdentifier(fromPlist: altTeams.appendingPathComponent("Contents/Info.plist")),
               bID == "com.microsoft.teams" {
                hasClassicTeams = true
            }
        }
        if !hasClassicTeams {
            let classicTeamsCandidates: [(title: String, url: URL, explanation: String)] = [
                ("Microsoft Teams (Classic) · Application Support", homeDirectoryURL.appendingPathComponent("Library/Application Support/Microsoft/Teams", isDirectory: true), "Eski Classic Teams veri klasörü (kurulu olan modern Teams 2 Containers/com.microsoft.teams2 kullanır)"),
                ("Microsoft Teams (Classic) · Group Container", homeDirectoryURL.appendingPathComponent("Library/Group Containers/UBF8T346G9.com.microsoft.teams", isDirectory: true), "Eski Classic Teams paylaşılan grup konteyneri (UBF8T346G9.com.microsoft.teams)"),
            ]
            for cand in classicTeamsCandidates where fm.fileExists(atPath: cand.url.path) {
                if isCancelled() { break }
                let size = DiskSpace.size(of: cand.url, isCancelled: isCancelled)
                if size > 0 {
                    items.append(HeavyCacheItem(
                        category: .appVersionCache,
                        title: cand.title,
                        ownerApp: "Microsoft Teams",
                        url: cand.url,
                        sizeBytes: size,
                        explanation: cand.explanation
                    ))
                }
            }
        }

        // c4) JetBrains Air Artıkları (`library_clean.md`: 0,8 GB — `Caches/JetBrains/Air` ve `Application Support/JetBrains/Air`)
        let jbAirApp = applicationsDirectoryURL.appendingPathComponent("JetBrains Air.app")
        if !fm.fileExists(atPath: jbAirApp.path) {
            let jbAirCandidates = [
                homeDirectoryURL.appendingPathComponent("Library/Caches/JetBrains/Air", isDirectory: true),
                homeDirectoryURL.appendingPathComponent("Library/Application Support/JetBrains/Air", isDirectory: true),
            ]
            for jbURL in jbAirCandidates where fm.fileExists(atPath: jbURL.path) {
                if isCancelled() { break }
                let size = DiskSpace.size(of: jbURL, isCancelled: isCancelled)
                if size > 0 {
                    items.append(HeavyCacheItem(
                        category: .appVersionCache,
                        title: "JetBrains Air (\(jbURL.deletingLastPathComponent().lastPathComponent)/\(jbURL.lastPathComponent))",
                        ownerApp: "JetBrains Air",
                        url: jbURL,
                        sizeBytes: size,
                        explanation: StringTable.shared.string(.scanExpJetBrainsAirUygulamaArtigiUygulama, language: language)
                    ))
                }
            }
        }

        // c5) IcedTea-Web Java Web Start Önbelleği (`~/.cache/icedtea-web` — `library_clean.md`)
        let icedTeaDir = homeDirectoryURL.appendingPathComponent(".cache/icedtea-web", isDirectory: true)
        if !isCancelled(), fm.fileExists(atPath: icedTeaDir.path) {
            let size = DiskSpace.size(of: icedTeaDir, isCancelled: isCancelled)
            if size > 0 {
                items.append(HeavyCacheItem(
                    category: .appVersionCache,
                    title: ".cache/icedtea-web",
                    ownerApp: "IcedTea-Web",
                    url: icedTeaDir,
                    sizeBytes: size,
                    explanation: StringTable.shared.string(.scanExpJavaWebStartOnbellekArtigi, language: language)
                ))
            }
        }

        // d) Aktif hiçbir projede kullanılmayan eski `~/.gradle/caches/<sürüm>` ve `~/.gradle/wrapper/dists/gradle-<sürüm>-*`
        let gradleCaches = homeDirectoryURL.appendingPathComponent(".gradle/caches", isDirectory: true)
        if !isCancelled(), let cacheEntries = try? fm.contentsOfDirectory(at: gradleCaches, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in cacheEntries {
                if isCancelled() { break }
                let name = entry.lastPathComponent
                // `modules-2`, `jars-*`, `transforms-*` ortak depolardır; yalnızca sürüm numaralı klasörleri (ör. `8.14.3`) denetle
                guard name.first?.isNumber == true else { continue }
                if !activeGradle.contains(name) {
                    let size = DiskSpace.size(of: entry, isCancelled: isCancelled)
                    items.append(HeavyCacheItem(
                        category: .unusedGradleCache,
                        title: ".gradle/caches/\(name)",
                        ownerApp: "Gradle",
                        url: entry,
                        sizeBytes: size,
                        explanation: StringTable.shared.format(.scanExpGradleVersionIsNotReferenced, language: language, "\(name)")
                    ))
                }
            }
        }

        let gradleDists = homeDirectoryURL.appendingPathComponent(".gradle/wrapper/dists", isDirectory: true)
        if !isCancelled(), let distEntries = try? fm.contentsOfDirectory(at: gradleDists, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in distEntries where entry.lastPathComponent.hasPrefix("gradle-") {
                if isCancelled() { break }
                let name = entry.lastPathComponent
                let isUsed = activeGradle.contains { ver in name.contains("gradle-\(ver)-") }
                if !isUsed {
                    let size = DiskSpace.size(of: entry, isCancelled: isCancelled)
                    items.append(HeavyCacheItem(
                        category: .unusedGradleCache,
                        title: ".gradle/wrapper/dists/\(name)",
                        ownerApp: "Gradle",
                        url: entry,
                        sizeBytes: size,
                        explanation: StringTable.shared.string(.scanExpUnusedGradleWrapperDistributionModules, language: language)
                    ))
                }
            }
        }

        // e) `~/.dartServer/.analysis-driver`
        let dartAnalysis = homeDirectoryURL.appendingPathComponent(".dartServer/.analysis-driver", isDirectory: true)
        if !isCancelled(), fm.fileExists(atPath: dartAnalysis.path) {
            let size = DiskSpace.size(of: dartAnalysis, isCancelled: isCancelled)
            if size > 0 {
                items.append(HeavyCacheItem(
                    category: .dartAnalysisCache,
                    title: ".dartServer/.analysis-driver",
                    ownerApp: "Dart / Flutter",
                    url: dartAnalysis,
                    sizeBytes: size,
                    explanation: StringTable.shared.string(.scanExpDartAnalysisServerCacheRegenerated, language: language)
                ))
            }
        }

        // f) `~/Downloads` ve `~/Desktop` içindeki `.dmg`, `.pkg`, `.iso`, `.xip` kurulum dosyaları ve Office kilit dosyaları (`~$*`, `.~lock*`)
        let installerExts: Set<String> = ["dmg", "pkg", "iso", "xip"]
        for scanDir in [homeDirectoryURL.appendingPathComponent("Downloads"), homeDirectoryURL.appendingPathComponent("Desktop")] {
            if isCancelled() { break }
            guard let files = try? fm.contentsOfDirectory(at: scanDir, includingPropertiesForKeys: nil, options: []) else { continue }
            for file in files {
                if isCancelled() { break }
                let fname = file.lastPathComponent
                if fname.hasPrefix("~$") || fname.hasPrefix(".~lock.") {
                    let size = DiskSpace.size(of: file, isCancelled: isCancelled)
                    items.append(HeavyCacheItem(
                        category: .officeLockFile,
                        title: fname,
                        ownerApp: "Microsoft Office / LibreOffice",
                        url: file,
                        sizeBytes: size,
                        explanation: StringTable.shared.format(.scanExpStaleOfficeLockFileIn, language: language, "\(scanDir.lastPathComponent)")
                    ))
                } else if installerExts.contains(file.pathExtension.lowercased()) {
                    let size = DiskSpace.size(of: file, isCancelled: isCancelled)
                    items.append(HeavyCacheItem(
                        category: .diskInstaller,
                        title: fname,
                        ownerApp: scanDir.lastPathComponent,
                        url: file,
                        sizeBytes: size,
                        explanation: StringTable.shared.format(.scanExpInstallerImagePackageIn, language: language, "\(scanDir.lastPathComponent)"),
                        isSelected: false
                    ))
                }
            }
        }

        // g) Audio Units Bileşen Önbelleği (`com.apple.audiounits.cache`)
        let auCache = homeDirectoryURL.appendingPathComponent("Library/Caches/com.apple.audiounits.cache")
        if !isCancelled(), fm.fileExists(atPath: auCache.path) {
            let size = DiskSpace.size(of: auCache, isCancelled: isCancelled)
            if size > 10 * 1024 { // > 10 KB
                items.append(HeavyCacheItem(
                    category: .audioUnitsCache,
                    title: "com.apple.audiounits.cache",
                    ownerApp: "Audio Units / CoreAudio",
                    url: auCache,
                    sizeBytes: size,
                    explanation: StringTable.shared.string(.scanExpAudioUnitsPlugInValidation, language: language)
                ))
            }
        }

        // h) Eski Müzik / iTunes Kütüphane Yedekleri (`Previous iTunes Libraries`)
        let prevMusicDirs = [
            homeDirectoryURL.appendingPathComponent("Music/Music/Previous iTunes Libraries"),
            homeDirectoryURL.appendingPathComponent("Music/iTunes/Previous iTunes Libraries")
        ]
        for dir in prevMusicDirs {
            if isCancelled() { break }
            if fm.fileExists(atPath: dir.path) {
                let size = DiskSpace.size(of: dir, isCancelled: isCancelled)
                if size > 100 * 1024 { // > 100 KB
                    items.append(HeavyCacheItem(
                        category: .previousMusicLibraries,
                        title: dir.lastPathComponent,
                        ownerApp: "Apple Music / iTunes",
                        url: dir,
                        sizeBytes: size,
                        explanation: StringTable.shared.format(.scanExpObsoletePreviousMusicITunesLibrary, language: language, "\(dir.path)")
                    ))
                }
            }
        }

        // i) Xcode Arşivleri (`~/Library/Developer/Xcode/Archives`)
        let xcodeArchivesDir = homeDirectoryURL.appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true)
        if !isCancelled(), fm.fileExists(atPath: xcodeArchivesDir.path) {
            let size = DiskSpace.size(of: xcodeArchivesDir, isCancelled: isCancelled)
            if size > 10 * 1024 * 1024 { // > 10 MB
                items.append(HeavyCacheItem(
                    category: .xcodeArchives,
                    title: strings.string(.scanXcodeArchives, language: language),
                    ownerApp: "Xcode",
                    url: xcodeArchivesDir,
                    sizeBytes: size,
                    explanation: StringTable.shared.string(.scanExpBuiltXcarchiveApplicationDistributionPackages, language: language)
                ))
            }
        }

        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    // MARK: - 4. Time Machine Yerel Anlık Görüntüleri (`tmutil`)

    public func listTimeMachineSnapshots() async -> [TimeMachineSnapshot] {
        let tmutil = URL(fileURLWithPath: "/usr/bin/tmutil")
        guard FileManager.default.isExecutableFile(atPath: tmutil.path) else { return [] }
        let runner = CommandRunner(executableURL: tmutil)
        guard let res = try? await runner.run(["listlocalsnapshots", "/"], timeout: 10), res.exitCode == 0 else {
            return []
        }
        return Self.parseTimeMachineSnapshots(res.stdout)
    }

    public static func parseTimeMachineSnapshots(_ output: String) -> [TimeMachineSnapshot] {
        var snapshots: [TimeMachineSnapshot] = []
        let pattern = #"com\.apple\.TimeMachine\.([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6})(?:\.local)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        for line in output.split(whereSeparator: \.isNewline) {
            let s = String(line).trimmingCharacters(in: .whitespaces)
            guard let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
                  let fullRange = Range(match.range(at: 0), in: s),
                  let dateRange = Range(match.range(at: 1), in: s) else { continue }
            snapshots.append(TimeMachineSnapshot(
                id: String(s[fullRange]),
                dateStamp: String(s[dateRange])
            ))
        }
        return snapshots
    }

    public func thinTimeMachineSnapshots(bytesToThin: Int64 = 30_000_000_000, urgency: Int = 4) async throws -> String {
        let tmutil = URL(fileURLWithPath: "/usr/bin/tmutil")
        let runner = CommandRunner(executableURL: tmutil)
        let res = try await runner.run(["thinlocalsnapshots", "/", String(bytesToThin), String(urgency)], timeout: 60)
        return res.stdout + (res.stderr.isEmpty ? "" : "\n" + res.stderr)
    }

    // MARK: - 5. Dil ve Ekosistem Paket Yöneticileri & macOS Sistem Runtimeları

    /// Sistemdeki dil/ekosistem paket yöneticisi önbelleklerini ve korumalı macOS sistem çalışma zamanlarını denetler.
    public func scanLanguageEcosystemItems(isCancelled: () -> Bool = { false }) -> [LanguageEcosystemItem] {
        let fm = FileManager.default
        var items: [LanguageEcosystemItem] = []

        // MARK: 0. macOS Sistem Çalışma Zamanları (SIP Korumalı · Dokunulmaz)
        // Kural: macOS dahili python3, ruby, perl ve framework'lerine ASLA dokunulamaz, silinemez, yazılamaz.
        let systemRuntimes: [(path: String, name: String, explanation: String)] = [
            ("/usr/bin/python3", "macOS Sistem Python 3", "macOS dahili Python 3 ikilisi (/usr/bin/python3) · SIP Korumalı"),
            ("/System/Library/Frameworks/Python.framework", "macOS Python Framework", "macOS sistem Python çatı dizini · SIP Korumalı"),
            ("/usr/bin/ruby", "macOS Sistem Ruby", "macOS dahili Ruby ikilisi (/usr/bin/ruby) · SIP Korumalı"),
            ("/System/Library/Frameworks/Ruby.framework", "macOS Ruby Framework", "macOS sistem Ruby çatı dizini · SIP Korumalı"),
            ("/usr/bin/perl", "macOS Sistem Perl", "macOS dahili Perl ikilisi (/usr/bin/perl) · SIP Korumalı"),
        ]

        for runtime in systemRuntimes {
            if isCancelled() { break }
            let url = URL(fileURLWithPath: runtime.path)
            if fm.fileExists(atPath: runtime.path) {
                let size: Int64 = (try? fm.attributesOfItem(atPath: runtime.path)[.size] as? Int64) ?? 0
                items.append(LanguageEcosystemItem(
                    ecosystem: .macosSystemRuntime,
                    origin: .macosSystem,
                    toolName: runtime.name,
                    path: runtime.path,
                    url: url,
                    sizeBytes: size,
                    explanation: runtime.explanation,
                    isSystemProtected: true,
                    isSelected: false
                ))
            }
        }

        // Adaylar önce yalnızca varlık denetimiyle toplanır; boyutları sonda tek bir paralel gezintide hesaplanır
        // (`~/.gradle/caches`, `~/.pub-cache` gibi on binlerce dosyalı önbellekler sıralı gezintinin çoğunu tüketiyordu).
        var candidates: [(url: URL, make: (Int64) -> LanguageEcosystemItem)] = []

        func probe(
            ecosystem: LanguageEcosystemItem.Ecosystem,
            origin: LanguageEcosystemItem.Origin = .userStandalone,
            toolName: String,
            relPath: String,
            explanation: String,
            fullURL: URL? = nil
        ) {
            if isCancelled() { return }
            let targetURL = fullURL ?? (relPath.hasPrefix("/") ? URL(fileURLWithPath: relPath) : homeDirectoryURL.appendingPathComponent(relPath))
            guard fm.fileExists(atPath: targetURL.path) else { return }
            let displayPath = relPath.hasPrefix("/") ? relPath : "~/\(relPath)"
            candidates.append((targetURL, { size in
                LanguageEcosystemItem(
                    ecosystem: ecosystem,
                    origin: origin,
                    toolName: toolName,
                    path: displayPath,
                    url: targetURL,
                    sizeBytes: size,
                    explanation: explanation,
                    isSystemProtected: origin == .macosSystem,
                    isSelected: origin != .macosSystem
                )
            }))
        }

        // 1. Python (pip, uv, pipx, poetry, pdm, conda/mamba)
        probe(ecosystem: .python, toolName: "pip", relPath: "Library/Caches/pip", explanation: StringTable.shared.string(.scanExpPipPaketIndirmeVeHTTP, language: language))
        probe(ecosystem: .python, toolName: "pip", relPath: ".cache/pip", explanation: StringTable.shared.string(.scanExpPipPaketIndirmeOnbellegiCache, language: language))
        probe(ecosystem: .python, toolName: "uv", relPath: "Library/Caches/uv", explanation: StringTable.shared.string(.scanExpUvTekerlekWheelVePaket, language: language))
        probe(ecosystem: .python, toolName: "uv", relPath: ".cache/uv", explanation: StringTable.shared.string(.scanExpUvOnbellekDiziniCacheUv, language: language))
        probe(ecosystem: .python, toolName: "pipx", relPath: ".local/pipx/trash", explanation: StringTable.shared.string(.scanExpPipxGeciciVeSilinmisPaket, language: language))
        probe(ecosystem: .python, toolName: "pipx", relPath: ".local/share/pipx/shared", explanation: StringTable.shared.string(.scanExpPipxPaylasilanKutuphanelerOnbellegi, language: language))
        probe(ecosystem: .python, toolName: "pipx", relPath: ".cache/pipx", explanation: StringTable.shared.string(.scanExpPipxTekerlekOnbellegiCachePipx, language: language))
        probe(ecosystem: .python, toolName: "poetry", relPath: "Library/Caches/pypoetry", explanation: StringTable.shared.string(.scanExpPoetryPaketVeSanalOrtam, language: language))
        probe(ecosystem: .python, toolName: "poetry", relPath: ".cache/pypoetry", explanation: StringTable.shared.string(.scanExpPoetryOnbellekDiziniCachePypoetry, language: language))
        probe(ecosystem: .python, toolName: "pdm", relPath: "Library/Caches/pdm", explanation: StringTable.shared.string(.scanExpPDMPaketYoneticisiOnbellegi, language: language))
        probe(ecosystem: .python, toolName: "pdm", relPath: ".cache/pdm", explanation: StringTable.shared.string(.scanExpPDMPaketOnbellegiCachePdm, language: language))
        probe(ecosystem: .python, toolName: "conda / mamba", relPath: ".conda/pkgs", explanation: StringTable.shared.string(.scanExpCondaMambaPaketArsiviOnbellegi, language: language))
        probe(ecosystem: .python, toolName: "conda / mamba", relPath: ".mamba/pkgs", explanation: StringTable.shared.string(.scanExpMambaPaketArsiviOnbellegiMamba, language: language))
        probe(ecosystem: .python, toolName: "miniforge", relPath: "miniforge3/pkgs", explanation: StringTable.shared.string(.scanExpMiniforgeCondaPaketArsivi, language: language))
        probe(ecosystem: .python, toolName: "anaconda", relPath: "anaconda3/pkgs", explanation: StringTable.shared.string(.scanExpAnacondaCondaPaketArsivi, language: language))

        // 2. JavaScript / TypeScript (npm, pnpm, yarn, bun, deno)
        let npmCachePath = homeDirectoryURL.appendingPathComponent(".npm/_cacache").path
        if fm.fileExists(atPath: npmCachePath) {
            probe(ecosystem: .javascriptNode, toolName: "npm", relPath: ".npm/_cacache", explanation: StringTable.shared.string(.scanExpNpmIcerikAdreslenebilirPaketOnbellegi, language: language))
        } else {
            probe(ecosystem: .javascriptNode, toolName: "npm", relPath: ".npm", explanation: StringTable.shared.string(.scanExpNpmIndirmeOnbellegi, language: language))
        }
        probe(ecosystem: .javascriptNode, toolName: "pnpm", relPath: "Library/pnpm/store", explanation: StringTable.shared.string(.scanExpPnpmKureselIcerikDeposuOnbellegi, language: language))
        probe(ecosystem: .javascriptNode, toolName: "pnpm", relPath: ".local/share/pnpm/store", explanation: StringTable.shared.string(.scanExpPnpmVeriDeposuLocalShare, language: language))
        probe(ecosystem: .javascriptNode, toolName: "pnpm", relPath: "Library/Caches/pnpm", explanation: StringTable.shared.string(.scanExpPnpmGeciciPaketOnbellegi, language: language))
        probe(ecosystem: .javascriptNode, toolName: "yarn", relPath: "Library/Caches/Yarn", explanation: StringTable.shared.string(.scanExpYarnPaketOnbellegi, language: language))
        probe(ecosystem: .javascriptNode, toolName: "yarn", relPath: ".yarn/berry/cache", explanation: StringTable.shared.string(.scanExpYarnBerryV2PaketOnbellegi, language: language))
        probe(ecosystem: .javascriptNode, toolName: "yarn", relPath: ".cache/yarn", explanation: StringTable.shared.string(.scanExpYarnOnbellekDiziniCacheYarn, language: language))
        probe(ecosystem: .javascriptNode, toolName: "bun", relPath: ".bun/install/cache", explanation: StringTable.shared.string(.scanExpBunHizliPaketIndirmeOnbellegi, language: language))
        probe(ecosystem: .javascriptNode, toolName: "deno", relPath: "Library/Caches/deno", explanation: StringTable.shared.string(.scanExpDenoDerlemeVeUzaktanModul, language: language))
        probe(ecosystem: .javascriptNode, toolName: "deno", relPath: ".deno/deps", explanation: StringTable.shared.string(.scanExpDenoUzakBagimlilikOnbellegiDeno, language: language))

        // 3. Rust (Asla ~/.cargo/bin veya config'e dokunulmaz!)
        probe(ecosystem: .rust, toolName: "cargo", relPath: ".cargo/registry/cache", explanation: StringTable.shared.string(.scanExpCargoCratePaketIndirmeArsivi, language: language))
        probe(ecosystem: .rust, toolName: "cargo", relPath: ".cargo/git/db", explanation: StringTable.shared.string(.scanExpCargoGitBagimliliklariKlonVeritabani, language: language))

        // 4. Go (go-build, mod cache)
        probe(ecosystem: .goLang, toolName: "go-build", relPath: "Library/Caches/go-build", explanation: StringTable.shared.string(.scanExpGoDerlemeVeAraNesne, language: language))
        probe(ecosystem: .goLang, toolName: "go mod", relPath: "go/pkg/mod/cache", explanation: StringTable.shared.string(.scanExpGoModulIndirmeOnbellegiGOPATH, language: language))

        // 5. Ruby (bundler, gem)
        probe(ecosystem: .ruby, toolName: "bundler", relPath: ".bundle/cache", explanation: StringTable.shared.string(.scanExpBundlerGemArsivOnbellegi, language: language))
        probe(ecosystem: .ruby, toolName: "gem", relPath: ".gem/specs", explanation: StringTable.shared.string(.scanExpRubyGemsUzakSpesifikasyonlarOnbellegi, language: language))
        probe(ecosystem: .ruby, toolName: "gem", relPath: ".gem/cache", explanation: StringTable.shared.string(.scanExpRubyGemsGemIkiliPaketIndirme, language: language))
        probe(ecosystem: .ruby, toolName: "gem", relPath: ".local/share/gem", explanation: StringTable.shared.string(.scanExpRubyGemsKullaniciKutuphaneDiziniLocal, language: language))

        // 6. PHP (composer)
        probe(ecosystem: .php, toolName: "composer", relPath: "Library/Caches/composer", explanation: StringTable.shared.string(.scanExpComposerPaketVeHavuzOnbellegi, language: language))
        probe(ecosystem: .php, toolName: "composer", relPath: ".composer/cache", explanation: StringTable.shared.string(.scanExpComposerKureselOnbellekDiziniComposer, language: language))

        // 7. JVM (Java / Kotlin / Scala: gradle, maven, coursier/sbt)
        probe(ecosystem: .jvm, toolName: "gradle", relPath: ".gradle/caches", explanation: StringTable.shared.string(.scanExpGradleBagimlilikVeDerlemeOnbellegi, language: language))
        probe(ecosystem: .jvm, toolName: "maven", relPath: ".m2/repository", explanation: StringTable.shared.string(.scanExpMavenYerelKutuphaneDeposuM2, language: language))
        probe(ecosystem: .jvm, toolName: "coursier / sbt", relPath: "Library/Caches/Coursier", explanation: StringTable.shared.string(.scanExpScalaSBTCoursierBagimlilikOnbellegi, language: language))
        probe(ecosystem: .jvm, toolName: "coursier / sbt", relPath: ".cache/coursier", explanation: StringTable.shared.string(.scanExpCoursierIndirmeOnbellegiCacheCoursier, language: language))
        probe(ecosystem: .jvm, toolName: "sbt", relPath: ".sbt/boot", explanation: StringTable.shared.string(.scanExpSBTOnyuklemeBilesenleriOnbellegiSbt, language: language))

        // 8. .NET / C# (nuget)
        probe(ecosystem: .dotnet, toolName: "nuget", relPath: ".nuget/packages", explanation: StringTable.shared.string(.scanExpNuGetPaketIndirmeOnbellegi, language: language))
        probe(ecosystem: .dotnet, toolName: "nuget", relPath: ".local/share/NuGet/v3-cache", explanation: StringTable.shared.string(.scanExpNuGetV3HTTPMetaVeri, language: language))

        // 9. Swift (spm, cocoapods, carthage)
        probe(ecosystem: .swift, toolName: "swiftpm", relPath: "Library/Caches/org.swift.swiftpm", explanation: StringTable.shared.string(.scanExpSwiftPackageManagerRepoVe, language: language))
        probe(ecosystem: .swift, toolName: "swiftpm", relPath: "Library/org.swift.swiftpm", explanation: StringTable.shared.string(.scanExpSwiftPackageManagerYapilandirmaVe, language: language))
        probe(ecosystem: .swift, toolName: "cocoapods", relPath: "Library/Caches/CocoaPods", explanation: StringTable.shared.string(.scanExpCocoaPodsPaketVeSpecIndirme, language: language))
        probe(ecosystem: .swift, toolName: "carthage", relPath: "Library/Caches/carthage", explanation: StringTable.shared.string(.scanExpCarthageIkiliDerlemeOnbellegi, language: language))

        // 10. Dart / Flutter (pub, analysis-driver)
        probe(ecosystem: .dartFlutter, toolName: "pub", relPath: ".pub-cache", explanation: StringTable.shared.string(.scanExpDartFlutterPubPaketDeposu, language: language))
        probe(ecosystem: .dartFlutter, toolName: "dartServer", relPath: ".dartServer/.analysis-driver", explanation: StringTable.shared.string(.scanExpDartAnalizSunucusuOnbellegi, language: language))

        // 11. Sürüm Yöneticileri (Version Managers: mise, asdf, nvm, fnm, pyenv, rbenv, rustup, sdkman)
        probe(ecosystem: .versionManager, toolName: "mise", relPath: ".local/share/mise/cache", explanation: StringTable.shared.string(.scanExpMiseCalismaZamaniIndirmeOnbellegi, language: language))
        probe(ecosystem: .versionManager, toolName: "mise", relPath: ".local/share/mise/downloads", explanation: StringTable.shared.string(.scanExpMiseArsivIndirmeleri, language: language))
        probe(ecosystem: .versionManager, toolName: "mise", relPath: ".cache/mise", explanation: StringTable.shared.string(.scanExpMiseOnbellekDiziniCacheMise, language: language))
        probe(ecosystem: .versionManager, toolName: "asdf", relPath: ".asdf/downloads", explanation: StringTable.shared.string(.scanExpAsdfCalismaZamaniIndirmeArsivi, language: language))
        probe(ecosystem: .versionManager, toolName: "asdf", relPath: ".asdf/repository", explanation: StringTable.shared.string(.scanExpAsdfEklentiDeposuMetaVerileri, language: language))
        probe(ecosystem: .versionManager, toolName: "nvm", relPath: ".nvm/.cache", explanation: StringTable.shared.string(.scanExpNvmNodeJsSurumIndirme, language: language))
        probe(ecosystem: .versionManager, toolName: "fnm", relPath: ".local/share/fnm/cache", explanation: StringTable.shared.string(.scanExpFnmNodeIndirmeOnbellegi, language: language))
        probe(ecosystem: .versionManager, toolName: "fnm", relPath: "Library/Caches/fnm_multicache", explanation: StringTable.shared.string(.scanExpFnmCokluSurumOnbellegi, language: language))
        probe(ecosystem: .versionManager, toolName: "pyenv", relPath: ".pyenv/cache", explanation: StringTable.shared.string(.scanExpPyenvPythonKaynakKoduIndirme, language: language))
        probe(ecosystem: .versionManager, toolName: "rbenv", relPath: ".rbenv/cache", explanation: StringTable.shared.string(.scanExpRbenvRubyKaynakKoduIndirme, language: language))
        probe(ecosystem: .versionManager, toolName: "rustup", relPath: ".rustup/downloads", explanation: StringTable.shared.string(.scanExpRustupAracZinciriIndirmeArsivi, language: language))
        probe(ecosystem: .versionManager, toolName: "sdkman", relPath: ".sdkman/archives", explanation: StringTable.shared.string(.scanExpSDKMANJVMSurumArsivleri, language: language))
        probe(ecosystem: .versionManager, toolName: "sdkman", relPath: ".sdkman/tmp", explanation: StringTable.shared.string(.scanExpSDKMANGeciciDosyalari, language: language))

        // 12. Diğer Ekosistemler (Elixir, Haskell, Lua, R, Perl)
        probe(ecosystem: .otherEcosystem, toolName: "hex / mix", relPath: ".hex/cache", explanation: StringTable.shared.string(.scanExpElixirHexPaketOnbellegi, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "mix", relPath: ".mix/archives", explanation: StringTable.shared.string(.scanExpElixirMixArsivOnbellegi, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "cabal", relPath: ".cabal/packages", explanation: StringTable.shared.string(.scanExpHaskellCabalPaketDeposu, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "stack", relPath: ".stack/snapshots", explanation: StringTable.shared.string(.scanExpHaskellStackSnapshotDerlemeOnbellegi, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "stack", relPath: ".stack/indices", explanation: StringTable.shared.string(.scanExpHaskellStackHackageIndeksArsivi, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "luarocks", relPath: ".cache/luarocks", explanation: StringTable.shared.string(.scanExpLuaRocksPaketIndirmeOnbellegi, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "luarocks", relPath: ".luarocks/cache", explanation: StringTable.shared.string(.scanExpLuaRocksYerelKayacOnbellegi, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "R / renv", relPath: "Library/Caches/R", explanation: StringTable.shared.string(.scanExpRRenvPaketOnbellegi, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "R / renv", relPath: ".cache/R/renv", explanation: StringTable.shared.string(.scanExpRRenvProjePaketHavuzu, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "cpan", relPath: ".cpan/sources", explanation: StringTable.shared.string(.scanExpPerlCPANKaynakArsivleri, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "cpan", relPath: ".cpan/build", explanation: StringTable.shared.string(.scanExpPerlCPANDerlemeArtiklariCpan, language: language))
        probe(ecosystem: .otherEcosystem, toolName: "cpanm", relPath: ".cpanm/work", explanation: StringTable.shared.string(.scanExpAppCpanminusGeciciCalismaDizini, language: language))

        // 13. Homebrew Ekosistem Araçları ve Çalışma Zamanları (Origin: .homebrew)
        let brewPrefixes = ["/opt/homebrew", "/usr/local"]
        for prefix in brewPrefixes {
            if isCancelled() { break }
            guard fm.fileExists(atPath: prefix) else { continue }
            // Homebrew Python
            for pyVer in ["python@3.13", "python@3.12", "python@3.11", "python3"] {
                let pyPath = "\(prefix)/opt/\(pyVer)"
                if fm.fileExists(atPath: pyPath) {
                    probe(ecosystem: .python, origin: .homebrew, toolName: "Homebrew Python (\(pyVer))", relPath: pyPath, explanation: StringTable.shared.string(.scanExpHomebrewPythonCalismaOrtamiVe, language: language), fullURL: URL(fileURLWithPath: pyPath))
                }
            }
            // Homebrew Node
            let nodePath = "\(prefix)/opt/node"
            if fm.fileExists(atPath: nodePath) {
                probe(ecosystem: .javascriptNode, origin: .homebrew, toolName: "Homebrew Node.js", relPath: nodePath, explanation: StringTable.shared.string(.scanExpHomebrewNodeJsCalismaOrtami, language: language), fullURL: URL(fileURLWithPath: nodePath))
            }
            // Homebrew Ruby
            for rbVer in ["ruby", "ruby@3.3", "ruby@3.2"] {
                let rbPath = "\(prefix)/opt/\(rbVer)"
                if fm.fileExists(atPath: rbPath) {
                    probe(ecosystem: .ruby, origin: .homebrew, toolName: "Homebrew Ruby (\(rbVer))", relPath: rbPath, explanation: StringTable.shared.string(.scanExpHomebrewRubyCalismaOrtami, language: language), fullURL: URL(fileURLWithPath: rbPath))
                }
            }
            // Homebrew Go
            let goPath = "\(prefix)/opt/go"
            if fm.fileExists(atPath: goPath) {
                probe(ecosystem: .goLang, origin: .homebrew, toolName: "Homebrew Go", relPath: goPath, explanation: StringTable.shared.string(.scanExpHomebrewGoSDKAraclari, language: language), fullURL: URL(fileURLWithPath: goPath))
            }
            // Homebrew Rust
            let rustPath = "\(prefix)/opt/rust"
            if fm.fileExists(atPath: rustPath) {
                probe(ecosystem: .rust, origin: .homebrew, toolName: "Homebrew Rust", relPath: rustPath, explanation: StringTable.shared.string(.scanExpHomebrewRustDerlemeAraclari, language: language), fullURL: URL(fileURLWithPath: rustPath))
            }
            // Homebrew OpenJDK
            let jdkPath = "\(prefix)/opt/openjdk"
            if fm.fileExists(atPath: jdkPath) {
                probe(ecosystem: .jvm, origin: .homebrew, toolName: "Homebrew OpenJDK", relPath: jdkPath, explanation: StringTable.shared.string(.scanExpHomebrewJavaGelistirmeOrtami, language: language), fullURL: URL(fileURLWithPath: jdkPath))
            }
            // Homebrew Perl
            let perlPath = "\(prefix)/opt/perl"
            if fm.fileExists(atPath: perlPath) {
                probe(ecosystem: .otherEcosystem, origin: .homebrew, toolName: "Homebrew Perl", relPath: perlPath, explanation: StringTable.shared.string(.scanExpHomebrewPerl5Ortami, language: language), fullURL: URL(fileURLWithPath: perlPath))
            }
        }
        // Homebrew Downloads / Caches
        probe(ecosystem: .otherEcosystem, origin: .homebrew, toolName: "Homebrew İndirme Önbelleği", relPath: "Library/Caches/Homebrew/downloads", explanation: StringTable.shared.string(.scanExpHomebrewSiseBottleVeKaynak, language: language))

        let sizes = DiskSpace.sizes(of: candidates.map(\.url), isCancelled: isCancelled)
        for (candidate, size) in zip(candidates, sizes) where size > 0 {
            items.append(candidate.make(size))
        }
        return items
    }

    /// Verilen önbellek dizininin alt klasör ve dosyalarını inceleyerek boyutlarını raporlar.
    public static func inspectCacheSubdirectories(at url: URL, maxCount: Int = 20) -> [CacheSubdirectoryInfo] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return [] }
        guard isDir.boolValue else {
            let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
            return [CacheSubdirectoryInfo(id: url.path, name: url.lastPathComponent, sizeBytes: size, isDirectory: false)]
        }
        guard let entries = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var list: [CacheSubdirectoryInfo] = []
        for entry in entries.prefix(maxCount) {
            let size = DiskSpace.size(of: entry)
            let isEntryDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            list.append(CacheSubdirectoryInfo(
                id: entry.path,
                name: entry.lastPathComponent,
                sizeBytes: size,
                isDirectory: isEntryDir
            ))
        }
        return list.sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
