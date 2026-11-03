// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Arayüz dilleri. `system`, macOS'un tercih ettiği dili izler.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case tr
    case en
    case ro

    public static let supportedCodes = ["tr", "en", "ro"]

    public var id: String { rawValue }

    public var nativeName: String? {
        switch self {
        case .system: nil
        case .tr: "Türkçe"
        case .en: "English"
        case .ro: "Română"
        }
    }

    public var flag: String {
        switch self {
        case .system: "🌐"
        case .tr: "🇹🇷"
        case .en: "🇬🇧"
        case .ro: "🇷🇴"
        }
    }

    public func resolvedCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if self != .system { return rawValue }
        for identifier in preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier ?? String(identifier.prefix(2))
            if Self.supportedCodes.contains(code) { return code }
        }
        return "tr"
    }
}

/// Her dil için `Localizable.strings` tablolarını tutar; uygulama içinde anında dil değişimine izin verir.
public struct StringTable: Sendable {
    public let tables: [String: [String: String]]

    public init(tables: [String: [String: String]]) {
        self.tables = tables
    }

    public init(bundle: Bundle = .main) {
        var loaded: [String: [String: String]] = [:]
        let repoResources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)

        for code in AppLanguage.supportedCodes {
            if let url = bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: code),
               let table = Self.load(contentsOf: url) {
                loaded[code] = table
            } else {
                let fallbackURL = repoResources
                    .appendingPathComponent("\(code).lproj", isDirectory: true)
                    .appendingPathComponent("Localizable.strings")
                if let table = Self.load(contentsOf: fallbackURL) {
                    loaded[code] = table
                }
            }
        }
        self.init(tables: loaded)
    }

    public static func load(contentsOf url: URL) -> [String: String]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: String]
    }

    public func string(_ key: LKey, language code: String) -> String {
        tables[code]?[key.rawValue] ?? tables["tr"]?[key.rawValue] ?? tables["en"]?[key.rawValue] ?? key.rawValue
    }
}

/// Tüm arayüz metinlerinin anahtarları. Her anahtar `tr`, `en` ve `ro` tablolarında bire bir bulunmalıdır.
public enum LKey: String, CaseIterable, Sendable {
    // Genel uygulama ve karşılama ekranı (WelcomeView)
    case appName, appTagline
    case welcomeTitle, welcomeSubtitle
    case welcomeDropTitle, welcomeDropSubtitle
    case engineReady, engineMissing, engineMissingDetail
    case safetyBannerDatedTrash, safetyBannerProtected
    case searchPrompt, buttonScan, buttonRefresh, buttonMoveToDatedTrash, buttonRestore
    case confirmTrashTitle, confirmTrashMessage, confirmUninstallMessage
    case buttonSelectAll, buttonDeselectAll, buttonShowInFinder, buttonCopyCommand, buttonCopied
    case buttonCancel, buttonOK, buttonClose, buttonChoose, buttonOpenSettings

    // Kenar çubuğu bölümleri
    case sidebarSectionStudio, sidebarSectionSystem
    case navHome, navLibraryAudit, navUninstaller, navHomebrew, navDevAndAI, navBrowserAndCaches
    case navDiskAnalyzer, navSystemStatus, navTrashHistory

    // Menü çubuğu ve komutlar
    case menuAbout, menuScanNow, menuUpdateMole, menuCheckAppUpdates, menuShowLog, menuWebsite, menuEngineManual
    case menuOpenCuratare, menuQuit

    // 1. Kitaplık Kalıntıları (Library Leftovers)
    case auditTitle, auditSubtitle
    case auditGroupAll, auditGroupA, auditGroupB, auditGroupC, auditGroupD, auditGroupE
    case auditGroupADesc, auditGroupBDesc, auditGroupCDesc, auditGroupDDesc, auditGroupEDesc
    case auditGroupFullA, auditGroupFullB, auditGroupFullC, auditGroupFullD, auditGroupFullE
    case auditGroupScopeAll, auditGroupScopeA, auditGroupScopeB, auditGroupScopeC, auditGroupScopeD, auditGroupScopeE
    case auditWelcomeTitle, auditWelcomeDesc, auditWelcomeButton, auditWelcomeSafetyBadge
    case auditItemsCount
    case auditInstalledCount, auditSelectedSummary, auditNoFindingsTitle, auditNoFindingsMessage
    case auditSudoSectionTitle, auditSudoSectionHint, auditRequiresSudoBadge

