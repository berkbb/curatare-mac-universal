// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Security

/// Kapsamlı yerel uygulama, araç takımı (Widget) ve eklenti (Plugin) kaldırıcı.
///
/// Özellikler:
/// - **Uygulamalar (`Applications`)**, **Araç Takımları (`Widgets`)** ve **Eklentiler (`Plugins`)** sekmeleri.
/// - Sürükle-bırak veya listeden seçimle bir `.app` / eklenti açıldığında `~/Library` ve `/Library` altındaki tüm ilişkili
///   konteyner, grup konteyneri, tercih, ByHost, önbellek, kayıtlı durum, HTTPStorage, çerez, WebKit, günlük, tanılama raporu,
///   LaunchAgent, LaunchDaemon, PrivilegedHelper, paket makbuzu ve paylaşılan veri dosyalarını boyutları ve onay kutularıyla listeler (`AssociatedFile`).
/// - Curatare Akıllı Eşleştirme Motoru (`SmartBundleMatcher`) ve Kod İmzalama Hakları (`com.apple.security.application-groups`) çözümlemesini uygular.
/// - Sistem uygulamalarını, çalışan uygulamaları (`pgrep` / `NSRunningApplication`) ve Curatare ailesini korur.
/// - Seçilen tüm dosyaları **yalnızca tarihli `~/.Trash/Curatare-YYYY-MM-DD-HHmmss` klasörüne** taşır (`DatedTrashService`).
public enum BundleKind: String, Sendable, Codable, CaseIterable, Identifiable {
    case application
    case widget
    case plugin

    public var id: String { rawValue }
}

public struct AssociatedFile: Sendable, Codable, Equatable, Identifiable {
    public enum LocationKind: String, Sendable, Codable, Equatable, CaseIterable {
        case appBundle
        case container
        case groupContainer
        case applicationSupport
        case crashReporter
        case caches
        case preferences
        case byHostPreferences
        case syncedPreferences
        case savedState
        case httpStorage
        case cookies
        case webKit
        case logs
        case diagnosticReports
        case launchAgent
        case launchDaemon
        case privilegedHelper
        case applicationScripts
        case autosaveInformation
        case recentDocuments
        case receipts
        case sharedUserData
        case plugin
        case safariExtensions
        case accounts

        /// Kalıntı türünün etiketi; metinler her dilin kendi `Localizable.strings` dosyasındadır.
        public var titleKey: LKey {
            switch self {
            case .appBundle: .uninstallerKindAppBundle
            case .container: .uninstallerKindContainer
            case .groupContainer: .uninstallerKindGroupContainer
            case .applicationSupport: .uninstallerKindApplicationSupport
            case .crashReporter: .uninstallerKindCrashReporter
            case .caches: .uninstallerKindCaches
            case .preferences: .uninstallerKindPreferences
            case .byHostPreferences: .uninstallerKindByHostPreferences
            case .syncedPreferences: .uninstallerKindSyncedPreferences
            case .savedState: .uninstallerKindSavedState
            case .httpStorage: .uninstallerKindHTTPStorage
            case .cookies: .uninstallerKindCookies
            case .webKit: .uninstallerKindWebKit
            case .logs: .uninstallerKindLogs
            case .diagnosticReports: .uninstallerKindDiagnosticReports
            case .launchAgent: .uninstallerKindLaunchAgent
            case .launchDaemon: .uninstallerKindLaunchDaemon
            case .privilegedHelper: .uninstallerKindPrivilegedHelper
            case .applicationScripts: .uninstallerKindApplicationScripts
            case .autosaveInformation: .uninstallerKindAutosaveInformation
            case .recentDocuments: .uninstallerKindRecentDocuments
            case .receipts: .uninstallerKindReceipts
            case .sharedUserData: .uninstallerKindSharedUserData
            case .plugin: .uninstallerKindPlugin
            case .safariExtensions: .uninstallerKindSafariExtensions
            case .accounts: .uninstallerKindAccounts
            }
        }
    }

    public let id: String
    public let url: URL
    public let kind: LocationKind
    public let sizeBytes: Int64
    public let requiresSudo: Bool
    public var isSelected: Bool

    public init(
        url: URL,
        kind: LocationKind,
        sizeBytes: Int64,
        requiresSudo: Bool = false,
        isSelected: Bool = true
    ) {
        self.id = url.path
        self.url = url
        self.kind = kind
        self.sizeBytes = sizeBytes
        self.requiresSudo = requiresSudo
        self.isSelected = isSelected
    }
}

