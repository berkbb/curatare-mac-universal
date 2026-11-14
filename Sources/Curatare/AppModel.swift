// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

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

    @ObservationIgnored var inspectionTask: Task<Void, Never>?

    public var uninstallerSearchText: String = ""
    public var smartDeleteEvent: TrashedAppEvent?

    var trashWatcher: TrashWatcher?

    // 3. Geliştirme ve Yapay Zekâ
    public var repoArtifacts: [RepoBuildArtifact] = []

    public var aiFootprintItems: [AIFootprintItem] = []

    public var languageEcosystemItems: [LanguageEcosystemItem] = []

    public var selectedEcosystemFilter: LanguageEcosystemItem.Ecosystem? = nil

    public var homebrewStatus: HomebrewStatus = .notInstalled

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

    public var languageEcosystemOriginTab: LanguageEcosystemOriginTab = .cleanableAll

    public var hasScannedLanguageEcosystems: Bool = false

    public var hasScannedDevAndAI: Bool = false

    public var languageEcosystemFilter: LanguageEcosystemFilterKind = .all {
        didSet { settings.lastLanguageEcosystemFilter = languageEcosystemFilter }
    }

    public var languageEcosystemSearchText: String = ""
    public var selectedLanguageEcosystemItemID: String? = nil

    // 4. Tarayıcı, Önbellekler ve Time Machine
    public var heavyCacheItems: [HeavyCacheItem] = []

    public var selectedCacheCategory: HeavyCacheItem.Category? = nil

    public var selectedCacheFilterGroup: HeavyCacheItem.FilterGroup = .all

    public var timeMachineSnapshots: [TimeMachineSnapshot] = []

    // 5. Disk Analizi
    public var currentAnalyzedURL: URL

    public var diskAnalysis: MoleDiskAnalysis?

    public var diskAnalyzerSubTab: DiskAnalyzerSubTab = .usage

    // 5b. Yinelenen İndirmeler (APFS klonu olmayan aynı içerikli dosyalar)
    public let duplicateFinder = DuplicateFileFinder()

    public var duplicateScan: DuplicateScanResult?

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
    public var screenshotLocation: String?

    public var safariDevelopMenuShown: Bool = false

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

    /// Tam Disk Erişimi durumu; pencere görünüp denetlenene kadar `nil` (şerit yanıp sönmez).
    public var fullDiskAccessGranted: Bool?

    /// Kullanıcı izin şeridini "Sonra" ile kapattıysa bu oturumda yeniden gösterilmez.
    public var permissionBannerDismissed: Bool = false

    let homeDirectoryURL: URL

    /// Gerçek uygulamada açılış işleri pencere görünene kadar bekletilir (`windowDidAppear`).
    private var launchWorkPending: Bool = false

    var activeOperationID: UUID?

    var activeCancelToken: ScanCancellationToken?

    var activeCancelHandler: (() -> Void)?

    @ObservationIgnored public var dockProgress = DockProgress()

    @ObservationIgnored var dockProgressDelayTask: Task<Void, Never>?

    @ObservationIgnored public var dockProgressInlineDelay: Duration = .milliseconds(350)

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
        self.homeDirectoryURL = homeDirectoryURL
        let resolvedTrash = trashService ?? DatedTrashService(homeDirectoryURL: homeDirectoryURL)
        self.trashService = resolvedTrash
        self.libraryScanner = libraryScanner ?? LibraryScanner(homeDirectoryURL: homeDirectoryURL)
        self.extendedScanners = extendedScanners ?? ExtendedScanners(homeDirectoryURL: homeDirectoryURL)
        self.appUninstaller = appUninstaller ?? AppUninstaller(homeDirectoryURL: homeDirectoryURL)
        let resolvedTweakManager = tweakManager ?? SystemTweakManager()
        self.tweakManager = resolvedTweakManager
        self.systemStatusSubTab = resolvedSettings.lastSystemStatusSubTab
        self.systemCenterTab = resolvedSettings.lastSystemCenterTab
        self.currentAnalyzedURL = homeDirectoryURL
        self.selectedSection = resolvedSettings.lastSelectedSection
        self.uninstallerMode = resolvedSettings.uninstallerMode
        self.selectedUninstallerKind = resolvedSettings.selectedUninstallerKind
        self.devAISubTab = resolvedSettings.lastDevAISubTab
        self.homebrewPackageFilter = resolvedSettings.lastHomebrewFilter
        self.languageEcosystemFilter = resolvedSettings.lastLanguageEcosystemFilter
        self.trashHistoryFilter = resolvedSettings.lastTrashHistoryFilter
        self.homebrewZapCasks = resolvedSettings.homebrewZapCasks

        resolvedSettings.onDockProgressSettingChanged = { [weak self] in
            self?.syncDockProgress(respectInlineDelay: false)
        }

        // Gerçek uygulamada init yalnızca kendi ayarlarını okur. Başka uygulamaların tercihleri, ~/.Trash ve motor
        // pencere göründükten sonra okunur: macOS bir izin sorarsa ya da bir okuma takılırsa arayüz zaten ekrandadır.
        if startBackgroundWatchers {
            launchWorkPending = true
        } else {
            loadLocalState()
        }
    }

    /// İnce ayar tercihleri ve Tarihli Çöp turları.
    private func loadLocalState() {
        refreshSystemTweaks()
        trashBatches = trashService.listBatches()
    }

    /// Ana pencere her göründüğünde çağrılır; açılış işleri yalnızca ilk seferde, ilk kare çizildikten sonra başlar.
    public func windowDidAppear() {
        guard launchWorkPending else {
            refreshPermissionStatus()
            presentPendingConsentIfIdle()
            return
        }
        launchWorkPending = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            loadLocalState()
            refreshPermissionStatus()
            configureSmartDeleteWatcher()
            await refreshEngine()
            // Açılışta yalnızca hafif canlı ölçümler (alt başlıktaki sağlık puanı); Sistem Merkezi ve güvenlik
            // durumu Sistem Durumu sekmesi ilk açıldığında yüklenir.
            await refreshLiveMetrics()
            if !settings.updateConsentAsked {
                consentPending = true
                presentPendingConsentIfIdle()
            } else if settings.checkUpdatesAtLaunch {
                await checkMoleUpdate(interactive: false)
                await checkAppUpdate(interactive: false)
            }
        }
    }

    /// Tam Disk Erişimini yeniden denetler; uygulama öne geldiğinde de çağrılır (Sistem Ayarları'ndan dönüş).
    public func refreshPermissionStatus() {
        fullDiskAccessGranted = FullDiskAccess.isGranted(homeDirectoryURL: homeDirectoryURL)
    }

    public var showsPermissionBanner: Bool {
        fullDiskAccessGranted == false && !permissionBannerDismissed
    }

    public func L(_ key: LKey) -> String { settings.L(key) }

    /// Mole motor sürümü; motor bulunamazsa koda gömülü bir sürüm yerine çevrilmiş "bilinmiyor" metni gösterilir.
    public var engineVersionText: String { engineInfo?.version ?? L(.engineVersionUnknown) }

    public func LF(_ key: LKey, _ args: CVarArg...) -> String {
        let format = L(key)
        return String(format: format, locale: Locale(identifier: settings.resolvedLanguageCode), arguments: args)
    }

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
            diskAnalyzerSubTab = .usage
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
}
