// SPDX-License-Identifier: GPL-3.0-or-later
@testable import Curatare
import CuratareCore
import Foundation
import SwiftUI
import Testing

/// Testlerin `~/Library/Preferences` içinde hiçbir `.plist` bırakmaması için geçici klasörde `UserDefaults` oluşturur.
enum TestDefaults {
    static func make() -> (defaults: UserDefaults, cleanup: () -> Void) {
        let dir = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("curatare-defaults-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let suitePath = dir.appendingPathComponent("prefs.plist").path
        let defaults = UserDefaults(suiteName: suitePath)!
        return (defaults, {
            defaults.removePersistentDomain(forName: suitePath)
            try? FileManager.default.removeItem(at: dir)
        })
    }
}

@Suite("Curatare AppModel & View Rendering Tests")
@MainActor
struct CuratareAppTests {
    @Test("AppSettings persists in isolated UserDefaults and switches languages immediately")
    func settingsAndLanguageSwitch() {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let settings = AppSettings(defaults: defaults)
        settings.language = .tr
        #expect(settings.L(.buttonMoveToDatedTrash) == "Tarihli Çöp'e Taşı")

        settings.language = .en
        #expect(settings.L(.buttonMoveToDatedTrash) == "Move to Dated Trash")

        settings.language = .ro
        #expect(settings.L(.buttonMoveToDatedTrash) == "Mută în Coșul Datat")

        settings.addWhitelistPath("/Users/tester/KeepThis")
        #expect(settings.customWhitelistPaths.contains("/Users/tester/KeepThis"))
        settings.removeWhitelistPath("/Users/tester/KeepThis")
        #expect(settings.customWhitelistPaths.isEmpty)

        // Kaldırıcı Ayarları (Başlangıç Görünümü, Korunan Uygulamalar)
        settings.startupView = .list
        #expect(settings.startupView == .list)
        settings.startupView = .dropZone
        #expect(settings.startupView == .dropZone)

        settings.protectRunningApps = false
        #expect(settings.protectRunningApps == false)
        settings.protectRunningApps = true
        #expect(settings.protectRunningApps == true)

        settings.showProtectedApps = false
        #expect(settings.showProtectedApps == false)
        settings.showProtectedApps = true
        #expect(settings.showProtectedApps == true)

        #expect(settings.allowUninstallingProtectedApps == false)
        settings.allowUninstallingProtectedApps = true
        #expect(settings.allowUninstallingProtectedApps == true)
        settings.allowUninstallingProtectedApps = false
        #expect(settings.allowUninstallingProtectedApps == false)
    }

    @Test("Uninstaller: mode switching and protected apps filtering")
    func uninstallerModesAndProtectionFiltering() {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let settings = AppSettings(defaults: defaults)
        let model = AppModel(settings: settings, log: AppLog(directory: nil), startBackgroundWatchers: false)

        #expect(model.uninstallerMode == .dropZone)
        model.uninstallerMode = .list
        #expect(model.uninstallerMode == .list)

        // Test bundle filtering with protected apps
        let safeApp = InstalledBundle(
            kind: .application,
            name: "Safari",
            bundleID: "com.apple.Safari",
            version: "18.0",
            url: URL(fileURLWithPath: "/Applications/Safari.app"),
            bundleSizeBytes: 1024,
            isProtected: true,
            protectionReason: "System Protected",
            isRunning: false,
            isWrapperIOSApp: false
        )
        let userApp = InstalledBundle(
            kind: .application,
            name: "TestApp",
            bundleID: "com.custom.TestApp",
            version: "1.0",
            url: URL(fileURLWithPath: "/Applications/TestApp.app"),
            bundleSizeBytes: 2048,
            isProtected: false,
            protectionReason: nil,
            isRunning: false,
            isWrapperIOSApp: false
        )

        model.installedBundles = [safeApp, userApp]
        model.selectedUninstallerKind = .application

        settings.showProtectedApps = true
        #expect(model.filteredBundles.count == 2)

        settings.showProtectedApps = false
        #expect(model.filteredBundles.count == 1)
        #expect(model.filteredBundles[0].bundleID == "com.custom.TestApp")
    }