public struct InstalledBundle: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let kind: BundleKind
    public let name: String
    public let bundleID: String
    public let version: String
    public let url: URL
    public let bundleSizeBytes: Int64
    public let isProtected: Bool
    public let protectionReason: String?
    public let isRunning: Bool
    public let isWrapperIOSApp: Bool
    public let appGroups: [String]
    public let nestedBundleIDs: [String]

    public var isMountedVolume: Bool {
        let p = url.standardizedFileURL.path
        if p.hasPrefix("/Volumes/") && !p.hasPrefix("/Volumes/Macintosh HD") {
            return true
        }
        if let res = try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey]), res.volumeIsReadOnly == true {
            return true
        }
        return false
    }

    public var isSystemImmutable: Bool {
        let p = url.standardizedFileURL.path.lowercased()
        return p.hasPrefix("/system/") || p == "/system"
    }

    public init(
        kind: BundleKind,
        name: String,
        bundleID: String,
        version: String,
        url: URL,
        bundleSizeBytes: Int64,
        isProtected: Bool = false,
        protectionReason: String? = nil,
        isRunning: Bool = false,
        isWrapperIOSApp: Bool = false,
        appGroups: [String] = [],
        nestedBundleIDs: [String] = []
    ) {
        self.id = url.path
        self.kind = kind
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.url = url
        self.bundleSizeBytes = bundleSizeBytes
        self.isProtected = isProtected
        self.protectionReason = protectionReason
        self.isRunning = isRunning
        self.isWrapperIOSApp = isWrapperIOSApp
        self.appGroups = appGroups
        self.nestedBundleIDs = nestedBundleIDs
    }
}

/// Launchd Servis Denetleyicisi: LaunchAgent ve LaunchDaemon'ları launchctl üzerinden durdurur ve geri yükler.
public enum LaunchdManager: Sendable {
    public static func extractLabel(from plistURL: URL) -> String? {
        guard let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] else { return nil }
        return dict["Label"] as? String
    }

    @discardableResult
    public static func unloadJob(at plistURL: URL, isUserAgent: Bool = true) -> Bool {
        let uid = getuid()
        let domain = isUserAgent ? "gui/\(uid)" : "system"
        if let label = extractLabel(from: plistURL), !label.isEmpty {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            p.arguments = ["bootout", "\(domain)/\(label)"]
            try? p.run()
            p.waitUntilExit()
            if p.terminationStatus == 0 { return true }
        }

        let p2 = Process()
        p2.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p2.arguments = ["unload", plistURL.path]
        try? p2.run()
        p2.waitUntilExit()
        return p2.terminationStatus == 0
    }

    @discardableResult
    public static func loadJob(at plistURL: URL, isUserAgent: Bool = true) -> Bool {
        let uid = getuid()
        let domain = isUserAgent ? "gui/\(uid)" : "system"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = ["bootstrap", domain, plistURL.path]
        try? p.run()
        p.waitUntilExit()
        if p.terminationStatus == 0 { return true }

        let p2 = Process()
        p2.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p2.arguments = ["load", plistURL.path]
        try? p2.run()
        p2.waitUntilExit()
        return p2.terminationStatus == 0
    }
}

public struct AppUninstaller: Sendable {
    public let homeDirectoryURL: URL
    public let applicationDirectories: [URL]
    public let pluginDirectories: [URL]
    public let widgetDirectories: [URL]

