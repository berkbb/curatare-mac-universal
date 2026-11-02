// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Darwin
import Foundation

/// `library_clean.md` Kural 2'de tanımlanan "Dokunulmayacaklar Listesi" ve çalışan süreç (`pgrep` / `NSRunningApplication`)
/// koruma denetimleri.
public enum ProtectionCategory: String, Sendable, Codable, Equatable, CaseIterable {
    case appleSystem
    case sharedFramework
    case sharedDevToolchain
    case virtualization
    case activeAITool
    case curatareFamily
    case credentialVault
    case userWhitelisted
    case runningApplication
}

public struct ProtectionDecision: Sendable, Equatable {
    public let isProtected: Bool
    public let category: ProtectionCategory?
    public let reason: String?

    public static let allowed = ProtectionDecision(isProtected: false, category: nil, reason: nil)

    public static func protected(_ category: ProtectionCategory, reason: String) -> ProtectionDecision {
        ProtectionDecision(isProtected: true, category: category, reason: reason)
    }
}

public struct ProtectionRules: Sendable, Equatable {
    public var installedBundleIDs: Set<String>
    public var installedAppNames: Set<String>
    public var activeGradleVersions: Set<String>
    public var userWhitelistPatterns: [String]
    public var hasAntigravityIDE: Bool
    public var allowUninstallingProtectedApps: Bool
    public var allowDeveloperCacheCleaning: Bool
    public var allowUserCacheCleaning: Bool

    public init(
        installedBundleIDs: Set<String> = [],
        installedAppNames: Set<String> = [],
        activeGradleVersions: Set<String> = [],
        userWhitelistPatterns: [String] = [],
        hasAntigravityIDE: Bool = false,
        allowUninstallingProtectedApps: Bool = false,
        allowDeveloperCacheCleaning: Bool = false,
        allowUserCacheCleaning: Bool = false
    ) {
        self.installedBundleIDs = Set(installedBundleIDs.map { $0.lowercased() })
        self.installedAppNames = Set(installedAppNames.map { $0.lowercased() })
        self.activeGradleVersions = activeGradleVersions
        self.userWhitelistPatterns = userWhitelistPatterns
        self.hasAntigravityIDE = hasAntigravityIDE
        self.allowUninstallingProtectedApps = allowUninstallingProtectedApps
        self.allowDeveloperCacheCleaning = allowDeveloperCacheCleaning
        self.allowUserCacheCleaning = allowUserCacheCleaning
    }

    // MARK: - Sabit Koruma Kümeleri (library_clean.md Kural 2)

    /// Apple sistem önekleri — asla dokunulmaz.
    public static let systemPrefixes: [String] = [
        "com.apple.",
        "group.com.apple.",
        "systemgroup.",
        "org.cups.",
    ]

    /// Apple sistem servis adları (bundle ID olmayan çıplak adlar).
    public static let appleSystemBareNames: Set<String> = [
        "addressbook", "clouddocs", "knowledge", "fileprovider", "contactsd",
        "cloudkit", "coredata", "metadata", "biome", "safari", "mail", "messages",
        "passkit", "homekit", "healthkit", "familycircle", "audio", "colorpickers",
        "inputmethods", "keychains", "accounts", "assistant", "autoupdate",
        "caches", "containers", "group containers", "preferences", "logs",
        "saved application state", "httpstorages", "webkit", "application support",
        "application scripts", "launchagents", "launchdaemons", "byhost",
    ]

    /// Birden çok uygulamanın ortak kullandığı üçüncü parti çatılar (`library_clean.md`).
    public static let sharedFrameworkTokens: [String] = [
        "org.sparkle-project.sparkle",
        "sparkle",
        "com.google.firebase",
        "firebase",
        "com.crashlytics",
        "crashlytics",
        "io.fabric",
        "com.onevcat.kingfisher",
        "kingfisher",
        "com.segment",
        "segment",
        "com.google.keystone",
        "keystone",
        "sentry",
    ]