    @Test("AppModel executes audit, moves findings to dated Trash, and restores batch")
    func appModelAuditAndRestoreFlow() async throws {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("curatare-appmodel-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let fakeHome = tempRoot.appendingPathComponent("Home", isDirectory: true)
        let fakeApps = tempRoot.appendingPathComponent("Applications", isDirectory: true)
        let fakeSysLib = tempRoot.appendingPathComponent("SystemLibrary", isDirectory: true)
        let fakeGitHub = fakeHome.appendingPathComponent("Documents/GitHub", isDirectory: true)
        try fm.createDirectory(at: fakeApps, withIntermediateDirectories: true)
        try fm.createDirectory(at: fakeSysLib, withIntermediateDirectories: true)
        try fm.createDirectory(at: fakeGitHub, withIntermediateDirectories: true)

        let orphanPlist = fakeHome.appendingPathComponent("Library/Preferences/com.removedvendor.oldapp.plist")
        try fm.createDirectory(at: orphanPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("orphan-data".utf8).write(to: orphanPlist)

        let settings = AppSettings(defaults: defaults)
        let trashService = DatedTrashService(
            trashRootURL: fakeHome.appendingPathComponent(".Trash"),
            homeDirectoryURL: fakeHome,
            registryFileURL: fakeHome.appendingPathComponent("Library/Application Support/Curatare/trash-batches.json")
        )
        let scanner = LibraryScanner(
            homeDirectoryURL: fakeHome,
            systemLibraryURL: fakeSysLib,
            applicationDirectories: [fakeApps],
            githubDirectoryURL: fakeGitHub
        )
        let model = AppModel(
            settings: settings,
            log: AppLog(directory: nil),
            homeDirectoryURL: fakeHome,
            trashService: trashService,
            libraryScanner: scanner,
            startBackgroundWatchers: false
        )

        await model.runLibraryAudit()
        let report = try #require(model.auditReport)
        #expect(report.findings.count == 1)
        #expect(report.findings[0].url.resolvingSymlinksInPath() == orphanPlist.resolvingSymlinksInPath())

        model.moveSelectedAuditFindingsToDatedTrash()
        #expect(!fm.fileExists(atPath: orphanPlist.path))
        #expect(model.trashBatches.count == 1)

        let batch = model.trashBatches[0]
        model.restoreTrashBatch(batch)
        #expect(fm.fileExists(atPath: orphanPlist.path))
        #expect(model.trashBatches[0].isRestored == true)
    }

    @Test("AppModel supports immediate scan cancellation via cancelActiveOperation")
    func scanCancellationFlow() async throws {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let settings = AppSettings(defaults: defaults)
        settings.language = .tr
        let model = AppModel(settings: settings, log: AppLog(directory: nil), startBackgroundWatchers: false)

        let task = Task {
            await model.runLibraryAudit()
        }

        // isBusy true olana kadar bekle, ardından iptal tetikle
        for _ in 0..<100 {
            if model.isBusy { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        model.cancelActiveOperation()
        await task.value

        #expect(model.isBusy == false)
        #expect(model.toastMessage == "Tarama iptal edildi.")
    }

    @Test("Uninstaller list loads without walking bundle sizes; the selected bundle is sized on inspection")
    func uninstallerListSkipsBundleSizes() async throws {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("curatare-apps-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let contents = apps.appendingPathComponent("Ornek.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        _ = (["CFBundleIdentifier": "net.example.ornek", "CFBundleName": "Ornek"] as NSDictionary)
            .write(to: contents.appendingPathComponent("Info.plist"), atomically: true)
        try Data(count: 64 * 1024).write(to: contents.appendingPathComponent("Resources/payload.bin"))

        let uninstaller = AppUninstaller(homeDirectoryURL: root, applicationDirectories: [apps], pluginDirectories: [], widgetDirectories: [])
        let model = AppModel(
            settings: AppSettings(defaults: defaults),
            log: AppLog(directory: nil),
            homeDirectoryURL: root,
            appUninstaller: uninstaller,
            startBackgroundWatchers: false
        )

        await model.scanUninstallerBundles()

        #expect(model.isBusy == false)
        #expect(model.isBusyInline == false)
        #expect(model.hasScannedUninstaller)
        let bundle = try #require(model.installedBundles.first { $0.bundleID == "net.example.ornek" })
        #expect(bundle.bundleSizeBytes == 0)

        // Liste boyut hesaplamaz; seçilen paketin boyutu inceleme sırasında hesaplanır.
        for _ in 0..<200 where model.isInspectingBundleLoading {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let bundleEntry = try #require(model.associatedFiles.first { $0.kind == .appBundle })
        #expect(bundleEntry.sizeBytes >= 64 * 1024)
    }

    @Test("Dev & AI scan leaves Homebrew status to the Homebrew tab")
    func devAIScanSkipsHomebrewStatus() async throws {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let root = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("curatare-devai-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let model = AppModel(
            settings: AppSettings(defaults: defaults),
            log: AppLog(directory: nil),
            homeDirectoryURL: root,
            startBackgroundWatchers: false
        )

        await model.scanDevAndAI()

        #expect(model.hasScannedDevAndAI)
        #expect(model.isBusy == false)
        // `brew cleanup --dry-run` (~7 sn) Dev & AI taramasında çalışmaz; Homebrew sekmesi kendi taramasını yapar.
        #expect(model.homebrewStatus.isInstalled == false)
        #expect(model.hasScannedHomebrew == false)
    }

    @Test("All studio views render off-screen without crashing across tr, en, and ro")
    func renderAllViews() {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let settings = AppSettings(defaults: defaults)
        let model = AppModel(settings: settings, log: AppLog(directory: nil), startBackgroundWatchers: false)

        for lang in [AppLanguage.tr, .en, .ro] {
            settings.language = lang
            for section in StudioSection.allCases {
                model.selectedSection = section
                let host = NSHostingView(rootView: ContentView(model: model))
                host.frame = NSRect(x: 0, y: 0, width: 1024, height: 680)
                host.layoutSubtreeIfNeeded()
                #expect(host.bounds.width == 1024)
            }
            let settingsHost = NSHostingView(rootView: SettingsView(model: model))
            settingsHost.frame = NSRect(x: 0, y: 0, width: 560, height: 575)
            settingsHost.layoutSubtreeIfNeeded()

            let logHost = NSHostingView(rootView: LogView(model: model))
            logHost.frame = NSRect(x: 0, y: 0, width: 720, height: 440)
            logHost.layoutSubtreeIfNeeded()

            let aboutHost = NSHostingView(rootView: AboutView(model: model))
            aboutHost.frame = NSRect(x: 0, y: 0, width: 440, height: 320)
            aboutHost.layoutSubtreeIfNeeded()

            model.selectedSection = .devAndAI
            model.devAISubTab = .languageEcosystems
            let ecoHost = NSHostingView(rootView: LanguageEcosystemsMasterDetailView(model: model))
            ecoHost.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
            ecoHost.layoutSubtreeIfNeeded()
            #expect(ecoHost.bounds.width == 900)

            model.selectedSection = .homebrew
            let hbHost = NSHostingView(rootView: HomebrewPackagesMasterDetailView(model: model))
            hbHost.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
            hbHost.layoutSubtreeIfNeeded()
            #expect(hbHost.bounds.width == 900)

            let hbStudioHost = NSHostingView(rootView: HomebrewStudioView(model: model))
            hbStudioHost.frame = NSRect(x: 0, y: 0, width: 1024, height: 680)
            hbStudioHost.layoutSubtreeIfNeeded()
            #expect(hbStudioHost.bounds.width == 1024)

            let trashHost = NSHostingView(rootView: TrashHistoryView(model: model))
            trashHost.frame = NSRect(x: 0, y: 0, width: 1024, height: 680)
            trashHost.layoutSubtreeIfNeeded()
            #expect(trashHost.bounds.width == 1024)
        }
    }

    @Test("UI State Persistence: AppSettings persists sections, sub-tabs, filters, widths, and resetToDefaults")
    func uiStatePersistenceAndReset() {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        // Instance 1: Değişiklikleri yap
        do {
            let settings = AppSettings(defaults: defaults)
            settings.lastSelectedSection = .homebrew
            settings.uninstallerMode = .list
            settings.lastDevAISubTab = .languageEcosystems
            settings.lastHomebrewFilter = .casks
            settings.lastLanguageEcosystemFilter = .python
            settings.lastTrashHistoryFilter = .pendingRestore
            settings.homebrewZapCasks = true
            settings.selectedUninstallerKind = .plugin
            settings.masterPaneWidth = 410.0
            settings.trashMasterPaneWidth = 430.0
        }

        // Instance 2: UserDefaults'tan yeniden oku ve doğrula
        do {
            let settings = AppSettings(defaults: defaults)
            #expect(settings.lastSelectedSection == .homebrew)
            #expect(settings.uninstallerMode == .list)
            #expect(settings.lastDevAISubTab == .languageEcosystems)
            #expect(settings.lastHomebrewFilter == .casks)
            #expect(settings.lastLanguageEcosystemFilter == .python)
            #expect(settings.lastTrashHistoryFilter == .pendingRestore)
            #expect(settings.homebrewZapCasks == true)
            #expect(settings.selectedUninstallerKind == .plugin)
            #expect(settings.masterPaneWidth == 410.0)
            #expect(settings.trashMasterPaneWidth == 430.0)

            // Sıfırla ve varsayılanları doğrula
            settings.resetToDefaults()
            #expect(settings.lastSelectedSection == .home)
            #expect(settings.uninstallerMode == .dropZone)
            #expect(settings.lastDevAISubTab == .overview)
            #expect(settings.lastHomebrewFilter == .all)
            #expect(settings.lastLanguageEcosystemFilter == .all)
            #expect(settings.lastTrashHistoryFilter == .all)
            #expect(settings.homebrewZapCasks == false)
            #expect(settings.selectedUninstallerKind == .application)
            #expect(settings.masterPaneWidth == 360.0)
            #expect(settings.trashMasterPaneWidth == 380.0)
        }
    }

    @Test("AppModel Trash History: Purge single batch, purge all batches, and search/filter")
    func appModelTrashHistoryPurgeAndFilter() throws {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("curatare-appmodel-trash-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let trashRoot = tempRoot.appendingPathComponent(".Trash", isDirectory: true)
        let registry = tempRoot.appendingPathComponent("batches.json")
        let trashService = DatedTrashService(trashRootURL: trashRoot, homeDirectoryURL: tempRoot, registryFileURL: registry)

        let settings = AppSettings(defaults: defaults)
        let model = AppModel(
            settings: settings,
            log: AppLog(directory: nil),
            homeDirectoryURL: tempRoot,
            trashService: trashService,
            startBackgroundWatchers: false
        )

        let fileA = tempRoot.appendingPathComponent("user/docA.txt")
        let fileB = tempRoot.appendingPathComponent("user/docB.txt")
        try fm.createDirectory(at: fileA.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "A".write(to: fileA, atomically: true, encoding: .utf8)
        try "B".write(to: fileB, atomically: true, encoding: .utf8)

        let b1 = try trashService.moveToDatedTrash(
            candidates: [DatedTrashMoveCandidate(url: fileA, category: "Test", bundleID: nil)],
            title: "Alpha Cleanup",
            verifyRunningProcess: false
        )
        let b2 = try trashService.moveToDatedTrash(
            candidates: [DatedTrashMoveCandidate(url: fileB, category: "Test", bundleID: nil)],
            title: "Beta Cleanup",
            verifyRunningProcess: false
        )
        model.refreshTrashBatches()
        #expect(model.trashBatches.count == 2)

        // Filtreleme testi
        model.trashHistoryFilter = .all
        #expect(model.filteredTrashBatches.count == 2)

        model.trashHistorySearchText = "Alpha"
        #expect(model.filteredTrashBatches.count == 1)
        #expect(model.filteredTrashBatches.first?.id == b1.id)

        model.trashHistorySearchText = ""
        #expect(model.filteredTrashBatches.count == 2)

        // Tekli silme
        model.purgeTrashBatch(b1)
        #expect(model.trashBatches.count == 1)
        #expect(!fm.fileExists(atPath: b1.batchDirectoryPath))

        // Tekil öğe silme ve seçim testi (b2 içinde)
        let itemToPurge = b2.items[0]
        model.selectedTrashBatchID = b2.id
        #expect(model.selectedTrashedItemIDs.isEmpty)

        model.toggleSelectAllTrashedItems(in: b2)
        #expect(model.selectedTrashedItemIDs.contains(itemToPurge.id))

        model.toggleSelectAllTrashedItems(in: b2)
        #expect(model.selectedTrashedItemIDs.isEmpty)

        model.toggleTrashedItemSelection(id: itemToPurge.id)
        #expect(model.selectedTrashedItemIDs.contains(itemToPurge.id))

        model.purgeTrashedItem(batch: b2, item: itemToPurge)
        // b2 tek öğeli olduğu için öğe silinince tüm tur temizlenir
        #expect(model.trashBatches.isEmpty)
        #expect(!fm.fileExists(atPath: b2.batchDirectoryPath))

        // Tümünü silme
        model.purgeAllTrashBatches()
        #expect(model.trashBatches.isEmpty)
    }

    @Test("AppModel Selection Shortcuts: toggleSelectAllDevAndAIOverview, toggleSelectAllHeavyCaches, toggleSelectAllFilteredEcosystemItems, toggleSelectAllHomebrewPackages")
    func testAppModelSelectionShortcuts() {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let settings = AppSettings(defaults: defaults)
        let model = AppModel(settings: settings, log: AppLog(directory: nil), startBackgroundWatchers: false)

        // 1. Dev & AI Overview selection toggle
        let repo1 = RepoBuildArtifact(
            repoName: "Repo1",
            repoURL: URL(fileURLWithPath: "/tmp/repo1"),
            artifactURL: URL(fileURLWithPath: "/tmp/repo1/build"),
            relativePath: "build",
            sizeBytes: 1024,
            containsTrackedFiles: false,
            isSelected: false
        )
        let repoTracked = RepoBuildArtifact(
            repoName: "Repo2",
            repoURL: URL(fileURLWithPath: "/tmp/repo2"),
            artifactURL: URL(fileURLWithPath: "/tmp/repo2/tracked"),
            relativePath: "tracked",
            sizeBytes: 2048,
            containsTrackedFiles: true,
            isSelected: false
        )
        let aiLocal = AIFootprintItem(
            kind: .legacyConfig,
            title: "Config",
            url: URL(fileURLWithPath: "/tmp/ai_config"),
            sizeBytes: 512,
            detail: "Test",
            isCloudOnly: false,
            isSelected: false
        )
        let aiCloud = AIFootprintItem(
            kind: .ollamaModel,
            title: "CloudModel",
            url: nil,
            sizeBytes: 0,
            detail: "Cloud",
            isCloudOnly: true,
            isSelected: false
        )

        model.repoArtifacts = [repo1, repoTracked]
        model.aiFootprintItems = [aiLocal, aiCloud]

        // Select all
        model.toggleSelectAllDevAndAIOverview()
        #expect(model.repoArtifacts[0].isSelected == true)
        #expect(model.repoArtifacts[1].isSelected == false) // tracked remains unselected
        #expect(model.aiFootprintItems[0].isSelected == true)
        #expect(model.aiFootprintItems[1].isSelected == false) // cloud remains unselected

        // Deselect all
        model.toggleSelectAllDevAndAIOverview()
        #expect(model.repoArtifacts[0].isSelected == false)
        #expect(model.aiFootprintItems[0].isSelected == false)

        // 2. Heavy Caches selection toggle
        let cache1 = HeavyCacheItem(
            category: .browserSiteData,
            title: "Browser Data",
            ownerApp: "Chrome",
            url: URL(fileURLWithPath: "/tmp/cache1"),
            sizeBytes: 4096,
            explanation: "Site cache",
            isSelected: false
        )
        let cache2 = HeavyCacheItem(
            category: .browserSiteData,
            title: "Safari Cookies",
            ownerApp: "Safari",
            url: URL(fileURLWithPath: "/tmp/cache2"),
            sizeBytes: 8192,
            explanation: "Cookies",
            isSelected: false
        )

        model.heavyCacheItems = [cache1, cache2]
        model.toggleSelectAllHeavyCaches()
        #expect(model.heavyCacheItems.allSatisfy { $0.isSelected })

        model.toggleSelectAllHeavyCaches()
        #expect(model.heavyCacheItems.allSatisfy { !$0.isSelected })

        // 3. Homebrew packages selection toggle
        let brewPkg1 = HomebrewPackage(
            id: "wget",
            name: "wget",
            kind: .formula,
            version: "1.21",
            path: "/tmp/brew/wget",
            sizeBytes: 1000,
            isSelected: false
        )
        let brewPkg2 = HomebrewPackage(
            id: "curl",
            name: "curl",
            kind: .formula,
            version: "8.0",
            path: "/tmp/brew/curl",
            sizeBytes: 2000,
            isSelected: false
        )
        model.homebrewPackages = [brewPkg1, brewPkg2]
        model.toggleSelectAllHomebrewPackages()
        #expect(model.homebrewPackages.allSatisfy { $0.isSelected })
        model.toggleSelectAllHomebrewPackages()
        #expect(model.homebrewPackages.allSatisfy { !$0.isSelected })

        // 4. Language Ecosystems selection toggle
        let ecoCleanable = LanguageEcosystemItem(
            id: "pip-sample",
            ecosystem: .python,
            toolName: "pip (Python)",
            path: "/tmp/pip/sample",
            url: URL(fileURLWithPath: "/tmp/pip/sample"),
            sizeBytes: 1500,
            explanation: "User package",
            isSystemProtected: false,
            isSelected: false
        )
        let ecoProtected = LanguageEcosystemItem(
            id: "system-sample",
            ecosystem: .python,
            toolName: "macOS System Python",
            path: "/System/Library/sample",
            url: URL(fileURLWithPath: "/System/Library/sample"),
            sizeBytes: 3000,
            explanation: "Protected system python",
            isSystemProtected: true,
            isSelected: false
        )
        model.languageEcosystemItems = [ecoCleanable, ecoProtected]
        model.toggleSelectAllFilteredEcosystemItems()
        #expect(model.languageEcosystemItems[0].isSelected == true)
        #expect(model.languageEcosystemItems[1].isSelected == false) // protected remains unselected

        model.toggleSelectAllFilteredEcosystemItems()
        #expect(model.languageEcosystemItems.allSatisfy { !$0.isSelected })
    }

    @Test("AppUpdate: GitHub noReleases behavior matches Arhivar with warning and alert")
    func appUpdateNoReleasesMatchesArhivar() async throws {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("curatare-appupdate-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let settings = AppSettings(defaults: defaults)
        let model = AppModel(
            settings: settings,
            log: AppLog(directory: nil),
            homeDirectoryURL: tempRoot,
            startBackgroundWatchers: false
        )

        // 1. Configured repository defaults to berkbb/curatare-mac-universal
        let repo = try #require(AppUpdater.configuredRepository())
        #expect(repo == "berkbb/curatare-mac-universal")

        // 2. Mock 404 response / noReleases handling
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            let data = """
            {"message": "Not Found", "documentation_url": "https://docs.github.com/rest/releases/releases#get-the-latest-release"}
            """.data(using: .utf8)!
            return (response, data)
        }

        // Test AppUpdater.check directly with mock session
        let result = try await AppUpdater.check(repository: repo, currentVersion: "1.0.0", session: mockSession)
        #expect(result == .noReleases(repo: repo))

        // 3. Verify AppModel UI transition and alert item when no releases exist
        model.appUpdateUIState = .noReleases(repo: repo)
        let expectedMsg = model.L(.appUpdateNoReleases)
        #expect(expectedMsg.contains("Curatare"))
        #expect(!expectedMsg.contains("%@"))

        // Simulate interactive check behavior
        model.updateAlertMessage = expectedMsg
        model.alertItem = AlertItem(
            title: model.L(.menuCheckAppUpdates),
            message: expectedMsg,
            actionTitle: model.L(.buttonOK),
            action: {}
        )
        #expect(model.alertItem?.title == model.L(.menuCheckAppUpdates))
        #expect(model.alertItem?.message == expectedMsg)
        #expect(model.appUpdateUIState == .noReleases(repo: repo))
    }

    @Test("AppModel maintenance: only completed tasks are counted, failures and admin commands raise one alert")
    func optimizationOutcomeReporting() {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }
        let model = AppModel(
            settings: AppSettings(defaults: defaults),
            log: AppLog(directory: nil),
            tweakManager: SystemTweakManager(store: MockPreferenceStore()),
            startBackgroundWatchers: false
        )

        model.reportOptimizationOutcomes([MoleOptimizationOutcome(kind: .quickLookCacheRefresh, status: .done, detail: "ok")])
        #expect(model.alertItem == nil)

        model.reportOptimizationOutcomes([
            MoleOptimizationOutcome(kind: .quickLookCacheRefresh, status: .done, detail: "ok"),
            MoleOptimizationOutcome(kind: .apfsVolumeVerify, status: .failed, detail: "problem"),
            MoleOptimizationOutcome(kind: .dnsCacheFlush, status: .needsAdmin(command: MoleOptimizationOutcome.dnsFlushCommand), detail: "admin")
        ])
        let alert = model.alertItem
        #expect(alert?.title == model.L(.optimizeAttentionTitle))
        #expect(alert?.message.contains(model.L(MoleOptimizationTask.ActionKind.apfsVolumeVerify.titleKey)) == true)
        #expect(alert?.message.contains(MoleOptimizationOutcome.dnsFlushCommand) == true)
        #expect(alert?.actionTitle == model.L(.optimizeCopyCommand))
        #expect(model.toastMessage == model.LF(.toastOptimizationDone, Int64(1)))

        // Yalnızca yönetici komutu gereken çalıştırmada uyarının arkasında "0 görev tamamlandı" bildirimi çıkmaz.
        model.toastMessage = nil
        model.reportOptimizationOutcomes([
            MoleOptimizationOutcome(kind: .dnsCacheFlush, status: .needsAdmin(command: MoleOptimizationOutcome.dnsFlushCommand), detail: "admin")
        ])
        #expect(model.toastMessage == nil)
        #expect(model.alertItem != nil)
    }

    @Test("AppModel System Tweaks: apply tweak updates state and reset restores defaults")
    func systemTweaksAppModelTest() {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let mockStore = MockPreferenceStore()
        let tweakManager = SystemTweakManager(store: mockStore)
        let settings = AppSettings(defaults: defaults)
        let model = AppModel(
            settings: settings,
            log: AppLog(directory: nil),
            tweakManager: tweakManager,
            startBackgroundWatchers: false
        )

        #expect(model.systemTweaks.count == 30)
        #expect(model.systemChoiceTweaks.count == 8)
        #expect(model.systemStatusSubTab == .systemCenter)
        #expect(model.systemCenterTab == .hardware)
        #expect(model.hiddenUtilities.count >= 7)
        #expect(model.optimizationTasks.count == 12)

        model.systemCenterTab = .memory
        #expect(settings.lastSystemCenterTab == .memory)

        model.systemStatusSubTab = .dashboard
        #expect(settings.lastSystemStatusSubTab == .dashboard)

        model.systemStatusSubTab = .tweaks
        #expect(settings.lastSystemStatusSubTab == .tweaks)

        model.systemStatusSubTab = .checksum
        #expect(settings.lastSystemStatusSubTab == .checksum)

        model.applySystemTweak(id: "finder.showHiddenFiles", enabled: true)
        #expect(model.systemTweaks.first(where: { $0.id == "finder.showHiddenFiles" })?.isEnabled == true)
        #expect(mockStore.readBool(domain: "com.apple.finder", key: "AppleShowAllFiles", defaultValue: false) == true)

        model.applyChoiceTweak(id: "dock.minimizeEffect", optionID: "scale")
        #expect(model.systemChoiceTweaks.first(where: { $0.id == "dock.minimizeEffect" })?.selectedOptionID == "scale")
        model.setScreenshotNamePrefix("Shot:")
        #expect(model.screenshotNamePrefix == "Shot")
        #expect(model.screenshotLocation == nil)
        model.setScreenshotLocation("/Users/test/Pictures")
        #expect(model.screenshotLocation == "/Users/test/Pictures")

        model.resetAllSystemTweaks()
        #expect(model.screenshotLocation == nil)
        #expect(model.systemTweaks.first(where: { $0.id == "finder.showHiddenFiles" })?.isEnabled == false)
        #expect(mockStore.readBool(domain: "com.apple.finder", key: "AppleShowAllFiles", defaultValue: true) == false)
        #expect(model.systemChoiceTweaks.first(where: { $0.id == "dock.minimizeEffect" })?.selectedOptionID == "genie")
        #expect(model.screenshotNamePrefix == "")
    }

    @Test("Launch reads wait for the window, and missing Full Disk Access shows a dismissible banner")
    func permissionsAfterWindowAppears() throws {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let fm = FileManager.default
        let fakeHome = fm.temporaryDirectory.appendingPathComponent("curatare-permissions-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: fakeHome, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: fakeHome) }

        // `true` ile init hiçbir tercih, çöp ya da izin okuması yapmaz; hepsi `windowDidAppear` ile başlar.
        let model = AppModel(
            settings: AppSettings(defaults: defaults),
            log: AppLog(directory: nil),
            homeDirectoryURL: fakeHome,
            tweakManager: SystemTweakManager(store: MockPreferenceStore()),
            startBackgroundWatchers: true
        )
        #expect(model.systemTweaks.isEmpty)
        #expect(model.trashBatches.isEmpty)
        #expect(model.fullDiskAccessGranted == nil)
        #expect(model.showsPermissionBanner == false)

        model.refreshPermissionStatus()
        #expect(model.fullDiskAccessGranted == false)
        #expect(model.showsPermissionBanner)

        model.permissionBannerDismissed = true
        #expect(model.showsPermissionBanner == false)

        let bookmarks = fakeHome.appendingPathComponent("Library/Safari/Bookmarks.plist")
        try fm.createDirectory(at: bookmarks.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("bookmarks".utf8).write(to: bookmarks)
        model.permissionBannerDismissed = false
        model.refreshPermissionStatus()
        #expect(model.fullDiskAccessGranted == true)
        #expect(model.showsPermissionBanner == false)
    }

    @Test("Duplicate downloads: no scan at launch, one copy always kept, extras move to dated Trash")
    func duplicateDownloadsFlow() async throws {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }

        let fm = FileManager.default
        let fakeHome = fm.temporaryDirectory.appendingPathComponent("curatare-duplicates-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: fakeHome) }
        let downloads = fakeHome.appendingPathComponent("Downloads", isDirectory: true)
        try fm.createDirectory(at: downloads, withIntermediateDirectories: true)
        let payload = Data((0..<(2 << 20)).map { _ in UInt8.random(in: 0...255) })
        let original = downloads.appendingPathComponent("installer.dmg")
        let extra = downloads.appendingPathComponent("installer (1).dmg")
        try payload.write(to: original)
        try payload.write(to: extra)
        try fm.setAttributes([.creationDate: Date(timeIntervalSince1970: 1_700_000_000)], ofItemAtPath: original.path)

        let settings = AppSettings(defaults: defaults)
        settings.language = .en
        let model = AppModel(
            settings: settings,
            log: AppLog(directory: nil),
            homeDirectoryURL: fakeHome,
            trashService: DatedTrashService(
                trashRootURL: fakeHome.appendingPathComponent(".Trash"),
                homeDirectoryURL: fakeHome,
                registryFileURL: fakeHome.appendingPathComponent("Library/Application Support/Curatare/trash-batches.json")
            ),
            tweakManager: SystemTweakManager(store: MockPreferenceStore()),
            startBackgroundWatchers: false
        )
        // Alt sekme kaydedilmez ve İndirilenler kendiliğinden okunmaz.
        #expect(model.diskAnalyzerSubTab == .usage)
        #expect(model.duplicateScan == nil)

        await model.scanDuplicateDownloads()
        #expect(model.isBusy == false)
        let group = try #require(model.duplicateScan?.groups.first)
        #expect(model.duplicateScan?.groups.count == 1)
        #expect(group.copies.count == 2)
        #expect(group.copies[0].url.lastPathComponent == "installer.dmg")

        // Her gruptan en az bir kopya yerinde kalır
        model.toggleDuplicateCopySelection(groupID: group.id, copyID: group.copies[0].id)
        #expect(model.selectedDuplicateCopyCount == 1)
        #expect(model.canSelectDuplicateCopy(groupID: group.id, copyID: group.copies[1].id) == false)
        model.toggleDuplicateCopySelection(groupID: group.id, copyID: group.copies[1].id)
        #expect(model.selectedDuplicateCopyCount == 1)

        model.toggleSelectAllDuplicateExtras()
        #expect(model.allDuplicateExtrasSelected)
        #expect(model.duplicateScan?.groups[0].copies.map(\.isSelected) == [false, true])
        #expect(model.selectedDuplicateBytes == Int64(payload.count))

        model.diskAnalyzerSubTab = .duplicateDownloads
        model.selectedSection = .diskAnalyzer
        for language in [AppLanguage.tr, .en, .ro] {
            settings.language = language
            let host = NSHostingView(rootView: ContentView(model: model))
            host.frame = NSRect(x: 0, y: 0, width: 1180, height: 700)
            host.layoutSubtreeIfNeeded()
            #expect(host.bounds.width == 1180)
        }
        settings.language = .en

        settings.confirmBeforeTrashMove = true
        model.requestMoveDuplicatesToDatedTrash()
        #expect(model.pendingTrashConfirmation == .duplicateDownloads(count: 1, bytes: Int64(payload.count)))
        model.executePendingTrashMove()

        #expect(fm.fileExists(atPath: original.path))
        #expect(!fm.fileExists(atPath: extra.path))
        #expect(model.duplicateScan?.groups.isEmpty == true)
        #expect(model.trashBatches.count == 1)
        #expect(model.trashBatches.first?.title == "Duplicate Downloads Cleanup")
        #expect(model.trashBatches.first?.items.map(\.trashedRelativePath) == ["user/Downloads/installer (1).dmg"])
    }
}

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@Suite("Portable Rules AppModel Tests (roadmap 2c)")
@MainActor
struct PortableRulesAppModelTests {
    @Test("Export and import change only Curatare's whitelist and Mole purge paths; no file is moved or deleted")
    func exportMergeReplace() throws {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("curatare-portable-app-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: home) }
        let keep = home.appendingPathComponent("Documents/Keep", isDirectory: true)
        try fm.createDirectory(at: keep, withIntermediateDirectories: true)
        let note = keep.appendingPathComponent("note.txt")
        try Data("not touched".utf8).write(to: note)

        let settings = AppSettings(defaults: defaults)
        settings.language = .en
        settings.customWhitelistPaths = [keep.path, "/Volumes/Work/Shared"]
        let model = AppModel(settings: settings, log: AppLog(directory: nil), homeDirectoryURL: home, startBackgroundWatchers: false)

        let purgeFile = model.molePurgePathsFile
        try fm.createDirectory(at: purgeFile.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "# my note\n~/Projects\n".write(to: purgeFile.url, atomically: true, encoding: .utf8)

        // Dışa aktarma: ev klasörü altındaki yollar `~/` ile yazılır.
        let exportURL = home.appendingPathComponent("export.json")
        try model.exportPortableRules(to: exportURL)
        let exported = try PortableRules.decode(Data(contentsOf: exportURL))
        #expect(exported.whitelist == ["~/Documents/Keep", "/Volumes/Work/Shared"])
        #expect(exported.purgePaths == ["~/Projects"])

        // İçe aktarma dosyası: iki geçerli, iki reddedilen giriş.
        let importURL = home.appendingPathComponent("import.json")
        try Data("""
        {"version": 1, "whitelist": ["~/Documents/Keep", "~/Documents/Other", "~/Library/Caches/com.apple.Safari"], "purgePaths": ["~/Code", "/"]}
        """.utf8).write(to: importURL)
        let validation = try model.validatePortableRules(at: importURL)
        #expect(validation.rejected.count == 2)
        let protectedRejection = try #require(validation.rejected.first { $0.section == .whitelist })
        if case .protected(let detail) = protectedRejection.reason {
            #expect(!detail.isEmpty)
        } else {
            Issue.record("com.apple.* entry should be rejected as protected")
        }

        // Birleştir (varsayılan): mevcut girişler kalır.
        let merge = model.portableRulesImportPlan(for: validation, mode: .merge)
        try model.applyPortableRulesImport(merge)
        let other = (home.appendingPathComponent("Documents/Other").path as NSString).standardizingPath
        #expect(settings.customWhitelistPaths == [keep.path, "/Volumes/Work/Shared", other])
        #expect(purgeFile.load() == ["~/Projects", "~/Code"])

        // Değiştir: dosyada olmayan girişler ayarlardan çıkarılır, yorum satırı korunur.
        let replace = model.portableRulesImportPlan(for: validation, mode: .replace)
        #expect(replace.whitelistToRemove == ["/Volumes/Work/Shared"])
        #expect(replace.purgePathsToRemove == ["~/Projects"])
        try model.applyPortableRulesImport(replace)
        #expect(settings.customWhitelistPaths.count == 2)
        #expect(Set(settings.customWhitelistPaths.map { ($0 as NSString).standardizingPath }) == [(keep.path as NSString).standardizingPath, other])
        #expect(try String(contentsOf: purgeFile.url, encoding: .utf8) == "# my note\n~/Code\n")

        // Hiçbir dosya taşınmaz veya silinmez; Tarihli Çöp turu oluşmaz.
        #expect(fm.fileExists(atPath: note.path))
        #expect(!fm.fileExists(atPath: home.appendingPathComponent(".Trash").path))
        let files = try #require(fm.enumerator(atPath: home.path)).compactMap { $0 as? String }
        #expect(Set(files) == [
            "Documents", "Documents/Keep", "Documents/Keep/note.txt",
            ".config", ".config/mole", ".config/mole/purge_paths",
            "export.json", "import.json",
        ])

        // Hatalar kullanıcının dilinde bildirilir.
        let broken = home.appendingPathComponent("broken.json")
        try Data("not json".utf8).write(to: broken)
        #expect(throws: PortableRulesError.unreadable) { try model.validatePortableRules(at: broken) }
        #expect(model.portableRulesErrorMessage(PortableRulesError.unreadable) == settings.L(.rulesErrorUnreadable))
    }
}