    public init(
        homeDirectoryURL: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        applicationDirectories: [URL]? = nil,
        pluginDirectories: [URL]? = nil,
        widgetDirectories: [URL]? = nil
    ) {
        self.homeDirectoryURL = homeDirectoryURL
        self.applicationDirectories = applicationDirectories ?? [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Applications", isDirectory: true),
        ]
        self.pluginDirectories = pluginDirectories ?? [
            homeDirectoryURL.appendingPathComponent("Library/PreferencePanes", isDirectory: true),
            URL(fileURLWithPath: "/Library/PreferencePanes", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/QuickLook", isDirectory: true),
            URL(fileURLWithPath: "/Library/QuickLook", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Internet Plug-Ins", isDirectory: true),
            URL(fileURLWithPath: "/Library/Internet Plug-Ins", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Screen Savers", isDirectory: true),
            URL(fileURLWithPath: "/Library/Screen Savers", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Spotlight", isDirectory: true),
            URL(fileURLWithPath: "/Library/Spotlight", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Contextual Menu Items", isDirectory: true),
            URL(fileURLWithPath: "/Library/Contextual Menu Items", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/InputManagers", isDirectory: true),
            URL(fileURLWithPath: "/Library/InputManagers", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/Mail/Bundles", isDirectory: true),
            URL(fileURLWithPath: "/Library/Mail/Bundles", isDirectory: true),
            homeDirectoryURL.appendingPathComponent("Library/QuickTime", isDirectory: true),
            URL(fileURLWithPath: "/Library/QuickTime", isDirectory: true),
            URL(fileURLWithPath: "/Library/Audio/Plug-Ins/Components", isDirectory: true),
        ]
        self.widgetDirectories = widgetDirectories ?? [
            homeDirectoryURL.appendingPathComponent("Library/Widgets", isDirectory: true),
            URL(fileURLWithPath: "/Library/Widgets", isDirectory: true),
        ]
    }

    /// Kurulu uygulamaları, widget'ları ve eklentileri tarar.
    public func scanInstalledBundles(
        protectionRules: ProtectionRules = ProtectionRules(),
        computeBundleSizes: Bool = true,
        isCancelled: () -> Bool = { false }
    ) -> [InstalledBundle] {
        let fm = FileManager.default
        let runningSnapshot = ProtectionRules.RunningProcessSnapshot()
        var results: [InstalledBundle] = []
        var seenPaths: Set<String> = []

        func addBundle(at url: URL, kind: BundleKind) {
            let stdPath = url.standardizedFileURL.path
            guard !seenPaths.contains(stdPath) else { return }
            seenPaths.insert(stdPath)
            if let info = inspectBundle(
                at: url,
                kind: kind,
                protectionRules: protectionRules,
                runningSnapshot: runningSnapshot,
                computeSize: computeBundleSizes,
                isCancelled: isCancelled
            ) {
                results.append(info)
            }
        }

        // 1. Uygulamalar (ve içlerindeki .appex Widget eklentileri)
        for dir in applicationDirectories {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for item in items {
                if isCancelled() { break }
                if item.pathExtension.lowercased() == "app" {
                    addBundle(at: item, kind: .application)
                    scanEmbeddedWidgets(inApp: item, addBundle: addBundle)
                } else if let subItems = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for sub in subItems where sub.pathExtension.lowercased() == "app" {
                        addBundle(at: sub, kind: .application)
                        scanEmbeddedWidgets(inApp: sub, addBundle: addBundle)
                    }
                }
            }
        }

        // 2. Bağımsız Widget klasörleri
        for dir in widgetDirectories {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for item in items where ["wdgt", "appex"].contains(item.pathExtension.lowercased()) {
                if isCancelled() { break }
                addBundle(at: item, kind: .widget)
            }
        }

        // 3. Eklentiler (PreferencePanes, QuickLook, Internet Plug-Ins, Screen Savers, Spotlight, Audio Components)
        let pluginExts: Set<String> = ["prefpane", "qlgenerator", "plugin", "saver", "mdimporter", "component"]
        for dir in pluginDirectories {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for item in items where pluginExts.contains(item.pathExtension.lowercased()) {
                if isCancelled() { break }
                addBundle(at: item, kind: .plugin)
            }
        }

        return results.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func scanEmbeddedWidgets(inApp appURL: URL, addBundle: (URL, BundleKind) -> Void) {
        let plugInsDir = appURL.appendingPathComponent("Contents/PlugIns", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(at: plugInsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return }
        for entry in entries where entry.pathExtension.lowercased() == "appex" {
            let plistURL = entry.appendingPathComponent("Contents/Info.plist")
            if let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
               let extDict = dict["NSExtension"] as? [String: Any],
               let pointID = extDict["NSExtensionPointIdentifier"] as? String,
               pointID.contains("widgetkit") || pointID.contains("widget") {
                addBundle(entry, .widget)
            }
        }
    }

    /// Uygulamanın kod imzalama haklarından (`entitlements`) `com.apple.security.application-groups` gruplarını çeker.
    public static func extractEntitlementAppGroups(at bundleURL: URL) -> [String] {
        var secCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &secCode) == errSecSuccess,
              let code = secCode else {
            return []
        }
        var infoCF: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &infoCF) == errSecSuccess,
              let info = infoCF as? [String: Any],
              let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] else {
            return []
        }
        var groups: [String] = []
        if let list = entitlements["com.apple.security.application-groups"] as? [String] {
            groups.append(contentsOf: list)
        }
        return Array(Set(groups)).sorted()
    }

    /// Tek bir `.app` / widget / plugin paketinin üstverisini (`Wrapper/*.app` dahil) okur.
    public func inspectBundle(
        at url: URL,
        kind: BundleKind = .application,
        protectionRules: ProtectionRules = ProtectionRules(),
        runningSnapshot: ProtectionRules.RunningProcessSnapshot? = nil,
        computeSize: Bool = true,
        deepInspection: Bool = false,
        isCancelled: () -> Bool = { false }
    ) -> InstalledBundle? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return nil }

        var plistDict: [String: Any]?
        var isWrapper = false

        let standardPlist = url.appendingPathComponent("Contents/Info.plist")
        if let d = NSDictionary(contentsOf: standardPlist) as? [String: Any] {
            plistDict = d
        } else {
            // iOS Wrapper uygulaması: <App>.app/Wrapper/<Inner>.app/Info.plist
            let wrapperDir = url.appendingPathComponent("Wrapper", isDirectory: true)
            if let innerApps = try? fm.contentsOfDirectory(at: wrapperDir, includingPropertiesForKeys: nil),
               let innerApp = innerApps.first(where: { $0.pathExtension.lowercased() == "app" }),
               let d = NSDictionary(contentsOf: innerApp.appendingPathComponent("Info.plist")) as? [String: Any] {
                plistDict = d
                isWrapper = true
            }
        }

        let fallbackName = url.deletingPathExtension().lastPathComponent
        let name = (plistDict?["CFBundleDisplayName"] as? String)
            ?? (plistDict?["CFBundleName"] as? String)
            ?? fallbackName
        let bundleID = (plistDict?["CFBundleIdentifier"] as? String) ?? "unknown.\(fallbackName.lowercased())"
        let version = (plistDict?["CFBundleShortVersionString"] as? String)
            ?? (plistDict?["CFBundleVersion"] as? String)
            ?? "—"

        let decision = protectionRules.evaluate(path: url.path, candidateIdentifier: bundleID)
        let snapshot = runningSnapshot ?? ProtectionRules.RunningProcessSnapshot()
        let running = snapshot.isRunning(bundleID: bundleID, processName: name, executablePath: url.path)
        let size: Int64
        if computeSize {
            size = DiskSpace.size(of: url, isCancelled: isCancelled)
        } else {
            size = 0
        }

        let appGroups = deepInspection ? AppUninstaller.extractEntitlementAppGroups(at: url) : []
        let nestedHelpers = deepInspection ? AppUninstaller.extractNestedHelperBundleIDs(from: url) : []

        return InstalledBundle(
            kind: kind,
            name: name,
            bundleID: bundleID,
            version: version,
            url: url,
            bundleSizeBytes: size,
            isProtected: decision.isProtected,
            protectionReason: decision.reason,
            isRunning: running,
            isWrapperIOSApp: isWrapper,
            appGroups: appGroups,
            nestedBundleIDs: nestedHelpers
        )
    }

    /// Uygulamanın içindeki gömülü yardımcı paketleri (`Frameworks`, `Helpers`, `PlugIns`, `XPCServices`) tarar.
    public static func extractNestedHelperBundleIDs(from appURL: URL) -> [String] {
        let fm = FileManager.default
        var helperIDs: [String] = []
        let subfolders = [
            "Contents/Frameworks",
            "Contents/Helpers",
            "Contents/Library/LaunchServices",
            "Contents/PlugIns",
            "Contents/XPCServices"
        ]

        for sub in subfolders {
            let dir = appURL.appendingPathComponent(sub, isDirectory: true)
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for entry in entries {
                let plistURL = entry.appendingPathComponent("Contents/Info.plist")
                let altPlist = entry.appendingPathComponent("Resources/Info.plist")
                let targetPlist = fm.fileExists(atPath: plistURL.path) ? plistURL : (fm.fileExists(atPath: altPlist.path) ? altPlist : nil)
                if let targetPlist, let dict = NSDictionary(contentsOf: targetPlist) as? [String: Any],
                   let bid = dict["CFBundleIdentifier"] as? String {
                    let bidLower = bid.lowercased()
                    if !bidLower.hasPrefix("com.apple.") && !bidLower.contains("sparkle") && !bidLower.hasPrefix("org.sparkle-project") {
                        helperIDs.append(bid)
                    }
                }
            }
        }
        return Array(Set(helperIDs)).sorted()
    }

    /// Curatare Akıllı Paket ve Kalıntı İlişkilendirme Motoru (Smart Bundle Association Engine).
    /// Çok katmanlı belirteç analizi, önek (`widget-`, `helper-`, `plugin-`, `daemon-`, `service-`, `xpc-`) ve sınır kurallarını uygular.
    public struct SmartBundleMatcher: Sendable {
        public let regexes: [NSRegularExpression]
        public let primaryIDLower: String

        public init(bundleID: String, name: String, bundleFileName: String, nestedBundleIDs: [String] = []) {
            self.primaryIDLower = bundleID.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            var tokens: [String] = []

            if !primaryIDLower.isEmpty, !primaryIDLower.hasPrefix("unknown.") {
                tokens.append(bundleID.trimmingCharacters(in: .whitespacesAndNewlines))
                // Alan adı son bileşeni analizi (örn: "com.tinyspeck.slackmacgap" -> "slackmacgap")
                let parts = primaryIDLower.split(separator: ".")
                if let lastPart = parts.last.map(String.init), lastPart.count >= 4,
                   !["macos", "client", "desktop", "application"].contains(lastPart) {
                    tokens.append(lastPart)
                }
            }
            let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if n.count >= 3 {
                tokens.append(n)
            }
            let fn = bundleFileName.trimmingCharacters(in: .whitespacesAndNewlines)
            if fn.count >= 3 && fn.lowercased() != n.lowercased() {
                tokens.append(fn)
            }
            for nested in nestedBundleIDs {
                let nbid = nested.trimmingCharacters(in: .whitespacesAndNewlines)
                if !nbid.isEmpty && !nbid.lowercased().hasPrefix("com.apple.") && !tokens.contains(nbid) {
                    tokens.append(nbid)
                }
            }

            var compiled: [NSRegularExpression] = []
            for token in tokens {
                let escaped = NSRegularExpression.escapedPattern(for: token)
                // Curatare akıllı önek ve sınır deseni: ^(?:(?:widget|helper|plugin|daemon|service|xpc)-)?<TOKEN>(?:[\.\-_\s\d]+.*)?$
                let pattern = "^(?:(?:widget|helper|plugin|daemon|service|xpc)-)?" + escaped + "(?:[\\.\\-_\\s\\d]+.*)?$"
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    compiled.append(regex)
                }
            }
            self.regexes = compiled
        }

        public func matches(_ filename: String) -> Bool {
            let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
            for regex in regexes {
                if regex.firstMatch(in: filename, options: [], range: range) != nil {
                    return true
                }
            }
            return false
        }
    }

    /// Bir uygulamanın veya eklentinin `~/Library` ve `/Library` içindeki TÜM ilişkili dosya ve klasörlerini bulur.
    ///
    /// Curatare 22 farklı sistem ve kullanıcı dizinini tarar:
    /// - `Containers`, `Group Containers`, `Application Scripts`
    /// - `Application Support`, `CrashReporter`, `Recent Documents`
    /// - `Caches`, `Caches/Metadata`
    /// - `Preferences`, `Preferences/ByHost`, `SyncedPreferences`
    /// - `Saved Application State`, `HTTPStorages`, `Cookies`, `WebKit`
    /// - `Logs`, `DiagnosticReports`
    /// - `LaunchAgents` (`~/Library` ve `/Library`), `LaunchDaemons` (`/Library`)
    /// - `PrivilegedHelperTools`, `SMPrivilegedExecutables`
    /// - `Autosave Information`, `Receipts` (`/Library/Receipts` ve `/private/var/db/receipts`), `/Users/Shared`
    public func discoverAssociatedFiles(
        for bundle: InstalledBundle,
        includeBundleItself: Bool = true,
        protectionRules: ProtectionRules = ProtectionRules(),
        isCancelled: () -> Bool = { false }
    ) -> [AssociatedFile] {
        let fm = FileManager.default
        var files: [AssociatedFile] = []
        var seenPaths: Set<String> = []

        func checkRequiresSudo(for url: URL) -> Bool {
            let p = url.standardizedFileURL.path
            if p.hasPrefix(homeDirectoryURL.path) {
                return false
            }
            if !fm.isWritableFile(atPath: p) {
                return true
            }
            let parent = url.deletingLastPathComponent().path
            if !fm.isWritableFile(atPath: parent) {
                return true
            }
            return false
        }

        func appendFile(_ url: URL, kind: AssociatedFile.LocationKind, explicitRequiresSudo: Bool? = nil) {
            let std = url.standardizedFileURL.path
            guard !seenPaths.contains(std), fm.fileExists(atPath: std) else { return }
            // Korunan sistem/ortak öğeleri ilişkili dosya listesine sokma
            if protectionRules.evaluate(path: std).isProtected && kind != .appBundle {
                return
            }
            seenPaths.insert(std)
            let sudoNeeded = explicitRequiresSudo ?? checkRequiresSudo(for: url)
            let size = DiskSpace.size(of: url, isCancelled: isCancelled)
            files.append(AssociatedFile(
                url: url,
                kind: kind,
                sizeBytes: size,
                requiresSudo: sudoNeeded,
                isSelected: !sudoNeeded
            ))
        }

        // 1. Uygulama / Eklenti paketinin kendisi
        if includeBundleItself, fm.fileExists(atPath: bundle.url.path) {
            let needsSudo = checkRequiresSudo(for: bundle.url)
            files.append(AssociatedFile(
                url: bundle.url,
                kind: .appBundle,
                sizeBytes: bundle.bundleSizeBytes > 0 ? bundle.bundleSizeBytes : DiskSpace.size(of: bundle.url, isCancelled: isCancelled),
                requiresSudo: needsSudo,
                isSelected: true
            ))
            seenPaths.insert(bundle.url.standardizedFileURL.path)
        }

        let bundleFileName = bundle.url.deletingPathExtension().lastPathComponent
        let nestedBundleIDs = !bundle.nestedBundleIDs.isEmpty ? bundle.nestedBundleIDs : AppUninstaller.extractNestedHelperBundleIDs(from: bundle.url)
        let appGroups = !bundle.appGroups.isEmpty ? bundle.appGroups : AppUninstaller.extractEntitlementAppGroups(at: bundle.url)
        let matcher = SmartBundleMatcher(
            bundleID: bundle.bundleID,
            name: bundle.name,
            bundleFileName: bundleFileName,
            nestedBundleIDs: nestedBundleIDs
        )
        let idLower = matcher.primaryIDLower

        let userLib = homeDirectoryURL.appendingPathComponent("Library", isDirectory: true)
        let sysLib = URL(fileURLWithPath: "/Library", isDirectory: true)

        // MARK: - 2. Kullanıcı Kütüphanesi (`~/Library`) Taraması

        // A. Konteynerler (`~/Library/Containers/<bundleID>`)
        let containersDir = userLib.appendingPathComponent("Containers", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: containersDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries {
                if isCancelled() { break }
                let raw = entry.lastPathComponent
                if matcher.matches(raw) || (!idLower.isEmpty && raw.lowercased().contains(idLower)) {
                    appendFile(entry, kind: .container)
                }
            }
        }

        // B. Grup Konteynerleri (`~/Library/Group Containers`)
        let groupContainersDir = userLib.appendingPathComponent("Group Containers", isDirectory: true)
        // 1. Kod imzasından doğrudan çekilen uygulama grupları:
        for group in appGroups {
            let gURL = groupContainersDir.appendingPathComponent(group, isDirectory: true)
            if fm.fileExists(atPath: gURL.path) {
                appendFile(gURL, kind: .groupContainer)
            }
        }
        // 2. Dizin içindeki grup adlarını eşleştirme:
        if let entries = try? fm.contentsOfDirectory(at: groupContainersDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries {
                if isCancelled() { break }
                let raw = entry.lastPathComponent
                if matcher.matches(raw) || (!idLower.isEmpty && raw.lowercased().contains(idLower)) {
                    appendFile(entry, kind: .groupContainer)
                }
            }
        }

        // C. Uygulama Betikleri (`~/Library/Application Scripts/<bundleID>`)
        let appScriptsDir = userLib.appendingPathComponent("Application Scripts", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: appScriptsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries {
                if isCancelled() { break }
                let raw = entry.lastPathComponent
                if matcher.matches(raw) || (!idLower.isEmpty && raw.lowercased().contains(idLower)) {
                    appendFile(entry, kind: .applicationScripts)
                }
            }
        }

        // D. Uygulama Desteği (`~/Library/Application Support`) ve alt klasörler
        let appSupportDir = userLib.appendingPathComponent("Application Support", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: appSupportDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries {
                if isCancelled() { break }
                let raw = entry.lastPathComponent
                if raw == "CrashReporter" {
                    // CrashReporter içindeki çökme günlükleri
                    if let crashFiles = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                        for cf in crashFiles where matcher.matches(cf.lastPathComponent) {
                            appendFile(cf, kind: .crashReporter)
                        }
                    }
                } else if raw == "com.apple.sharedfilelist" {
                    // Recent Documents içindeki .sfl dosyaları
                    let recDocs = entry.appendingPathComponent("com.apple.LSSharedFileList.ApplicationRecentDocuments", isDirectory: true)
                    if let docFiles = try? fm.contentsOfDirectory(at: recDocs, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                        for df in docFiles where matcher.matches(df.lastPathComponent) {
                            appendFile(df, kind: .recentDocuments)
                        }
                    }
                } else if matcher.matches(raw) {
                    appendFile(entry, kind: .applicationSupport)
                }
            }
        }

        // E. Önbellekler (`~/Library/Caches` ve `~/Library/Caches/Metadata`)
        let cachesDir = userLib.appendingPathComponent("Caches", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries {
                if isCancelled() { break }
                let raw = entry.lastPathComponent
                if raw == "Metadata" {
                    if let metaEntries = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                        for me in metaEntries where matcher.matches(me.lastPathComponent) {
                            appendFile(me, kind: .caches)
                        }
                    }
                } else if matcher.matches(raw) {
                    appendFile(entry, kind: .caches)
                }
            }
        }

        // F. Tercihler (`~/Library/Preferences`, `ByHost`, `SyncedPreferences`)
        let prefsDir = userLib.appendingPathComponent("Preferences", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: prefsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries {
                if isCancelled() { break }
                let raw = entry.lastPathComponent
                if raw == "ByHost" {
                    if let byHostEntries = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                        for bh in byHostEntries where matcher.matches(bh.lastPathComponent) {
                            appendFile(bh, kind: .byHostPreferences)
                        }
                    }
                } else if matcher.matches(raw) {
                    appendFile(entry, kind: .preferences)
                }
            }
        }