    // 2. Uygulama Kaldırıcı & SmartDelete
    case uninstallerTitle, uninstallerSubtitle
    case uninstallerTabApps, uninstallerTabWidgets, uninstallerTabPlugins
    case uninstallerDropHint, uninstallerProtectedBadge, uninstallerRunningBadge, uninstallerWrapperBadge
    case uninstallerAssociatedTitle, uninstallerSelectAppHint, uninstallerScanningAssociated
    case smartDeleteBannerTitle, smartDeleteBannerDetail, smartDeleteCleanButton, smartDeleteDismissButton
    case uninstallerModeDropZone, uninstallerModeList
    case uninstallerDropHere, uninstallerSelectToView
    case uninstallerSectionUserApps, uninstallerSectionSystemApps
    case uninstallerButtonBack

    // 3. Geliştirme ve Yapay Zekâ Temizliği
    case devAITitle, devAISubtitle
    case devAISectionGitHub, devAISectionAI
    case devAISectionHomebrew, devAIHomebrewInstalled, devAIHomebrewNotInstalled
    case devAIHomebrewCleanupButton, devAIHomebrewCleanupFullButton, devAIHomebrewAutoremoveButton, devAIHomebrewServicesButton
    case devAIHomebrewCacheLabel, devAIHomebrewEstimatedSavings, devAIHomebrewUnneededDepsLabel
    case devAITabOverview, devAITabHomebrewPackages, devAITabLanguageEcosystems
    case homebrewPackagesTitle, homebrewPackagesSubtitle
    case homebrewFilterAll, homebrewFilterFormulae, homebrewFilterCasks, homebrewFilterOrphans
    case homebrewBadgeFormula, homebrewBadgeCask, homebrewBadgeDependency, homebrewBadgeInstalledOnRequest
    case homebrewDependenciesTitle, homebrewInstallPathTitle, homebrewSizeLabel
    case homebrewUninstallButton, homebrewUninstallSelectedButton, homebrewZapOption
    case homebrewEmptySelectionTitle, homebrewEmptySelectionSubtitle
    case homebrewConfirmUninstallTitle, homebrewConfirmUninstallMessage
    case homebrewOpenManagerButton
    case devAITrackedWarning, devAICloudModelBadge, devAINoItems
    case devAISectionSystemRuntimes, devAISystemRuntimeProtected
    case devAISectionEcosystems, devAIEcosystemsSubtitle
    case devAIEcosystemFilterAll, devAIEcosystemSelectAll, devAIEcosystemDeselectAll
    case devAIEcosystemProtectedBadge
    case ecosystemsTitle, ecosystemsSubtitle
    case ecosystemsOriginAll, ecosystemsOriginUser, ecosystemsOriginHomebrew, ecosystemsOriginMacOS
    case ecosystemsMacOSBannerTitle, ecosystemsMacOSBannerDesc
    case ecosystemsBadgeUser, ecosystemsBadgeHomebrew, ecosystemsBadgeMacOS
    case ecosystemsFilterAll, ecosystemsFilterPython, ecosystemsFilterNode, ecosystemsFilterRust, ecosystemsFilterGo, ecosystemsFilterRuby, ecosystemsFilterJVM, ecosystemsFilterDotNet, ecosystemsFilterSwift, ecosystemsFilterDart, ecosystemsFilterVersionManagers, ecosystemsFilterSystemRuntimes, ecosystemsFilterOther
    case ecosystemsEmptyTitle, ecosystemsEmptySubtitle
    case ecosystemsMoveSelectedButton, ecosystemsMoveSingleButton
    case ecosystemsProtectedNotice, ecosystemsCleanableNotice
    case ecosystemsContentsTitle
    case ecosystemsConfirmMoveTitle, ecosystemsConfirmMoveMessage
    case ecosystemsOpenManagerButton

