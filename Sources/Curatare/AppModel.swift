// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

public enum StudioSection: String, CaseIterable, Identifiable, Sendable {
    case home
    case libraryAudit
    case uninstaller
    case homebrew
    case devAndAI
    case browserAndCaches
    case diskAnalyzer
    case systemStatus
    case trashHistory

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .home: "house"
        case .libraryAudit: "checklist.checked"
        case .uninstaller: "trash.slash.circle"
        case .homebrew: "mug.fill"
        case .devAndAI: "hammer.circle"
        case .browserAndCaches: "globe.badge.chevron.backward"
        case .diskAnalyzer: "chart.pie.fill"
        case .systemStatus: "gauge.with.dots.needle.67percent"
        case .trashHistory: "clock.arrow.circlepath"
        }
    }

    public var titleKey: LKey {
        switch self {
        case .home: .navHome
        case .libraryAudit: .navLibraryAudit
        case .uninstaller: .navUninstaller
        case .homebrew: .navHomebrew
        case .devAndAI: .navDevAndAI
        case .browserAndCaches: .navBrowserAndCaches
        case .diskAnalyzer: .navDiskAnalyzer
        case .systemStatus: .navSystemStatus
        case .trashHistory: .navTrashHistory
        }
    }
}

public enum EngineUpdateUIState: Sendable, Equatable {
    case idle
    case checking
    case installing
    case upToDate(String)
    case available(latest: String)
    case installed(String)
    case failed(String)
}

public enum AppUpdateUIState: Sendable, Equatable {
    case idle
    case checking
    case upToDate(String)
    case available(latest: AppRelease)
    case noReleases(repo: String)
    case failed(String)
    case unconfigured
}

public enum PendingTrashConfirmation: Sendable, Equatable {
    case auditFindings(count: Int, bytes: Int64)
    case uninstall(bundle: InstalledBundle, count: Int, bytes: Int64)
    case devAI(count: Int, bytes: Int64)
}

public enum DevAISubTab: String, CaseIterable, Sendable {
    case overview
    case languageEcosystems
}

public enum LanguageEcosystemOriginTab: String, CaseIterable, Sendable {
    case cleanableAll
    case userStandalone
    case homebrew
    case macosSystem
}

public struct AlertItem: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let actionTitle: String?
    public let action: (@Sendable () -> Void)?
    public let cancelTitle: String?
    public let cancelAction: (@Sendable () -> Void)?

    public init(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (@Sendable () -> Void)? = nil,
        cancelTitle: String? = nil,
        cancelAction: (@Sendable () -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.cancelTitle = cancelTitle
        self.cancelAction = cancelAction
    }
}

@Observable
@MainActor
public final class AppModel {
    public var settings: AppSettings
    public let log: AppLog
    public var trashService: DatedTrashService
    public var libraryScanner: LibraryScanner
    public var extendedScanners: ExtendedScanners
    public var appUninstaller: AppUninstaller

    public var selectedSection: StudioSection = .home {
        didSet { settings.lastSelectedSection = selectedSection }
    }
    public var engineInfo: EngineInfo?
    public var engineUpdateState: EngineUpdateUIState = .idle
    public var appUpdateState: AppUpdateResult?
    public var appUpdateUIState: AppUpdateUIState = .idle
    public var updateAlertMessage: String?
    public var updateBannerDismissed: Bool = false

    // 1. Library Denetimi (A–E)
    public var auditReport: LibraryAuditReport?
    public var selectedAuditGroup: AuditGroup? = nil
    public var auditSearchText: String = ""

    // 2. Uygulama Kaldırıcı & SmartDelete
    public var installedBundles: [InstalledBundle] = []
    public var hasScannedUninstaller: Bool = false
    public var selectedUninstallerKind: BundleKind = .application {
        didSet { settings.selectedUninstallerKind = selectedUninstallerKind }
    }
    public var selectedBundleID: String?
    public var inspectingBundle: InstalledBundle?
    public var uninstallerMode: UninstallerStartupView = .dropZone {
        didSet { settings.uninstallerMode = uninstallerMode }
    }
    public var associatedFiles: [AssociatedFile] = []
    public var isInspectingBundleLoading: Bool = false
    @ObservationIgnored private var inspectionTask: Task<Void, Never>?
    public var uninstallerSearchText: String = ""
    public var smartDeleteEvent: TrashedAppEvent?
    private var trashWatcher: TrashWatcher?

    // 3. Geliştirme ve Yapay Zekâ
    public var repoArtifacts: [RepoBuildArtifact] = []
    public var aiFootprintItems: [AIFootprintItem] = []
    public var languageEcosystemItems: [LanguageEcosystemItem] = []
    public var selectedEcosystemFilter: LanguageEcosystemItem.Ecosystem? = nil
    public var homebrewStatus: HomebrewStatus = .notInstalled
    /// `brew` yürütülebilir dosyası var mı (iki dosya varlık denetimi; tarama gerektirmez).
    public var isHomebrewAvailable: Bool { homebrewStatus.isInstalled || HomebrewScanner.locateBrew() != nil }
    public var devAISubTab: DevAISubTab = .overview {
        didSet { settings.lastDevAISubTab = devAISubTab }
    }
    public var homebrewPackages: [HomebrewPackage] = []
    public var hasScannedHomebrew: Bool = false
    public var selectedHomebrewPackageID: String? = nil
    public var homebrewPackageFilter: HomebrewFilterKind = .all {
        didSet { settings.lastHomebrewFilter = homebrewPackageFilter }
    }
    public var homebrewPackageSearchText: String = ""
    public var homebrewZapCasks: Bool = false {
        didSet { settings.homebrewZapCasks = homebrewZapCasks }
    }

    // 7. Tarihli Çöp Turları Master-Detail
    public var trashHistoryFilter: TrashHistoryFilterKind = .all {
        didSet { settings.lastTrashHistoryFilter = trashHistoryFilter }
    }
    public var trashHistorySearchText: String = ""
    public var selectedTrashBatchID: String? = nil {
        didSet {
            selectedTrashedItemIDs.removeAll()
        }
    }
    public var selectedTrashedItemIDs: Set<UUID> = []

    public var selectedTrashBatch: TrashBatchManifest? {
        if let id = selectedTrashBatchID {
            return trashBatches.first { $0.id == id }
        }
        return filteredTrashBatches.first
    }

    public var filteredTrashBatches: [TrashBatchManifest] {
        var list = trashBatches
        switch trashHistoryFilter {
        case .all:
            break
        case .pendingRestore:
            list = list.filter { !$0.isRestored }
        case .restored:
            list = list.filter { $0.isRestored }
        }
        if !trashHistorySearchText.isEmpty {
            let q = trashHistorySearchText.trimmingCharacters(in: .whitespaces).lowercased()
            list = list.filter {
                $0.id.lowercased().contains(q) ||
                $0.title.lowercased().contains(q) ||
                $0.batchDirectoryPath.lowercased().contains(q) ||
                $0.items.contains(where: { $0.trashedRelativePath.lowercased().contains(q) || $0.originalPath.lowercased().contains(q) })
            }
        }
        return list
    }

    public var systemRuntimeItems: [LanguageEcosystemItem] {
        languageEcosystemItems.filter { $0.isSystemProtected }
    }

    public var cleanableEcosystemItems: [LanguageEcosystemItem] {
        languageEcosystemItems.filter { !$0.isSystemProtected }
    }

    public var filteredCleanableEcosystemItems: [LanguageEcosystemItem] {
        guard let filter = selectedEcosystemFilter else { return cleanableEcosystemItems }
        return cleanableEcosystemItems.filter { $0.ecosystem == filter }
    }

    public var selectedEcosystemItemsCount: Int {
        cleanableEcosystemItems.filter(\.isSelected).count
    }

    public var selectedEcosystemItemsTotalBytes: Int64 {
        cleanableEcosystemItems.filter(\.isSelected).map(\.sizeBytes).reduce(0, +)
    }

    public func toggleSelectAllEcosystemItems() {
        let items = filteredCleanableEcosystemItems
        let allSelected = items.allSatisfy(\.isSelected)
        let filteredIDs = Set(items.map(\.id))
        for i in languageEcosystemItems.indices {
            if filteredIDs.contains(languageEcosystemItems[i].id) && !languageEcosystemItems[i].isSystemProtected {
                languageEcosystemItems[i].isSelected = !allSelected
            }
        }
    }

    // MARK: - Dil ve Ekosistem Master-Detail Yönetimi

    public var languageEcosystemOriginTab: LanguageEcosystemOriginTab = .cleanableAll
    public var hasScannedLanguageEcosystems: Bool = false
    public var hasScannedDevAndAI: Bool = false

