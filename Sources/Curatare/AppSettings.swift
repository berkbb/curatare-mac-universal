// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation
import SwiftUI

public enum AppInfo {
    public static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    public static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

public enum AppLinks {
    public static let repository = URL(string: "https://github.com/berkbb/curatare-mac-universal")!
    public static let engineWebsite = URL(string: "https://mole.fit")!
    public static let engineManual = URL(string: "https://github.com/tw93/mole")!
    public static let companyWebsite = URL(string: "https://babadogan.net")!
    public static let arhivarRepository = URL(string: "https://github.com/berkbb/arhivar-mac-universal")!
    public static let copiatorRepository = URL(string: "https://github.com/berkbb/copiator-mac-universal")!
    public static let descarcatorRepository = URL(string: "https://github.com/berkbb/descarcator-mac-universal")!
    public static let curatareRepository = URL(string: "https://github.com/berkbb/curatare-mac-universal")!
}

public struct FamilyApp: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let bundleID: String
    public let fallbackBundleIDs: [String]
    public let roleKey: LKey
    public let iconSystemName: String
    public let repoURL: URL

    public init(
        id: String,
        name: String,
        bundleID: String,
        fallbackBundleIDs: [String] = [],
        roleKey: LKey,
        iconSystemName: String,
        repoURL: URL
    ) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.fallbackBundleIDs = fallbackBundleIDs
        self.roleKey = roleKey
        self.iconSystemName = iconSystemName
        self.repoURL = repoURL
    }

    public var installedURL: URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url
        }
        for fallback in fallbackBundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: fallback) {
                return url
            }
        }
        return nil
    }

    public var isInstalled: Bool {
        installedURL != nil
    }

    public func open() {
        if let url = installedURL {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(repoURL)
        }
    }
}

public enum FamilyApps {
    public static let all: [FamilyApp] = [
        FamilyApp(
            id: "arhivar",
            name: "Arhivar",
            bundleID: "com.babadogantech.arhivar",
            fallbackBundleIDs: ["net.babadogan.arhivar"],
            roleKey: .aboutFamilyArhivarDesc,
            iconSystemName: "doc.zipper",
            repoURL: AppLinks.arhivarRepository
        ),
        FamilyApp(
            id: "copiator",
            name: "Copiator",
            bundleID: "com.babadogantech.copiator",
            roleKey: .aboutFamilyCopiatorDesc,
            iconSystemName: "doc.on.clipboard",
            repoURL: AppLinks.copiatorRepository
        ),
        FamilyApp(
            id: "descarcator",
            name: "Descarcator",
            bundleID: "com.babadogantech.descarcator",
            roleKey: .aboutFamilyDescarcatorDesc,
            iconSystemName: "arrow.down.circle.fill",
            repoURL: AppLinks.descarcatorRepository
        ),
        FamilyApp(
            id: "curatare",
            name: "Curatare",
            bundleID: "com.babadogantech.curatare",
            roleKey: .aboutFamilyCuratareDesc,
            iconSystemName: "wand.and.stars",
            repoURL: AppLinks.curatareRepository
        ),
    ]
}

public enum SystemStatusSubTab: String, CaseIterable, Sendable, Codable {
    case systemCenter
    case dashboard
    case tweaks
    case checksum
}

public enum SystemCenterTab: String, CaseIterable, Sendable, Codable, Identifiable {
    case hardware
    case memory
    case volumes
    case system
    case profile

    public var id: String { rawValue }

    public var titleKey: LKey {
        switch self {
        case .hardware: .sysCenterTabHardware
        case .memory: .sysCenterTabMemory
        case .volumes: .sysCenterTabVolumes
        case .system: .sysCenterTabSystem
        case .profile: .sysCenterTabProfile
        }
    }

    public var iconName: String {
        switch self {
        case .hardware: "macbook.and.iphone"
        case .memory: "memorychip"
        case .volumes: "internaldrive"
        case .system: "gearshape.2"
        case .profile: "doc.text.magnifyingglass"
        }
    }
}

public enum LicenseDocument: String, CaseIterable, Identifiable, Sendable {
    case appLicense
    case engineLicense
    case notices

    public var id: String { rawValue }