    // 4. Tarayıcı, Önbellekler, Yükleyiciler ve Time Machine
    case cachesTitle, cachesSubtitle
    case cachesCategoryAll, cachesCategoryBrowser, cachesCategoryAppVersion, cachesCategoryGradle
    case cachesCategoryDart, cachesCategoryLockFiles, cachesCategoryInstallers
    case cachesFilterAll, cachesFilterBrowsers, cachesFilterMailBackups, cachesFilterSystemLogs, cachesFilterMedia, cachesFilterUpdatesInstallers
    case cachesCategoryMailDownloads, cachesCategoryIOSBackups, cachesCategoryPartialDownloads
    case cachesCategoryWindowsMetadata, cachesCategoryCrashDumps, cachesCategoryShellSessions
    case cachesCategoryWallpapers, cachesCategoryQuickTime
    case cachesCategoryAudioUnits, cachesCategoryPreviousMusicLibraries, cachesCategoryXcodeArchives
    case timeMachineSectionTitle, timeMachineSectionSubtitle, timeMachineThinButton, timeMachineSnapshotCount

    // 5. Disk Analizi (`analyze-go`)
    case diskTitle, diskSubtitle
    case diskChooseFolder, diskNavigateUp, diskTotalSize, diskEmptyFolder, diskInspectFolder