    public var languageEcosystemFilter: LanguageEcosystemFilterKind = .all {
        didSet { settings.lastLanguageEcosystemFilter = languageEcosystemFilter }
    }
    public var languageEcosystemSearchText: String = ""
    public var selectedLanguageEcosystemItemID: String? = nil

    public var selectedLanguageEcosystemItem: LanguageEcosystemItem? {
        if let id = selectedLanguageEcosystemItemID {
            return languageEcosystemItems.first { $0.id == id }
        }
        return filteredLanguageEcosystemItems.first
    }

    public var filteredLanguageEcosystemItems: [LanguageEcosystemItem] {
        var list = languageEcosystemItems

        // 1. Menşe / Koruma Ayrımı
        switch languageEcosystemOriginTab {
        case .cleanableAll:
            list = list.filter { !$0.isSystemProtected }
        case .userStandalone:
            list = list.filter { $0.origin == .userStandalone && !$0.isSystemProtected }
        case .homebrew:
            list = list.filter { $0.origin == .homebrew && !$0.isSystemProtected }
        case .macosSystem:
            list = list.filter { $0.origin == .macosSystem || $0.isSystemProtected }
        }

        // 2. Alt Ekosistem / Dil Filtresi (Yalnızca temizlenebilir sekmelerde uygulanır)
        if languageEcosystemOriginTab != .macosSystem {
            switch languageEcosystemFilter {
            case .all:
                break
            case .python:
                list = list.filter { $0.ecosystem == .python }
            case .nodeJS:
                list = list.filter { $0.ecosystem == .javascriptNode }
            case .rust:
                list = list.filter { $0.ecosystem == .rust }
            case .goLang:
                list = list.filter { $0.ecosystem == .goLang }
            case .ruby:
                list = list.filter { $0.ecosystem == .ruby }
            case .jvm:
                list = list.filter { $0.ecosystem == .jvm }
            case .dotnet:
                list = list.filter { $0.ecosystem == .dotnet }
            case .swift:
                list = list.filter { $0.ecosystem == .swift }
            case .dart:
                list = list.filter { $0.ecosystem == .dartFlutter }
            case .versionManagers:
                list = list.filter { $0.ecosystem == .versionManager }
            case .otherEcosystems:
                list = list.filter { $0.ecosystem == .otherEcosystem }
            case .systemRuntimes:
                list = list.filter { $0.isSystemProtected }
            }
        }

        // 3. Arama Metni Filtresi
        if !languageEcosystemSearchText.isEmpty {
            let q = languageEcosystemSearchText.trimmingCharacters(in: .whitespaces).lowercased()
            list = list.filter {
                $0.toolName.lowercased().contains(q) ||
                $0.path.lowercased().contains(q) ||
                $0.explanation.lowercased().contains(q) ||
                $0.ecosystem.titleTR.lowercased().contains(q) ||
                $0.origin.titleTR.lowercased().contains(q)
            }
        }
        return list
    }

    public var selectedCleanableEcosystemItemsCount: Int {
        filteredLanguageEcosystemItems.filter { !$0.isSystemProtected && $0.isSelected }.count
    }

    public var selectedCleanableEcosystemItemsTotalBytes: Int64 {
        filteredLanguageEcosystemItems.filter { !$0.isSystemProtected && $0.isSelected }.map(\.sizeBytes).reduce(0, +)
    }

    public func selectLanguageEcosystemItem(_ item: LanguageEcosystemItem) {
        selectedLanguageEcosystemItemID = item.id
    }

    public func toggleSelectAllFilteredEcosystemItems() {
        guard languageEcosystemOriginTab != .macosSystem else { return }
        let cleanable = filteredLanguageEcosystemItems.filter { !$0.isSystemProtected }
        guard !cleanable.isEmpty else { return }
        let allSelected = cleanable.allSatisfy(\.isSelected)
        let filteredIDs = Set(cleanable.map(\.id))
        for i in languageEcosystemItems.indices {
            if filteredIDs.contains(languageEcosystemItems[i].id) && !languageEcosystemItems[i].isSystemProtected {
                languageEcosystemItems[i].isSelected = !allSelected
            }
        }
    }

    public func inspectCacheSubdirectories(for item: LanguageEcosystemItem) -> [CacheSubdirectoryInfo] {
        ExtendedScanners.inspectCacheSubdirectories(at: item.url)
    }

