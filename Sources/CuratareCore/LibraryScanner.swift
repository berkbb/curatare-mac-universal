// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// `library_clean.md` içindeki 5 bulgu grubu (A–E) ve 6 adımlı `~/Library` + `/Library` denetim motoru.
public enum AuditGroup: String, Sendable, Codable, CaseIterable, Identifiable {
    /// Grup A — Kullanıcının kendi projelerinden kalanlar (`*Tests-<UUID>.plist`, `*Fuzz-<UUID>.plist`, şablon ID'ler).
    case groupA = "A"
    /// Grup B — Silinmiş proje konteynerleri (`containermanagerd` metadata `application_bundle` yolu diskte yok).
    case groupB = "B"
    /// Grup C — Çıplak adlı geliştirme izleri (`swift run` veya bundle ID'siz ikililer).
    case groupC = "C"
    /// Grup D — Kaldırılmış uygulama artıkları (11 `~/Library` klasöründe kurulu hiçbir uygulamayla eşleşmeyen reverse-DNS öğeleri).
    case groupD = "D"
    /// Grup E — Bozuk `LaunchAgents`/`LaunchDaemons`, `/Library` sistem artıkları ve yetim `pkgutil` paket kayıtları.
    case groupE = "E"

    public var id: String { rawValue }
}

public struct LibraryFinding: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let group: AuditGroup
    public let url: URL
    public let displayName: String
    public let matchedIdentifier: String
    public let librarySubfolder: String
    public let sizeBytes: Int64
    public let explanation: String
    public let requiresSudo: Bool
    public let associatedReceiptID: String?
    public let launchctlLabel: String?
    public var isSelected: Bool

    public init(
        id: String? = nil,
        group: AuditGroup,
        url: URL,
        displayName: String,
        matchedIdentifier: String,
        librarySubfolder: String,
        sizeBytes: Int64,
        explanation: String,
        requiresSudo: Bool = false,
        associatedReceiptID: String? = nil,
        launchctlLabel: String? = nil,
        isSelected: Bool = true
    ) {
        self.id = id ?? url.path
        self.group = group
        self.url = url
        self.displayName = displayName
        self.matchedIdentifier = matchedIdentifier
        self.librarySubfolder = librarySubfolder
        self.sizeBytes = sizeBytes
        self.explanation = explanation
        self.requiresSudo = requiresSudo
        self.associatedReceiptID = associatedReceiptID
        self.launchctlLabel = launchctlLabel
        self.isSelected = isSelected
    }
}

public struct InstalledBundleIndex: Sendable, Equatable {
    public let bundleIDs: Set<String>
    public let rootPrefixes: Set<String>
    public let appNames: Set<String>
    public let githubRepoNames: Set<String>

    public init(
        bundleIDs: Set<String>,
        rootPrefixes: Set<String>? = nil,
        appNames: Set<String> = [],
        githubRepoNames: Set<String> = []
    ) {
        let lowerIDs = Set(bundleIDs.map { $0.lowercased() })
        self.bundleIDs = lowerIDs
        if let rootPrefixes {
            self.rootPrefixes = Set(rootPrefixes.map { $0.lowercased() })
        } else {
            self.rootPrefixes = Self.computeRootPrefixes(from: lowerIDs)
        }
        self.appNames = Set(appNames.map { $0.lowercased() })
        self.githubRepoNames = Set(githubRepoNames.map { $0.lowercased() })
    }

    public static func computeRootPrefixes(from bundleIDs: Set<String>) -> Set<String> {
        var roots: Set<String> = []
        for id in bundleIDs {
            let parts = id.split(separator: ".")
            if parts.count >= 3 {
                roots.insert(parts.prefix(3).joined(separator: ".").lowercased())
            } else if parts.count == 2 {
                roots.insert(parts.joined(separator: ".").lowercased())
            }
        }
        return roots
    }