    // 6. Sistem Durumu ve Bakım (`status-go`, `optimize` & `SystemTweaks`)
    case statusTitle, statusSubtitle
    case statusHealthScore, statusCPU, statusMemory, statusDisk, statusUptime
    case statusTabSystemCenter, statusTabDashboard, statusTabTweaks, statusTabChecksum
    case sysCenterTabHardware, sysCenterTabMemory, sysCenterTabVolumes, sysCenterTabSystem, sysCenterTabProfile
    case sysCenterModelName, sysCenterModelIdentifier, sysCenterChip, sysCenterArchitecture, sysCenterTotalCores
    case sysCenterGPU, sysCenterGPUCores, sysCenterResolution, sysCenterSystemFirmware, sysCenterHardwareUUID, sysCenterPhysicalDisk, sysCenterSerialNumber
    case sysCenterPhysicalMemory, sysCenterMemoryType, sysCenterUsedMemory, sysCenterWiredMemory, sysCenterCachedFiles, sysCenterMemoryPressure
    case sysCenterSwapUsed, sysCenterSwapCount, sysCenterPageIns, sysCenterPageOuts, sysCenterActiveMemory, sysCenterInactiveMemory, sysCenterPurgeAction, sysCenterShowInFinder
    case sysCenterCapacity, sysCenterAvailable, sysCenterUsedSpace, sysCenterBsdNode, sysCenterMountPoint, sysCenterLastVerification
    case sysCenterOSVersion, sysCenterKernelVersion, sysCenterFinderVersion, sysCenterAppleScriptVersion, sysCenterSQLiteVersion, sysCenterComputerName, sysCenterUserName, sysCenterUserUUID, sysCenterUptime, sysCenterIdentityTitle
    case sysCenterProfileDesc, sysCenterProfileKind, sysCenterFileFormat, sysCenterButtonShowProfile, sysCenterButtonSaveProfile
    case sysCenterCoresBreakdown, sysCenterGPUBuiltIn, sysCenterBytesValue, sysCenterGroupsLabel
    case sysCenterVolumeKindBootSnapshot, sysCenterVolumeKindData
    case sysCenterProfileKindHardware, sysCenterProfileKindMemory, sysCenterProfileKindStorage
    case sysCenterProfileKindDisplay, sysCenterProfileKindNetwork, sysCenterProfileKindSoftware
    case sysCenterProfileFormatText, sysCenterProfileFormatJSON
    case sysCenterProfileLoading, sysCenterProfileEmptyTitle, sysCenterProfileEmptyMessage
    case sysCenterProfileFailed, sysCenterProfileSaved, sysCenterProfileSaveFailed, sysCenterProfileFileName
    case statusCoresCount
    case sysCenterSmartStatus, sysCenterSmartVerified, sysCenterSmartFailing, sysCenterSmartNotSupported
    case tweakScreenshotFormatTitle, tweakScreenshotFormatDesc
    case statusSecurityOverviewTitle, statusSIPProtected, statusGatekeeperEnabled
    case statusFileVaultProtected, statusXProtectVersion, statusXProtectRemediator, statusLockdownMode
    case statusSecuritySIP, statusSecurityFileVault, statusSecurityGatekeeper, statusSecurityXProtect
    case statusEnabled, statusDisabled
    case statusMemoryPressure, statusPressureNormal, statusPressureWarn, statusPressureCritical
    case statusHardwareIdentity, statusSwapUsed
    case buttonPurgeMemory, toastMemoryPurged
    case buttonAddDockSpacer, buttonRemoveDockSpacers, toastDockSpacerAdded, toastDockSpacersRemoved
    case optimizeSectionTitle, optimizeSectionSubtitle, optimizeRunButton
    case optimizeQuickLook, optimizeSavedState, optimizeDNS, optimizeIconServices, optimizeFontCache, optimizeLaunchServices
    case optimizeSpotlightIndex, optimizeDiagnosticReports, optimizeLocalSnapshots
    case optimizeMailEnvelopeIndex, optimizeCUPSQueue, optimizeAPFSVerify
    case checksumTitle, checksumSubtitle, checksumDropPrompt, checksumChooseFile, checksumComparePlaceholder, checksumMatch, checksumMismatch
    case hiddenUtilitiesTitle, hiddenUtilitiesSubtitle, buttonLaunchUtility, toastLaunchedUtility
    case utilWirelessDiagnosticsTitle, utilWirelessDiagnosticsDesc
    case utilDirectoryUtilityTitle, utilDirectoryUtilityDesc
    case utilColorSyncUtilityTitle, utilColorSyncUtilityDesc
    case utilArchiveUtilityTitle, utilArchiveUtilityDesc
    case utilKeychainAccessTitle, utilKeychainAccessDesc
    case utilFeedbackAssistantTitle, utilFeedbackAssistantDesc
    case utilScreenSharingTitle, utilScreenSharingDesc
    case tweaksSectionFinder, tweaksSectionDock, tweaksSectionScreenshot, tweaksSectionDiskAndNetwork, tweaksSectionSystem
    case tweaksCategoryAll, tweaksResetAllButton, tweaksRestartNoticeFinder, tweaksRestartNoticeDock, tweaksRestartNoticeSystemUI
    case tweakShowHiddenFilesTitle, tweakShowHiddenFilesDesc
    case tweakShowFullPathInTitleTitle, tweakShowFullPathInTitleDesc
    case tweakShowAllExtensionsTitle, tweakShowAllExtensionsDesc
    case tweakQuitFinderMenuTitle, tweakQuitFinderMenuDesc
    case tweakNetworkStoresTitle, tweakNetworkStoresDesc
    case tweakUSBStoresTitle, tweakUSBStoresDesc
    case tweakDockStaticOnlyTitle, tweakDockStaticOnlyDesc
    case tweakDockDimHiddenTitle, tweakDockDimHiddenDesc
    case tweakScreenshotShadowTitle, tweakScreenshotShadowDesc
    case tweakScreenshotIncludeDateTitle, tweakScreenshotIncludeDateDesc
    case tweakScreenshotLocationTitle, tweakScreenshotLocationDesc
    case tweakCrashReporterDialogTitle, tweakCrashReporterDialogDesc
    case tweakMusicHalfStarsTitle, tweakMusicHalfStarsDesc
    case tweakWindowDragOnGestureTitle, tweakWindowDragOnGestureDesc
    case tweakPressAndHoldRepeatTitle, tweakPressAndHoldRepeatDesc
    case tweakTextEditBlankDocumentTitle, tweakTextEditBlankDocumentDesc
    case tweakDockInstantAutohideTitle, tweakDockInstantAutohideDesc
    case tweakSafariDevelopMenuTitle, tweakSafariDevelopMenuDesc
    case tweakHideDesktopIconsTitle, tweakHideDesktopIconsDesc
    case tweakDisableWindowAnimationsTitle, tweakDisableWindowAnimationsDesc
    case tweakPathBarFromHomeTitle, tweakPathBarFromHomeDesc
    case tweakDockLockContentsTitle, tweakDockLockContentsDesc
    case tweakDockLockSizeTitle, tweakDockLockSizeDesc
    case tweakDockStackHighlightTitle, tweakDockStackHighlightDesc
    case tweakScreenshotThumbnailTitle, tweakScreenshotThumbnailDesc
    case tweakScreenshotCursorTitle, tweakScreenshotCursorDesc
    case tweakExpandedSaveDialogTitle, tweakExpandedSaveDialogDesc
    case tweakDisableAppNapTitle, tweakDisableAppNapDesc
    case toastTweakApplied, toastTweaksReset