    public func moveSingleEcosystemItemToDatedTrash(_ item: LanguageEcosystemItem) {
        guard !item.isSystemProtected else { return }
        let candidate = DatedTrashMoveCandidate(
            url: item.url,
            category: "Ecosystem:\(item.ecosystem.rawValue):\(item.toolName)",
            precomputedSize: item.sizeBytes
        )
        do {
            let protection = ProtectionRules(
                userWhitelistPatterns: settings.customWhitelistPaths,
                allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps,
                allowDeveloperCacheCleaning: true
            )
            let manifest = try trashService.moveToDatedTrash(
                candidates: [candidate],
                title: "Ecosystem Cleanup: \(item.toolName)",
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            let moved = Set(manifest.items.map(\.originalPath))
            languageEcosystemItems.removeAll { item in moved.contains(item.url.path) }
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "Moved \(item.toolName) cache to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    // 4. Tarayıcı, Önbellekler ve Time Machine
    public var heavyCacheItems: [HeavyCacheItem] = []
    public var selectedCacheCategory: HeavyCacheItem.Category? = nil
    public var selectedCacheFilterGroup: HeavyCacheItem.FilterGroup = .all
    public var timeMachineSnapshots: [TimeMachineSnapshot] = []

    // 5. Disk Analizi
    public var currentAnalyzedURL: URL
    public var diskAnalysis: MoleDiskAnalysis?

    // 6. Sistem Durumu, Bakım ve İnce Ayarlar
    public var systemStatus: MoleSystemStatus = MoleBridge.fallbackSystemStatus()
    public var securityStatus: SystemSecurityStatus = SystemSecurityStatus()
    public let hiddenUtilities: [HiddenSystemUtility] = HiddenSystemUtility.defaultUtilities
    public var optimizationTasks: [MoleOptimizationTask] = MoleOptimizationTask.defaultTasks
    public var systemStatusSubTab: SystemStatusSubTab {
        didSet { settings.lastSystemStatusSubTab = systemStatusSubTab }
    }
    public var systemCenterTab: SystemCenterTab {
        didSet { settings.lastSystemCenterTab = systemCenterTab }
    }
    public var systemCenterHardware: SystemCenterHardware?
    public var systemCenterMemory: SystemCenterMemory?
    public var systemCenterVolumes: SystemCenterVolumes?
    public var systemCenterOS: SystemCenterOSAndIdentity?
    public var systemCenterProfileText: String = ""
    public var selectedProfileKind: SystemProfilerProfileKind = .hardware
    public var selectedProfileFormat: SystemProfilerFormat = .text
    public var isGeneratingProfile: Bool = false
    public var hasLoadedSystemCenter: Bool = false
    public var hasLoadedSystemStatus: Bool = false
    public var isLoadingSystemStatus: Bool = false
    public var systemTweaks: [SystemTweakItem] = []
    public var systemChoiceTweaks: [SystemChoiceTweak] = []
    public var screenshotFormat: ScreenshotFormat?
    public var screenshotNamePrefix: String = ""
    public let tweakManager: SystemTweakManager
    public var checksumResult: FileChecksumResult?
    public var checksumExpectedHash: String = ""
    public var isCalculatingChecksum: Bool = false

    // 7. Tarihli Çöp Turları
    public var trashBatches: [TrashBatchManifest] = []

    // Durum & Geri Bildirim
    public var isBusy: Bool = false
    public var busyMessage: String?
    /// `true` iken süren işlem salt okunur bir taramadır: tam ekran katman yerine sekme içi şerit gösterilir.
    /// Temizlik ve silme işlemleri `false` kalır ve `ProgressOverlay` ile gösterilir.
    public var isBusyInline: Bool = false
    public var toastMessage: String?
    public var activeErrorMessage: String?
    public var pendingTrashConfirmation: PendingTrashConfirmation?
    public var lastDroppedBundleID: String?
    public var alertItem: AlertItem?
    public var consentPending: Bool = false

    private var activeOperationID: UUID?
    private var activeCancelToken: ScanCancellationToken?
    private var activeCancelHandler: (() -> Void)?

    public init(
        settings: AppSettings? = nil,
        log: AppLog = .shared,
        homeDirectoryURL: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
        trashService: DatedTrashService? = nil,
        libraryScanner: LibraryScanner? = nil,
        extendedScanners: ExtendedScanners? = nil,
        appUninstaller: AppUninstaller? = nil,
        tweakManager: SystemTweakManager? = nil,
        startBackgroundWatchers: Bool = false
    ) {
        let resolvedSettings = settings ?? AppSettings()
        self.settings = resolvedSettings
        self.log = log
        let resolvedTrash = trashService ?? DatedTrashService(homeDirectoryURL: homeDirectoryURL)
        self.trashService = resolvedTrash
        self.libraryScanner = libraryScanner ?? LibraryScanner(homeDirectoryURL: homeDirectoryURL)
        self.extendedScanners = extendedScanners ?? ExtendedScanners(homeDirectoryURL: homeDirectoryURL)
        self.appUninstaller = appUninstaller ?? AppUninstaller(homeDirectoryURL: homeDirectoryURL)
        let resolvedTweakManager = tweakManager ?? SystemTweakManager()
        self.tweakManager = resolvedTweakManager
        self.systemStatusSubTab = resolvedSettings.lastSystemStatusSubTab
        self.systemCenterTab = resolvedSettings.lastSystemCenterTab
        self.systemTweaks = resolvedTweakManager.loadAllTweaks()
        self.systemChoiceTweaks = resolvedTweakManager.loadChoiceTweaks()
        self.screenshotFormat = resolvedTweakManager.screenshotFormat()
        self.screenshotNamePrefix = resolvedTweakManager.screenshotNamePrefix()
        self.currentAnalyzedURL = homeDirectoryURL
        self.trashBatches = resolvedTrash.listBatches()
        self.selectedSection = resolvedSettings.lastSelectedSection
        self.uninstallerMode = resolvedSettings.uninstallerMode
        self.selectedUninstallerKind = resolvedSettings.selectedUninstallerKind
        self.devAISubTab = resolvedSettings.lastDevAISubTab
        self.homebrewPackageFilter = resolvedSettings.lastHomebrewFilter
        self.languageEcosystemFilter = resolvedSettings.lastLanguageEcosystemFilter
        self.trashHistoryFilter = resolvedSettings.lastTrashHistoryFilter
        self.homebrewZapCasks = resolvedSettings.homebrewZapCasks

        if startBackgroundWatchers {
            configureSmartDeleteWatcher()
            Task {
                await refreshEngine()
                // Açılışta yalnızca hafif canlı ölçümler (alt başlıktaki sağlık puanı); Sistem Merkezi ve güvenlik
                // durumu Sistem Durumu sekmesi ilk açıldığında yüklenir.
                await refreshLiveMetrics()
                if !resolvedSettings.updateConsentAsked {
                    consentPending = true
                    presentPendingConsentIfIdle()
                } else if resolvedSettings.checkUpdatesAtLaunch {
                    await checkMoleUpdate(interactive: false)
                    await checkAppUpdate(interactive: false)
                }
            }
        }
    }

    public func L(_ key: LKey) -> String { settings.L(key) }
    public func LF(_ key: LKey, _ args: CVarArg...) -> String {
        let format = L(key)
        return String(format: format, locale: Locale(identifier: settings.resolvedLanguageCode), arguments: args)
    }

    // MARK: - İptal Edilebilir İşlem Yürütücüsü

    public func cancelActiveOperation() {
        guard isBusy else { return }
        activeCancelToken?.cancel()
        activeCancelHandler?()
        activeCancelToken = nil
        activeCancelHandler = nil
        activeOperationID = nil
        isBusy = false
        busyMessage = nil
        showToast(L(.toastScanCancelled))
        log.info(.app, "Operation cancelled by user")
    }

    private func performCancellableOperation<T: Sendable>(
        message: String? = nil,
        inline: Bool = false,
        operation: @escaping @Sendable (ScanCancellationToken) async -> T,
        onComplete: (T) async -> Void
    ) async {
        activeCancelToken?.cancel()
        activeCancelHandler?()

        let opID = UUID()
        let token = ScanCancellationToken()
        activeOperationID = opID
        activeCancelToken = token
        isBusy = true
        isBusyInline = inline
        busyMessage = message ?? L(.statusScanning)

        let worker = Task.detached(priority: .userInitiated) {
            await operation(token)
        }
        activeCancelHandler = {
            token.cancel()
            worker.cancel()
        }

        defer {
            if activeOperationID == opID {
                isBusy = false
                isBusyInline = false
                busyMessage = nil
                activeCancelToken = nil
                activeCancelHandler = nil
                activeOperationID = nil
            }
        }

        let result = await withTaskCancellationHandler {
            await worker.value
        } onCancel: {
            token.cancel()
            worker.cancel()
        }

        guard !token.isCancelled, activeOperationID == opID else { return }
        await onComplete(result)
    }

    // MARK: - SmartDelete (~/.Trash İzleyicisi)

    public func configureSmartDeleteWatcher() {
        trashWatcher?.stop()
        guard settings.smartDeleteEnabled else {
            trashWatcher = nil
            return
        }
        let uninstaller = appUninstaller
        let trashURL = trashService.trashRootURL
        let watcher = TrashWatcher(trashURL: trashURL, uninstaller: uninstaller) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.settings.smartDeleteEnabled else { return }
                self.smartDeleteEvent = event
                self.log.info(.uninstall, "SmartDelete detected trashed app", detail: event.bundle.name)
            }
        }
        watcher.start()
        trashWatcher = watcher
    }

    public func acceptSmartDeleteEvent() {
        guard let event = smartDeleteEvent else { return }
        do {
            let manifest = try appUninstaller.uninstallToDatedTrash(
                bundle: event.bundle,
                associatedFiles: event.orphanedFiles,
                trashService: trashService,
                verifyRunningProcess: false
            )
            smartDeleteEvent = nil
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "SmartDelete leftovers moved to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    public func dismissSmartDeleteEvent() {
        smartDeleteEvent = nil
    }

    // MARK: - Mole Motoru ve GitHub Güncelleyicisi

    public func refreshEngine() async {
        let custom = settings.customEnginePath.isEmpty ? nil : settings.customEnginePath
        let info = await EngineLocator.inspect(customPath: custom)
        self.engineInfo = info
        if let info {
            log.info(.engine, "Mole engine ready (\(info.version))", detail: info.url.path)
        } else {
            log.warning(.engine, "Mole engine not found")
        }
    }

    public func checkMoleUpdate(interactive: Bool = false) async {
        engineUpdateState = .checking
        do {
            let res = try await EngineUpdater.check(currentVersion: engineInfo?.version)
            switch res {
            case .upToDate(let version):
                engineUpdateState = .upToDate(version)
                if interactive {
                    updateAlertMessage = LF(.moleUpdateAlertUpToDate, version)
                    showToast(LF(.moleUpdateAlertUpToDate, version))
                }
            case .updateAvailable(_, let latest, _):
                engineUpdateState = .available(latest: latest)
                if interactive {
                    updateAlertMessage = LF(.moleUpdateAlertAvailable, latest)
                    showToast(LF(.moleUpdateAlertAvailable, latest))
                }
            case .installed(let version, _):
                engineUpdateState = .installed(version)
            }
        } catch {
            if let version = engineInfo?.version, !version.isEmpty {
                engineUpdateState = .upToDate(version)
                if interactive {
                    updateAlertMessage = LF(.moleUpdateAlertUpToDate, version)
                    showToast(LF(.moleUpdateAlertUpToDate, version))
                }
                log.info(.update, "Mole update check fallback, using current version", detail: version)
            } else {
                let msg = (error as? EngineError).map {
                    switch $0 {
                    case .failed(_, let m): return m
                    default: return "\($0)"
                    }
                } ?? error.localizedDescription
                engineUpdateState = .failed(msg)
                if interactive {
                    updateAlertMessage = LF(.moleUpdateAlertFailed, msg)
                    showToast(LF(.moleUpdateAlertFailed, msg))
                }
                log.error(.update, "Mole update check failed", detail: msg)
            }
        }
    }

    public func installMoleUpdate(force: Bool = false) async {
        engineUpdateState = .installing
        do {
            let res = try await EngineUpdater.install(force: force)
            await refreshEngine()
            switch res {
            case .installed(let version, _):
                engineUpdateState = .installed(version)
                log.info(.update, "Mole updated from GitHub", detail: version)
            case .upToDate(let version):
                engineUpdateState = .upToDate(version)
            case .updateAvailable(_, let latest, _):
                engineUpdateState = .available(latest: latest)
            }
        } catch {
            let msg = (error as? EngineError).map {
                switch $0 {
                case .failed(_, let m): return m
                default: return "\($0)"
                }
            } ?? error.localizedDescription
            engineUpdateState = .failed(msg)
            log.error(.update, "Mole update installation failed", detail: msg)
        }
    }

    public func checkAppUpdate(interactive: Bool = false) async {
        guard appUpdateUIState != .checking else { return }
        appUpdateUIState = .checking
        guard let repo = AppUpdater.configuredRepository() else {
            appUpdateUIState = .unconfigured
            let msg = L(.appUpdateAlertUnconfigured)
            if interactive {
                updateAlertMessage = msg
                showToast(msg)
                alertItem = AlertItem(
                    title: L(.menuCheckAppUpdates),
                    message: msg,
                    actionTitle: L(.buttonOK),
                    action: {}
                )
            }
            return
        }
        do {
            let result = try await AppUpdater.check(repository: repo)
            appUpdateState = result
            switch result {
            case .upToDate(let v):
                appUpdateUIState = .upToDate(v)
                if interactive {
                    let msg = LF(.appUpdateAlertUpToDate, v)
                    updateAlertMessage = msg
                    showToast(msg)
                    alertItem = AlertItem(
                        title: L(.menuCheckAppUpdates),
                        message: msg,
                        actionTitle: L(.buttonOK),
                        action: {}
                    )
                }
            case .updateAvailable(_, let release):
                appUpdateUIState = .available(latest: release)
                if interactive {
                    let msg = LF(.appUpdateAlertAvailable, release.version)
                    updateAlertMessage = msg
                    showToast(msg)
                    alertItem = AlertItem(
                        title: L(.menuCheckAppUpdates),
                        message: msg,
                        actionTitle: L(.appUpdateDownload),
                        action: { [weak self] in
                            Task { @MainActor in
                                self?.openAppDownload()
                            }
                        },
                        cancelTitle: L(.buttonCancel),
                        cancelAction: {}
                    )
                }
            case .noReleases(let r):
                appUpdateUIState = .noReleases(repo: r)
                let msg = L(.appUpdateNoReleases)
                if interactive {
                    updateAlertMessage = msg
                    showToast(msg)
                    alertItem = AlertItem(
                        title: L(.menuCheckAppUpdates),
                        message: msg,
                        actionTitle: L(.buttonOK),
                        action: {}
                    )
                }
                log.warning(.update, "Curatare update check: no public release found on GitHub yet", detail: r)
            case .unconfigured:
                appUpdateUIState = .unconfigured
                let msg = L(.appUpdateAlertUnconfigured)
                if interactive {
                    updateAlertMessage = msg
                    showToast(msg)
                    alertItem = AlertItem(
                        title: L(.menuCheckAppUpdates),
                        message: msg,
                        actionTitle: L(.buttonOK),
                        action: {}
                    )
                }
            }
        } catch {
            let msg = error.localizedDescription
            appUpdateUIState = .failed(msg)
            if interactive {
                let alertMsg = LF(.appUpdateAlertFailed, msg)
                updateAlertMessage = alertMsg
                showToast(alertMsg)
                alertItem = AlertItem(
                    title: L(.menuCheckAppUpdates),
                    message: alertMsg,
                    actionTitle: L(.buttonOK),
                    action: {}
                )
            }
            log.warning(.update, "Curatare update check failed: \(AppLog.describe(error).kind)", detail: msg)
        }
    }

    public func openAppDownload() {
        guard case .available(let release) = appUpdateUIState else {
            NSWorkspace.shared.open(AppLinks.repository.appendingPathComponent("releases"))
            return
        }
        NSWorkspace.shared.open(release.dmgURL ?? release.htmlURL)
    }

    public func presentPendingConsentIfIdle() {
        guard consentPending, !isBusy, alertItem == nil, pendingTrashConfirmation == nil else { return }
        consentPending = false
        askUpdateConsent()
    }

    public func askUpdateConsent() {
        alertItem = AlertItem(
            title: L(.consentTitle),
            message: L(.consentMessage),
            actionTitle: L(.consentAllow),
            action: { [weak self] in
                Task { @MainActor in
                    self?.respondToUpdateConsent(true)
                }
            },
            cancelTitle: L(.consentDeny),
            cancelAction: { [weak self] in
                Task { @MainActor in
                    self?.respondToUpdateConsent(false)
                }
            }
        )
    }

    public func respondToUpdateConsent(_ allow: Bool) {
        settings.updateConsentAsked = true
        settings.checkUpdatesAtLaunch = allow
        guard allow else { return }
        Task {
            await checkMoleUpdate(interactive: false)
            await checkAppUpdate(interactive: false)
        }
    }

    // MARK: - 1. Library Denetimi (A–E)

    public var filteredAuditFindings: [LibraryFinding] {
        guard let report = auditReport else { return [] }
        let byGroup = selectedAuditGroup.map { report.findings(for: $0) } ?? report.findings
        let q = auditSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return byGroup }
        return byGroup.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.matchedIdentifier.lowercased().contains(q) ||
            $0.librarySubfolder.lowercased().contains(q) ||
            $0.explanation.lowercased().contains(q)
        }
    }

