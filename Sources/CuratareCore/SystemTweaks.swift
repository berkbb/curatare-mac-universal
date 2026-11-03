import Foundation
import AppKit

public enum SystemTweakCategory: String, Sendable, CaseIterable, Identifiable {
    case finder
    case dock
    case screenshot
    case diskAndNetwork
    case system

    public var id: String { rawValue }

    public var titleKey: LKey {
        switch self {
        case .finder: .tweaksSectionFinder
        case .dock: .tweaksSectionDock
        case .screenshot: .tweaksSectionScreenshot
        case .diskAndNetwork: .tweaksSectionDiskAndNetwork
        case .system: .tweaksSectionSystem
        }
    }

    public var iconSystemName: String {
        switch self {
        case .finder: "macwindow"
        case .dock: "dock.rectangle"
        case .screenshot: "camera.viewfinder"
        case .diskAndNetwork: "externaldrive.connected.to.line.below"
        case .system: "gearshape.2"
        }
    }
}

public struct SystemTweakItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let category: SystemTweakCategory
    public let titleKey: LKey
    public let descriptionKey: LKey
    public let domain: String
    public let key: String
    public let defaultValue: Bool
    public var isEnabled: Bool
    public let restartService: RestartService

    public enum RestartService: String, Sendable, Equatable {
        case none
        case finder
        case dock
        case systemUIServer

        public var noticeKey: LKey? {
            switch self {
            case .none: nil
            case .finder: .tweaksRestartNoticeFinder
            case .dock: .tweaksRestartNoticeDock
            case .systemUIServer: .tweaksRestartNoticeSystemUI
            }
        }
    }

    public init(
        id: String,
        category: SystemTweakCategory,
        titleKey: LKey,
        descriptionKey: LKey,
        domain: String,
        key: String,
        defaultValue: Bool,
        isEnabled: Bool,
        restartService: RestartService
    ) {
        self.id = id
        self.category = category
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.domain = domain
        self.key = key
        self.defaultValue = defaultValue
        self.isEnabled = isEnabled
        self.restartService = restartService
    }
}

/// Yeni ekran resimlerinin dosya biçimi (`com.apple.screencapture` → `type`). macOS varsayılanı PNG'dir.
public enum ScreenshotFormat: String, Sendable, CaseIterable, Identifiable {
    case png
    case jpg
    case heic
    case pdf

    public var id: String { rawValue }

    /// Biçim adı her dilde aynıdır (PNG, JPG, HEIC, PDF).
    public var displayName: String { rawValue.uppercased() }

    public static let domain = "com.apple.screencapture"
    public static let key = "type"
}

public protocol PreferenceStoreProtocol: Sendable {
    func readBool(domain: String, key: String, defaultValue: Bool) -> Bool
    func writeBool(domain: String, key: String, value: Bool)
    func readString(domain: String, key: String, defaultValue: String) -> String
    func writeString(domain: String, key: String, value: String)
    func removeValue(domain: String, key: String)
    func restartService(_ service: SystemTweakItem.RestartService)
}

public struct SystemPreferenceStore: PreferenceStoreProtocol {
    public init() {}

    public func readBool(domain: String, key: String, defaultValue: Bool) -> Bool {
        if let val = CFPreferencesCopyAppValue(key as CFString, domain as CFString) {
            if let b = val as? Bool { return b }
            if let num = val as? NSNumber { return num.boolValue }
            if let s = val as? String {
                let lower = s.lowercased()
                if lower == "true" || lower == "yes" || lower == "1" { return true }
                if lower == "false" || lower == "no" || lower == "0" { return false }
            }
        }
        return defaultValue
    }