    // 7. Tarihli Çöp Turları ve Geçmiş (`~/.Trash/Curatare-...`)
    case trashHistoryTitle, trashHistorySubtitle
    case trashHistoryEmptyTitle, trashHistoryEmptyMessage
    case trashBatchRestoredBadge, trashBatchItemsCount
    case trashPurgeSingleButton, trashPurgeAllButton
    case trashPurgeSelectedItemsButton, trashPurgeSingleItemTooltip
    case trashConfirmPurgeSingleTitle, trashConfirmPurgeSingleMessage
    case trashConfirmPurgeAllTitle, trashConfirmPurgeAllMessage
    case trashConfirmPurgeSingleItemTitle, trashConfirmPurgeSingleItemMessage
    case trashConfirmPurgeSelectedItemsTitle, trashConfirmPurgeSelectedItemsMessage
    case trashFilterAll, trashFilterPending, trashFilterRestored
    case trashEmptySelectionTitle, trashEmptySelectionSubtitle
    case toastBatchPurged, toastAllBatchesPurged, toastItemPurged, toastSelectedItemsPurged
    case contextMenuCopyPath, contextMenuCopyName, contextMenuLaunchApp, contextMenuOpenHomepage, contextMenuZapUninstall

    // Homebrew Stüdyosu
    case shortcutHomebrew
    case homebrewStudioTitle, homebrewStudioSubtitle
    case homebrewNotInstalledTitle, homebrewNotInstalledDesc, homebrewInstallSiteButton