    /// Verilen reverse-DNS kimliğinin kurulu bir uygulama, eklenti veya 3 bileşenli kök önekle eşleşip eşleşmediğini döner.
    public func matches(identifier: String) -> Bool {
        let clean = ProtectionRules.stripKnownSuffixes(from: identifier).lowercased()
        if bundleIDs.contains(clean) { return true }
        for installed in bundleIDs {
            if clean.hasPrefix(installed + ".") || installed.hasPrefix(clean + ".") {
                return true
            }
        }
        let parts = clean.split(separator: ".")
        if parts.count >= 3 {
            let root3 = parts.prefix(3).joined(separator: ".")
            if rootPrefixes.contains(root3) { return true }
        }
        return false
    }
}

public struct LibraryAuditReport: Sendable, Equatable {
    public let scannedAt: Date
    public let installedCount: Int
    public let findings: [LibraryFinding]
    public let orphanedReceipts: [String]
    public let sudoCommand: String?

    public init(
        scannedAt: Date = Date(),
        installedCount: Int,
        findings: [LibraryFinding],
        orphanedReceipts: [String] = [],
        sudoCommand: String? = nil
    ) {
        self.scannedAt = scannedAt
        self.installedCount = installedCount
        self.findings = findings
        self.orphanedReceipts = orphanedReceipts
        self.sudoCommand = sudoCommand
    }

    public var totalReclaimableBytes: Int64 {
        findings.map(\.sizeBytes).saturatingSum()
    }

    public func findings(for group: AuditGroup) -> [LibraryFinding] {
        findings.filter { $0.group == group }
    }
}

/// `library_clean.md` Adım 1–6 tarayıcısı.
public struct LibraryScanner: Sendable {
    /// Kullanıcıya gösterilen açıklama ve gerekçelerin dili; metinler `Localizable.strings` tablolarından gelir.
    public var language: String = "en"

    /// Aynı yapılandırmanın verilen dilde metin üreten kopyası.
    public func localized(to code: String) -> LibraryScanner {
        var copy = self
        copy.language = code
        return copy
    }

    /// Denetlenen 11 `~/Library` klasörü (`library_clean.md` Adım 2).
    public static let userLibrarySubfolders: [String] = [
        "Preferences",
        "Containers",
        "Group Containers",
        "Application Support",
        "Caches",
        "Saved Application State",
        "HTTPStorages",
        "WebKit",
        "Application Scripts",
        "Logs",
        "LaunchAgents",
    ]

    public let homeDirectoryURL: URL
    public let systemLibraryURL: URL
    public let applicationDirectories: [URL]
    public let githubDirectoryURL: URL

    public init(
        homeDirectoryURL: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        systemLibraryURL: URL = URL(fileURLWithPath: "/Library", isDirectory: true),
        applicationDirectories: [URL]? = nil,
        githubDirectoryURL: URL? = nil
    ) {
        self.homeDirectoryURL = homeDirectoryURL
        self.systemLibraryURL = systemLibraryURL
        self.applicationDirectories = applicationDirectories ?? [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/Caskroom", isDirectory: true),
        ]
        self.githubDirectoryURL = githubDirectoryURL ?? homeDirectoryURL.appendingPathComponent("Documents/GitHub", isDirectory: true)
    }

    // MARK: - Adım 1: Kurulu Uygulamaların ve Bileşenlerin Bundle ID İndeksi