    public func toggleAuditFindingSelection(id: String) {
        guard let report = auditReport else { return }
        var updated = report.findings
        if let idx = updated.firstIndex(where: { $0.id == id }) {
            updated[idx].isSelected.toggle()
            auditReport = LibraryAuditReport(
                scannedAt: report.scannedAt,
                installedCount: report.installedCount,
                findings: updated,
                orphanedReceipts: report.orphanedReceipts,
                sudoCommand: report.sudoCommand
            )
        }
    }

    public func setAllAuditFindingsSelected(_ selected: Bool) {
        guard let report = auditReport else { return }
        let visibleIDs = Set(filteredAuditFindings.map(\.id))
        let updated = report.findings.map { item -> LibraryFinding in
            var copy = item
            if visibleIDs.contains(item.id) && !item.requiresSudo {
                copy.isSelected = selected
            }
            return copy
        }
        auditReport = LibraryAuditReport(
            scannedAt: report.scannedAt,
            installedCount: report.installedCount,
            findings: updated,
            orphanedReceipts: report.orphanedReceipts,
            sudoCommand: report.sudoCommand
        )
    }

    public func runLibraryAudit() async {
        let scanner = libraryScanner
        let whitelist = settings.customWhitelistPaths
        await performCancellableOperation(
            inline: true,
            operation: { token in
                scanner.scanAll(customWhitelist: whitelist, isCancelled: { token.isCancelled })
            },
            onComplete: { report in
                self.auditReport = report
                self.log.info(.audit, "Library audit completed: \(report.findings.count) findings (\(DiskSpace.formatBytes(report.totalReclaimableBytes)))")
            }
        )
    }

    public func moveSelectedAuditFindingsToDatedTrash() {
        guard let report = auditReport else { return }
        let selected = report.findings.filter { $0.isSelected && !$0.requiresSudo }
        guard !selected.isEmpty else { return }

        let candidates = selected.map { f in
            DatedTrashMoveCandidate(
                url: f.url,
                category: "LibraryAudit:Group\(f.group.rawValue):\(f.librarySubfolder)",
                bundleID: f.matchedIdentifier,
                precomputedSize: f.sizeBytes
            )
        }

        do {
            let protection = ProtectionRules(
                userWhitelistPatterns: settings.customWhitelistPaths,
                allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps
            )
            let manifest = try trashService.moveToDatedTrash(
                candidates: candidates,
                title: "Library Audit (Groups A–E)",
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            let movedPaths = Set(manifest.items.map(\.originalPath))
            let remaining = report.findings.filter { !movedPaths.contains($0.url.path) }
            auditReport = LibraryAuditReport(
                scannedAt: Date(),
                installedCount: report.installedCount,
                findings: remaining,
                orphanedReceipts: report.orphanedReceipts,
                sudoCommand: LibraryScanner.generateSudoCommand(for: remaining, orphanedReceipts: report.orphanedReceipts)
            )
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "Moved \(manifest.items.count) Library items to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    public func requestMoveAuditFindingsToDatedTrash() {
        guard let report = auditReport else { return }
        let selected = report.findings.filter { $0.isSelected && !$0.requiresSudo }
        guard !selected.isEmpty else { return }
        let total = selected.map(\.sizeBytes).saturatingSum()
        if settings.confirmBeforeTrashMove {
            pendingTrashConfirmation = .auditFindings(count: selected.count, bytes: total)
        } else {
            moveSelectedAuditFindingsToDatedTrash()
        }
    }

    // MARK: - 2. Uygulama Kaldırıcı

    public var filteredBundles: [InstalledBundle] {
        var byKind = installedBundles.filter { $0.kind == selectedUninstallerKind }
        if !settings.showProtectedApps {
            byKind = byKind.filter { !$0.isProtected }
        }
        let q = uninstallerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return byKind }
        return byKind.filter {
            $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q) || $0.url.path.lowercased().contains(q)
        }
    }