    // Ayarlar (Genel, Temizlik ve Koruma, Kısayollar, Gelişmiş)
    case settingsGeneral, settingsProtection, settingsEngine, settingsShortcuts, settingsAdvanced
    case settingsLanguage, settingsLanguageNote, languageSystem
    case restartMenuBarNotice, restartWarningTitle, restartWarningMessage
    case settingsAppearance, appearanceSystem, appearanceLight, appearanceDark
    case settingsSmartDelete, settingsSmartDeleteNote, settingsSmartDeleteBigNote
    case settingsStartupView, settingsProtectRunningApps, settingsProtectRunningAppsNote, settingsProtectRunningAppsFooter, settingsShowProtectedApps, settingsShowProtectedAppsNote
    case settingsAllowUninstallingProtectedApps, settingsAllowUninstallingProtectedAppsNote
    case settingsFullDiskAccessHeader, settingsFullDiskAccessGranted, settingsFullDiskAccessMissing, settingsFullDiskAccessDesc, settingsOpenSystemSettings
    case uninstallerSystemImmutableNotice, uninstallerSystemImmutableDesc, uninstallerProtectedUnlockNotice, uninstallerProtectedUnlockedBanner
    case uninstallerRunningAppWarningTitle, uninstallerRunningAppWarningMessage, uninstallerQuitAppButton, toastAppTerminated
    case settingsAddAppsToKeepSafe, settingsTabSmartDelete, settingsTabUpdates
    case settingsConfirmation, settingsConfirmationNote
    case settingsPlaySoundEffects, settingsPlaySoundEffectsDesc
    case uninstallerMountedVolumeNotice, buttonQuickLook
    case settingsInterfaceSection, settingsShowMenuBarIcon, settingsShowMenuBarIconDesc, settingsShowDockProgress
    case settingsProtectedRulesTitle, settingsProtectedRulesDesc
    case settingsProtectedRuleSystem, settingsProtectedRuleFrameworks, settingsProtectedRuleDevCaches, settingsProtectedRuleAIAndVMs
    case settingsWhitelistTitle, settingsWhitelistNote, settingsWhitelistAdd, settingsWhitelistRemove, settingsWhitelistEmpty
    case settingsShortcutsDesc, shortcutPressKeys, shortcutReset, shortcutResetAll, shortcutConflict
    case shortcutScanAudit, shortcutUninstaller, shortcutDevAI, shortcutBrowserCaches, shortcutDiskAnalyzer, shortcutSystemStatus, shortcutTrashHistory, shortcutShowLog
    case settingsShortcutRefTitle, shortcutRefCut, shortcutRefCopy, shortcutRefPaste, shortcutRefSelectAll
    case settingsEngineVersion, settingsEngineSource, settingsEnginePath, settingsEngineCustomPath
    case settingsEngineUseCustom, settingsEngineCheck, settingsEngineNotFound, settingsSandbox, settingsSandboxNote
    case updateSection, updateSource, updateCheck, updateInstall, updateChecking, updateInstalling
    case updateAvailable, updateUpToDate, updateInstalled, updateFailed
    case updateBannerTitle, updateBannerMessage, updateNow, updateLater
    case consentTitle, consentMessage, consentAllow, consentDeny
    case appUpdateSection, appVersionLabel, appUpdateAvailable, appUpdateUpToDate, appUpdateDownload, appUpdateNoReleases, updateAutoCheck
    case appUpdateAlertUpToDate, appUpdateAlertAvailable, appUpdateAlertNoReleases, appUpdateAlertFailed, appUpdateAlertUnconfigured
    case moleUpdateAlertUpToDate, moleUpdateAlertAvailable, moleUpdateAlertFailed
    case updateAppTitle, updateMoleTitle, updateAppSubtitle, updateMoleSubtitle, updateCheckingApp
    case settingsReset, settingsResetConfirm
    case toggleOff, toggleOn
    case moleEngineVersionBadge, moleUpdateAvailableBadge

    // Günlük (LogView) ve Hakkında (AboutView)
    case logTitle, logAllMessages, logProblems, logSearchPrompt, logClear, logOpenInConsole
    case logEmptyTitle, logEmptyMessage, logFilterCount, logTotalCount
    case logColumnTime, logColumnType, logColumnCategory, logColumnProcess, logColumnMessage
    case logLevelInfo, logLevelWarning, logLevelError
    case logCategoryApp, logCategoryEngine, logCategoryAudit, logCategoryUninstall, logCategoryTrash, logCategoryUpdate
    case aboutVersion, aboutPoweredBy, aboutEngineCredit, aboutEngineWebsite
    case aboutLicense, aboutAppLicense, aboutNotices, aboutCopyright, aboutRepository

    // Babadogan Mac Araçları Ailesi (AboutView)
    case aboutFamilyTitle, aboutFamilySubtitle
    case aboutFamilyArhivarDesc, aboutFamilyCopiatorDesc, aboutFamilyDescarcatorDesc, aboutFamilyCuratareDesc
    case aboutFamilyOpenApp, aboutFamilyInstalled, aboutFamilyCurrentApp

    // Mole 5 Temel Sütunu (WelcomeView)
    case welcomePillarsHeader
    case welcomePillarCleanTitle, welcomePillarCleanDesc
    case welcomePillarUninstallTitle, welcomePillarUninstallDesc
    case welcomePillarOptimizeTitle, welcomePillarOptimizeDesc
    case welcomePillarAnalyzeTitle, welcomePillarAnalyzeDesc
    case welcomePillarStatusTitle, welcomePillarStatusDesc

    // Durum iletileri ve hatalar
    case statusScanning, statusMovingToTrash, statusRestoring
    case toastMovedToDatedTrash, toastRestoredBatch, toastOptimizationDone, toastScanCancelled
    case errorTitle, errorProtectedTarget, errorProcessRunning, errorEngineNotFound
}