    public func buildInstalledIndex(isCancelled: () -> Bool = { false }) -> InstalledBundleIndex {
        let fm = FileManager.default
        var ids: Set<String> = []
        var appNames: Set<String> = []

        func inspectBundle(at url: URL) {
            if isCancelled() { return }
            let ext = url.pathExtension.lowercased()
            if ext == "app" {
                appNames.insert(url.deletingPathExtension().lastPathComponent.lowercased())
            }
            // Standart Info.plist
            let infoPlist = url.appendingPathComponent("Contents/Info.plist")
            if let id = Self.readBundleIdentifier(fromPlist: infoPlist) {
                ids.insert(id.lowercased())
            }
            // iOS / iPadOS Wrapper uygulaması: <App>.app/Wrapper/<Inner>.app/Info.plist (`library_clean.md` Adım 1)
            let wrapperDir = url.appendingPathComponent("Wrapper", isDirectory: true)
            if let wrapperEntries = try? fm.contentsOfDirectory(at: wrapperDir, includingPropertiesForKeys: nil) {
                for inner in wrapperEntries where inner.pathExtension.lowercased() == "app" {
                    appNames.insert(inner.deletingPathExtension().lastPathComponent.lowercased())
                    let innerPlist = inner.appendingPathComponent("Info.plist")
                    if let id = Self.readBundleIdentifier(fromPlist: innerPlist) {
                        ids.insert(id.lowercased())
                    }
                }
            }
            // Gömülü yardımcılar: Contents/Library/LaunchServices, Contents/PlugIns, Contents/XPCServices
            for embeddedRel in ["Contents/Library/LaunchServices", "Contents/PlugIns", "Contents/XPCServices", "Contents/Library/LoginItems"] {
                let embeddedDir = url.appendingPathComponent(embeddedRel, isDirectory: true)
                if let children = try? fm.contentsOfDirectory(at: embeddedDir, includingPropertiesForKeys: nil) {
                    for child in children {
                        if let id = Self.readBundleIdentifier(fromPlist: child.appendingPathComponent("Contents/Info.plist")) {
                            ids.insert(id.lowercased())
                        } else {
                            ids.insert(child.deletingPathExtension().lastPathComponent.lowercased())
                        }
                    }
                }
            }
        }

        for dir in applicationDirectories {
            if isCancelled() { break }
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
            for item in items {
                if isCancelled() { break }
                let ext = item.pathExtension.lowercased()
                if ["app", "prefpane", "qlgenerator", "saver", "plugin", "mdimporter", "component"].contains(ext) {
                    inspectBundle(at: item)
                } else if let subItems = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    // Alt klasör içindeki uygulamalar (ör. /Applications/Adobe Photoshop 2026/*.app veya Caskroom/<cask>/<ver>/*.app)
                    for sub in subItems {
                        if isCancelled() { break }
                        if sub.pathExtension.lowercased() == "app" {
                            inspectBundle(at: sub)
                        } else if let deepItems = try? fm.contentsOfDirectory(at: sub, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                            for deep in deepItems where deep.pathExtension.lowercased() == "app" {
                                inspectBundle(at: deep)
                            }
                        }
                    }
                }
            }
        }

        // Ek sistem / kullanıcı eklenti klasörleri
        let pluginDirs: [URL] = [
            systemLibraryURL.appendingPathComponent("PreferencePanes"),
            systemLibraryURL.appendingPathComponent("QuickLook"),
            systemLibraryURL.appendingPathComponent("Internet Plug-Ins"),
            systemLibraryURL.appendingPathComponent("Printers"),
            systemLibraryURL.appendingPathComponent("PrivilegedHelperTools"),
            homeDirectoryURL.appendingPathComponent("Library/PreferencePanes"),
            homeDirectoryURL.appendingPathComponent("Library/QuickLook"),
            homeDirectoryURL.appendingPathComponent("Library/Screen Savers"),
        ]
        for dir in pluginDirs {
            if isCancelled() { break }
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for item in items {
                if let id = Self.readBundleIdentifier(fromPlist: item.appendingPathComponent("Contents/Info.plist")) {
                    ids.insert(id.lowercased())
                } else {
                    ids.insert(item.deletingPathExtension().lastPathComponent.lowercased())
                }
            }
        }

        // GitHub klasöründeki aktif depo adları (Grup A/B/C karşılaştırması için)
        var repoNames: Set<String> = []
        if let repos = try? fm.contentsOfDirectory(at: githubDirectoryURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for r in repos {
                repoNames.insert(r.lastPathComponent.lowercased())
            }
        }