    /// Kardeş uygulamalar ve Curatare'nin kendisi.
    public static let siblingIdentifiers: Set<String> = [
        "com.babadogantech.curatare",
        "com.babadogantech.arhivar",
        "net.babadogan.arhivar",
        "com.babadogantech.copiator",
        "com.babadogantech.descarcator",
        "curatare",
        "arhivar",
        "copiator",
        "descarcator",
    ]

    /// Ortak geliştirme önbellekleri (`library_clean.md`: birden çok projenin paylaştığı paket/SDK depoları).
    public static let sharedDevTokens: Set<String> = [
        "nuget", ".nuget", ".pub-cache", "homebrew", "org.swift.swiftpm", "swiftpm",
        "go-build", "pip", "ms-playwright", "ms-playwright-go", ".rustup", ".konan",
        ".hvigor", "cocoapods", "carthage",
    ]

    /// Aktif yapay zekâ araç verileri (`library_clean.md`).
    public static let activeAIPathMarkers: [String] = [
        "/.codex",
        "/.gemini",
        "/codex-primary-runtime",
        "/.antigravity-ide",
        "/optguideondevicemodel",
        "/sensei_model_cache",
        "/vm_bundles/claudevm.bundle",
        "/virtual machines.localized",
        "/ggml-large-v3-turbo.bin",
        "/safaritabs.db",
        "/updf",
    ]

    /// Kimlik bilgisi ve anahtar klasörleri.
    public static let credentialMarkers: [String] = [
        "/.ssh",
        "/.gnupg",
        "/.aws",
        "/.kube",
        "/library/keychains",
    ]

    // MARK: - Denetim Yöntemleri