    public func writeBool(domain: String, key: String, value: Bool) {
        CFPreferencesSetAppValue(key as CFString, value ? kCFBooleanTrue : kCFBooleanFalse, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    public func readString(domain: String, key: String, defaultValue: String) -> String {
        if let val = CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? String {
            return val
        }
        return defaultValue
    }

    public func writeString(domain: String, key: String, value: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFString, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    public func removeValue(domain: String, key: String) {
        CFPreferencesSetAppValue(key as CFString, nil, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    public func restartService(_ service: SystemTweakItem.RestartService) {
        guard service != .none else { return }
        let name: String
        switch service {
        case .none: return
        case .finder: name = "Finder"
        case .dock: name = "Dock"
        case .systemUIServer: name = "SystemUIServer"
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = [name]
        try? p.run()
    }
}

public final class MockPreferenceStore: PreferenceStoreProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var boolValues: [String: Bool] = [:]
    private var stringValues: [String: String] = [:]
    public private(set) var restartedServices: [SystemTweakItem.RestartService] = []

    public init(initialBools: [String: Bool] = [:], initialStrings: [String: String] = [:]) {
        self.boolValues = initialBools
        self.stringValues = initialStrings
    }

    private func compositeKey(_ domain: String, _ key: String) -> String {
        "\(domain):\(key)"
    }

    public func readBool(domain: String, key: String, defaultValue: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return boolValues[compositeKey(domain, key)] ?? defaultValue
    }

    public func writeBool(domain: String, key: String, value: Bool) {
        lock.lock()
        defer { lock.unlock() }
        boolValues[compositeKey(domain, key)] = value
    }

    public func readString(domain: String, key: String, defaultValue: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return stringValues[compositeKey(domain, key)] ?? defaultValue
    }

    public func writeString(domain: String, key: String, value: String) {
        lock.lock()
        defer { lock.unlock() }
        stringValues[compositeKey(domain, key)] = value
    }

    public func removeValue(domain: String, key: String) {
        lock.lock()
        defer { lock.unlock() }
        boolValues.removeValue(forKey: compositeKey(domain, key))
        stringValues.removeValue(forKey: compositeKey(domain, key))
    }

    public func restartService(_ service: SystemTweakItem.RestartService) {
        lock.lock()
        defer { lock.unlock() }
        restartedServices.append(service)
    }
}

public struct SystemTweakManager: Sendable {
    public let store: any PreferenceStoreProtocol

    public init(store: any PreferenceStoreProtocol = SystemPreferenceStore()) {
        self.store = store
    }

    /// Tüm tanımlı macOS sistem ayarlarını okur ve durumlarıyla listeler.
    public func loadAllTweaks() -> [SystemTweakItem] {
        definitions.map { def in
            let currentVal = readValue(for: def)
            var item = def
            item.isEnabled = currentVal
            return item
        }
    }

    /// Belirtilen ayarı uygular ve gerekirse ilgili hizmeti (Finder/Dock vb.) yeniden başlatır.
    public func applyTweak(id: String, enabled: Bool, restartService: Bool = true) -> SystemTweakItem? {
        guard let def = definitions.first(where: { $0.id == id }) else { return nil }
        writeValue(for: def, value: enabled)
        if restartService {
            store.restartService(def.restartService)
        }
        var updated = def
        updated.isEnabled = enabled
        return updated
    }

    /// Tüm ayarları sistem varsayılanlarına sıfırlar.
    public func restoreAllToDefaults(restartServices: Bool = true) -> [SystemTweakItem] {
        var servicesToRestart: Set<SystemTweakItem.RestartService> = []
        let result = definitions.map { def in
            writeValue(for: def, value: def.defaultValue)
            if def.restartService != .none {
                servicesToRestart.insert(def.restartService)
            }
            var item = def
            item.isEnabled = def.defaultValue
            return item
        }
        setScreenshotFormat(.png, restartService: false)
        servicesToRestart.insert(.systemUIServer)
        if restartServices {
            for service in servicesToRestart {
                store.restartService(service)
            }
        }
        return result
    }

    /// Dock'a ayırıcı boşluk (spacer) ekler.
    @discardableResult
    public func addDockSpacer(small: Bool = false) -> Bool {
        let tileType = small ? "small-spacer-tile" : "spacer-tile"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = ["write", "com.apple.dock", "persistent-apps", "-array-add", "{\"tile-type\"=\"\(tileType)\";}"]
        try? p.run()
        p.waitUntilExit()
        store.restartService(.dock)
        return p.terminationStatus == 0
    }

    /// Dock'taki tüm ayırıcı boşlukları temizler.
    @discardableResult
    public func removeDockSpacers() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        let script = "tell application \"System Events\" to do shell script \"python3 -c 'import plistlib, os; p=os.path.expanduser(\\\"~/Library/Preferences/com.apple.dock.plist\\\"); d=plistlib.load(open(p, \\\"rb\\\")); d[\\\"persistent-apps\\\"] = [x for x in d.get(\\\"persistent-apps\\\", []) if \\\"spacer\\\" not in x.get(\\\"tile-type\\\", \\\"\\\")]; plistlib.dump(d, open(p, \\\"wb\\\"))' 2>/dev/null || true\""
        p.arguments = ["-e", script]
        try? p.run()
        p.waitUntilExit()
        store.restartService(.dock)
        return true
    }

    /// Geçerli ekran resmi biçimi; anahtar yoksa macOS varsayılanı PNG. Terminal ile listede olmayan bir biçim
    /// (ör. `tiff`) ayarlanmışsa `nil` döner ve seçici hiçbir biçimi işaretlemez.
    public func screenshotFormat() -> ScreenshotFormat? {
        let raw = store.readString(domain: ScreenshotFormat.domain, key: ScreenshotFormat.key, defaultValue: "png").lowercased()
        return ScreenshotFormat(rawValue: raw == "jpeg" ? "jpg" : raw)
    }

    /// Ekran resmi biçimini yazar; PNG seçilince anahtar silinir (sistem varsayılanına döner).
    public func setScreenshotFormat(_ format: ScreenshotFormat, restartService: Bool = true) {
        if format == .png {
            store.removeValue(domain: ScreenshotFormat.domain, key: ScreenshotFormat.key)
        } else {
            store.writeString(domain: ScreenshotFormat.domain, key: ScreenshotFormat.key, value: format.rawValue)
        }
        if restartService {
            store.restartService(.systemUIServer)
        }
    }

    private func readValue(for item: SystemTweakItem) -> Bool {
        if item.id == "system.suppressCrashDialog" {
            let str = store.readString(domain: item.domain, key: item.key, defaultValue: "prompt")
            return str.lowercased() == "none"
        }
        if item.id == "dock.instantAutohide" {
            let str = store.readString(domain: item.domain, key: item.key, defaultValue: "default")
            return str == "0"
        }
        if item.id == "screenshot.saveToDownloads" {
            let loc = store.readString(domain: item.domain, key: item.key, defaultValue: "")
            return loc.contains("Downloads")
        }
        if item.id == "system.pressAndHoldRepeat" || item.id == "system.textEditBlankDocument" || item.id == "finder.hideDesktopIcons" || item.id == "system.disableWindowAnimations" {
            let raw = store.readBool(domain: item.domain, key: item.key, defaultValue: true)
            return !raw
        }
        return store.readBool(domain: item.domain, key: item.key, defaultValue: item.defaultValue)
    }

    private func writeValue(for item: SystemTweakItem, value: Bool) {
        if item.id == "system.suppressCrashDialog" {
            if value {
                store.writeString(domain: item.domain, key: item.key, value: "none")
            } else {
                store.removeValue(domain: item.domain, key: item.key)
            }
            return
        }
        if item.id == "dock.instantAutohide" {
            if value {
                store.writeString(domain: item.domain, key: item.key, value: "0")
            } else {
                store.removeValue(domain: item.domain, key: item.key)
            }
            return
        }
        if item.id == "screenshot.saveToDownloads" {
            if value {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                store.writeString(domain: item.domain, key: item.key, value: "\(home)/Downloads")
            } else {
                store.removeValue(domain: item.domain, key: item.key)
            }
            return
        }
        if item.id == "system.pressAndHoldRepeat" || item.id == "system.textEditBlankDocument" || item.id == "finder.hideDesktopIcons" || item.id == "system.disableWindowAnimations" {
            store.writeBool(domain: item.domain, key: item.key, value: !value)
            return
        }
        store.writeBool(domain: item.domain, key: item.key, value: value)
    }

    public let definitions: [SystemTweakItem] = [
        // MARK: - Finder
        SystemTweakItem(
            id: "finder.showHiddenFiles",
            category: .finder,
            titleKey: .tweakShowHiddenFilesTitle,
            descriptionKey: .tweakShowHiddenFilesDesc,
            domain: "com.apple.finder",
            key: "AppleShowAllFiles",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.showFullPathInTitle",
            category: .finder,
            titleKey: .tweakShowFullPathInTitleTitle,
            descriptionKey: .tweakShowFullPathInTitleDesc,
            domain: "com.apple.finder",
            key: "_FXShowPosixPathInTitle",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.showAllExtensions",
            category: .finder,
            titleKey: .tweakShowAllExtensionsTitle,
            descriptionKey: .tweakShowAllExtensionsDesc,
            domain: "NSGlobalDomain",
            key: "AppleShowAllExtensions",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.quitMenuItem",
            category: .finder,
            titleKey: .tweakQuitFinderMenuTitle,
            descriptionKey: .tweakQuitFinderMenuDesc,
            domain: "com.apple.finder",
            key: "QuitMenuItem",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),
        SystemTweakItem(
            id: "finder.hideDesktopIcons",
            category: .finder,
            titleKey: .tweakHideDesktopIconsTitle,
            descriptionKey: .tweakHideDesktopIconsDesc,
            domain: "com.apple.finder",
            key: "CreateDesktop",
            defaultValue: false,
            isEnabled: false,
            restartService: .finder
        ),

        // MARK: - Dock
        SystemTweakItem(
            id: "dock.staticOnly",
            category: .dock,
            titleKey: .tweakDockStaticOnlyTitle,
            descriptionKey: .tweakDockStaticOnlyDesc,
            domain: "com.apple.dock",
            key: "static-only",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock
        ),
        SystemTweakItem(
            id: "dock.dimHidden",
            category: .dock,
            titleKey: .tweakDockDimHiddenTitle,
            descriptionKey: .tweakDockDimHiddenDesc,
            domain: "com.apple.dock",
            key: "showhidden",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock
        ),
        SystemTweakItem(
            id: "dock.instantAutohide",
            category: .dock,
            titleKey: .tweakDockInstantAutohideTitle,
            descriptionKey: .tweakDockInstantAutohideDesc,
            domain: "com.apple.dock",
            key: "autohide-delay",
            defaultValue: false,
            isEnabled: false,
            restartService: .dock
        ),

        // MARK: - Disk ve Ağ
        SystemTweakItem(
            id: "disk.dontWriteNetworkStores",
            category: .diskAndNetwork,
            titleKey: .tweakNetworkStoresTitle,
            descriptionKey: .tweakNetworkStoresDesc,
            domain: "com.apple.desktopservices",
            key: "DSDontWriteNetworkStores",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "disk.dontWriteUSBStores",
            category: .diskAndNetwork,
            titleKey: .tweakUSBStoresTitle,
            descriptionKey: .tweakUSBStoresDesc,
            domain: "com.apple.desktopservices",
            key: "DSDontWriteUSBStores",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),

        // MARK: - Ekran Resmi
        SystemTweakItem(
            id: "screenshot.disableShadow",
            category: .screenshot,
            titleKey: .tweakScreenshotShadowTitle,
            descriptionKey: .tweakScreenshotShadowDesc,
            domain: "com.apple.screencapture",
            key: "disable-shadow",
            defaultValue: false,
            isEnabled: false,
            restartService: .systemUIServer
        ),
        SystemTweakItem(
            id: "screenshot.includeDate",
            category: .screenshot,
            titleKey: .tweakScreenshotIncludeDateTitle,
            descriptionKey: .tweakScreenshotIncludeDateDesc,
            domain: "com.apple.screencapture",
            key: "include-date",
            defaultValue: true,
            isEnabled: true,
            restartService: .systemUIServer
        ),
        SystemTweakItem(
            id: "screenshot.saveToDownloads",
            category: .screenshot,
            titleKey: .tweakScreenshotLocationTitle,
            descriptionKey: .tweakScreenshotLocationDesc,
            domain: "com.apple.screencapture",
            key: "location",
            defaultValue: false,
            isEnabled: false,
            restartService: .systemUIServer
        ),

        // MARK: - Sistem & Uygulamalar
        SystemTweakItem(
            id: "system.suppressCrashDialog",
            category: .system,
            titleKey: .tweakCrashReporterDialogTitle,
            descriptionKey: .tweakCrashReporterDialogDesc,
            domain: "com.apple.CrashReporter",
            key: "DialogType",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.musicHalfStars",
            category: .system,
            titleKey: .tweakMusicHalfStarsTitle,
            descriptionKey: .tweakMusicHalfStarsDesc,
            domain: "com.apple.Music",
            key: "allow-half-stars",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.windowDragOnGesture",
            category: .system,
            titleKey: .tweakWindowDragOnGestureTitle,
            descriptionKey: .tweakWindowDragOnGestureDesc,
            domain: "NSGlobalDomain",
            key: "NSWindowShouldDragOnGesture",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.pressAndHoldRepeat",
            category: .system,
            titleKey: .tweakPressAndHoldRepeatTitle,
            descriptionKey: .tweakPressAndHoldRepeatDesc,
            domain: "NSGlobalDomain",
            key: "ApplePressAndHoldEnabled",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.textEditBlankDocument",
            category: .system,
            titleKey: .tweakTextEditBlankDocumentTitle,
            descriptionKey: .tweakTextEditBlankDocumentDesc,
            domain: "com.apple.TextEdit",
            key: "NSShowAppCentricOpenPanelInsteadOfUntitledFile",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.safariDevelopMenu",
            category: .system,
            titleKey: .tweakSafariDevelopMenuTitle,
            descriptionKey: .tweakSafariDevelopMenuDesc,
            domain: "com.apple.Safari",
            key: "IncludeDevelopMenu",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        ),
        SystemTweakItem(
            id: "system.disableWindowAnimations",
            category: .system,
            titleKey: .tweakDisableWindowAnimationsTitle,
            descriptionKey: .tweakDisableWindowAnimationsDesc,
            domain: "NSGlobalDomain",
            key: "NSAutomaticWindowAnimationsEnabled",
            defaultValue: false,
            isEnabled: false,
            restartService: .none
        )
    ]
}