        return InstalledBundleIndex(bundleIDs: ids, appNames: appNames, githubRepoNames: repoNames)
    }

    // MARK: - Tam Denetim (Adım 1–6, Grup A–E)

    public func scanAll(
        customWhitelist: [String] = [],
        installedIndexOverride: InstalledBundleIndex? = nil,
        isCancelled: () -> Bool = { false }
    ) -> LibraryAuditReport {
        let index = installedIndexOverride ?? buildInstalledIndex(isCancelled: isCancelled)
        guard !isCancelled() else {
            return LibraryAuditReport(installedCount: 0, findings: [], orphanedReceipts: [], sudoCommand: nil)
        }
        let userWhitelist = ProtectionRules.loadUserWhitelist(homeDirectory: homeDirectoryURL, extraPatterns: customWhitelist)
        let protection = ProtectionRules(
            installedBundleIDs: index.bundleIDs,
            installedAppNames: index.appNames,
            userWhitelistPatterns: userWhitelist
        )

        var findings: [LibraryFinding] = []
        var seenPaths: Set<String> = []

        func appendFinding(_ f: LibraryFinding) {
            guard !seenPaths.contains(f.url.path) else { return }
            seenPaths.insert(f.url.path)
            findings.append(f)
        }

        // Adım 3: Grup B — Silinmiş Proje Konteynerleri (`~/Library/Containers`)
        let userLibrary = homeDirectoryURL.appendingPathComponent("Library", isDirectory: true)
        let containersDir = userLibrary.appendingPathComponent("Containers", isDirectory: true)
        if let containerEntries = try? FileManager.default.contentsOfDirectory(at: containersDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for container in containerEntries {
                if isCancelled() { break }
                if let groupBFinding = evaluateContainerMetadata(at: container, index: index, protection: protection, isCancelled: isCancelled) {
                    appendFinding(groupBFinding)
                }
            }
        }

        // Adım 2 & 4: 11 `~/Library` klasöründe Grup A, C, D ve E (LaunchAgents) taraması
        for subfolder in Self.userLibrarySubfolders {
            if isCancelled() { break }
            let folderURL = userLibrary.appendingPathComponent(subfolder, isDirectory: true)
            guard let items = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
                continue
            }

            for item in items {
                if isCancelled() { break }
                guard !seenPaths.contains(item.path) else { continue }
                let rawName = item.lastPathComponent
                let stripped = ProtectionRules.stripKnownSuffixes(from: rawName)

                let decision = protection.evaluate(path: item.path, candidateIdentifier: stripped)
                if decision.isProtected { continue }

                // LaunchAgents özel denetimi (Adım 5 - Grup E)
                if subfolder == "LaunchAgents" && rawName.lowercased().hasSuffix(".plist") {
                    if let deadAgent = evaluateLaunchPlist(at: item, subfolder: "LaunchAgents", requiresSudo: false, protection: protection) {
                        appendFinding(deadAgent)
                        continue
                    }
                    // Program yaşıyorsa bu LaunchAgent'a ve sahibine dokunma
                    continue
                }

                // Grup A: Test plisti (`*Tests-<UUID>.plist`, `*Fuzz-<UUID>.plist`) veya şablon ID (`com.companyname.*`, `com.example.*`)
                if Self.isTestOrTemplateArtifact(name: rawName, strippedID: stripped) {
                    let size = DiskSpace.size(of: item, isCancelled: isCancelled)
                    appendFinding(LibraryFinding(
                        group: .groupA,
                        url: item,
                        displayName: rawName,
                        matchedIdentifier: stripped,
                        librarySubfolder: subfolder,
                        sizeBytes: size,
                        explanation: StringTable.shared.string(.auditExpTestRunOrTemplateProject, language: language)
                    ))
                    continue
                }

                // Reverse-DNS mi yoksa çıplak ad mı?
                if Self.looksLikeReverseDNS(stripped) {
                    if !index.matches(identifier: stripped) {
                        // Kullanıcının kendi geliştirme öneklerinden biri mi? (Grup A)
                        let group: AuditGroup = Self.isLikelyPersonalDevBundleID(stripped, repoNames: index.githubRepoNames) ? .groupA : .groupD
                        let size = DiskSpace.size(of: item, isCancelled: isCancelled)
                        appendFinding(LibraryFinding(
                            group: group,
                            url: item,
                            displayName: rawName,
                            matchedIdentifier: stripped,
                            librarySubfolder: subfolder,
                            sizeBytes: size,
                            explanation: group == .groupA
                                ? "Retired or uninstalled personal project identifier (\(stripped))"
                                : "No installed application matches \(stripped)"
                        ))
                    }
                } else if Self.isSuspiciousBareDevTrace(name: rawName, subfolder: subfolder, index: index) {
                    // Grup C: Çıplak adlı geliştirme izi
                    let size = DiskSpace.size(of: item, isCancelled: isCancelled)
                    appendFinding(LibraryFinding(
                        group: .groupC,
                        url: item,
                        displayName: rawName,
                        matchedIdentifier: stripped,
                        librarySubfolder: subfolder,
                        sizeBytes: size,
                        explanation: StringTable.shared.string(.auditExpBareNamedCLISwiftRun, language: language)
                    ))
                }
            }
        }

        // Adım 5 & 6: Grup E — `/Library/LaunchAgents`, `/Library/LaunchDaemons` ve `/Library/Application Support` sistem yetimleri
        for sysSub in ["LaunchAgents", "LaunchDaemons"] {
            let dir = systemLibraryURL.appendingPathComponent(sysSub, isDirectory: true)
            guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for item in items where item.pathExtension.lowercased() == "plist" {
                if isCancelled() { break }
                if let deadDaemon = evaluateLaunchPlist(at: item, subfolder: "/Library/\(sysSub)", requiresSudo: true, protection: protection) {
                    appendFinding(deadDaemon)
                }
            }
        }

        let sudoCmd = Self.generateSudoCommand(for: findings, orphanedReceipts: [])
        return LibraryAuditReport(
            installedCount: index.bundleIDs.count,
            findings: findings.sorted { $0.sizeBytes > $1.sizeBytes },
            orphanedReceipts: [],
            sudoCommand: sudoCmd
        )
    }

    // MARK: - Adım 3 Yardımcıları (`containermanagerd` Metadata Denetimi)

    func evaluateContainerMetadata(
        at containerURL: URL,
        index: InstalledBundleIndex,
        protection: ProtectionRules,
        isCancelled: () -> Bool = { false }
    ) -> LibraryFinding? {
        guard !isCancelled() else { return nil }
        let metaURL = containerURL.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
        guard let dict = NSDictionary(contentsOf: metaURL) as? [String: Any] else { return nil }

        let identifier = (dict["MCMMetadataIdentifier"] as? String) ?? containerURL.lastPathComponent
        let decision = protection.evaluate(path: containerURL.path, candidateIdentifier: identifier)
        if decision.isProtected { return nil }

        let info = dict["MCMMetadataInfo"] as? [String: Any]
        let appBundlePath = (info?["application_bundle"] as? String) ?? (dict["application_bundle"] as? String)
        guard let appBundlePath, !appBundlePath.isEmpty else { return nil }

        // iOS Wrapper konteynerleri (`/private/var/folders/.../Wrapper/X.app`) geçici çalışma kopyasıdır; atla!
        if appBundlePath.contains("/Wrapper/") { return nil }

        let isUserOrTempBuild = appBundlePath.hasPrefix("/Users/")
            || appBundlePath.hasPrefix("/Volumes/")
            || appBundlePath.hasPrefix("/private/tmp/")
            || appBundlePath.hasPrefix("/tmp/")
        guard isUserOrTempBuild else { return nil }

        let fm = FileManager.default
        guard !fm.fileExists(atPath: appBundlePath) else { return nil }

        // Uygulama şu anda `/Applications` içinde kuruluysa silinmiş sayma
        if index.matches(identifier: identifier) { return nil }

        // Kaynak deposu `~/Documents/GitHub` altında hâlâ duruyorsa dokunma (`library_clean.md` Adım 3)
        let bundleName = ((appBundlePath as NSString).lastPathComponent as NSString).deletingPathExtension.lowercased()
        if index.githubRepoNames.contains(bundleName) { return nil }

        let size = DiskSpace.size(of: containerURL, isCancelled: isCancelled)
        guard !isCancelled() else { return nil }
        return LibraryFinding(
            group: .groupB,
            url: containerURL,
            displayName: containerURL.lastPathComponent,
            matchedIdentifier: identifier,
            librarySubfolder: "Containers",
            sizeBytes: size,
            explanation: StringTable.shared.format(.auditExpContainerPointsToMissingBuild, language: language, "\(appBundlePath)")
        )
    }

    // MARK: - Adım 5 Yardımcıları (`LaunchAgents` / `LaunchDaemons` Plist Denetimi)

    public func evaluateLaunchPlist(
        at plistURL: URL,
        subfolder: String,
        requiresSudo: Bool,
        protection: ProtectionRules
    ) -> LibraryFinding? {
        let rawName = plistURL.lastPathComponent
        let stripped = ProtectionRules.stripKnownSuffixes(from: rawName)
        if protection.evaluate(path: plistURL.path, candidateIdentifier: stripped).isProtected {
            return nil
        }
        guard let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] else { return nil }
        let label = (dict["Label"] as? String) ?? stripped
        if protection.evaluate(path: plistURL.path, candidateIdentifier: label).isProtected {
            return nil
        }

        let program: String?
        if let p = dict["Program"] as? String, !p.isEmpty {
            program = p
        } else if let args = dict["ProgramArguments"] as? [String], let first = args.first, !first.isEmpty {
            // `sh -c "/yol/komut ..."` kalıbını da çöz
            if (first == "/bin/sh" || first == "/bin/bash" || first == "/bin/zsh"), args.count >= 3, args[1] == "-c" {
                let cmdLine = args[2].trimmingCharacters(in: .whitespaces)
                let firstToken = cmdLine.split(separator: " ").first.map(String.init) ?? ""
                program = firstToken.hasPrefix("/") ? firstToken : nil
            } else {
                program = first
            }
        } else {
            program = nil
        }

        guard let executablePath = program, executablePath.hasPrefix("/") else { return nil }
        // Sistem ikililerini (`/System/`, `/usr/libexec/`, `/usr/bin/`, `/bin/`, `/sbin/`, `/usr/sbin/`) kullanan plisti bozuk sayma
        let systemExecPrefixes = ["/System/", "/usr/libexec/", "/usr/bin/", "/bin/", "/sbin/", "/usr/sbin/"]
        if systemExecPrefixes.contains(where: { executablePath.hasPrefix($0) }) {
            return nil
        }

        guard !FileManager.default.fileExists(atPath: executablePath) else { return nil }
        let size = DiskSpace.size(of: plistURL)
        return LibraryFinding(
            group: .groupE,
            url: plistURL,
            displayName: rawName,
            matchedIdentifier: label,
            librarySubfolder: subfolder,
            sizeBytes: size,
            explanation: StringTable.shared.format(.auditExpTargetExecutableMissingOnDisk, language: language, "\(executablePath)"),
            requiresSudo: requiresSudo,
            launchctlLabel: label
        )
    }

    // MARK: - Adım 6: Tek Satırlık Güvenli `sudo` Komutu Üretici (`echo TAMAM`)

    /// `library_clean.md` Adım 6 kuralına uygun olarak `/Library` sistem yetimleri ve `pkgutil --forget` için
    /// tarihli `~/.Trash` klasörüne taşıyan, sahipliği kullanıcıya çeviren ve `echo TAMAM` ile biten tek satırlık komut üretir.
    public static func generateSudoCommand(
        for findings: [LibraryFinding],
        orphanedReceipts: [String],
        datedTrashFolderName: String = "Curatare-$(date +%Y-%m-%d-%H%M%S)"
    ) -> String? {
        let privileged = findings.filter(\.requiresSudo)
        guard !privileged.isEmpty || !orphanedReceipts.isEmpty else { return nil }

        var parts: [String] = [
            "TRASH_DIR=\"$HOME/.Trash/\(datedTrashFolderName)/system\"",
            "mkdir -p \"$TRASH_DIR\"",
        ]

        for item in privileged {
            if let label = item.launchctlLabel, !label.isEmpty {
                let domain = item.librarySubfolder.contains("LaunchAgents") ? "gui/$(id -u)" : "system"
                parts.append("sudo launchctl bootout \(domain)/\(shellQuote(label)) 2>/dev/null || true")
            }
            let relParent = item.url.deletingLastPathComponent().path
            let trimmedParent = relParent.hasPrefix("/") ? String(relParent.dropFirst()) : relParent
            parts.append("sudo mkdir -p \"$TRASH_DIR/\(trimmedParent)\"")
            parts.append("sudo mv \(shellQuote(item.url.path)) \"$TRASH_DIR/\(trimmedParent)/\"")
        }

        if !privileged.isEmpty {
            parts.append("sudo chown -R \"$(id -un):staff\" \"$TRASH_DIR\"")
        }

        for receipt in orphanedReceipts where !receipt.isEmpty {
            parts.append("sudo pkgutil --forget \(shellQuote(receipt))")
        }

        parts.append("echo TAMAM")
        return parts.joined(separator: " && ")
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Sınıflandırma Yardımcıları

    public static func readBundleIdentifier(fromPlist url: URL) -> String? {
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let id = dict["CFBundleIdentifier"] as? String,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func looksLikeReverseDNS(_ candidate: String) -> Bool {
        let parts = candidate.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty }) else { return false }
        let tlds: Set<String> = [
            "com", "org", "net", "io", "app", "me", "dev", "co", "edu", "gov",
            "tr", "ro", "de", "uk", "us", "ru", "at", "ch", "nl", "fr", "it",
            "es", "jp", "cn", "kr", "ca", "au", "br", "in", "xyz", "fit", " pro",
        ]
        return tlds.contains(parts[0].lowercased())
    }

    public static func isTestOrTemplateArtifact(name: String, strippedID: String) -> Bool {
        let lower = name.lowercased()
        let lowerID = strippedID.lowercased()
        if lowerID.hasPrefix("com.companyname.") || lowerID.hasPrefix("com.example.") ||
           lowerID.hasPrefix("org.reactjs.native.example.") || lowerID.hasPrefix("com.yourcompany.") {
            return true
        }
        // *Tests-<UUID>.plist veya *Fuzz-<UUID>.plist
        let testPattern = #"(tests|fuzz)-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"#
        if let regex = try? NSRegularExpression(pattern: testPattern, options: .caseInsensitive),
           regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) != nil {
            return true
        }
        return false
    }

    public static func isLikelyPersonalDevBundleID(_ strippedID: String, repoNames: Set<String>) -> Bool {
        let lower = strippedID.lowercased()
        if lower.hasPrefix("com.berkbabadogan.") || lower.hasPrefix("com.babadogantech.") || lower.hasPrefix("net.babadogan.") {
            return true
        }
        let lastPart = lower.split(separator: ".").last.map(String.init) ?? ""
        return !lastPart.isEmpty && repoNames.contains(lastPart)
    }

    public static func isSuspiciousBareDevTrace(name: String, subfolder: String, index: InstalledBundleIndex) -> Bool {
        guard ["Preferences", "Caches", "HTTPStorages", "WebKit"].contains(subfolder) else { return false }
        let stripped = ProtectionRules.stripKnownSuffixes(from: name)
        guard !stripped.contains("."), !stripped.contains(" "), !stripped.hasPrefix(".") else { return false }
        let lower = stripped.lowercased()
        if ProtectionRules.appleSystemBareNames.contains(lower) { return false }
        if index.appNames.contains(lower) || index.bundleIDs.contains(lower) { return false }
        // `swift run` veya CLI ikilisi `.plist` / HTTPStorage / Caches izi
        if subfolder == "Preferences" && name.lowercased().hasSuffix(".plist") {
            return index.githubRepoNames.contains(lower) || lower.hasSuffix("cli") || lower.hasSuffix("tests")
        }
        if subfolder == "HTTPStorages" || subfolder == "Caches" {
            return index.githubRepoNames.contains(lower) || lower.hasSuffix("cli") || lower.hasSuffix("tests")
        }
        return false
    }
}