    /// Verilen yolun korunup korunmadığını değerlendirir.
    public func evaluate(path: String, candidateIdentifier: String? = nil) -> ProtectionDecision {
        let normalizedPath = (path as NSString).standardizingPath
        let lowerPath = normalizedPath.lowercased()
        let lastComponent = (normalizedPath as NSString).lastPathComponent
        let lowerName = lastComponent.lowercased()

        // 1. Sistem kökleri
        if lowerPath.hasPrefix("/system/") || lowerPath == "/system" ||
           lowerPath.hasPrefix("/usr/bin") || lowerPath.hasPrefix("/usr/sbin") ||
           lowerPath.hasPrefix("/usr/lib") || lowerPath.hasPrefix("/bin/") || lowerPath.hasPrefix("/sbin/") {
            return .protected(.appleSystem, reason: "/System or OS core path")
        }

        // 2. Kimlik bilgisi kasaları
        for marker in Self.credentialMarkers where lowerPath.contains(marker) {
            return .protected(.credentialVault, reason: "Credential or keychain directory")
        }

        // 3. Kullanıcı beyaz listesi (`~/.config/mole/whitelist` ve özel kurallar)
        for pattern in userWhitelistPatterns where matchesWhitelistPattern(path: normalizedPath, pattern: pattern) {
            return .protected(.userWhitelisted, reason: "Whitelisted: \(pattern)")
        }

        // 4. Aktif YZ ve sanal makine diskleri
        for marker in Self.activeAIPathMarkers where lowerPath.contains(marker) {
            return .protected(.activeAITool, reason: "Protected AI/VM state (\(marker))")
        }

        // 5. Bundle ID veya aday kimlik değerlendirmesi
        let idToCheck = (candidateIdentifier ?? lastComponent).lowercased()
        let strippedID = Self.stripKnownSuffixes(from: idToCheck)

        if Self.siblingIdentifiers.contains(strippedID) || Self.siblingIdentifiers.contains(lowerName) {
            return .protected(.curatareFamily, reason: "Curatare / sibling application")
        }

        for sysPrefix in Self.systemPrefixes where strippedID.hasPrefix(sysPrefix) || lowerName.hasPrefix(sysPrefix) {
            if allowUserCacheCleaning && lowerPath.contains("/caches/") && !lowerPath.hasPrefix("/system") && !lowerPath.hasPrefix("/library") {
                continue
            }
            if allowUninstallingProtectedApps && !lowerPath.hasPrefix("/system") {
                if Self.appleSystemBareNames.contains(lowerName) || Self.knownAppleDaemons.contains(lowerName) {
                    return .protected(.appleSystem, reason: "Apple system service (\(lastComponent))")
                }
                continue
            }
            return .protected(.appleSystem, reason: "Apple system prefix (\(sysPrefix))")
        }

        if Self.appleSystemBareNames.contains(lowerName) || Self.appleSystemBareNames.contains(strippedID) {
            if allowUninstallingProtectedApps && !lowerPath.hasPrefix("/system") && lowerPath.hasSuffix(".app") {
                // Allowed when user unlocked protected apps for an app bundle outside /System
            } else {
                return .protected(.appleSystem, reason: "Apple system service (\(lastComponent))")
            }
        }

        // Sonu 'd' ile biten sistem daemon süreçleri (contactsd, cloudd, bird, rapportd vb.)
        if !strippedID.contains(".") && lowerName.hasSuffix("d") && Self.knownAppleDaemons.contains(lowerName) {
            return .protected(.appleSystem, reason: "Apple system daemon (\(lastComponent))")
        }

        // 6. Ortak çatılar (Sparkle, Firebase, Kingfisher, Segment, Keystone, install4j)
        for token in Self.sharedFrameworkTokens {
            if strippedID == token || strippedID.hasPrefix(token + ".") || lowerName == token || lowerPath.contains("/\(token)/") {
                return .protected(.sharedFramework, reason: "Shared framework (\(token))")
            }
        }

        if (strippedID.contains("install4j") || lowerName.contains("install4j")),
           installedBundleIDs.contains(where: { $0.contains("install4j") }) {
            return .protected(.sharedFramework, reason: "install4j runtime used by an installed app")
        }

        // Google / Microsoft ortak grupları (ilgili uygulamalar kuruluysa)
        if strippedID == "google" || strippedID.hasPrefix("com.google.common") || lowerName == "google" {
            if installedBundleIDs.contains(where: { $0.hasPrefix("com.google.") }) {
                return .protected(.sharedFramework, reason: "Shared Google group while Google apps are installed")
            }
        }
        if strippedID == "microsoft" || strippedID.hasPrefix("ubf8t346g9.") || lowerName == "microsoft" {
            // Classic Teams istisnası (`library_clean.md`): UBF8T346G9.com.microsoft.teams ve Application Support/Microsoft/Teams
            // yalnızca Classic Teams (com.microsoft.teams) kurulu değilse temizlenebilir (Modern Teams 2 com.microsoft.teams2 kullanır).
            if strippedID == "ubf8t346g9.com.microsoft.teams" && !installedBundleIDs.contains("com.microsoft.teams") {
                // İzin verildi
            } else if lowerPath.hasSuffix("/microsoft/teams") && !installedBundleIDs.contains("com.microsoft.teams") {
                // İzin verildi
            } else if installedBundleIDs.contains(where: { $0.hasPrefix("com.microsoft.") }) {
                return .protected(.sharedFramework, reason: "Shared Microsoft group while Microsoft apps are installed")
            }
        }

        // 7. Sanallaştırma yardımcıları (VMware Fusion / Parallels kuruluysa mksSandbox vb. korunur)
        if strippedID.hasPrefix("com.vmware.") || lowerName.contains("vmware") {
            if installedBundleIDs.contains("com.vmware.fusion") || installedAppNames.contains("vmware fusion") {
                return .protected(.virtualization, reason: "VMware helper protected while VMware Fusion is installed")
            }
        }
        if strippedID.hasPrefix("com.parallels.") || lowerName.contains("parallels") {
            if installedBundleIDs.contains(where: { $0.hasPrefix("com.parallels.") }) {
                return .protected(.virtualization, reason: "Parallels helper protected while Parallels is installed")
            }
        }

        // 8. Ortak geliştirici önbellekleri (`Gradle modules-2`, `.nuget`, `.pub-cache`, `ms-playwright*` vb.)
        if !allowDeveloperCacheCleaning {
            if Self.sharedDevTokens.contains(strippedID) || Self.sharedDevTokens.contains(lowerName) ||
               lowerName.hasPrefix("ms-playwright") {
                return .protected(.sharedDevToolchain, reason: "Shared developer toolchain cache (\(lastComponent))")
            }
            if lowerPath.contains("/.gradle/caches/modules-2") || lowerPath.contains("/.android/avd") {
                return .protected(.sharedDevToolchain, reason: "Protected Gradle modules-2 / Android AVD")
            }
            if lowerPath.contains("/.gradle/caches/") || lowerPath.contains("/.gradle/wrapper/dists/gradle-") {
                for activeVer in activeGradleVersions where !activeVer.isEmpty && lowerPath.contains(activeVer.lowercased()) {
                    return .protected(.sharedDevToolchain, reason: "Active Gradle version (\(activeVer))")
                }
            }
        }

        return .allowed
    }