    public var selectedBundle: InstalledBundle? {
        guard let id = selectedBundleID else { return nil }
        return installedBundles.first { $0.id == id }
    }

    public func scanUninstallerBundles() async {
        let uninstaller = appUninstaller
        let whitelist = settings.customWhitelistPaths
        let allowProtected = settings.allowUninstallingProtectedApps
        await performCancellableOperation(
            inline: true,
            operation: { token in
                let protection = ProtectionRules(
                    userWhitelistPatterns: whitelist,
                    allowUninstallingProtectedApps: allowProtected
                )
                // Liste paket boyutunu göstermez; boyut, seçilen paket incelenirken `discoverAssociatedFiles`
                // içinde hesaplanır. Tüm paketleri baştan gezmek (Xcode ~10 GB) listeyi ~30 sn geciktiriyordu.
                return uninstaller.scanInstalledBundles(
                    protectionRules: protection,
                    computeBundleSizes: false,
                    isCancelled: { token.isCancelled }
                )
            },
            onComplete: { bundles in
                self.installedBundles = bundles
                self.hasScannedUninstaller = true
                if let id = self.selectedBundleID, let existing = self.installedBundles.first(where: { $0.id == id }) {
                    self.selectBundle(existing)
                } else if let first = self.filteredBundles.first {
                    self.selectBundle(first)
                }
            }
        )
    }

    public func selectBundle(_ bundle: InstalledBundle) {
        selectedBundleID = bundle.id
        inspectingBundle = bundle
        isInspectingBundleLoading = true
        associatedFiles = []

        inspectionTask?.cancel()
        let uninstaller = appUninstaller
        let protection = ProtectionRules(
            userWhitelistPatterns: settings.customWhitelistPaths,
            allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps
        )
        inspectionTask = Task { @MainActor [weak self] in
            let files = await Task.detached(priority: .userInitiated) {
                uninstaller.discoverAssociatedFiles(
                    for: bundle,
                    includeBundleItself: true,
                    protectionRules: protection,
                    isCancelled: { Task.isCancelled }
                )
            }.value

            guard !Task.isCancelled, let self, self.inspectingBundle?.id == bundle.id else { return }
            self.associatedFiles = files
            self.isInspectingBundleLoading = false
        }
    }

    public func closeInspection() {
        inspectionTask?.cancel()
        inspectionTask = nil
        isInspectingBundleLoading = false
        if let droppedID = lastDroppedBundleID {
            installedBundles.removeAll { $0.id == droppedID }
            lastDroppedBundleID = nil
        }
        inspectingBundle = nil
        selectedBundleID = nil
        associatedFiles = []
    }

    public func handleDroppedURLs(_ urls: [URL]) {
        guard let first = urls.first else { return }
        selectedSection = .uninstaller
        let protection = ProtectionRules(
            userWhitelistPatterns: settings.customWhitelistPaths,
            allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps
        )
        let ext = first.pathExtension.lowercased()
        let kind: BundleKind = (ext == "wdgt" || ext == "appex") ? .widget : (ext == "app" ? .application : .plugin)
        guard let inspected = appUninstaller.inspectBundle(at: first, kind: kind, protectionRules: protection) else { return }
        if !installedBundles.contains(where: { $0.id == inspected.id }) {
            installedBundles.insert(inspected, at: 0)
            lastDroppedBundleID = inspected.id
        }
        selectedUninstallerKind = inspected.kind
        selectBundle(inspected)
        log.info(.uninstall, "Loaded bundle into uninstaller", detail: inspected.url.path)
    }

    public func toggleAssociatedFileSelection(id: String) {
        if let idx = associatedFiles.firstIndex(where: { $0.id == id }) {
            associatedFiles[idx].isSelected.toggle()
        }
    }

    public func requestUninstallSelectedBundleToDatedTrash() {
        guard let bundle = inspectingBundle ?? selectedBundle, !bundle.isProtected else { return }
        let selected = associatedFiles.filter { $0.isSelected && !$0.requiresSudo }
        guard !selected.isEmpty else { return }
        let total = selected.map(\.sizeBytes).saturatingSum()
        if settings.confirmBeforeTrashMove {
            pendingTrashConfirmation = .uninstall(bundle: bundle, count: selected.count, bytes: total)
        } else {
            uninstallSelectedBundleToDatedTrash()
        }
    }