        let syncedPrefsDir = userLib.appendingPathComponent("SyncedPreferences", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: syncedPrefsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .syncedPreferences)
            }
        }

        // G. Kayıtlı Durum (`~/Library/Saved Application State`)
        let savedStateDir = userLib.appendingPathComponent("Saved Application State", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: savedStateDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .savedState)
            }
        }

        // H. Ağ ve Çerez Depoları (`HTTPStorages`, `Cookies`, `WebKit`)
        let httpStoragesDir = userLib.appendingPathComponent("HTTPStorages", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: httpStoragesDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .httpStorage)
            }
        }

        let cookiesDir = userLib.appendingPathComponent("Cookies", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: cookiesDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .cookies)
            }
        }

        let webKitDir = userLib.appendingPathComponent("WebKit", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: webKitDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .webKit)
            }
        }

        // I. Günlükler (`~/Library/Logs` ve `~/Library/Logs/DiagnosticReports`)
        let logsDir = userLib.appendingPathComponent("Logs", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries {
                if isCancelled() { break }
                let raw = entry.lastPathComponent
                if raw == "DiagnosticReports" {
                    if let diagEntries = try? fm.contentsOfDirectory(at: entry, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                        for de in diagEntries where matcher.matches(de.lastPathComponent) {
                            appendFile(de, kind: .diagnosticReports)
                        }
                    }
                } else if matcher.matches(raw) {
                    appendFile(entry, kind: .logs)
                }
            }
        }

        // J. Kullanıcı Başlatma Ajanları (`~/Library/LaunchAgents`)
        let launchAgentsDir = userLib.appendingPathComponent("LaunchAgents", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: launchAgentsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .launchAgent)
            }
        }

        // K. Otomatik Kayıt Bilgileri (`~/Library/Autosave Information`)
        let autosaveDir = userLib.appendingPathComponent("Autosave Information", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: autosaveDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .autosaveInformation)
            }
        }

        // L. Safari Uzantıları (`~/Library/Safari/Extensions`)
        let safariExtDir = userLib.appendingPathComponent("Safari/Extensions", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: safariExtDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .safariExtensions)
            }
        }

        // M. Hesaplar (`~/Library/Accounts`)
        let accountsDir = userLib.appendingPathComponent("Accounts", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: accountsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .accounts)
            }
        }

        // N. Ek Kullanıcı Eklenti, Hizmet ve Yapılandırma Alanları (Genişletilmiş Sistem Kapsamı)
        let additionalUserTargets: [(dir: URL, kind: AssociatedFile.LocationKind)] = [
            (userLib.appendingPathComponent("Services", isDirectory: true), .plugin),
            (userLib.appendingPathComponent("Audio", isDirectory: true), .applicationSupport),
            (userLib.appendingPathComponent("Input Methods", isDirectory: true), .plugin),
            (userLib.appendingPathComponent("ColorPickers", isDirectory: true), .plugin),
            (userLib.appendingPathComponent("ColorSync", isDirectory: true), .plugin),
            (userLib.appendingPathComponent("Compositions", isDirectory: true), .plugin),
            (userLib.appendingPathComponent("Keyboard Layouts", isDirectory: true), .plugin),
            (userLib.appendingPathComponent("PDF Services", isDirectory: true), .plugin),
            (userLib.appendingPathComponent("ScriptingAdditions", isDirectory: true), .plugin),
            (userLib.appendingPathComponent("Scripts", isDirectory: true), .applicationScripts),
        ]
        for target in additionalUserTargets {
            if isCancelled() { break }
            guard let entries = try? fm.contentsOfDirectory(at: target.dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: target.kind)
            }
        }

        // MARK: - 3. Sistem Kütüphanesi (`/Library`) ve Ortak Alanlar Taraması

        let systemScanTargets: [(dir: URL, kind: AssociatedFile.LocationKind)] = [
            (sysLib.appendingPathComponent("Application Support", isDirectory: true), .applicationSupport),
            (sysLib.appendingPathComponent("Caches", isDirectory: true), .caches),
            (sysLib.appendingPathComponent("Preferences", isDirectory: true), .preferences),
            (sysLib.appendingPathComponent("LaunchAgents", isDirectory: true), .launchAgent),
            (sysLib.appendingPathComponent("LaunchDaemons", isDirectory: true), .launchDaemon),
            (sysLib.appendingPathComponent("PrivilegedHelperTools", isDirectory: true), .privilegedHelper),
            (sysLib.appendingPathComponent("SMPrivilegedExecutables", isDirectory: true), .privilegedHelper),
            (sysLib.appendingPathComponent("Cookies", isDirectory: true), .cookies),
            (sysLib.appendingPathComponent("Logs", isDirectory: true), .logs),
            (sysLib.appendingPathComponent("Receipts", isDirectory: true), .receipts),
            (sysLib.appendingPathComponent("Accounts", isDirectory: true), .accounts),
            (sysLib.appendingPathComponent("Services", isDirectory: true), .plugin),
            (sysLib.appendingPathComponent("Audio", isDirectory: true), .applicationSupport),
            (sysLib.appendingPathComponent("CoreMediaIO/Plug-Ins/DAL", isDirectory: true), .plugin),
            (sysLib.appendingPathComponent("Input Methods", isDirectory: true), .plugin),
            (sysLib.appendingPathComponent("ColorPickers", isDirectory: true), .plugin),
            (sysLib.appendingPathComponent("ColorSync", isDirectory: true), .plugin),
            (sysLib.appendingPathComponent("Compositions", isDirectory: true), .plugin),
            (sysLib.appendingPathComponent("Keyboard Layouts", isDirectory: true), .plugin),
            (sysLib.appendingPathComponent("PDF Services", isDirectory: true), .plugin),
            (sysLib.appendingPathComponent("ScriptingAdditions", isDirectory: true), .plugin),
            (sysLib.appendingPathComponent("Scripts", isDirectory: true), .applicationScripts),
            (URL(fileURLWithPath: "/Users/Shared", isDirectory: true), .sharedUserData),
        ]

        for target in systemScanTargets {
            if isCancelled() { break }
            guard let entries = try? fm.contentsOfDirectory(at: target.dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: target.kind)
            }
        }

        // L. Paket Makbuzları (`/private/var/db/receipts/<bundleID>.bom`, `<bundleID>.plist`)
        let receiptsDir = URL(fileURLWithPath: "/private/var/db/receipts", isDirectory: true)
        if !idLower.isEmpty, let entries = try? fm.contentsOfDirectory(at: receiptsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for entry in entries where matcher.matches(entry.lastPathComponent) {
                if isCancelled() { break }
                appendFile(entry, kind: .receipts, explicitRequiresSudo: true)
            }
        }

        return files
    }

    /// Seçilen ilişkili dosyaları tarihli `~/.Trash/Curatare-...` klasörüne taşır.
    public func uninstallToDatedTrash(
        bundle: InstalledBundle,
        associatedFiles: [AssociatedFile],
        trashService: DatedTrashService,
        protectionRules: ProtectionRules = ProtectionRules(),
        verifyRunningProcess: Bool = true
    ) throws -> TrashBatchManifest {
        let selected = associatedFiles.filter { $0.isSelected && !$0.requiresSudo }

        // launchd Servis Yönetimi: Trashing yapmadan önce LaunchAgent ve LaunchDaemon'ları durdur (unload)
        for file in selected {
            if file.kind == .launchAgent || file.kind == .launchDaemon {
                LaunchdManager.unloadJob(at: file.url, isUserAgent: file.kind == .launchAgent)
            }
        }

        let candidates = selected.map { file in
            DatedTrashMoveCandidate(
                url: file.url,
                category: "Uninstall:\(bundle.name):\(file.kind.rawValue)",
                bundleID: bundle.bundleID,
                processName: bundle.name,
                precomputedSize: file.sizeBytes
            )
        }
        return try trashService.moveToDatedTrash(
            candidates: candidates,
            title: "Uninstall \(bundle.name)",
            protectionRules: protectionRules,
            verifyRunningProcess: verifyRunningProcess
        )
    }
}