    public static func stripKnownSuffixes(from rawName: String) -> String {
        var s = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffixes = [
            ".savedstate",
            ".binarycookies",
            ".plist",
            ".lockfile",
            ".savedState",
        ]
        for suffix in suffixes where s.lowercased().hasSuffix(suffix) {
            s = String(s.dropLast(suffix.count))
        }
        // Team ID öneki (ör. "UBF8T346G9.com.microsoft.Word" -> "com.microsoft.Word")
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count >= 3,
           parts[0].count == 10,
           parts[0].allSatisfy({ $0.isLetter || $0.isNumber }),
           ["com", "org", "net", "io", "app", "me", "dev", "tr", "ro", "de", "uk", "us", "ru", "at"].contains(parts[1].lowercased()) {
            s = parts.dropFirst().joined(separator: ".")
        }
        if s.lowercased().hasPrefix("group.") {
            s = String(s.dropFirst("group.".count))
        }
        return s
    }

    private func matchesWhitelistPattern(path: String, pattern: String) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return false }
        let expanded = (trimmed as NSString).expandingTildeInPath
        if expanded.hasSuffix("/*") {
            let prefix = String(expanded.dropLast(2))
            return path == prefix || path.hasPrefix(prefix + "/")
        }
        if expanded.contains("*") {
            let regexPattern = "^" + NSRegularExpression.escapedPattern(for: expanded)
                .replacingOccurrences(of: "\\*", with: ".*") + "$"
            return (try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive))?
                .firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil
        }
        return path == expanded || path.hasPrefix(expanded + "/")
    }

    private static let knownAppleDaemons: Set<String> = [
        "accountsd", "adid", "airplayxpchelper", "akd", "amfid", "apsd", "askpermissiond",
        "audioclocksyncd", "averagerd", "biomed", "bird", "bluetoothd", "calaccessd",
        "callhistoryd", "chronod", "cloudd", "commcenter", "Containermanagerd", "containermanagerd",
        "contextstored", "ControlCenter", "coreaudiod", "coreauthd", "coreduetd", "coreservicesd",
        "corespotlightd", "ctkd", "dasd", "distnoted", "dmd", "donotdisturbd", " duetexpertd",
        "familycircled", "fileproviderd", "findmydeviced", "fmfd", "fseventsd", "gamed",
        "geod", "healthd", "homed", "icdd", "identityservicesd", "imagent", "imdpersistenceagent",
        "installd", "kbd", "knowledge-agent", "locationd", "lockdownd", "logd", "lsd",
        "mapspushd", "mdbulkimport", "mds", "mediaremoted", "milod", "mobileactivationd",
        "mobileassetd", "nanoregistryd", "navd", "neagent", "nehelper", "nesessionmanager",
        "networkserviceproxy", "nfcd", "nsurlsessiond", "parsecd", "passd", "pasteboard",
        "pbs", "peopled", "photoanalysisd", "photolibraryd", "pkd", "powerd", " printtool",
        " progressd", "protectedcloudkeysyncing", "rapportd", " remindd", "replayd", " reversetemplated",
        "routined", "runningboardd", "searchpartyd", "secinitd", "securityd", "secd", "sharingd",
        "siriactionsd", "siriknowledged", "sociallayerd", "softwareupdated", "spotlightknowledged",
        " stickersd", "StocksWidget", "suggestd", "swcd", " symptomsd", "SyncedDefaults", "syslogd",
        "systemstats", "tccd", " timed", "translationd", "triald", "trustd", "universalaccessd",
        "usermanagerd", "useractivityd", "videosubscriptionsd", " voiced", "weatherd", "webkit",
        "wifid", "windowserver", "xpcroleaccountd",
    ]

    // MARK: - Çalışan Süreç Denetimi (`pgrep` / `NSRunningApplication` / `sysctl`)

    /// Toplu paket taramalarında her uygulama için ayrı `sysctl` çağrısı yapmamak üzere tek seferlik süreç anlık görüntüsü.
    public struct RunningProcessSnapshot: Sendable {
        public let bundleIDs: Set<String>
        public let processNames: Set<String>

        public init() {
            var ids: Set<String> = []
            for app in NSWorkspace.shared.runningApplications where !app.isTerminated {
                if let bid = app.bundleIdentifier?.lowercased(), !bid.isEmpty {
                    ids.insert(bid)
                }
            }
            self.bundleIDs = ids
            self.processNames = ProtectionRules.currentProcessNames()
        }

        public func isRunning(bundleID: String? = nil, processName: String? = nil, executablePath: String? = nil) -> Bool {
            if let bundleID, !bundleID.isEmpty, bundleIDs.contains(bundleID.lowercased()) {
                return true
            }
            if let processName, !processName.isEmpty {
                let target = processName.lowercased()
                let maxPrefix = String(target.prefix(Int(MAXCOMLEN)))
                if processNames.contains(target) || processNames.contains(maxPrefix) {
                    return true
                }
            }
            if let executablePath, !executablePath.isEmpty {
                let execName = (executablePath as NSString).lastPathComponent.lowercased()
                let maxPrefix = String(execName.prefix(Int(MAXCOMLEN)))
                if !execName.isEmpty && (processNames.contains(execName) || processNames.contains(maxPrefix)) {
                    return true
                }
            }
            return false
        }
    }

    /// Uygulamanın veya sürecin şu anda çalışıp çalışmadığını denetler.
    public static func isProcessRunning(bundleID: String? = nil, processName: String? = nil, executablePath: String? = nil) -> Bool {
        RunningProcessSnapshot().isRunning(bundleID: bundleID, processName: processName, executablePath: executablePath)
    }

    public static func currentProcessNames() -> Set<String> {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: Int = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        let count = size / MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        var actualSize = size
        guard sysctl(&mib, 4, &procs, &actualSize, nil, 0) == 0 else { return [] }
        let actualCount = actualSize / MemoryLayout<kinfo_proc>.stride
        var names: Set<String> = []
        names.reserveCapacity(actualCount)
        for i in 0..<actualCount {
            var comm = procs[i].kp_proc.p_comm
            let name = withUnsafePointer(to: &comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) {
                    String(cString: $0).lowercased()
                }
            }
            if !name.isEmpty {
                names.insert(name)
            }
        }
        return names
    }

    /// `~/.config/mole/whitelist` dosyasından ve ekstra desenlerden beyaz listeyi yükler.
    public static func loadUserWhitelist(homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()), extraPatterns: [String] = []) -> [String] {
        let moleWhitelist = homeDirectory.appendingPathComponent(".config/mole/whitelist")
        var patterns: [String] = extraPatterns
        if let content = try? String(contentsOf: moleWhitelist, encoding: .utf8) {
            for line in content.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                    patterns.append(trimmed)
                }
            }
        }
        return patterns
    }
}