    public var titleKey: LKey {
        switch self {
        case .appLicense: .aboutAppLicense
        case .engineLicense: .aboutLicense
        case .notices: .aboutNotices
        }
    }

    public var systemImage: String {
        switch self {
        case .appLicense: "doc.badge.gearshape"
        case .engineLicense: "doc.text"
        case .notices: "list.bullet.rectangle"
        }
    }

    public var text: String {
        switch self {
        case .appLicense:
            return Self.loadBundledOrFallback(
                fileName: "LICENSE",
                fallback: """
                Curatare — Universal macOS 26 System Cleaner, Library Auditor & App Uninstaller
                Copyright (C) 2026 Babadogan Tech and Edu

                This program is free software: you can redistribute it and/or modify
                it under the terms of the GNU General Public License as published by
                the Free Software Foundation, either version 3 of the License, or
                (at your option) any later version.

                This program is distributed in the hope that it will be useful,
                but WITHOUT ANY WARRANTY; without even the implied warranty of
                MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
                GNU General Public License for more details.
                """
            )
        case .engineLicense:
            return Self.loadBundledOrFallback(
                fileName: "Mole-LICENSE.txt",
                fallback: """
                Mole Engine (tw93/mole)
                https://github.com/tw93/mole — https://mole.fit

                GNU GENERAL PUBLIC LICENSE
                Version 3, 29 June 2007

                Copyright (C) 2025 Tw93 and contributors
                Everyone is permitted to copy and distribute verbatim copies
                of this license document, but changing it is not allowed.

                This program is free software: you can redistribute it and/or modify
                it under the terms of the GNU General Public License as published by
                the Free Software Foundation, either version 3 of the License, or
                (at your option) any later version.

                This program is distributed in the hope that it will be useful,
                but WITHOUT ANY WARRANTY; without even the implied warranty of
                MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
                GNU General Public License for more details.
                """
            )
        case .notices:
            return Self.loadBundledOrFallback(
                fileName: "THIRD_PARTY_NOTICES.md",
                fallback: """
                CURATARE — THIRD-PARTY NOTICES & ARCHITECTURAL CREDITS

                1. Mole Engine (`tw93/mole`)
                   - Source: https://github.com/tw93/mole (https://mole.fit)
                   - License: GNU General Public License v3.0 (GPL-3.0)
                   - Components: `mole`, `bin/*.sh`, `lib/**`, universal Mach-O `analyze-go` & `status-go` (`arm64` + `x86_64`)
                   - Updater: `Scripts/update-mole.sh` / Settings → Advanced → Update Mole from GitHub

                2. Library Orphan & Ecosystem Audit (Library Clean Methodology)
                   - 5-Group (`A`–`E`) `~/Library` and `/Library` orphan audit
                   - iOS/iPadOS `Wrapper/*.app` bundle resolution
                   - Non-destructive Dated Trash batches (`~/.Trash/Curatare-YYYY-MM-DD-HHMMSS`)
                   - Constitutional Do-Not-Touch Protection (`ProtectionRules`)

                3. Native Application Uninstaller & SmartDelete
                   - Deep inspection of Applications, Widgets, and System Plugins
                   - `~/.Trash` FSEvents / DispatchSource watcher (`TrashWatcher`)
                """
            )
        }
    }

    private static func loadBundledOrFallback(fileName: String, fallback: String) -> String {
        if let url = Bundle.main.url(forResource: fileName, withExtension: nil),
           let str = try? String(contentsOf: url, encoding: .utf8), !str.isEmpty {
            return str
        }
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let repoFile = repoRoot.appendingPathComponent(fileName)
        if let str = try? String(contentsOf: repoFile, encoding: .utf8), !str.isEmpty {
            return str
        }
        if fileName == "Mole-LICENSE.txt" {
            let moleLicense = repoRoot.appendingPathComponent("Vendor/mole/LICENSE")
            if let str = try? String(contentsOf: moleLicense, encoding: .utf8), !str.isEmpty {
                return str
            }
        }
        return fallback
    }
}

public enum UninstallerStartupView: String, CaseIterable, Identifiable, Sendable {
    case dropZone
    case list

    public var id: String { rawValue }

    public var titleKey: LKey {
        switch self {
        case .dropZone: .uninstallerModeDropZone
        case .list: .uninstallerModeList
        }
    }
}

public enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var titleKey: LKey {
        switch self {
        case .system: .appearanceSystem
        case .light: .appearanceLight
        case .dark: .appearanceDark
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    @MainActor
    public var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - Klavye Kısayolları (`KeyboardShortcutData` & `ShortcutAction`)

public struct KeyboardShortcutData: Codable, Equatable, Sendable {
    public var key: String
    public var command: Bool = true
    public var shift: Bool = false
    public var option: Bool = false
    public var control: Bool = false

    public init(key: String, command: Bool = true, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.key = key
        self.command = command
        self.shift = shift
        self.option = option
        self.control = control
    }

    public var eventModifiers: SwiftUI.EventModifiers {
        var m: SwiftUI.EventModifiers = []
        if command { m.insert(.command) }
        if shift { m.insert(.shift) }
        if option { m.insert(.option) }
        if control { m.insert(.control) }
        return m
    }

    public var keyEquivalent: KeyEquivalent {
        KeyEquivalent(key.lowercased().first ?? " ")
    }

    public var displayString: String {
        var s = ""
        if control { s += "⌃" }
        if option { s += "⌥" }
        if shift { s += "⇧" }
        if command { s += "⌘" }
        s += key.uppercased()
        return s
    }
}

public enum ShortcutAction: String, CaseIterable, Identifiable, Sendable {
    case scanAudit
    case uninstaller
    case homebrew
    case devAI
    case browserCaches
    case diskAnalyzer
    case systemStatus
    case trashHistory
    case showLog

    public var id: String { rawValue }

    public var labelKey: LKey {
        switch self {
        case .scanAudit: .shortcutScanAudit
        case .uninstaller: .shortcutUninstaller
        case .homebrew: .shortcutHomebrew
        case .devAI: .shortcutDevAI
        case .browserCaches: .shortcutBrowserCaches
        case .diskAnalyzer: .shortcutDiskAnalyzer
        case .systemStatus: .shortcutSystemStatus
        case .trashHistory: .shortcutTrashHistory
        case .showLog: .shortcutShowLog
        }
    }

    public var defaultShortcut: KeyboardShortcutData {
        switch self {
        case .scanAudit: KeyboardShortcutData(key: "r", command: true)
        case .uninstaller: KeyboardShortcutData(key: "u", command: true, shift: true)
        case .homebrew: KeyboardShortcutData(key: "h", command: true, shift: true)
        case .devAI: KeyboardShortcutData(key: "d", command: true, shift: true)
        case .browserCaches: KeyboardShortcutData(key: "b", command: true, shift: true)
        case .diskAnalyzer: KeyboardShortcutData(key: "k", command: true, shift: true)
        case .systemStatus: KeyboardShortcutData(key: "m", command: true, shift: true)
        case .trashHistory: KeyboardShortcutData(key: "z", command: true, option: true)
        case .showLog: KeyboardShortcutData(key: "l", command: true, option: true)
        }
    }
}

/// Kullanıcı tercihleri; `UserDefaults` üzerinde kalıcı tutulur ve testlerde geçici `UserDefaults` ile yalıtılır.
@Observable
@MainActor
public final class AppSettings {
    private let defaults: UserDefaults
    public let strings: StringTable

    public var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
            Self.applyLanguageToDefaults(language, defaults: defaults)
        }
    }

    public var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
            NSApp?.appearance = appearance.nsAppearance
        }
    }

    public var smartDeleteEnabled: Bool {
        didSet { defaults.set(smartDeleteEnabled, forKey: Keys.smartDeleteEnabled) }
    }

    public var startupView: UninstallerStartupView {
        didSet { defaults.set(startupView.rawValue, forKey: Keys.startupView) }
    }

    public var protectRunningApps: Bool {
        didSet { defaults.set(protectRunningApps, forKey: Keys.protectRunningApps) }
    }

    public var showProtectedApps: Bool {
        didSet { defaults.set(showProtectedApps, forKey: Keys.showProtectedApps) }
    }

    public var allowUninstallingProtectedApps: Bool {
        didSet { defaults.set(allowUninstallingProtectedApps, forKey: Keys.allowUninstallingProtectedApps) }
    }

    public var confirmBeforeTrashMove: Bool {
        didSet { defaults.set(confirmBeforeTrashMove, forKey: Keys.confirmBeforeTrashMove) }
    }

    public var playSoundEffects: Bool {
        didSet { defaults.set(playSoundEffects, forKey: Keys.playSoundEffects) }
    }

    public var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon) }
    }

    public var showDockProgress: Bool {
        didSet { defaults.set(showDockProgress, forKey: Keys.showDockProgress) }
    }

    public var sandboxEngine: Bool {
        didSet { defaults.set(sandboxEngine, forKey: Keys.sandboxEngine) }
    }

    public var checkUpdatesAtLaunch: Bool {
        didSet { defaults.set(checkUpdatesAtLaunch, forKey: Keys.checkUpdatesAtLaunch) }
    }

    public var updateConsentAsked: Bool {
        didSet { defaults.set(updateConsentAsked, forKey: Keys.updateConsentAsked) }
    }

    public var customEnginePath: String {
        didSet { defaults.set(customEnginePath, forKey: Keys.customEnginePath) }
    }

    public var customWhitelistPaths: [String] {
        didSet { defaults.set(customWhitelistPaths, forKey: Keys.customWhitelistPaths) }
    }

    public var shortcuts: [ShortcutAction: KeyboardShortcutData] {
        didSet {
            let dict = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
            if let data = try? JSONEncoder().encode(dict) {
                defaults.set(data, forKey: Keys.shortcuts)
            }
        }
    }

    public var lastSelectedSection: StudioSection {
        didSet { defaults.set(lastSelectedSection.rawValue, forKey: Keys.lastSelectedSection) }
    }

    public var uninstallerMode: UninstallerStartupView {
        didSet { defaults.set(uninstallerMode.rawValue, forKey: Keys.uninstallerMode) }
    }

    public var lastDevAISubTab: DevAISubTab {
        didSet { defaults.set(lastDevAISubTab.rawValue, forKey: Keys.lastDevAISubTab) }
    }

    public var lastHomebrewFilter: HomebrewFilterKind {
        didSet { defaults.set(lastHomebrewFilter.rawValue, forKey: Keys.lastHomebrewFilter) }
    }

    public var lastLanguageEcosystemFilter: LanguageEcosystemFilterKind {
        didSet { defaults.set(lastLanguageEcosystemFilter.rawValue, forKey: Keys.lastLanguageEcosystemFilter) }
    }

    public var lastTrashHistoryFilter: TrashHistoryFilterKind {
        didSet { defaults.set(lastTrashHistoryFilter.rawValue, forKey: Keys.lastTrashHistoryFilter) }
    }

    public var homebrewZapCasks: Bool {
        didSet { defaults.set(homebrewZapCasks, forKey: Keys.homebrewZapCasks) }
    }

    public var selectedUninstallerKind: BundleKind {
        didSet { defaults.set(selectedUninstallerKind.rawValue, forKey: Keys.selectedUninstallerKind) }
    }

    public var lastSystemStatusSubTab: SystemStatusSubTab {
        didSet { defaults.set(lastSystemStatusSubTab.rawValue, forKey: Keys.lastSystemStatusSubTab) }
    }

    public var lastSystemCenterTab: SystemCenterTab {
        didSet { defaults.set(lastSystemCenterTab.rawValue, forKey: Keys.lastSystemCenterTab) }
    }

    public var masterPaneWidth: Double {
        didSet { defaults.set(masterPaneWidth, forKey: Keys.masterPaneWidth) }
    }

    public var trashMasterPaneWidth: Double {
        didSet { defaults.set(trashMasterPaneWidth, forKey: Keys.trashMasterPaneWidth) }
    }

    private enum Keys {
        static let language = "curatare.language"
        static let appearance = "curatare.appearance"
        static let smartDeleteEnabled = "curatare.smartDeleteEnabled"
        static let startupView = "curatare.startupView"
        static let protectRunningApps = "curatare.protectRunningApps"
        static let showProtectedApps = "curatare.showProtectedApps"
        static let allowUninstallingProtectedApps = "curatare.allowUninstallingProtectedApps"
        static let confirmBeforeTrashMove = "curatare.confirmBeforeTrashMove"
        static let playSoundEffects = "curatare.playSoundEffects"
        static let showMenuBarIcon = "curatare.showMenuBarIcon"
        static let showDockProgress = "curatare.showDockProgress"
        static let sandboxEngine = "curatare.sandboxEngine"
        static let checkUpdatesAtLaunch = "curatare.checkUpdatesAtLaunch"
        static let updateConsentAsked = "curatare.updateConsentAsked"
        static let customEnginePath = "curatare.customEnginePath"
        static let customWhitelistPaths = "curatare.customWhitelistPaths"
        static let shortcuts = "curatare.shortcuts"
        static let lastSelectedSection = "curatare.ui.lastSelectedSection"
        static let uninstallerMode = "curatare.ui.uninstallerMode"
        static let lastDevAISubTab = "curatare.ui.lastDevAISubTab"
        static let lastHomebrewFilter = "curatare.ui.lastHomebrewFilter"
        static let lastLanguageEcosystemFilter = "curatare.ui.lastLanguageEcosystemFilter"
        static let lastTrashHistoryFilter = "curatare.ui.lastTrashHistoryFilter"
        static let homebrewZapCasks = "curatare.ui.homebrewZapCasks"
        static let selectedUninstallerKind = "curatare.ui.selectedUninstallerKind"
        static let lastSystemStatusSubTab = "curatare.ui.lastSystemStatusSubTab"
        static let lastSystemCenterTab = "curatare.ui.lastSystemCenterTab"
        static let masterPaneWidth = "curatare.ui.masterPaneWidth"
        static let trashMasterPaneWidth = "curatare.ui.trashMasterPaneWidth"
    }

    public init(defaults: UserDefaults = .standard, strings: StringTable = StringTable()) {
        self.defaults = defaults
        self.strings = strings
        let lang = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        self.language = lang
        Self.applyLanguageToDefaults(lang, defaults: defaults)
        self.appearance = AppAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.smartDeleteEnabled = defaults.object(forKey: Keys.smartDeleteEnabled) as? Bool ?? true
        self.startupView = UninstallerStartupView(rawValue: defaults.string(forKey: Keys.startupView) ?? "") ?? .dropZone
        self.protectRunningApps = defaults.object(forKey: Keys.protectRunningApps) as? Bool ?? true
        self.showProtectedApps = defaults.object(forKey: Keys.showProtectedApps) as? Bool ?? true
        self.allowUninstallingProtectedApps = defaults.object(forKey: Keys.allowUninstallingProtectedApps) as? Bool ?? false
        self.confirmBeforeTrashMove = defaults.object(forKey: Keys.confirmBeforeTrashMove) as? Bool ?? true
        self.playSoundEffects = defaults.object(forKey: Keys.playSoundEffects) as? Bool ?? true
        self.showMenuBarIcon = defaults.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
        self.showDockProgress = defaults.object(forKey: Keys.showDockProgress) as? Bool ?? true
        self.sandboxEngine = defaults.object(forKey: Keys.sandboxEngine) as? Bool ?? true
        self.checkUpdatesAtLaunch = defaults.object(forKey: Keys.checkUpdatesAtLaunch) as? Bool ?? false
        self.updateConsentAsked = defaults.object(forKey: Keys.updateConsentAsked) as? Bool ?? false
        self.customEnginePath = defaults.string(forKey: Keys.customEnginePath) ?? ""
        self.customWhitelistPaths = (defaults.array(forKey: Keys.customWhitelistPaths) as? [String]) ?? []

        self.lastSelectedSection = StudioSection(rawValue: defaults.string(forKey: Keys.lastSelectedSection) ?? "") ?? .home
        self.uninstallerMode = UninstallerStartupView(rawValue: defaults.string(forKey: Keys.uninstallerMode) ?? "") ?? (defaults.string(forKey: Keys.startupView).flatMap(UninstallerStartupView.init) ?? .dropZone)
        self.lastDevAISubTab = DevAISubTab(rawValue: defaults.string(forKey: Keys.lastDevAISubTab) ?? "") ?? .overview
        self.lastHomebrewFilter = HomebrewFilterKind(rawValue: defaults.string(forKey: Keys.lastHomebrewFilter) ?? "") ?? .all
        self.lastLanguageEcosystemFilter = LanguageEcosystemFilterKind(rawValue: defaults.string(forKey: Keys.lastLanguageEcosystemFilter) ?? "") ?? .all
        self.lastTrashHistoryFilter = TrashHistoryFilterKind(rawValue: defaults.string(forKey: Keys.lastTrashHistoryFilter) ?? "") ?? .all
        self.homebrewZapCasks = defaults.object(forKey: Keys.homebrewZapCasks) as? Bool ?? false
        self.selectedUninstallerKind = BundleKind(rawValue: defaults.string(forKey: Keys.selectedUninstallerKind) ?? "") ?? .application
        self.lastSystemStatusSubTab = SystemStatusSubTab(rawValue: defaults.string(forKey: Keys.lastSystemStatusSubTab) ?? "") ?? .systemCenter
        self.lastSystemCenterTab = SystemCenterTab(rawValue: defaults.string(forKey: Keys.lastSystemCenterTab) ?? "") ?? .hardware
        let mw = defaults.double(forKey: Keys.masterPaneWidth)
        self.masterPaneWidth = mw > 100 ? mw : 360.0
        let tmw = defaults.double(forKey: Keys.trashMasterPaneWidth)
        self.trashMasterPaneWidth = tmw > 100 ? tmw : 380.0

        var loadedShortcuts: [ShortcutAction: KeyboardShortcutData] = [:]
        if let data = defaults.data(forKey: Keys.shortcuts),
           let raw = try? JSONDecoder().decode([String: KeyboardShortcutData].self, from: data) {
            for (k, v) in raw {
                if let action = ShortcutAction(rawValue: k) {
                    loadedShortcuts[action] = v
                }
            }
        }
        for action in ShortcutAction.allCases where loadedShortcuts[action] == nil {
            loadedShortcuts[action] = action.defaultShortcut
        }
        self.shortcuts = loadedShortcuts
    }

    private static func applyLanguageToDefaults(_ lang: AppLanguage, defaults: UserDefaults) {
        if lang == .system {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([lang.rawValue], forKey: "AppleLanguages")
        }
    }

    public var resolvedLanguageCode: String {
        language.resolvedCode()
    }

    public var locale: Locale {
        Locale(identifier: resolvedLanguageCode)
    }

    public func L(_ key: LKey) -> String {
        strings.string(key, language: resolvedLanguageCode)
    }

    public func LF(_ key: LKey, _ args: CVarArg...) -> String {
        let format = L(key)
        return String(format: format, locale: locale, arguments: args)
    }

    public func shortcut(for action: ShortcutAction) -> KeyboardShortcutData {
        shortcuts[action] ?? action.defaultShortcut
    }

    public func addWhitelistPath(_ path: String) {
        let clean = (path as NSString).standardizingPath
        guard !clean.isEmpty, !customWhitelistPaths.contains(clean) else { return }
        customWhitelistPaths.append(clean)
    }

    public func removeWhitelistPath(_ path: String) {
        customWhitelistPaths.removeAll { $0 == path }
    }

    public func resetShortcuts() {
        shortcuts = Dictionary(uniqueKeysWithValues: ShortcutAction.allCases.map { ($0, $0.defaultShortcut) })
    }

    public func resetToDefaults() {
        language = .system
        appearance = .system
        smartDeleteEnabled = true
        startupView = .dropZone
        protectRunningApps = true
        showProtectedApps = true
        allowUninstallingProtectedApps = false
        confirmBeforeTrashMove = true
        playSoundEffects = true
        showMenuBarIcon = true
        showDockProgress = true
        sandboxEngine = true
        checkUpdatesAtLaunch = false
        updateConsentAsked = false
        customEnginePath = ""
        customWhitelistPaths = []
        lastSelectedSection = .home
        uninstallerMode = .dropZone
        lastDevAISubTab = .overview
        lastHomebrewFilter = .all
        lastLanguageEcosystemFilter = .all
        lastTrashHistoryFilter = .all
        homebrewZapCasks = false
        selectedUninstallerKind = .application
        lastSystemStatusSubTab = .systemCenter
        lastSystemCenterTab = .hardware
        masterPaneWidth = 360.0
        trashMasterPaneWidth = 380.0
        resetShortcuts()
    }
}