    public func uninstallSelectedBundleToDatedTrash() {
        guard let bundle = inspectingBundle ?? selectedBundle, !bundle.isProtected else { return }
        if settings.protectRunningApps && bundle.isRunning {
            presentError(DatedTrashError.processRunning(name: bundle.name, path: bundle.url.path))
            return
        }
        do {
            let protection = ProtectionRules(
                userWhitelistPatterns: settings.customWhitelistPaths,
                allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps
            )
            let manifest = try appUninstaller.uninstallToDatedTrash(
                bundle: bundle,
                associatedFiles: associatedFiles,
                trashService: trashService,
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            installedBundles.removeAll { $0.id == bundle.id }
            inspectingBundle = nil
            selectedBundleID = filteredBundles.first?.id
            associatedFiles = []
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.uninstall, "Uninstalled \(bundle.name) to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    public func quitRunningApp(_ bundle: InstalledBundle) {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            ($0.bundleIdentifier?.caseInsensitiveCompare(bundle.bundleID) == .orderedSame) ||
            ($0.bundleURL?.path == bundle.url.path)
        }) {
            app.terminate()
            showToast(LF(.toastAppTerminated, bundle.name))
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await scanUninstallerBundles()
            }
        }
    }

    // MARK: - 3. Geliştirme ve Yapay Zekâ Temizliği

    public func scanDevAndAI() async {
        let scanners = extendedScanners
        let currentWorkspace = Bundle.main.bundleURL.deletingLastPathComponent().path
        await performCancellableOperation(
            inline: true,
            // Homebrew durumu (`brew cleanup --dry-run`, ~7 sn) burada taranmaz: bu sekme onu göstermez ve
            // Homebrew sekmesi ilk açılışta kendi taramasını yapar. Taranması sekmeyi ~11 sn'den ~3,5 sn'ye uzatıyordu.
            operation: { token in
                async let repos = scanners.scanGitHubBuildArtifacts(excludeRepoPath: currentWorkspace, isCancelled: { token.isCancelled })
                async let ai = scanners.scanAIFootprint(isCancelled: { token.isCancelled })
                async let ecosystems = scanners.scanLanguageEcosystemItems(isCancelled: { token.isCancelled })
                return await (repos, ai, ecosystems)
            },
            onComplete: { (r, a, e) in
                self.repoArtifacts = r
                self.aiFootprintItems = a
                self.languageEcosystemItems = e
                self.hasScannedDevAndAI = true
                self.hasScannedLanguageEcosystems = true
                self.log.info(.audit, "Dev & Project Artifacts scan completed: \(r.count) build dirs, \(a.count) AI items, \(e.count) ecosystem items")
            }
        )
    }

    public func scanLanguageEcosystems() async {
        let scanners = extendedScanners
        await performCancellableOperation(
            inline: true,
            operation: { token in
                scanners.scanLanguageEcosystemItems(isCancelled: { token.isCancelled })
            },
            onComplete: { items in
                self.languageEcosystemItems = items
                self.hasScannedLanguageEcosystems = true
                self.log.info(.audit, "Language ecosystems scan completed: \(items.count) items found")
            }
        )
    }

    public func executeHomebrewCleanup(pruneAll: Bool = true, scrub: Bool = true) async {
        guard homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.executeCleanup(pruneAll: pruneAll, scrub: scrub)
                return await scanner.scan()
            },
            onComplete: { (status: HomebrewStatus) in
                self.homebrewStatus = status
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                self.log.info(.engine, "Homebrew cleanup completed (pruneAll: \(pruneAll), scrub: \(scrub))")
            }
        )
    }

    public func executeHomebrewAutoremove() async {
        guard homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.executeAutoremove()
                return await scanner.scan()
            },
            onComplete: { (status: HomebrewStatus) in
                self.homebrewStatus = status
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                self.log.info(.engine, "Homebrew autoremove completed")
            }
        )
    }

    public func executeHomebrewServicesCleanup() async {
        guard homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.executeServicesCleanup()
                return await scanner.scan()
            },
            onComplete: { (status: HomebrewStatus) in
                self.homebrewStatus = status
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                self.log.info(.engine, "Homebrew services cleanup completed")
            }
        )
    }

    // MARK: - Homebrew Paket Yöneticisi & Master-Detail

    public var selectedHomebrewPackage: HomebrewPackage? {
        if let id = selectedHomebrewPackageID {
            return homebrewPackages.first { $0.id == id }
        }
        return filteredHomebrewPackages.first
    }

    public var filteredHomebrewPackages: [HomebrewPackage] {
        var list = homebrewPackages
        switch homebrewPackageFilter {
        case .all:
            break
        case .formulae:
            list = list.filter { $0.kind == .formula }
        case .casks:
            list = list.filter { $0.kind == .cask }
        case .orphans:
            list = list.filter { $0.isDependency }
        }

        if !homebrewPackageSearchText.isEmpty {
            let query = homebrewPackageSearchText.trimmingCharacters(in: .whitespaces).lowercased()
            list = list.filter {
                $0.name.lowercased().contains(query) ||
                $0.id.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.version.lowercased().contains(query)
            }
        }
        return list
    }

    public var selectedHomebrewPackagesCount: Int {
        homebrewPackages.filter(\.isSelected).count
    }

    public var selectedHomebrewPackagesTotalBytes: Int64 {
        homebrewPackages.filter(\.isSelected).map(\.sizeBytes).reduce(0, +)
    }

    public func selectHomebrewPackage(_ package: HomebrewPackage) {
        selectedHomebrewPackageID = package.id
    }

    public func toggleSelectAllHomebrewPackages() {
        let allSelected = filteredHomebrewPackages.allSatisfy(\.isSelected)
        let filteredIDs = Set(filteredHomebrewPackages.map(\.id))
        for i in homebrewPackages.indices {
            if filteredIDs.contains(homebrewPackages[i].id) {
                homebrewPackages[i].isSelected = !allSelected
            }
        }
    }

    public func scanHomebrewStudio() async {
        let scanner = HomebrewScanner()
        guard scanner.brewPath != nil else {
            self.homebrewStatus = .notInstalled
            self.homebrewPackages = []
            self.hasScannedHomebrew = true
            return
        }

        await performCancellableOperation(
            inline: true,
            operation: { token in
                async let pkgsTask = scanner.scanPackages(isCancelled: { token.isCancelled })
                async let statusTask = scanner.scan(isCancelled: { token.isCancelled })
                let (packages, status) = await (pkgsTask, statusTask)
                return (status, packages)
            },
            onComplete: { (res: (HomebrewStatus, [HomebrewPackage])) in
                self.homebrewStatus = res.0
                self.homebrewPackages = res.1
                self.hasScannedHomebrew = true
                if self.selectedHomebrewPackageID == nil || !res.1.contains(where: { $0.id == self.selectedHomebrewPackageID }) {
                    self.selectedHomebrewPackageID = res.1.first?.id
                }
                self.log.info(.audit, "Homebrew studio scanned: installed=\(res.0.isInstalled), \(res.1.count) packages")
            }
        )
    }

    public func scanHomebrewPackages() async {
        await scanHomebrewStudio()
    }

    public func uninstallHomebrewPackage(_ package: HomebrewPackage, zap: Bool = false) async {
        guard homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.uninstallPackage(id: package.id, isCask: package.kind == .cask, zap: zap)
                async let remainingTask = scanner.scanPackages()
                async let statusTask = scanner.scan()
                let (remaining, status) = await (remainingTask, statusTask)
                return (remaining, status)
            },
            onComplete: { (res: ([HomebrewPackage], HomebrewStatus)) in
                self.homebrewPackages = res.0
                self.homebrewStatus = res.1
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                if self.selectedHomebrewPackageID == package.id {
                    self.selectedHomebrewPackageID = self.homebrewPackages.first?.id
                }
                self.log.info(.uninstall, "Uninstalled Homebrew package: \(package.id)")
            }
        )
    }

    public func uninstallSelectedHomebrewPackages() async {
        let selected = homebrewPackages.filter(\.isSelected)
        guard !selected.isEmpty, homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.uninstallPackages(packages: selected, zapCasks: self.homebrewZapCasks)
                async let remainingTask = scanner.scanPackages()
                async let statusTask = scanner.scan()
                let (remaining, status) = await (remainingTask, statusTask)
                return (remaining, status)
            },
            onComplete: { (res: ([HomebrewPackage], HomebrewStatus)) in
                self.homebrewPackages = res.0
                self.homebrewStatus = res.1
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                self.selectedHomebrewPackageID = self.homebrewPackages.first?.id
                self.log.info(.uninstall, "Uninstalled \(selected.count) selected Homebrew packages")
            }
        )
    }

    public func moveSelectedDevAndAIToDatedTrash() {
        var candidates: [DatedTrashMoveCandidate] = []
        for repo in repoArtifacts where repo.isSelected && !repo.containsTrackedFiles {
            candidates.append(DatedTrashMoveCandidate(
                url: repo.artifactURL,
                category: "GitHubBuild:\(repo.repoName)",
                precomputedSize: repo.sizeBytes
            ))
        }
        for ai in aiFootprintItems where ai.isSelected && !ai.isCloudOnly {
            if let url = ai.url {
                candidates.append(DatedTrashMoveCandidate(
                    url: url,
                    category: "AIFootprint:\(ai.kind.rawValue)",
                    precomputedSize: ai.sizeBytes
                ))
            }
        }
        for eco in languageEcosystemItems where eco.isSelected && !eco.isSystemProtected {
            candidates.append(DatedTrashMoveCandidate(
                url: eco.url,
                category: "Ecosystem:\(eco.ecosystem.rawValue):\(eco.toolName)",
                precomputedSize: eco.sizeBytes
            ))
        }
        guard !candidates.isEmpty else { return }

        do {
            let protection = ProtectionRules(
                userWhitelistPatterns: settings.customWhitelistPaths,
                allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps,
                allowDeveloperCacheCleaning: true
            )
            let manifest = try trashService.moveToDatedTrash(
                candidates: candidates,
                title: "Developer & AI Cleanup",
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            let moved = Set(manifest.items.map(\.originalPath))
            repoArtifacts.removeAll { moved.contains($0.artifactURL.path) }
            aiFootprintItems.removeAll { item in item.url.map { moved.contains($0.path) } ?? false }
            languageEcosystemItems.removeAll { item in moved.contains(item.url.path) }
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "Moved \(manifest.items.count) Dev/AI items to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    public func toggleSelectAllDevAndAIOverview() {
        let selectableRepos = repoArtifacts.indices.filter { !repoArtifacts[$0].containsTrackedFiles }
        let selectableAIs = aiFootprintItems.indices.filter { !aiFootprintItems[$0].isCloudOnly && aiFootprintItems[$0].url != nil }
        guard !selectableRepos.isEmpty || !selectableAIs.isEmpty else { return }

        let allSelected = selectableRepos.allSatisfy { repoArtifacts[$0].isSelected }
            && selectableAIs.allSatisfy { aiFootprintItems[$0].isSelected }
        let target = !allSelected
        for i in selectableRepos {
            repoArtifacts[i].isSelected = target
        }
        for i in selectableAIs {
            aiFootprintItems[i].isSelected = target
        }
    }

    public func requestMoveDevAndAIToDatedTrash() {
        var count = 0
        var bytes: Int64 = 0
        for repo in repoArtifacts where repo.isSelected && !repo.containsTrackedFiles {
            count += 1
            bytes = bytes.saturatingAdding(repo.sizeBytes)
        }
        for ai in aiFootprintItems where ai.isSelected && !ai.isCloudOnly {
            count += 1
            bytes = bytes.saturatingAdding(ai.sizeBytes)
        }
        for eco in languageEcosystemItems where eco.isSelected && !eco.isSystemProtected {
            count += 1
            bytes = bytes.saturatingAdding(eco.sizeBytes)
        }
        guard count > 0 else { return }
        if settings.confirmBeforeTrashMove {
            pendingTrashConfirmation = .devAI(count: count, bytes: bytes)
        } else {
            moveSelectedDevAndAIToDatedTrash()
        }
    }

    public func executePendingTrashMove() {
        guard let pending = pendingTrashConfirmation else { return }
        pendingTrashConfirmation = nil
        switch pending {
        case .auditFindings:
            moveSelectedAuditFindingsToDatedTrash()
        case .uninstall:
            uninstallSelectedBundleToDatedTrash()
        case .devAI:
            moveSelectedDevAndAIToDatedTrash()
        }
    }

    public func cancelPendingTrashMove() {
        pendingTrashConfirmation = nil
    }

    public func confirmationMessage(for pending: PendingTrashConfirmation) -> String {
        switch pending {
        case .auditFindings(let count, let bytes):
            return LF(.confirmTrashMessage, Int64(count), DiskSpace.formatBytes(bytes))
        case .uninstall(let bundle, let count, let bytes):
            return LF(.confirmUninstallMessage, bundle.name, Int64(count), DiskSpace.formatBytes(bytes))
        case .devAI(let count, let bytes):
            return LF(.confirmTrashMessage, Int64(count), DiskSpace.formatBytes(bytes))
        }
    }

    // MARK: - 4. Tarayıcı, Önbellekler ve Time Machine

    public var filteredHeavyCaches: [HeavyCacheItem] {
        heavyCacheItems.filter { item in
            if selectedCacheFilterGroup != .all && item.filterGroup != selectedCacheFilterGroup {
                return false
            }
            if let cat = selectedCacheCategory, item.category != cat {
                return false
            }
            return true
        }
    }

    public func scanBrowserAndCaches() async {
        let scanners = extendedScanners
        await performCancellableOperation(
            inline: true,
            operation: { token in
                let caches = scanners.scanHeavyCachesAndInstallers(isCancelled: { token.isCancelled })
                guard !token.isCancelled else { return ([HeavyCacheItem](), [TimeMachineSnapshot]()) }
                let snapshots = await scanners.listTimeMachineSnapshots()
                return (caches, snapshots)
            },
            onComplete: { (caches, snapshots) in
                self.heavyCacheItems = caches
                self.timeMachineSnapshots = snapshots
            }
        )
    }

    public func toggleSelectAllHeavyCaches() {
        let items = filteredHeavyCaches
        guard !items.isEmpty else { return }
        let allSelected = items.allSatisfy(\.isSelected)
        let target = !allSelected
        let itemIDs = Set(items.map(\.id))
        for i in heavyCacheItems.indices where itemIDs.contains(heavyCacheItems[i].id) {
            heavyCacheItems[i].isSelected = target
        }
    }

    public func moveSelectedCachesToDatedTrash() {
        let selected = filteredHeavyCaches.filter(\.isSelected)
        guard !selected.isEmpty else { return }
        let activeGradle = extendedScanners.discoverActiveGradleVersions()
        let protection = ProtectionRules(
            activeGradleVersions: activeGradle,
            userWhitelistPatterns: settings.customWhitelistPaths,
            allowDeveloperCacheCleaning: true,
            allowUserCacheCleaning: true
        )
        let candidates = selected.map { item in
            DatedTrashMoveCandidate(
                url: item.url,
                category: "HeavyCache:\(item.category.rawValue)",
                processName: item.processToVerify,
                precomputedSize: item.sizeBytes
            )
        }

        do {
            let manifest = try trashService.moveToDatedTrash(
                candidates: candidates,
                title: "Browser & Heavy Caches Cleanup",
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            let moved = Set(manifest.items.map(\.originalPath))
            heavyCacheItems.removeAll { moved.contains($0.url.path) }
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "Moved \(manifest.items.count) cache items to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    public func thinTimeMachineSnapshots() async {
        let scanners = extendedScanners
        await performCancellableOperation(
            operation: { token in
                _ = try? await scanners.thinTimeMachineSnapshots()
                guard !token.isCancelled else { return [TimeMachineSnapshot]() }
                return await scanners.listTimeMachineSnapshots()
            },
            onComplete: { snapshots in
                self.timeMachineSnapshots = snapshots
            }
        )
    }

    // MARK: - 5. Disk Analizi (`analyze-go`)

    public func analyzeFolder(_ url: URL? = nil) async {
        let target = url ?? currentAnalyzedURL
        currentAnalyzedURL = target
        let bridge = MoleBridge(engine: engineInfo)
        await performCancellableOperation(
            inline: true,
            operation: { token in
                await bridge.analyzeDirectory(at: target, isCancelled: { token.isCancelled })
            },
            onComplete: { analysis in
                self.diskAnalysis = analysis
            }
        )
    }

    public func navigateUpDiskAnalyzer() async {
        let parent = currentAnalyzedURL.deletingLastPathComponent()
        guard parent.path != currentAnalyzedURL.path else { return }
        await analyzeFolder(parent)
    }

    // MARK: - 6. Sistem Durumu, Bakım ve İnce Ayarlar (`status-go`, `optimize` & `SystemTweaks`)

    public func loadSystemCenterInfo(force: Bool = false) async {
        guard force || !hasLoadedSystemCenter else { return }
        hasLoadedSystemCenter = true
        async let hw = SystemCenterCollector.fetchHardware()
        async let mem = SystemCenterCollector.fetchMemory()
        async let vols = SystemCenterCollector.fetchVolumes()
        async let os = SystemCenterCollector.fetchOSAndIdentity()
        let (h, m, v, o) = await (hw, mem, vols, os)
        self.systemCenterHardware = h
        self.systemCenterMemory = m
        self.systemCenterVolumes = v
        self.systemCenterOS = o
    }

    public func generateSystemProfile() async {
        isGeneratingProfile = true
        defer { isGeneratingProfile = false }
        guard let text = await SystemCenterCollector.generateProfile(kind: selectedProfileKind, format: selectedProfileFormat) else {
            self.systemCenterProfileText = ""
            activeErrorMessage = L(.sysCenterProfileFailed)
            return
        }
        self.systemCenterProfileText = text
    }

    public func saveSystemProfile() {
        guard !systemCenterProfileText.isEmpty else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        let ext = selectedProfileFormat.rawValue
        panel.nameFieldStringValue = "\(L(.sysCenterProfileFileName))-\(selectedProfileKind.rawValue).\(ext)"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try systemCenterProfileText.write(to: url, atomically: true, encoding: .utf8)
                showToast(LF(.sysCenterProfileSaved, url.lastPathComponent))
            } catch {
                activeErrorMessage = LF(.sysCenterProfileSaveFailed, error.localizedDescription)
            }
        }
    }

    public func revealSwapDirectory() {
        let swapURL = URL(fileURLWithPath: "/private/var/vm")
        NSWorkspace.shared.activateFileViewerSelecting([swapURL])
    }

    /// Yalnızca `status-go` canlı ölçümleri (CPU, bellek, disk, sağlık puanı). Açılışta pencere alt başlığı ve
    /// menü çubuğu paneli için, Canlı Durum panosu açıkken de periyodik olarak çağrılır.
    public func refreshLiveMetrics() async {
        let bridge = MoleBridge(engine: engineInfo)
        if let status = try? await bridge.fetchSystemStatus() {
            systemStatus = status
        }
    }

    /// Sistem Durumu sekmesinin tüm verisi: canlı ölçümler, güvenlik durumu, ince ayarlar ve Sistem Merkezi.
    /// Aynı anda ikinci bir çağrı gelirse süren yenilemeye bırakılır (çift `system_profiler` turu olmaz).
    public func refreshSystemStatus() async {
        guard !isLoadingSystemStatus else { return }
        isLoadingSystemStatus = true
        defer {
            isLoadingSystemStatus = false
            hasLoadedSystemStatus = true
        }
        await refreshLiveMetrics()
        let sec = await MoleBridge.fetchSecurityStatus()
        self.securityStatus = sec
        refreshSystemTweaks()
        await loadSystemCenterInfo(force: true)
    }

    /// Sekme ilk açıldığında bir kez yükler; sonraki ziyaretlerde önbellekteki veri gösterilir (Yenile ile tazelenir).
    public func loadSystemStatusIfNeeded() async {
        guard !hasLoadedSystemStatus else { return }
        await refreshSystemStatus()
    }

    public func purgeMemory() async {
        let res = await MoleBridge.purgeInactiveMemory()
        switch res {
        case .success:
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(L(.toastMemoryPurged))
            log.info(.engine, "System inactive memory purged successfully")
            await refreshSystemStatus()
        case .failure(let err):
            presentError(err)
        }
    }

    public func addDockSpacer(small: Bool = false) {
        tweakManager.addDockSpacer(small: small)
        showToast(L(.toastDockSpacerAdded))
        log.info(.engine, "Added spacer to Dock (small: \(small))")
    }

    public func removeDockSpacers() {
        tweakManager.removeDockSpacers()
        showToast(L(.toastDockSpacersRemoved))
        log.info(.engine, "Removed all spacers from Dock")
    }

    public func launchSystemUtility(_ util: HiddenSystemUtility) {
        guard let url = util.resolvedURL else { return }
        NSWorkspace.shared.open(url)
        showToast(LF(.toastLaunchedUtility, L(util.titleKey)))
        log.info(.engine, "Launched hidden system utility: \(url.path)")
    }

    public func refreshSystemTweaks() {
        systemTweaks = tweakManager.loadAllTweaks()
        systemChoiceTweaks = tweakManager.loadChoiceTweaks()
        screenshotFormat = tweakManager.screenshotFormat()
        screenshotNamePrefix = tweakManager.screenshotNamePrefix()
    }

    public func applyChoiceTweak(id: String, optionID: String) {
        guard let updated = tweakManager.applyChoiceTweak(id: id, optionID: optionID) else { return }
        if let idx = systemChoiceTweaks.firstIndex(where: { $0.id == id }) {
            systemChoiceTweaks[idx] = updated
        }
        showToast(LF(.toastTweakApplied, L(updated.titleKey)))
        log.info(.engine, "System tweak applied: \(id) = \(optionID)")
    }

    public func setScreenshotNamePrefix(_ raw: String) {
        screenshotNamePrefix = tweakManager.setScreenshotNamePrefix(raw)
        showToast(LF(.toastTweakApplied, L(.tweakScreenshotNameTitle)))
        log.info(.engine, "Screenshot name prefix updated")
    }

    public func setScreenshotFormat(_ format: ScreenshotFormat) {
        tweakManager.setScreenshotFormat(format)
        screenshotFormat = format
        showToast(LF(.toastTweakApplied, "\(L(.tweakScreenshotFormatTitle)) (\(format.displayName))"))
        log.info(.engine, "Screenshot format set to \(format.rawValue)")
    }

    public func applySystemTweak(id: String, enabled: Bool) {
        guard let updated = tweakManager.applyTweak(id: id, enabled: enabled) else { return }
        if let idx = systemTweaks.firstIndex(where: { $0.id == id }) {
            systemTweaks[idx] = updated
        }
        let title = L(updated.titleKey)
        showToast(LF(.toastTweakApplied, title))
        log.info(.engine, "System tweak applied: \(id) = \(enabled)")
    }

    public func computeChecksum(for url: URL) {
        isCalculatingChecksum = true
        Task.detached {
            let res = try? FileChecksumCalculator.computeHashes(for: url)
            await MainActor.run {
                self.checksumResult = res
                self.isCalculatingChecksum = false
            }
        }
    }

    public func resetAllSystemTweaks() {
        systemTweaks = tweakManager.restoreAllToDefaults()
        systemChoiceTweaks = tweakManager.loadChoiceTweaks()
        screenshotFormat = tweakManager.screenshotFormat()
        screenshotNamePrefix = tweakManager.screenshotNamePrefix()
        showToast(L(.toastTweaksReset))
        log.info(.engine, "All system tweaks reset to defaults")
    }

    public func runSelectedOptimizations() async {
        let bridge = MoleBridge(engine: engineInfo)
        let tasks = optimizationTasks
        await performCancellableOperation(
            operation: { _ in
                await bridge.runOptimizationTasks(tasks)
            },
            onComplete: { completed in
                for item in completed {
                    self.log.info(.engine, item)
                }
                self.showToast(self.LF(.toastOptimizationDone, Int64(completed.count)))
                await self.refreshSystemStatus()
            }
        )
    }

    // MARK: - 7. Tarihli Çöp Turları ve Geri Yükleme

    public func refreshTrashBatches() {
        trashBatches = trashService.listBatches()
    }

    public func restoreTrashBatch(_ batch: TrashBatchManifest) {
        do {
            let count = try trashService.restoreBatch(id: batch.id, overwriteExisting: true)
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playRestoreSound()
            }
            showToast(LF(.toastRestoredBatch, Int64(count)))
            log.info(.trash, "Restored batch \(batch.id) (\(count) items)")
        } catch {
            presentError(error)
        }
    }

    public func purgeTrashBatch(_ batch: TrashBatchManifest) {
        do {
            _ = try trashService.purgeBatch(id: batch.id)
            trashBatches = trashService.listBatches()
            if selectedTrashBatchID == batch.id {
                selectedTrashBatchID = filteredTrashBatches.first?.id
            }
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastBatchPurged, batch.id))
            log.info(.trash, "Permanently purged trash batch \(batch.id)")
        } catch {
            presentError(error)
        }
    }

    public func purgeAllTrashBatches() {
        do {
            let result = try trashService.purgeAllBatches()
            trashBatches = trashService.listBatches()
            selectedTrashBatchID = nil
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastAllBatchesPurged, Int64(result.purgedCount), DiskSpace.formatBytes(result.totalBytes)))
            log.info(.trash, "Permanently purged all \(result.purgedCount) trash batches (\(result.totalBytes) bytes)")
        } catch {
            presentError(error)
        }
    }

    public func toggleTrashedItemSelection(id: UUID) {
        if selectedTrashedItemIDs.contains(id) {
            selectedTrashedItemIDs.remove(id)
        } else {
            selectedTrashedItemIDs.insert(id)
        }
    }

    public func toggleSelectAllTrashedItems(in batch: TrashBatchManifest) {
        let allIDs = Set(batch.items.map(\.id))
        if selectedTrashedItemIDs.isSuperset(of: allIDs) && !allIDs.isEmpty {
            selectedTrashedItemIDs.removeAll()
        } else {
            selectedTrashedItemIDs = allIDs
        }
    }

    public func purgeTrashedItem(batch: TrashBatchManifest, item: TrashedItemRecord) {
        do {
            let updated = try trashService.purgeTrashedItem(batchID: batch.id, itemID: item.id)
            trashBatches = trashService.listBatches()
            selectedTrashedItemIDs.remove(item.id)
            if updated == nil {
                if selectedTrashBatchID == batch.id {
                    selectedTrashBatchID = filteredTrashBatches.first?.id
                }
            }
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(L(.toastItemPurged))
            log.info(.trash, "Permanently purged trashed item \(item.trashedRelativePath) from batch \(batch.id)")
        } catch {
            presentError(error)
        }
    }

    public func purgeSelectedTrashedItems(batch: TrashBatchManifest) {
        guard !selectedTrashedItemIDs.isEmpty else { return }
        let count = Int64(selectedTrashedItemIDs.count)
        do {
            let updated = try trashService.purgeTrashedItems(batchID: batch.id, itemIDs: selectedTrashedItemIDs)
            trashBatches = trashService.listBatches()
            selectedTrashedItemIDs.removeAll()
            if updated == nil {
                if selectedTrashBatchID == batch.id {
                    selectedTrashBatchID = filteredTrashBatches.first?.id
                }
            }
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastSelectedItemsPurged, count))
            log.info(.trash, "Permanently purged \(count) trashed items from batch \(batch.id)")
        } catch {
            presentError(error)
        }
    }

    public func copyToClipboard(_ string: String, label: String? = nil) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        let lastComp = string.split(separator: "/").last.map(String.init) ?? string
        showToast(label ?? "\(L(.buttonCopied)): \(lastComp)")
    }

    // MARK: - Yardımcılar

    public func chooseBundleForUninstaller() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if panel.runModal() == .OK, let url = panel.url {
            handleDroppedURLs([url])
        }
    }

    public func performShortcut(_ action: ShortcutAction) {
        switch action {
        case .scanAudit:
            selectedSection = .libraryAudit
            Task { await runLibraryAudit() }
        case .uninstaller:
            selectedSection = .uninstaller
        case .homebrew:
            selectedSection = .homebrew
            if !hasScannedHomebrew {
                Task { await scanHomebrewStudio() }
            }
        case .devAI:
            selectedSection = .devAndAI
            Task { await scanDevAndAI() }
        case .browserCaches:
            selectedSection = .browserAndCaches
            Task { await scanBrowserAndCaches() }
        case .diskAnalyzer:
            selectedSection = .diskAnalyzer
            Task { await analyzeFolder() }
        case .systemStatus:
            selectedSection = .systemStatus
            Task { await refreshSystemStatus() }
        case .trashHistory:
            selectedSection = .trashHistory
            refreshTrashBatches()
        case .showLog:
            break
        }
    }

    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func quickLookPreview(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    public func showToast(_ text: String) {
        toastMessage = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            if self?.toastMessage == text {
                self?.toastMessage = nil
            }
        }
    }

    public func presentError(_ error: Error) {
        switch error {
        case DatedTrashError.protectedTarget(let path, let reason):
            activeErrorMessage = LF(.errorProtectedTarget, path, reason)
        case DatedTrashError.processRunning(let name, let path):
            activeErrorMessage = LF(.errorProcessRunning, name, path)
        default:
            activeErrorMessage = error.localizedDescription
        }
        log.error(.app, "Operation failed", detail: activeErrorMessage)
    }
}

// MARK: - Uygulama İkon Belleği (Zero-Lag Icon Cache)

@MainActor
public final class AppIconCache {
    public static let shared = AppIconCache()
    private var cache = NSCache<NSString, NSImage>()

    public func icon(for path: String, size: CGFloat = 28) -> NSImage {
        let key = "\(path)_\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let rawIcon = NSWorkspace.shared.icon(forFile: path)
        let icon = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            rawIcon.draw(in: rect)
            return true
        }
        cache.setObject(icon, forKey: key)
        return icon
    }
}
