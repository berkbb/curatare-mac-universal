// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CryptoKit
import CuratareCore
import Foundation
import Testing

@Suite("Localization & Trilingual Parity Tests")
struct LocalizationTests {
    @Test("Every LKey exists in tr, en, and ro with matching format specifiers")
    func trilingualParity() {
        let table = StringTable()
        for code in AppLanguage.supportedCodes {
            #expect(table.tables[code] != nil, "Missing string table for \(code)")
        }
        for key in LKey.allCases {
            let tr = table.tables["tr"]?[key.rawValue]
            let en = table.tables["en"]?[key.rawValue]
            let ro = table.tables["ro"]?[key.rawValue]
            #expect(tr != nil && !(tr?.isEmpty ?? true), "Missing tr translation for \(key.rawValue)")
            #expect(en != nil && !(en?.isEmpty ?? true), "Missing en translation for \(key.rawValue)")
            #expect(ro != nil && !(ro?.isEmpty ?? true), "Missing ro translation for \(key.rawValue)")

            if let tr, let en, let ro {
                let trSpecs = Self.formatSpecifiers(in: tr)
                let enSpecs = Self.formatSpecifiers(in: en)
                let roSpecs = Self.formatSpecifiers(in: ro)
                #expect(trSpecs == enSpecs, "Specifier mismatch tr vs en for \(key.rawValue): \(trSpecs) vs \(enSpecs)")
                #expect(trSpecs == roSpecs, "Specifier mismatch tr vs ro for \(key.rawValue): \(trSpecs) vs \(roSpecs)")
            }
        }
    }

    private static func formatSpecifiers(in text: String) -> [String] {
        let pattern = #"%(?:[0-9]+\$)?[-+#0 ]*(?:[0-9]+|\*)?(?:\.(?:[0-9]+|\*))?(?:hh|h|ll|l|q|z|t|j)?[@dDuUxXoOfeEgGcCsSpaA]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            ns.substring(with: $0.range)
        }
    }
}

@Suite("Protection Rules Tests (library_clean.md Rule 2)")
struct ProtectionRulesTests {
    @Test("Protects Apple system prefixes, shared frameworks, active VMs, dev toolchains, and AI state")
    func enforcesProtectionList() {
        let rules = ProtectionRules(
            installedBundleIDs: ["com.vmware.fusion", "com.install4j.1234.app", "com.microsoft.powerpoint", "com.google.chrome"],
            installedAppNames: ["vmware fusion"],
            activeGradleVersions: ["8.13"],
            userWhitelistPatterns: ["/Users/test/KeepMe/*"],
            hasAntigravityIDE: true
        )

        // Apple sistem önekleri
        #expect(rules.evaluate(path: "/Users/test/Library/Preferences/com.apple.Finder.plist").isProtected)
        #expect(rules.evaluate(path: "/Users/test/Library/Group Containers/group.com.apple.notes").isProtected)
        #expect(rules.evaluate(path: "/Users/test/Library/Application Support/AddressBook").isProtected)

        // Ortak çatılar
        #expect(rules.evaluate(path: "/Users/test/Library/Caches/org.sparkle-project.Sparkle").isProtected)
        #expect(rules.evaluate(path: "/Users/test/Library/Application Support/Crashlytics").isProtected)
        #expect(rules.evaluate(path: "/Users/test/Library/Preferences/com.install4j.runtime.plist").isProtected)
        #expect(rules.evaluate(path: "/Users/test/Library/Application Support/Google").isProtected)
        #expect(rules.evaluate(path: "/Users/test/Library/Group Containers/UBF8T346G9.Office").isProtected)

        // Sanallaştırma (VMware Fusion kuruluyken mksSandbox korunur)
        #expect(rules.evaluate(path: "/Users/test/Library/Containers/com.vmware.mksSandbox").isProtected)

        // Ortak geliştirme araçları ve aktif Gradle sürümü
        #expect(rules.evaluate(path: "/Users/test/.gradle/caches/modules-2").isProtected)
        #expect(rules.evaluate(path: "/Users/test/.gradle/caches/8.13").isProtected)
        #expect(!rules.evaluate(path: "/Users/test/.gradle/caches/8.4").isProtected)
        #expect(rules.evaluate(path: "/Users/test/Library/Caches/ms-playwright-go").isProtected)

        // Aktif YZ verileri ve kimlik kasaları
        #expect(rules.evaluate(path: "/Users/test/.codex/config.json").isProtected)
        #expect(rules.evaluate(path: "/Users/test/.gemini/settings.json").isProtected)
        #expect(rules.evaluate(path: "/Users/test/.ssh/id_ed25519").isProtected)

        // Özel beyaz liste
        #expect(rules.evaluate(path: "/Users/test/KeepMe/project").isProtected)

        // Kardeş uygulamalar (Curatare, Arhivar, Copiator, Descarcator) her zaman korunur
        #expect(rules.evaluate(path: "/Applications/Curatare.app", candidateIdentifier: "com.babadogantech.curatare").isProtected)
        #expect(rules.evaluate(path: "/Applications/Arhivar.app", candidateIdentifier: "com.babadogantech.arhivar").isProtected)
        #expect(rules.evaluate(path: "/Applications/Arhivar.app", candidateIdentifier: "net.babadogan.arhivar").isProtected)
        #expect(rules.evaluate(path: "/Applications/Copiator.app", candidateIdentifier: "com.babadogantech.copiator").isProtected)
        #expect(rules.evaluate(path: "/Applications/Descarcator.app", candidateIdentifier: "com.babadogantech.descarcator").isProtected)

        // Kaldırılmış sıradan üçüncü parti uygulama ise korunmaz
        #expect(!rules.evaluate(path: "/Users/test/Library/Preferences/com.uninstalled.oldapp.plist").isProtected)

        // Korumalı uygulama kilit açma (allowUninstallingProtectedApps)
        let unlockedRules = ProtectionRules(
            allowUninstallingProtectedApps: true
        )
        // Kardeş uygulamalar kilit açılsa bile korunmaya devam eder
        #expect(unlockedRules.evaluate(path: "/Applications/Arhivar.app", candidateIdentifier: "com.babadogantech.arhivar").isProtected)
        #expect(unlockedRules.evaluate(path: "/Applications/Arhivar.app", candidateIdentifier: "net.babadogan.arhivar").isProtected)
        #expect(unlockedRules.evaluate(path: "/Applications/Curatare.app", candidateIdentifier: "com.babadogantech.curatare").isProtected)
        // /System altındakiler her koşulda korunmaya devam eder (macOS SIP)
        #expect(unlockedRules.evaluate(path: "/System/Applications/Safari.app", candidateIdentifier: "com.apple.Safari").isProtected)
        #expect(unlockedRules.evaluate(path: "/System/Library/CoreServices/Finder.app", candidateIdentifier: "com.apple.finder").isProtected)
        // Kimlik kasaları her koşulda korunmaya devam eder
        #expect(unlockedRules.evaluate(path: "/Users/test/.ssh/id_ed25519").isProtected)
        // Ancak /Applications altındaki Apple uygulamaları (Pages, GarageBand vb.) serbest bırakılır
        #expect(!unlockedRules.evaluate(path: "/Applications/Pages.app", candidateIdentifier: "com.apple.iWork.Pages").isProtected)
        #expect(!unlockedRules.evaluate(path: "/Applications/GarageBand.app", candidateIdentifier: "com.apple.garageband10").isProtected)
        #expect(!unlockedRules.evaluate(path: "/Users/test/Library/Containers/com.apple.garageband10", candidateIdentifier: "com.apple.garageband10").isProtected)
    }
}

@Suite("Dated Trash & One-Click Restore Tests (library_clean.md Rule 1)")
struct DatedTrashTests {
    @Test("Moves items to dated Trash preserving relative paths and restores them cleanly")
    func moveAndRestoreRoundTrip() throws {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("curatare-trash-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let fakeHome = tempRoot.appendingPathComponent("Home", isDirectory: true)
        let fakeTrash = fakeHome.appendingPathComponent(".Trash", isDirectory: true)
        let registryURL = fakeHome.appendingPathComponent("Library/Application Support/Curatare/trash-batches.json")

        let prefFile = fakeHome.appendingPathComponent("Library/Preferences/com.oldvendor.removed.plist")
        try fm.createDirectory(at: prefFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("test-plist-content".utf8).write(to: prefFile)

        let service = DatedTrashService(
            trashRootURL: fakeTrash,
            homeDirectoryURL: fakeHome,
            registryFileURL: registryURL
        )

        let manifest = try service.moveToDatedTrash(
            candidates: [
                DatedTrashMoveCandidate(url: prefFile, category: "GroupD", bundleID: "com.oldvendor.removed")
            ],
            title: "Unit Test Cleanup",
            verifyRunningProcess: false
        )

        #expect(!fm.fileExists(atPath: prefFile.path))
        #expect(manifest.id.hasPrefix("Curatare-"))
        #expect(manifest.items.count == 1)
        #expect(manifest.items[0].trashedRelativePath == "user/Library/Preferences/com.oldvendor.removed.plist")

        let stagedFile = URL(fileURLWithPath: manifest.batchDirectoryPath)
            .appendingPathComponent("user/Library/Preferences/com.oldvendor.removed.plist")
        #expect(fm.fileExists(atPath: stagedFile.path))

        // Tek tıkla Geri Yükle
        let restoredCount = try service.restoreBatch(id: manifest.id)
        #expect(restoredCount == 1)
        #expect(fm.fileExists(atPath: prefFile.path))
        let batches = service.listBatches()
        #expect(batches.first?.isRestored == true)
    }

    @Test("DatedTrashService: Purges individual batch and purges all batches with safety guards")
    func purgesBatchesSafely() throws {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("curatare-purge-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let trashRoot = tempRoot.appendingPathComponent(".Trash", isDirectory: true)
        let registry = tempRoot.appendingPathComponent("batches.json")
        let service = DatedTrashService(
            trashRootURL: trashRoot,
            homeDirectoryURL: tempRoot,
            registryFileURL: registry
        )

        let file1 = tempRoot.appendingPathComponent("user/file1.txt")
        let file2 = tempRoot.appendingPathComponent("user/file2.txt")
        try fm.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "data1".write(to: file1, atomically: true, encoding: .utf8)
        try "data2".write(to: file2, atomically: true, encoding: .utf8)

        let batch1 = try service.moveToDatedTrash(
            candidates: [DatedTrashMoveCandidate(url: file1, category: "Test", bundleID: nil)],
            title: "Batch 1",
            verifyRunningProcess: false
        )
        let batch2 = try service.moveToDatedTrash(
            candidates: [DatedTrashMoveCandidate(url: file2, category: "Test", bundleID: nil)],
            title: "Batch 2",
            verifyRunningProcess: false
        )

        #expect(service.listBatches().count == 2)
        #expect(fm.fileExists(atPath: batch1.batchDirectoryPath))
        #expect(fm.fileExists(atPath: batch2.batchDirectoryPath))

        // Tekli temizleme
        let purged1 = try service.purgeBatch(id: batch1.id)
        #expect(purged1.id == batch1.id)
        #expect(!fm.fileExists(atPath: batch1.batchDirectoryPath))
        #expect(service.listBatches().count == 1)
        #expect(service.listBatches().first?.id == batch2.id)

        // Tümünü temizleme
        let allResult = try service.purgeAllBatches()
        #expect(allResult.purgedCount == 1)
        #expect(!fm.fileExists(atPath: batch2.batchDirectoryPath))
        #expect(service.listBatches().isEmpty)
    }

    @Test("DatedTrashService: Purges individual item and multiple items from batch")
    func purgesItemsFromBatch() throws {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("curatare-item-purge-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let trashRoot = tempRoot.appendingPathComponent(".Trash", isDirectory: true)
        let registry = tempRoot.appendingPathComponent("batches.json")
        let service = DatedTrashService(
            trashRootURL: trashRoot,
            homeDirectoryURL: tempRoot,
            registryFileURL: registry
        )

        let file1 = tempRoot.appendingPathComponent("user/item1.txt")
        let file2 = tempRoot.appendingPathComponent("user/item2.txt")
        let file3 = tempRoot.appendingPathComponent("user/item3.txt")
        try fm.createDirectory(at: file1.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "item1".write(to: file1, atomically: true, encoding: .utf8)
        try "item2".write(to: file2, atomically: true, encoding: .utf8)
        try "item3".write(to: file3, atomically: true, encoding: .utf8)

        let batch = try service.moveToDatedTrash(
            candidates: [
                DatedTrashMoveCandidate(url: file1, category: "Test"),
                DatedTrashMoveCandidate(url: file2, category: "Test"),
                DatedTrashMoveCandidate(url: file3, category: "Test")
            ],
            title: "Multi-item Batch",
            verifyRunningProcess: false
        )

        #expect(batch.items.count == 3)
        let item1 = batch.items[0]
        let item2 = batch.items[1]
        let item3 = batch.items[2]

        // Tek bir öğeyi sil
        let updated1 = try service.purgeTrashedItem(batchID: batch.id, itemID: item1.id)
        #expect(updated1 != nil)
        #expect(updated1?.items.count == 2)
        #expect(!updated1!.items.contains(where: { $0.id == item1.id }))

        let batchDir = URL(fileURLWithPath: batch.batchDirectoryPath)
        let trashedFile1 = batchDir.appendingPathComponent(item1.trashedRelativePath)
        #expect(!fm.fileExists(atPath: trashedFile1.path))

        // Çoklu öğe sil (kalan iki öğeyi silince tüm batch kapanır)
        let updated2 = try service.purgeTrashedItems(batchID: batch.id, itemIDs: [item2.id, item3.id])
        #expect(updated2 == nil)
        #expect(service.listBatches().isEmpty)
        #expect(!fm.fileExists(atPath: batch.batchDirectoryPath))
    }

    @Test("Refuses to move protected or currently running targets")
    func blocksProtectedAndRunning() throws {
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("curatare-guard-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempRoot) }

        let service = DatedTrashService(
            trashRootURL: tempRoot.appendingPathComponent(".Trash"),
            homeDirectoryURL: tempRoot,
            registryFileURL: tempRoot.appendingPathComponent("batches.json")
        )

        let applePlist = tempRoot.appendingPathComponent("Library/Preferences/com.apple.Finder.plist")
        try fm.createDirectory(at: applePlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("apple".utf8).write(to: applePlist)

        #expect(throws: DatedTrashError.self) {
            _ = try service.moveToDatedTrash(
                candidates: [DatedTrashMoveCandidate(url: applePlist, category: "Test", bundleID: "com.apple.Finder")],
                title: "Should Fail"
            )
        }

        let runningAppFile = tempRoot.appendingPathComponent("Library/Caches/com.active.app")
        try fm.createDirectory(at: runningAppFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("active".utf8).write(to: runningAppFile)

        #expect(throws: DatedTrashError.processRunning(name: "ActiveApp", path: runningAppFile.path)) {
            _ = try service.moveToDatedTrash(
                candidates: [DatedTrashMoveCandidate(url: runningAppFile, category: "Test", bundleID: "com.active.app", processName: "ActiveApp")],
                title: "Should Block Running",
                runningProcessCheck: { _, _, _ in true }
            )
        }
    }
}

@Suite("Library Scanner Tests (library_clean.md Steps 1–6 & Groups A–E)")
struct LibraryScannerTests {
    @Test("Detects Groups A–E accurately while respecting iOS Wrapper apps and 3-component root prefixes")
    func fullAuditGroupsAtoE() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("curatare-scanner-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let home = root.appendingPathComponent("Users/tester", isDirectory: true)
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let sysLib = root.appendingPathComponent("Library", isDirectory: true)
        let github = home.appendingPathComponent("Documents/GitHub", isDirectory: true)

        // 1. Kurulu standart uygulama: Adobe Photoshop (`com.adobe.Photoshop`)
        let psInfo = apps.appendingPathComponent("Adobe Photoshop.app/Contents/Info.plist")
        try fm.createDirectory(at: psInfo.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = (["CFBundleIdentifier": "com.adobe.Photoshop"] as NSDictionary).write(to: psInfo, atomically: true)

        // 2. Kurulu iOS Wrapper uygulaması: Tapo (`com.tplink.tapo` inside Wrapper/Tapo.app/Info.plist)
        let tapoWrapperInfo = apps.appendingPathComponent("Tapo.app/Wrapper/Tapo.app/Info.plist")
        try fm.createDirectory(at: tapoWrapperInfo.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = (["CFBundleIdentifier": "com.tplink.tapo"] as NSDictionary).write(to: tapoWrapperInfo, atomically: true)

        // 3. Aktif GitHub deposu: `my-active-repo`
        try fm.createDirectory(at: github.appendingPathComponent("my-active-repo"), withIntermediateDirectories: true)

        // --- ~/Library Öğeleri ---
        let userLib = home.appendingPathComponent("Library", isDirectory: true)

        // Korunması gereken: `com.adobe.acc.AdobeDesktopService.plist` (3 bileşenli kök `com.adobe` / kurulu uygulama)
        let prefsDir = userLib.appendingPathComponent("Preferences", isDirectory: true)
        try fm.createDirectory(at: prefsDir, withIntermediateDirectories: true)
        try Data("tapo".utf8).write(to: prefsDir.appendingPathComponent("com.tplink.tapo.plist"))

        // Grup A: Test plisti (`ArhivarTests-E2F389EC-1111-2222-3333-444455556666.plist`)
        let groupAPlist = prefsDir.appendingPathComponent("ArhivarTests-E2F389EC-1111-2222-3333-444455556666.plist")
        try Data("test-run".utf8).write(to: groupAPlist)

        // Grup B: Silinmiş proje konteyneri (`application_bundle` -> `/Users/tester/DerivedData/OldProject.app`)
        let deadContainer = userLib.appendingPathComponent("Containers/com.oldcompany.deletedproj", isDirectory: true)
        try fm.createDirectory(at: deadContainer, withIntermediateDirectories: true)
        let containerMeta: NSDictionary = [
            "MCMMetadataIdentifier": "com.oldcompany.deletedproj",
            "MCMMetadataInfo": ["application_bundle": "/Users/tester/DerivedData/OldProject.app"]
        ]
        _ = containerMeta.write(to: deadContainer.appendingPathComponent(".com.apple.containermanagerd.metadata.plist"), atomically: true)

        // Korunan iOS Wrapper konteyneri (`/private/var/folders/.../Wrapper/Tapo.app` -> silinmiş sayılmamalı!)
        let wrapperContainer = userLib.appendingPathComponent("Containers/F16167E0-1234-4567-89AB-CDEF01234567", isDirectory: true)
        try fm.createDirectory(at: wrapperContainer, withIntermediateDirectories: true)
        let wrapperMeta: NSDictionary = [
            "MCMMetadataIdentifier": "com.tplink.tapo",
            "MCMMetadataInfo": ["application_bundle": "/private/var/folders/xx/yy/Wrapper/Tapo.app"]
        ]
        _ = wrapperMeta.write(to: wrapperContainer.appendingPathComponent(".com.apple.containermanagerd.metadata.plist"), atomically: true)

        // Grup C: Çıplak adlı CLI izi (`mytoolcli.plist`)
        let groupCPlist = prefsDir.appendingPathComponent("mytoolcli.plist")
        try Data("cli".utf8).write(to: groupCPlist)

        // Grup D: Kaldırılmış uygulama (`org.uninstalled.foobar.plist`)
        let groupDPlist = prefsDir.appendingPathComponent("org.uninstalled.foobar.plist")
        try Data("orphan".utf8).write(to: groupDPlist)

        // Grup E: Bozuk LaunchAgent (Hedef ikilisi `/Applications/GhostApp.app/Contents/MacOS/Ghost` mevcut değil)
        let agentsDir = userLib.appendingPathComponent("LaunchAgents", isDirectory: true)
        try fm.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        let deadAgentPlist = agentsDir.appendingPathComponent("com.ghost.agent.plist")
        let deadAgentDict: NSDictionary = [
            "Label": "com.ghost.agent",
            "ProgramArguments": ["/Applications/GhostApp.app/Contents/MacOS/Ghost", "--daemon"]
        ]
        _ = deadAgentDict.write(to: deadAgentPlist, atomically: true)

        // Grup E (sudo gerektiren): `/Library/LaunchDaemons/com.ghost.daemon.plist`
        let sysDaemons = sysLib.appendingPathComponent("LaunchDaemons", isDirectory: true)
        try fm.createDirectory(at: sysDaemons, withIntermediateDirectories: true)
        let deadDaemonPlist = sysDaemons.appendingPathComponent("com.ghost.daemon.plist")
        let deadDaemonDict: NSDictionary = [
            "Label": "com.ghost.daemon",
            "Program": "/Library/Application Support/Ghost/ghostd"
        ]
        _ = deadDaemonDict.write(to: deadDaemonPlist, atomically: true)

        let scanner = LibraryScanner(
            homeDirectoryURL: home,
            systemLibraryURL: sysLib,
            applicationDirectories: [apps],
            githubDirectoryURL: github
        )

        let report = scanner.scanAll()

        // Tapo Wrapper uygulaması kurulu olarak bulunmuş olmalı
        #expect(!report.findings.contains(where: { $0.url.lastPathComponent == "com.tplink.tapo.plist" }))
        #expect(!report.findings.contains(where: { $0.url.resolvingSymlinksInPath() == wrapperContainer.resolvingSymlinksInPath() }))

        // Grup A–E bulguları doğrulanır
        #expect(report.findings(for: .groupA).contains(where: { $0.url.resolvingSymlinksInPath() == groupAPlist.resolvingSymlinksInPath() }))
        #expect(report.findings(for: .groupB).contains(where: { $0.url.resolvingSymlinksInPath() == deadContainer.resolvingSymlinksInPath() }))
        #expect(report.findings(for: .groupC).contains(where: { $0.url.resolvingSymlinksInPath() == groupCPlist.resolvingSymlinksInPath() }))
        #expect(report.findings(for: .groupD).contains(where: { $0.url.resolvingSymlinksInPath() == groupDPlist.resolvingSymlinksInPath() }))
        #expect(report.findings(for: .groupE).contains(where: { $0.url.resolvingSymlinksInPath() == deadAgentPlist.resolvingSymlinksInPath() && !$0.requiresSudo }))
        #expect(report.findings(for: .groupE).contains(where: { $0.url.resolvingSymlinksInPath() == deadDaemonPlist.resolvingSymlinksInPath() && $0.requiresSudo }))

        // Tek satırlık sudo komutu `echo TAMAM` ile bitmeli ve `rm -rf` içermemeli!
        let sudo = try #require(report.sudoCommand)
        #expect(sudo.hasSuffix("echo TAMAM"))
        #expect(!sudo.contains("rm -rf"))
        #expect(sudo.contains("sudo chown -R"))
    }
}

@Suite("Extended Scanners, Uninstaller & Mole Bridge Tests")
struct ExtendedAndMoleTests {
    @Test("Parses ollama list, Time Machine snapshots, and Mole uninstall JSON")
    func parsersAndDiskSpace() {
        #expect(DiskSpace.parseHumanSize("477.5MB") > 477_000_000)
        #expect(DiskSpace.parseHumanSize("2.11GB") > 2_100_000_000)
        #expect(Int64.max.saturatingAdding(100) == Int64.max)

        let ollamaSample = """
        NAME                        ID              SIZE      MODIFIED
        qwen3-coder:480b-cloud      abc123456       -         2 weeks ago
        gemma4:e4b                  def456789       9.6 GB    6 days ago
        """
        let ollamaItems = ExtendedScanners.parseOllamaList(ollamaSample)
        #expect(ollamaItems.count == 2)
        #expect(ollamaItems[0].isCloudOnly == true)
        #expect(ollamaItems[0].sizeBytes == 0)
        #expect(ollamaItems[1].isCloudOnly == false)
        #expect(ollamaItems[1].sizeBytes > 9_000_000_000)

        let tmSample = """
        Snapshots for disk /:
        com.apple.TimeMachine.2026-04-06-142038.local
        com.apple.TimeMachine.2026-04-06-225243.local
        """
        let snaps = ExtendedScanners.parseTimeMachineSnapshots(tmSample)
        #expect(snaps.count == 2)
        #expect(snaps[0].dateStamp == "2026-04-06-142038")

        let moleAppsJSON = """
        [
          {"name": "Transmission", "bundle_id": "org.m0k.transmission", "source": "App", "path": "/Applications/Transmission.app", "size": "24.5MB"}
        ]
        """
        let apps = MoleBridge.parseUninstallListJSON(moleAppsJSON)
        #expect(apps.count == 1)
        #expect(apps[0].bundleID == "org.m0k.transmission")
        #expect(apps[0].sizeBytes > 24_000_000)
    }

    @Test("ExtendedScanners: scanAIFootprint discovers LM Studio, Python SRT, Junie, and Claude-3p")
    func scanAIFootprintDiscovery() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("curatare-ai-footprint-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempDir) }

        // Setup mock AI leftovers
        let lmStudio = tempDir.appendingPathComponent(".lmstudio", isDirectory: true)
        let pySrt = tempDir.appendingPathComponent("python313_srt", isDirectory: true)
        let junie = tempDir.appendingPathComponent(".local/share/junie", isDirectory: true)
        let claude3p = tempDir.appendingPathComponent("Library/Application Support/Claude-3p", isDirectory: true)
        let oldAgy = tempDir.appendingPathComponent(".antigravity", isDirectory: true)
        let newAgy = tempDir.appendingPathComponent(".antigravity-ide", isDirectory: true)

        try fm.createDirectory(at: lmStudio, withIntermediateDirectories: true)
        try fm.createDirectory(at: pySrt, withIntermediateDirectories: true)
        try fm.createDirectory(at: junie, withIntermediateDirectories: true)
        try fm.createDirectory(at: claude3p, withIntermediateDirectories: true)
        try fm.createDirectory(at: oldAgy, withIntermediateDirectories: true)
        try fm.createDirectory(at: newAgy, withIntermediateDirectories: true)

        try Data("model_data".utf8).write(to: lmStudio.appendingPathComponent("model.bin"))
        try Data("venv_data".utf8).write(to: pySrt.appendingPathComponent("bin_python"))
        try Data("junie_cache".utf8).write(to: junie.appendingPathComponent("index.db"))
        try Data("claude_code".utf8).write(to: claude3p.appendingPathComponent("state.json"))
        try Data("legacy_ext".utf8).write(to: oldAgy.appendingPathComponent("extensions.json"))

        let scanners = ExtendedScanners(homeDirectoryURL: tempDir)
        let items = await scanners.scanAIFootprint(includeOllama: false)

        #expect(items.contains { $0.title == "~/.lmstudio" })
        #expect(items.contains { $0.title == "python313_srt" })
        #expect(items.contains { $0.title == ".local/share/junie" })
        #expect(items.contains { $0.title.contains("Claude-3p") })
        #expect(items.contains { $0.title == ".antigravity" })
    }

    @Test("AppUninstaller and TrashWatcher (SmartDelete) discover orphaned Library leftovers")
    func uninstallerAndSmartDelete() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("curatare-uninstall-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let home = root.appendingPathComponent("Home", isDirectory: true)
        let trash = home.appendingPathComponent(".Trash", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)

        // Kullanıcı Library içinde DemoApp artıkları
        let cacheDir = home.appendingPathComponent("Library/Caches/com.example.demoapp", isDirectory: true)
        let prefFile = home.appendingPathComponent("Library/Preferences/com.example.demoapp.plist")
        try fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: prefFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("demo-cache".utf8).write(to: cacheDir.appendingPathComponent("db.sqlite"))
        try Data("demo-pref".utf8).write(to: prefFile)

        let uninstaller = AppUninstaller(homeDirectoryURL: home, applicationDirectories: [], pluginDirectories: [], widgetDirectories: [])
        let watcher = TrashWatcher(trashURL: trash, uninstaller: uninstaller) { _ in }

        // Şimdi Çöp'e `DemoApp.app` bırakalım
        let trashedApp = trash.appendingPathComponent("DemoApp.app", isDirectory: true)
        let plistURL = trashedApp.appendingPathComponent("Contents/Info.plist")
        try fm.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = (["CFBundleIdentifier": "com.example.demoapp", "CFBundleName": "DemoApp"] as NSDictionary).write(to: plistURL, atomically: true)

        let events = watcher.checkForNewTrashedApps()
        #expect(events.count == 1)
        #expect(events[0].bundle.bundleID == "com.example.demoapp")
        #expect(events[0].orphanedFiles.count == 2)
    }

    @Test("Smart association heuristic matching and comprehensive 22-location discovery")
    func smartAssociationMatcherAndFullScanning() throws {
        // 1. Curatare Akıllı Eşleştirme Doğrulaması: ^(?:(?:widget|helper|plugin|daemon|service|xpc)-)?<TOKEN>(?:[\.\-_\s\d]+.*)?$
        let matcher = AppUninstaller.SmartBundleMatcher(
            bundleID: "com.tinyspeck.slackmacgap",
            name: "Slack",
            bundleFileName: "Slack"
        )
        // Pozitif eşleşmeler
        #expect(matcher.matches("com.tinyspeck.slackmacgap"))
        #expect(matcher.matches("com.tinyspeck.slackmacgap.plist"))
        #expect(matcher.matches("com.tinyspeck.slackmacgap.helper"))
        #expect(matcher.matches("com.tinyspeck.slackmacgap-2026-11-01"))
        #expect(matcher.matches("com.tinyspeck.slackmacgap.binarycookies"))
        #expect(matcher.matches("Slack"))
        #expect(matcher.matches("Slack Helper"))
        #expect(matcher.matches("Slack Helper (Renderer)"))
        #expect(matcher.matches("Slack 2"))
        #expect(matcher.matches("Slack.savedState"))
        #expect(matcher.matches("Slack-2026.log"))
        #expect(matcher.matches("widget-Slack"))
        #expect(matcher.matches("helper-Slack"))
        #expect(matcher.matches("slackmacgap"))
        #expect(matcher.matches("slackmacgap.cache"))

        // Negatif eşleşmeler (yanlış pozitif engeli)
        #expect(!matcher.matches("Slacker"))
        #expect(!matcher.matches("Slackware"))
        #expect(!matcher.matches("Unslack"))
        #expect(!matcher.matches("com.othercompany.app"))

        // 2. 22 Konumdan Çoklu Dizin Taraması
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("curatare-smartuninstaller-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let home = root.appendingPathComponent("Home", isDirectory: true)
        let lib = home.appendingPathComponent("Library", isDirectory: true)

        // Konumlar oluştur
        let byHostDir = lib.appendingPathComponent("Preferences/ByHost", isDirectory: true)
        let syncedPrefsDir = lib.appendingPathComponent("SyncedPreferences", isDirectory: true)
        let diagReportsDir = lib.appendingPathComponent("Logs/DiagnosticReports", isDirectory: true)
        let crashRepDir = lib.appendingPathComponent("Application Support/CrashReporter", isDirectory: true)
        let groupDir = lib.appendingPathComponent("Group Containers/group.com.example.testapp", isDirectory: true)
        let cookiesDir = lib.appendingPathComponent("Cookies", isDirectory: true)
        let autosaveDir = lib.appendingPathComponent("Autosave Information", isDirectory: true)

        try fm.createDirectory(at: byHostDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: syncedPrefsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: diagReportsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: crashRepDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: groupDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: cookiesDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: autosaveDir, withIntermediateDirectories: true)

        try Data("byhost".utf8).write(to: byHostDir.appendingPathComponent("com.example.testapp.12345678-ABCD.plist"))
        try Data("synced".utf8).write(to: syncedPrefsDir.appendingPathComponent("com.example.testapp.plist"))
        try Data("diag".utf8).write(to: diagReportsDir.appendingPathComponent("TestApp_2026-11-01.ips"))
        try Data("crash".utf8).write(to: crashRepDir.appendingPathComponent("TestApp_crash.plist"))
        try Data("group".utf8).write(to: groupDir.appendingPathComponent("settings.dat"))
        try Data("cookie".utf8).write(to: cookiesDir.appendingPathComponent("com.example.testapp.binarycookies"))
        try Data("autosave".utf8).write(to: autosaveDir.appendingPathComponent("com.example.testapp.saved"))

        let testAppBundle = InstalledBundle(
            kind: .application,
            name: "TestApp",
            bundleID: "com.example.testapp",
            version: "1.0",
            url: root.appendingPathComponent("TestApp.app"),
            bundleSizeBytes: 1024,
            appGroups: ["group.com.example.testapp"]
        )

        let uninstaller = AppUninstaller(homeDirectoryURL: home, applicationDirectories: [], pluginDirectories: [], widgetDirectories: [])
        let files = uninstaller.discoverAssociatedFiles(for: testAppBundle, includeBundleItself: false)

        #expect(files.count == 7)
        let kinds = Set(files.map(\.kind))
        #expect(kinds.contains(.byHostPreferences))
        #expect(kinds.contains(.syncedPreferences))
        #expect(kinds.contains(.diagnosticReports))
        #expect(kinds.contains(.crashReporter))
        #expect(kinds.contains(.groupContainer))
        #expect(kinds.contains(.cookies))
        #expect(kinds.contains(.autosaveInformation))

        // 3. İç içe gömülü yardımcı paketler (nestedBundleIDs) ve LaunchdManager doğrulaması
        let helperCacheDir = lib.appendingPathComponent("Caches/com.example.testapp.helper", isDirectory: true)
        try fm.createDirectory(at: helperCacheDir, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: helperCacheDir.appendingPathComponent("db.sqlite"))

        let testAppWithHelper = InstalledBundle(
            kind: .application,
            name: "TestApp",
            bundleID: "com.example.testapp",
            version: "1.0",
            url: root.appendingPathComponent("TestApp.app"),
            bundleSizeBytes: 1024,
            nestedBundleIDs: ["com.example.testapp.helper"]
        )

        let helperFiles = uninstaller.discoverAssociatedFiles(for: testAppWithHelper, includeBundleItself: false)
        #expect(helperFiles.contains(where: {
            $0.url.resolvingSymlinksInPath().path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ==
            helperCacheDir.resolvingSymlinksInPath().path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }))

        // 4. LaunchdManager Label çıkarma
        let dummyLaunchdPlist = root.appendingPathComponent("daemon.plist")
        let plistData: NSDictionary = ["Label": "com.example.testdaemon", "KeepAlive": true]
        _ = plistData.write(to: dummyLaunchdPlist, atomically: true)
        #expect(LaunchdManager.extractLabel(from: dummyLaunchdPlist) == "com.example.testdaemon")

        // 5. Takılı disk görüntüsü (isMountedVolume) kontrolü
        let mountedBundle = InstalledBundle(
            kind: .application,
            name: "DMGApp",
            bundleID: "com.example.dmgapp",
            version: "1.0",
            url: URL(fileURLWithPath: "/Volumes/TestDMG/DMGApp.app"),
            bundleSizeBytes: 2048
        )
        #expect(mountedBundle.isMountedVolume == true)
        #expect(testAppBundle.isMountedVolume == false)
    }

    @Test("Bundled Mole engine is located and executes status-go and analyze-go")
    func bundledMoleEngineIntegration() async throws {
        let info = try #require(await EngineLocator.inspect())
        #expect(!info.version.isEmpty)
        #expect(info.version != "unknown")

        let bridge = MoleBridge(engine: info)
        let status = try await bridge.fetchSystemStatus()
        #expect((0...100).contains(status.healthScore))

        let fm = FileManager.default
        let sampleDir = fm.temporaryDirectory.appendingPathComponent("curatare-analyze-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: sampleDir) }
        try fm.createDirectory(at: sampleDir, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 4096).write(to: sampleDir.appendingPathComponent("sample.bin"))

        let analysis = await bridge.analyzeDirectory(at: sampleDir)
        #expect(analysis.totalSize >= 4096)
        #expect(!analysis.entries.isEmpty)
    }

    @Test("update-mole.sh check parses GitHub release metadata and SandboxProfile blocks credential folders")
    func updaterScriptAndSandboxProfile() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("curatare-updater-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempDir) }
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let mockJSON = tempDir.appendingPathComponent("release.json")
        let payload = """
        {
          "tag_name": "V1.63.0",
          "html_url": "https://github.com/tw93/Mole/releases/tag/V1.63.0",
          "assets": [
            {
              "name": "binaries-darwin-arm64.tar.gz",
              "browser_download_url": "https://github.com/tw93/Mole/releases/download/V1.63.0/binaries-darwin-arm64.tar.gz",
              "digest": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
            },
            {
              "name": "binaries-darwin-amd64.tar.gz",
              "browser_download_url": "https://github.com/tw93/Mole/releases/download/V1.63.0/binaries-darwin-amd64.tar.gz",
              "digest": "sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
            }
          ]
        }
        """
        try Data(payload.utf8).write(to: mockJSON)

        let scriptURL = try #require(EngineUpdater.locateScript())
        let runner = CommandRunner(
            executableURL: scriptURL,
            environmentOverrides: ["CURATARE_MOLE_API_JSON": mockJSON.path]
        )
        let res = try await runner.run(["check", "--current", "1.62.0"], timeout: 15)
        #expect(res.exitCode == 0)
        let parsed = try EngineUpdater.parseScriptOutput(res.stdout)
        #expect(parsed == .updateAvailable(
            current: "1.62.0",
            latest: "1.63.0",
            source: "https://github.com/tw93/Mole/archive/refs/tags/V1.63.0.tar.gz"
        ))

        let profile = SandboxProfile.readingOnly()
        let scheme = profile.schemeSource(executable: URL(fileURLWithPath: "/usr/bin/true"))
        #expect(scheme.contains("(deny network*)"))
        #expect(scheme.contains("(deny file-write*)"))
        #expect(scheme.contains(".ssh"))
    }

    @Test("UpdateSignature Ed25519 verification, embedded public key and UpdateChecksums calculation")
    func updateSignatureAndChecksums() throws {
        let key = Curve25519.Signing.PrivateKey()
        let pubKey = key.publicKey.rawRepresentation.base64EncodedString()

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("curatare-test-dmg-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let data = Data(repeating: 0x42, count: 1024)
        try data.write(to: tmp)

        let sig = try key.signature(for: data).base64EncodedString()
        #expect(try UpdateSignature.isValid(fileURL: tmp, signatureBase64: sig, publicKeyBase64: pubKey))

        // Corrupted signature or payload
        let badSig = sig.reversed().map(String.init).joined()
        #expect(try !UpdateSignature.isValid(fileURL: tmp, signatureBase64: badSig, publicKeyBase64: pubKey))

        let otherKey = Curve25519.Signing.PrivateKey()
        let otherPub = otherKey.publicKey.rawRepresentation.base64EncodedString()
        #expect(try !UpdateSignature.isValid(fileURL: tmp, signatureBase64: sig, publicKeyBase64: otherPub))

        // Embedded Info.plist public key validation
        let infoPlistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Support/Info.plist")
        let plistData = try Data(contentsOf: infoPlistURL)
        let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
        let base64Key = plist?["CuratareUpdatePublicEDKey"] as? String
        let unwrappedKey = try #require(base64Key)
        let keyData = try #require(Data(base64Encoded: unwrappedKey))
        #expect(keyData.count == 32)
        _ = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)

        // Checksums
        let hex = try UpdateChecksums.sha256(of: tmp)
        #expect(!hex.isEmpty)
        #expect(hex.count == 64)

        let checksumsText = """
        \(hex)  Curatare-1.0.0.dmg
        e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 *Curatare-1.0.0.zip
        """
        let map = UpdateChecksums.parse(checksumsText)
        #expect(map["Curatare-1.0.0.dmg"] == hex)
        #expect(map["Curatare-1.0.0.zip"] == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }
}

@Suite("AppSoundEffects & Audio Assets Tests")
struct AppSoundEffectsTests {
    @Test("Synthesized audio assets exist in Resources and load valid NSSound")
    @MainActor
    func verifySynthesizedAudioAssets() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // CuratareCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // root
        let resourcesURL = rootURL.appendingPathComponent("Resources")

        let trashURL = resourcesURL.appendingPathComponent("curatare_trash.aiff")
        let restoreURL = resourcesURL.appendingPathComponent("curatare_restore.aiff")

        #expect(FileManager.default.fileExists(atPath: trashURL.path))
        #expect(FileManager.default.fileExists(atPath: restoreURL.path))

        let trashData = try Data(contentsOf: trashURL)
        let restoreData = try Data(contentsOf: restoreURL)

        #expect(trashData.count > 10_000, "Trash sound data is unexpectedly small")
        #expect(restoreData.count > 10_000, "Restore sound data is unexpectedly small")

        let trashSound = NSSound(contentsOf: trashURL, byReference: true)
        let restoreSound = NSSound(contentsOf: restoreURL, byReference: true)

        #expect(trashSound != nil, "Failed to load curatare_trash.aiff as NSSound")
        #expect(restoreSound != nil, "Failed to load curatare_restore.aiff as NSSound")

        if let trashSound {
            #expect(trashSound.duration > 0.1 && trashSound.duration < 2.0)
        }
        if let restoreSound {
            #expect(restoreSound.duration > 0.2 && restoreSound.duration < 3.0)
        }

        // Test playing invocations do not crash
        AppSoundEffects.playTrashSound()
        AppSoundEffects.playRestoreSound()
    }
}

@Suite("Smart Uninstaller, Nested Helpers & Deep Discovery Tests")
struct SmartUninstallerTests {
    @Test("SmartBundleMatcher: Multi-prefix parsing, domain trailing extraction, and negative boundary isolation")
    func smartBundleMatcherExhaustive() {
        let matcher = AppUninstaller.SmartBundleMatcher(
            bundleID: "com.acme.photostudio",
            name: "PhotoStudio Pro",
            bundleFileName: "PhotoStudio",
            nestedBundleIDs: ["com.acme.photostudio.helper", "com.acme.photostudio.renderer"]
        )

        // 1. Direct and suffixed matches
        #expect(matcher.matches("com.acme.photostudio"))
        #expect(matcher.matches("com.acme.photostudio.plist"))
        #expect(matcher.matches("com.acme.photostudio.savedState"))
        #expect(matcher.matches("com.acme.photostudio.binarycookies"))
        #expect(matcher.matches("com.acme.photostudio-2026.log"))
        #expect(matcher.matches("com.acme.photostudio.helper"))
        #expect(matcher.matches("com.acme.photostudio.renderer"))

        // 2. Name-based and nested tokens
        #expect(matcher.matches("PhotoStudio Pro"))
        #expect(matcher.matches("PhotoStudio Pro Helper"))
        #expect(matcher.matches("PhotoStudio Pro 2.0"))
        #expect(matcher.matches("PhotoStudio"))
        #expect(matcher.matches("PhotoStudio.db"))

        // 3. Domain trailing component token extraction (e.g. "photostudio" from "com.acme.photostudio")
        #expect(matcher.matches("photostudio"))
        #expect(matcher.matches("photostudio.cache"))
        #expect(matcher.matches("photostudio-settings.plist"))

        // 4. Multi-prefix matches
        #expect(matcher.matches("widget-PhotoStudio"))
        #expect(matcher.matches("helper-PhotoStudio"))
        #expect(matcher.matches("plugin-PhotoStudio"))
        #expect(matcher.matches("daemon-PhotoStudio"))
        #expect(matcher.matches("service-PhotoStudio"))
        #expect(matcher.matches("xpc-PhotoStudio"))
        #expect(matcher.matches("widget-photostudio"))
        #expect(matcher.matches("helper-photostudio"))

        // 5. Negative boundary isolation (Strict protection against substring false positives)
        #expect(!matcher.matches("PhotoStudioProExtendedApp"))
        #expect(!matcher.matches("PhotoStudioAppStore"))
        #expect(!matcher.matches("photostudiomania"))
        #expect(!matcher.matches("Unphotostudio"))
        #expect(!matcher.matches("com.othercorp.photostudiox"))
    }

    @Test("AppUninstaller: extractNestedHelperBundleIDs deep extraction across subfolders")
    func nestedHelperBundleIDsExtraction() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("curatare-nested-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tmp) }

        let appURL = tmp.appendingPathComponent("SuperApp.app", isDirectory: true)

        // Mock embedded subfolders
        let frameworksDir = appURL.appendingPathComponent("Contents/Frameworks/CoreHelper.framework/Resources", isDirectory: true)
        let sparkleDir = appURL.appendingPathComponent("Contents/Frameworks/Sparkle.framework/Resources", isDirectory: true)
        let appleDir = appURL.appendingPathComponent("Contents/Frameworks/AppleHelper.framework/Resources", isDirectory: true)
        let helpersDir = appURL.appendingPathComponent("Contents/Helpers/LoginHelper.app/Contents", isDirectory: true)
        let xpcDir = appURL.appendingPathComponent("Contents/XPCServices/Renderer.xpc/Contents", isDirectory: true)
        let pluginsDir = appURL.appendingPathComponent("Contents/PlugIns/EditorWidget.appex/Contents", isDirectory: true)
        let launchServicesDir = appURL.appendingPathComponent("Contents/Library/LaunchServices/Worker/Contents", isDirectory: true)

        try fm.createDirectory(at: frameworksDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: sparkleDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: appleDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: helpersDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: xpcDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: launchServicesDir, withIntermediateDirectories: true)

        // Write Info.plists
        _ = (["CFBundleIdentifier": "com.example.superapp.framework"] as NSDictionary).write(to: frameworksDir.appendingPathComponent("Info.plist"), atomically: true)
        _ = (["CFBundleIdentifier": "org.sparkle-project.Sparkle"] as NSDictionary).write(to: sparkleDir.appendingPathComponent("Info.plist"), atomically: true)
        _ = (["CFBundleIdentifier": "com.apple.security.helper"] as NSDictionary).write(to: appleDir.appendingPathComponent("Info.plist"), atomically: true)
        _ = (["CFBundleIdentifier": "com.example.superapp.login"] as NSDictionary).write(to: helpersDir.appendingPathComponent("Info.plist"), atomically: true)
        _ = (["CFBundleIdentifier": "com.example.superapp.renderer"] as NSDictionary).write(to: xpcDir.appendingPathComponent("Info.plist"), atomically: true)
        _ = (["CFBundleIdentifier": "com.example.superapp.widget"] as NSDictionary).write(to: pluginsDir.appendingPathComponent("Info.plist"), atomically: true)
        _ = (["CFBundleIdentifier": "com.example.superapp.worker"] as NSDictionary).write(to: launchServicesDir.appendingPathComponent("Info.plist"), atomically: true)

        let ids = AppUninstaller.extractNestedHelperBundleIDs(from: appURL)

        // Must include our custom helper bundle IDs
        #expect(ids.contains("com.example.superapp.framework"))
        #expect(ids.contains("com.example.superapp.login"))
        #expect(ids.contains("com.example.superapp.renderer"))
        #expect(ids.contains("com.example.superapp.widget"))
        #expect(ids.contains("com.example.superapp.worker"))

        // Must strictly exclude Apple system IDs and Sparkle
        #expect(!ids.contains("org.sparkle-project.Sparkle"))
        #expect(!ids.contains("com.apple.security.helper"))
    }

    @Test("AppUninstaller: Extended plugin & system locations discovery across 30+ locations")
    func comprehensivePluginLocationsDiscovery() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("curatare-extended-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }

        let home = root.appendingPathComponent("Home", isDirectory: true)
        let userLib = home.appendingPathComponent("Library", isDirectory: true)

        // Mock specialized plugin & service paths
        let servicesDir = userLib.appendingPathComponent("Services", isDirectory: true)
        let audioDir = userLib.appendingPathComponent("Audio", isDirectory: true)
        let inputDir = userLib.appendingPathComponent("Input Methods", isDirectory: true)
        let colorPickersDir = userLib.appendingPathComponent("ColorPickers", isDirectory: true)
        let colorSyncDir = userLib.appendingPathComponent("ColorSync", isDirectory: true)
        let compDir = userLib.appendingPathComponent("Compositions", isDirectory: true)
        let kbdDir = userLib.appendingPathComponent("Keyboard Layouts", isDirectory: true)
        let pdfDir = userLib.appendingPathComponent("PDF Services", isDirectory: true)
        let osaDir = userLib.appendingPathComponent("ScriptingAdditions", isDirectory: true)
        let launchAgentsDir = userLib.appendingPathComponent("LaunchAgents", isDirectory: true)

        try fm.createDirectory(at: servicesDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: audioDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: inputDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: colorPickersDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: colorSyncDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: compDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: kbdDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: pdfDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: osaDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        try Data("svc".utf8).write(to: servicesDir.appendingPathComponent("DemoTool.workflow"))
        try Data("audio".utf8).write(to: audioDir.appendingPathComponent("DemoTool.component"))
        try Data("input".utf8).write(to: inputDir.appendingPathComponent("DemoTool.app"))
        try Data("cp".utf8).write(to: colorPickersDir.appendingPathComponent("DemoTool.colorPicker"))
        try Data("cs".utf8).write(to: colorSyncDir.appendingPathComponent("DemoTool.icc"))
        try Data("comp".utf8).write(to: compDir.appendingPathComponent("DemoTool.qtz"))
        try Data("kbd".utf8).write(to: kbdDir.appendingPathComponent("DemoTool.keylayout"))
        try Data("pdf".utf8).write(to: pdfDir.appendingPathComponent("DemoTool.workflow"))
        try Data("osa".utf8).write(to: osaDir.appendingPathComponent("DemoTool.osax"))
        try Data("agent".utf8).write(to: launchAgentsDir.appendingPathComponent("com.example.demotool.agent.plist"))

        let bundle = InstalledBundle(
            kind: .application,
            name: "DemoTool",
            bundleID: "com.example.demotool",
            version: "2.1",
            url: root.appendingPathComponent("DemoTool.app"),
            bundleSizeBytes: 2048
        )

        let uninstaller = AppUninstaller(homeDirectoryURL: home, applicationDirectories: [], pluginDirectories: [], widgetDirectories: [])
        let files = uninstaller.discoverAssociatedFiles(for: bundle, includeBundleItself: false)

        #expect(files.count == 10)
        for file in files {
            #expect(!file.requiresSudo, "User-level file unexpectedly required sudo: \(file.url.path)")
            #expect(file.isSelected, "User-level file should be selected by default")
        }
        let kinds = Set(files.map(\.kind))
        #expect(kinds.contains(.plugin))
        #expect(kinds.contains(.applicationSupport))
        #expect(kinds.contains(.launchAgent))
    }
}

@Suite("Launchd Lifecycle, TCC Diagnostics & TrashWatcher Tests")
struct LaunchdAndDiagnosticsTests {
    @Test("LaunchdManager: Plist label extraction, error handling, and job lifecycle")
    func launchdManagerLifecycle() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("curatare-launchd-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let validPlist = tmp.appendingPathComponent("valid.plist")
        let noLabelPlist = tmp.appendingPathComponent("no_label.plist")
        let brokenFile = tmp.appendingPathComponent("broken.plist")

        _ = (["Label": "com.babadogantech.sampledaemon", "ProgramArguments": ["/bin/echo", "hello"]] as NSDictionary).write(to: validPlist, atomically: true)
        _ = (["KeepAlive": true] as NSDictionary).write(to: noLabelPlist, atomically: true)
        try Data("not a plist".utf8).write(to: brokenFile)

        #expect(LaunchdManager.extractLabel(from: validPlist) == "com.babadogantech.sampledaemon")
        #expect(LaunchdManager.extractLabel(from: noLabelPlist) == nil)
        #expect(LaunchdManager.extractLabel(from: brokenFile) == nil)

        // unloadJob and loadJob should execute without throwing on valid or mock URLs
        _ = LaunchdManager.unloadJob(at: validPlist, isUserAgent: true)
        _ = LaunchdManager.loadJob(at: validPlist, isUserAgent: true)
    }

    @Test("FullDiskAccess: Diagnostics check and system preferences URL validation")
    func fullDiskAccessDiagnostics() {
        // Must return a boolean without throwing or crashing
        let granted = FullDiskAccess.isGranted
        #expect(granted == true || granted == false)

        // Verify system deep link URL is well-formed
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        #expect(url != nil)
        #expect(url?.scheme == "x-apple.systempreferences")
    }

    @Test("TrashWatcher: SmartDelete event generation and non-app filtering")
    func trashWatcherFiltering() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("curatare-watcher-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tmp) }

        let trash = tmp.appendingPathComponent(".Trash", isDirectory: true)
        let home = tmp.appendingPathComponent("Home", isDirectory: true)
        try fm.createDirectory(at: trash, withIntermediateDirectories: true)
        try fm.createDirectory(at: home, withIntermediateDirectories: true)

        // Create library leftovers for the app so SmartDelete detects actionable files
        let cacheDir = home.appendingPathComponent("Library/Caches/com.example.calcplus", isDirectory: true)
        try fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        try Data("cache".utf8).write(to: cacheDir.appendingPathComponent("cache.db"))

        let uninstaller = AppUninstaller(homeDirectoryURL: home, applicationDirectories: [], pluginDirectories: [], widgetDirectories: [])
        let watcher = TrashWatcher(trashURL: trash, uninstaller: uninstaller) { _ in }

        // 1. Add non-app items to Trash: text files, dmgs, zips, folders
        try Data("readme".utf8).write(to: trash.appendingPathComponent("notes.txt"))
        try Data("disk".utf8).write(to: trash.appendingPathComponent("installer.dmg"))
        try Data("archive".utf8).write(to: trash.appendingPathComponent("files.zip"))
        let regularFolder = trash.appendingPathComponent("DocumentsFolder", isDirectory: true)
        try fm.createDirectory(at: regularFolder, withIntermediateDirectories: true)

        // Non-app files must be safely ignored
        let eventsNonApp = watcher.checkForNewTrashedApps()
        #expect(eventsNonApp.isEmpty)

        // 2. Add valid `.app` bundle
        let appBundle = trash.appendingPathComponent("CalculatorPlus.app", isDirectory: true)
        let infoPlist = appBundle.appendingPathComponent("Contents/Info.plist")
        try fm.createDirectory(at: infoPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = (["CFBundleIdentifier": "com.example.calcplus", "CFBundleName": "CalculatorPlus"] as NSDictionary).write(to: infoPlist, atomically: true)

        let eventsApp = watcher.checkForNewTrashedApps()
        #expect(eventsApp.count == 1)
        if !eventsApp.isEmpty {
            #expect(eventsApp[0].bundle.bundleID == "com.example.calcplus")
            #expect(eventsApp[0].bundle.name == "CalculatorPlus")
            #expect(eventsApp[0].orphanedFiles.count == 1)
        }

        // 3. Second poll without new apps should yield empty
        let eventsRepeat = watcher.checkForNewTrashedApps()
        #expect(eventsRepeat.isEmpty)
    }
}

@Suite("DiskSpace Parallel Walk Tests")
struct DiskSpaceParallelWalkTests {
    @Test("DiskSpace.sizes matches size(of:) per root: nested dirs, symlinks, file, missing and empty roots")
    func parallelSizesMatchSerial() throws {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("curatare-walk-test-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmp) }

        let tree = tmp.appendingPathComponent("tree", isDirectory: true)
        for i in 0..<40 {
            let dir = tree.appendingPathComponent("d\(i % 7)/n\(i % 3)/leaf\(i)", isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(repeating: 0x41, count: 100 + i * 37).write(to: dir.appendingPathComponent("f\(i).bin"))
        }
        let empty = tree.appendingPathComponent("empty", isDirectory: true)
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        let outside = tmp.appendingPathComponent("outside.bin")
        try Data(repeating: 0x42, count: 5_000).write(to: outside)
        // Sembolik bağlantılar izlenmez: dosyaya, üst dizine (döngü) ve köke verilen bağlantılar 0 bayt sayılır.
        try fm.createSymbolicLink(at: tree.appendingPathComponent("link-to-outside"), withDestinationURL: outside)
        try fm.createSymbolicLink(at: tree.appendingPathComponent("link-to-parent"), withDestinationURL: tmp)
        let rootLink = tmp.appendingPathComponent("root-link")
        try fm.createSymbolicLink(at: rootLink, withDestinationURL: tree)

        let roots = [tree, outside, tmp.appendingPathComponent("missing"), rootLink, empty, tree.appendingPathComponent("d1")]
        let parallel = DiskSpace.sizes(of: roots)
        #expect(parallel == roots.map { DiskSpace.size(of: $0) })
        let expectedTreeBytes: Int64 = (0..<40).map { Int64(100 + $0 * 37) }.reduce(0, +)
        #expect(parallel[0] == expectedTreeBytes)
        #expect(parallel[1] == 5_000)
        #expect(parallel[2] == 0)
        #expect(parallel[3] == 0)
        #expect(parallel[4] == 0)
        #expect(DiskSpace.sizes(of: []).isEmpty)
        #expect(DiskSpace.sizes(of: [tree], isCancelled: { true }) == [0])
    }
}

@Suite("HomebrewScanner Tests")
struct HomebrewScannerTests {
    @Test("HomebrewScanner: Nonexistent brew path returns notInstalled")
    func nonexistentBrewPath() async {
        let scanner = HomebrewScanner(brewPath: "/nonexistent/path/to/brew")
        let status = await scanner.scan()
        #expect(!status.isInstalled)
        #expect(status.cacheSizeBytes == 0)
        #expect(status.cleanableItems.isEmpty)
        #expect(status.unneededDependencies.isEmpty)
        #expect(status.estimatedSpaceFreed == nil)
    }

    @Test("HomebrewScanner: Locate brew on system and scan status")
    func systemBrewScan() async {
        let detected = HomebrewScanner.locateBrew()
        if let detected {
            #expect(FileManager.default.isExecutableFile(atPath: detected))
            let scanner = HomebrewScanner(brewPath: detected)
            let status = await scanner.scan(isCancelled: { false })
            #expect(status.isInstalled)
            #expect(status.version != nil)
            #expect(status.cacheSizeBytes >= 0)
        }
    }

    @Test("HomebrewScanner: Mock executable tests cleanup, autoremove, and services cleanup")
    func mockBrewOperations() async throws {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("curatare_brew_test_\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        let mockBrewURL = tmpDir.appendingPathComponent("brew")
        let scriptContent = """
        #!/bin/sh
        if [ "$1" = "--version" ]; then
            echo "Homebrew 4.4.15"
            exit 0
        elif [ "$1" = "cleanup" ] && [ "$2" = "--dry-run" ]; then
            echo "Would remove: /Users/test/Library/Caches/Homebrew/pkg.bottle (25.4MB)"
            echo "Would remove: /opt/homebrew/Cellar/oldpkg/1.0 (50.2MB)"
            echo "==> This operation would free approximately 75.6MB of disk space."
            exit 0
        elif [ "$1" = "autoremove" ] && [ "$2" = "--dry-run" ]; then
            echo "Would uninstall: liborphan1, liborphan2"
            exit 0
        elif [ "$1" = "cleanup" ]; then
            echo "Pruned cache and old versions successfully"
            exit 0
        elif [ "$1" = "autoremove" ]; then
            echo "Removed unneeded dependencies"
            exit 0
        elif [ "$1" = "services" ] && [ "$2" = "cleanup" ]; then
            echo "Removed unused launchd services"
            exit 0
        fi
        exit 0
        """
        try scriptContent.write(to: mockBrewURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mockBrewURL.path)

        let scanner = HomebrewScanner(brewPath: mockBrewURL.path)
        let status = await scanner.scan()

        #expect(status.isInstalled)
        #expect(status.version == "Homebrew 4.4.15")
        #expect(status.cleanableItems.count == 2)
        #expect(status.cleanableItems[0].title == "pkg.bottle")
        #expect(status.cleanableItems[0].kind == .cachedDownload)
        #expect(status.cleanableItems[1].title == "1.0")
        #expect(status.cleanableItems[1].kind == .oldVersion)
        #expect(status.unneededDependencies == ["liborphan1", "liborphan2"])
        #expect(status.estimatedSpaceFreed == "75.6MB")

        let cleanRes = try await scanner.executeCleanup(pruneAll: true, scrub: true)
        #expect(cleanRes.exitCode == 0)

        let autoRes = try await scanner.executeAutoremove()
        #expect(autoRes.exitCode == 0)

        let servRes = try await scanner.executeServicesCleanup()
        #expect(servRes.exitCode == 0)
    }

    @Test("HomebrewScanner: Mock executable scans formulae and casks, and executes uninstalls")
    func mockBrewPackagesScanAndUninstall() async throws {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("curatare_brew_pkg_test_\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        let mockBrewURL = tmpDir.appendingPathComponent("brew")
        let jsonMock = """
        {
          "formulae": [
            {
              "name": "node",
              "full_name": "node",
              "desc": "Platform built on V8 to build network applications",
              "homepage": "https://nodejs.org/",
              "installed": [
                {
                  "version": "26.12.1",
                  "installed_on_request": true
                }
              ],
              "dependencies": ["icu4c", "openssl"]
            }
          ],
          "casks": [
            {
              "token": "visual-studio-code",
              "name": ["Visual Studio Code"],
              "desc": "Code editor",
              "homepage": "https://code.visualstudio.com/",
              "version": "1.95.0",
              "installed": "1.95.0"
            }
          ]
        }
        """
        let jsonFile = tmpDir.appendingPathComponent("info.json")
        try jsonMock.write(to: jsonFile, atomically: true, encoding: .utf8)

        let scriptContent = """
        #!/bin/sh
        if [ "$1" = "info" ] && [ "$2" = "--json=v2" ]; then
            cat "\(jsonFile.path)"
            exit 0
        elif [ "$1" = "uninstall" ]; then
            echo "Uninstalled: $@"
            exit 0
        fi
        exit 0
        """
        try scriptContent.write(to: mockBrewURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mockBrewURL.path)

        let scanner = HomebrewScanner(brewPath: mockBrewURL.path)
        let packages = await scanner.scanPackages()

        #expect(packages.count == 2)

        let node = packages.first { $0.id == "node" }
        #expect(node != nil)
        #expect(node?.kind == .formula)
        #expect(node?.version == "26.12.1")
        #expect(node?.dependencies.count == 2)
        #expect(node?.isInstalledOnRequest == true)

        let vscode = packages.first { $0.id == "visual-studio-code" }
        #expect(vscode != nil)
        #expect(vscode?.kind == .cask)
        #expect(vscode?.name == "Visual Studio Code")
        #expect(vscode?.version == "1.95.0")

        let uninstNode = try await scanner.uninstallPackage(id: "node", isCask: false)
        #expect(uninstNode.exitCode == 0)

        let uninstVSCode = try await scanner.uninstallPackage(id: "visual-studio-code", isCask: true, zap: true)
        #expect(uninstVSCode.exitCode == 0)

        let batchRes = try await scanner.uninstallPackages(packages: packages, zapCasks: true)
        #expect(batchRes.count >= 1)
        #expect(batchRes.allSatisfy { $0.exitCode == 0 })
    }

    @Test("HomebrewScanner: Batched package sizing keeps Cellar/Caskroom sizes and paths per package")
    func batchedPackageSizing() async throws {
        let fm = FileManager.default
        let tmpDir = fm.temporaryDirectory.appendingPathComponent("curatare_brew_size_test_\(UUID().uuidString)", isDirectory: true)
        let binDir = tmpDir.appendingPathComponent("bin", isDirectory: true)
        try fm.createDirectory(at: binDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpDir) }

        let formulaDir = tmpDir.appendingPathComponent("Cellar/mockformula/1.0/bin", isDirectory: true)
        try fm.createDirectory(at: formulaDir, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 1_234).write(to: formulaDir.appendingPathComponent("tool"))
        let caskDir = tmpDir.appendingPathComponent("Caskroom/mockcask/2.0", isDirectory: true)
        try fm.createDirectory(at: caskDir, withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 321).write(to: caskDir.appendingPathComponent("meta.json"))

        let jsonFile = tmpDir.appendingPathComponent("info.json")
        try """
        {
          "formulae": [
            { "name": "mockformula", "installed": [{ "version": "1.0", "installed_on_request": false }] },
            { "name": "ghostformula", "installed": [{ "version": "9.9", "installed_on_request": true }] }
          ],
          "casks": [
            { "token": "mockcask", "name": ["Curatare Missing Mock Cask \(UUID().uuidString)"], "installed": "2.0" }
          ]
        }
        """.write(to: jsonFile, atomically: true, encoding: .utf8)
        let mockBrewURL = binDir.appendingPathComponent("brew")
        try """
        #!/bin/sh
        if [ "$1" = "info" ]; then cat "\(jsonFile.path)"; fi
        exit 0
        """.write(to: mockBrewURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mockBrewURL.path)

        let packages = await HomebrewScanner(brewPath: mockBrewURL.path).scanPackages()
        #expect(packages.count == 3)

        let formula = packages.first { $0.id == "mockformula" }
        #expect(formula?.sizeBytes == 1_234)
        #expect(formula?.path == tmpDir.appendingPathComponent("Cellar/mockformula/1.0").path)
        #expect(formula?.isDependency == true)

        let ghost = packages.first { $0.id == "ghostformula" }
        #expect(ghost?.sizeBytes == 0)
        #expect(ghost?.path == nil)

        let cask = packages.first { $0.id == "mockcask" }
        #expect(cask?.sizeBytes == 321)
        #expect(cask?.path == caskDir.path)
    }

    @Test("ExtendedScanners: Language ecosystem package managers & immutable macOS system runtimes")
    func languageEcosystemScannersAndProtection() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("curatare-ecosystem-test-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        // Setup mock ecosystem caches inside temporary home
        let mockPaths: [(rel: String, file: String, content: String)] = [
            ("Library/Caches/pip", "pip-cache.bin", "pip wheels binary data"),
            (".cache/uv", "uv-cache.bin", "uv fast package data"),
            (".npm/_cacache", "npm-cache.bin", "npm cacache index"),
            (".cargo/registry/cache", "crate-sample.crate", "cargo crate archive"),
            ("Library/Caches/go-build", "go-obj.a", "go compiled object"),
            (".bundle/cache", "gem-sample.gem", "bundler gem archive"),
            (".gradle/caches", "artifact.jar", "gradle jar cache"),
            (".m2/repository", "maven-pkg.pom", "<project>maven</project>"),
            (".nuget/packages", "nuget.nupkg", "nuget package archive"),
            ("Library/Caches/org.swift.swiftpm", "manifest.db", "swiftpm manifests"),
            (".pub-cache", "pub-package.tar", "dart pub package"),
            (".local/share/mise/cache", "mise-tar.gz", "mise runtime cache"),
            (".rustup/downloads", "rust-std.tar.gz", "rustup toolchain archive"),
        ]

        for entry in mockPaths {
            let dir = tempDir.appendingPathComponent(entry.rel)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent(entry.file)
            try entry.content.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let scanners = ExtendedScanners(homeDirectoryURL: tempDir)
        let items = scanners.scanLanguageEcosystemItems()

        // 1. Verify macOS System Runtimes are always detected and 100% protected
        let systemItems = items.filter(\.isSystemProtected)
        #expect(!systemItems.isEmpty)
        for sysItem in systemItems {
            #expect(sysItem.ecosystem == .macosSystemRuntime)
            #expect(sysItem.isSystemProtected == true)
            #expect(sysItem.isSelected == false)
            #expect(sysItem.path.hasPrefix("/usr/bin") || sysItem.path.hasPrefix("/System/Library"))
        }

        // 2. Verify all mock user ecosystem caches were discovered
        let userItems = items.filter { !$0.isSystemProtected }
        #expect(userItems.count >= 10)

        let pipItem = userItems.first { $0.toolName == "pip" }
        #expect(pipItem != nil)
        #expect(pipItem?.ecosystem == .python)
        #expect(pipItem?.isSelected == true)
        #expect(pipItem?.sizeBytes ?? 0 > 0)

        let npmItem = userItems.first { $0.toolName == "npm" }
        #expect(npmItem != nil)
        #expect(npmItem?.ecosystem == .javascriptNode)

        let cargoItem = userItems.first { $0.toolName == "cargo" }
        #expect(cargoItem != nil)
        #expect(cargoItem?.ecosystem == .rust)

        let goItem = userItems.first { $0.toolName == "go-build" }
        #expect(goItem != nil)
        #expect(goItem?.ecosystem == .goLang)

        let gradleItem = userItems.first { $0.toolName == "gradle" }
        #expect(gradleItem != nil)
        #expect(gradleItem?.ecosystem == .jvm)

        let nugetItem = userItems.first { $0.toolName == "nuget" }
        #expect(nugetItem != nil)
        #expect(nugetItem?.ecosystem == .dotnet)

        let swiftItem = userItems.first { $0.toolName == "swiftpm" }
        #expect(swiftItem != nil)
        #expect(swiftItem?.ecosystem == .swift)

        let pubItem = userItems.first { $0.toolName == "pub" }
        #expect(pubItem != nil)
        #expect(pubItem?.ecosystem == .dartFlutter)

        let miseItem = userItems.first { $0.toolName == "mise" }
        #expect(miseItem != nil)
        #expect(miseItem?.ecosystem == .versionManager)

        // 3. Test ProtectionRules: default vs allowDeveloperCacheCleaning
        let defaultProtection = ProtectionRules()
        let allowDevProtection = ProtectionRules(allowDeveloperCacheCleaning: true)

        let pipPath = tempDir.appendingPathComponent("Library/Caches/pip").path
        #expect(defaultProtection.evaluate(path: pipPath).isProtected == true)
        #expect(allowDevProtection.evaluate(path: pipPath).isProtected == false)

        // macOS system runtimes must ALWAYS remain protected, even with allowDeveloperCacheCleaning: true
        #expect(allowDevProtection.evaluate(path: "/usr/bin/python3").isProtected == true)
        #expect(allowDevProtection.evaluate(path: "/usr/bin/ruby").isProtected == true)
        #expect(allowDevProtection.evaluate(path: "/System/Library/Frameworks/Python.framework").isProtected == true)

        // Credential vaults must ALWAYS remain protected
        #expect(allowDevProtection.evaluate(path: "\(tempDir.path)/.ssh/id_ed25519").isProtected == true)

        // 4. Test DatedTrash move of ecosystem cache
        let trashDir = tempDir.appendingPathComponent(".Trash")
        try fm.createDirectory(at: trashDir, withIntermediateDirectories: true)
        let trashService = DatedTrashService(trashRootURL: trashDir, homeDirectoryURL: tempDir)

        let pipCandidate = DatedTrashMoveCandidate(
            url: tempDir.appendingPathComponent("Library/Caches/pip"),
            category: "Ecosystem:python:pip",
            precomputedSize: pipItem?.sizeBytes
        )

        let manifest = try trashService.moveToDatedTrash(
            candidates: [pipCandidate],
            title: "Test Dev & Ecosystem Cleanup",
            protectionRules: allowDevProtection,
            verifyRunningProcess: false
        )

        #expect(manifest.items.count == 1)
        #expect(!fm.fileExists(atPath: pipPath))

        // Moving protected system runtime must throw error
        let sysCandidate = DatedTrashMoveCandidate(
            url: URL(fileURLWithPath: "/usr/bin/python3"),
            category: "SystemRuntime"
        )
        #expect(throws: DatedTrashError.self) {
            _ = try trashService.moveToDatedTrash(
                candidates: [sysCandidate],
                title: "Should Fail",
                protectionRules: allowDevProtection,
                verifyRunningProcess: false
            )
        }

        // Restore pip cache from Dated Trash
        let restored = try trashService.restoreBatch(id: manifest.id)
        #expect(restored == 1)
        #expect(fm.fileExists(atPath: pipPath))
    }

    @Test("ExtendedScanners: Discovers full browser caches and extended system/media cleaning targets")
    func extendedHeavyCachesDiscovery() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("curatare-extended-caches-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: tempDir) }

        // Setup mock browser caches (> 100 KB)
        let chromeCache = tempDir.appendingPathComponent("Library/Caches/Google/Chrome/Default/Cache", isDirectory: true)
        try fm.createDirectory(at: chromeCache, withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: 200 * 1024).write(to: chromeCache.appendingPathComponent("data_0"))

        let safariCache = tempDir.appendingPathComponent("Library/Caches/com.apple.Safari", isDirectory: true)
        try fm.createDirectory(at: safariCache, withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 150 * 1024).write(to: safariCache.appendingPathComponent("fsCachedData"))

        let edgeCache = tempDir.appendingPathComponent("Library/Caches/Microsoft Edge", isDirectory: true)
        try fm.createDirectory(at: edgeCache, withIntermediateDirectories: true)
        try Data(repeating: 0x43, count: 120 * 1024).write(to: edgeCache.appendingPathComponent("edge_data"))

        // Setup mock Mail Downloads
        let mailDir = tempDir.appendingPathComponent("Library/Containers/com.apple.mail/Data/Library/Mail Downloads", isDirectory: true)
        try fm.createDirectory(at: mailDir, withIntermediateDirectories: true)
        try Data("attachment".utf8).write(to: mailDir.appendingPathComponent("invoice.pdf"))

        // Setup mock iOS Backup
        let backupDir = tempDir.appendingPathComponent("Library/Application Support/MobileSync/Backup/00008030-00112233", isDirectory: true)
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        try Data("backup".utf8).write(to: backupDir.appendingPathComponent("Manifest.db"))

        // Setup mock partial download
        let dlDir = tempDir.appendingPathComponent("Downloads", isDirectory: true)
        try fm.createDirectory(at: dlDir, withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: dlDir.appendingPathComponent("bigfile.iso.crdownload"))

        // Setup mock Windows & metadata files
        try Data("thumbs".utf8).write(to: dlDir.appendingPathComponent("Thumbs.db"))
        try Data("appledouble".utf8).write(to: dlDir.appendingPathComponent("._notes.txt"))

        // Setup mock diagnostic report
        let diagDir = tempDir.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        try fm.createDirectory(at: diagDir, withIntermediateDirectories: true)
        try Data(repeating: 0x58, count: 20 * 1024).write(to: diagDir.appendingPathComponent("crash.ips"))

        // Setup mock shell sessions
        let zshDir = tempDir.appendingPathComponent(".zsh_sessions", isDirectory: true)
        try fm.createDirectory(at: zshDir, withIntermediateDirectories: true)
        try Data("history".utf8).write(to: zshDir.appendingPathComponent("session1.history"))

        // Setup mock dynamic wallpaper cache (> 10 MB)
        let wpDir = tempDir.appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store", isDirectory: true)
        try fm.createDirectory(at: wpDir, withIntermediateDirectories: true)
        try Data(repeating: 0x59, count: 11 * 1024 * 1024).write(to: wpDir.appendingPathComponent("aerial.mov"))

        // Setup mock QuickTime autosave
        let qtDir = tempDir.appendingPathComponent("Library/Containers/com.apple.QuickTimePlayerX/Data/Library/Autosave Information", isDirectory: true)
        try fm.createDirectory(at: qtDir, withIntermediateDirectories: true)
        try Data("autosave".utf8).write(to: qtDir.appendingPathComponent("Unsaved.mov"))

        // Setup mock EdgeUpdater superseded version (> 1 version)
        let edgeUpdaterDir = tempDir.appendingPathComponent("Library/Application Support/Microsoft/EdgeUpdater/apps/msedge-stable", isDirectory: true)
        let v1 = edgeUpdaterDir.appendingPathComponent("156.0.4314.50", isDirectory: true)
        let v2 = edgeUpdaterDir.appendingPathComponent("156.0.4314.58", isDirectory: true)
        try fm.createDirectory(at: v1, withIntermediateDirectories: true)
        try fm.createDirectory(at: v2, withIntermediateDirectories: true)
        try Data(repeating: 0x45, count: 50 * 1024).write(to: v1.appendingPathComponent("edge.bin"))
        try Data(repeating: 0x46, count: 50 * 1024).write(to: v2.appendingPathComponent("edge.bin"))

        // Setup mock ShipIt updater cache
        let shipItDir = tempDir.appendingPathComponent("Library/Caches/com.microsoft.VSCode.ShipIt", isDirectory: true)
        try fm.createDirectory(at: shipItDir, withIntermediateDirectories: true)
        try Data(repeating: 0x56, count: 60 * 1024).write(to: shipItDir.appendingPathComponent("ShipIt_update.zip"))

        // Setup mock Classic Teams leftovers (`library_clean.md`)
        let classicTeamsDir = tempDir.appendingPathComponent("Library/Application Support/Microsoft/Teams", isDirectory: true)
        let classicTeamsGroup = tempDir.appendingPathComponent("Library/Group Containers/UBF8T346G9.com.microsoft.teams", isDirectory: true)
        try fm.createDirectory(at: classicTeamsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: classicTeamsGroup, withIntermediateDirectories: true)
        try Data("teams_old".utf8).write(to: classicTeamsDir.appendingPathComponent("storage.json"))
        try Data("teams_group".utf8).write(to: classicTeamsGroup.appendingPathComponent("group.json"))

        // Setup mock JetBrains Air & IcedTea-Web (`library_clean.md`)
        let jbAirDir = tempDir.appendingPathComponent("Library/Caches/JetBrains/Air", isDirectory: true)
        let icedTeaDir = tempDir.appendingPathComponent(".cache/icedtea-web", isDirectory: true)
        try fm.createDirectory(at: jbAirDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: icedTeaDir, withIntermediateDirectories: true)
        try Data("air_cache".utf8).write(to: jbAirDir.appendingPathComponent("air.bin"))
        try Data("icedtea".utf8).write(to: icedTeaDir.appendingPathComponent("cache.properties"))

        // Setup mock Teams 2 EBWebView & Copilot cache (`library_clean.md`)
        let ebWebViewDir = tempDir.appendingPathComponent("Library/Containers/com.microsoft.teams2/Data/Library/Caches/EBWebView", isDirectory: true)
        let copilotCache = tempDir.appendingPathComponent("Library/Caches/copilot", isDirectory: true)
        try fm.createDirectory(at: ebWebViewDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: copilotCache, withIntermediateDirectories: true)
        try Data(repeating: 0x50, count: 120 * 1024).write(to: ebWebViewDir.appendingPathComponent("webview_data"))
        try Data(repeating: 0x51, count: 110 * 1024).write(to: copilotCache.appendingPathComponent("copilot_data"))

        let scanners = ExtendedScanners(homeDirectoryURL: tempDir)
        let items = scanners.scanHeavyCachesAndInstallers()

        // 1. Verify Browser & Desktop Web caches are found
        #expect(items.contains { $0.category == .browserCache && $0.ownerApp == "Google Chrome" })
        #expect(items.contains { $0.category == .browserCache && $0.ownerApp == "Safari" })
        #expect(items.contains { $0.category == .browserCache && $0.ownerApp == "Microsoft Edge" })
        #expect(items.contains { $0.category == .browserCache && $0.ownerApp.contains("Teams 2") })
        #expect(items.contains { $0.category == .browserCache && $0.ownerApp.contains("Copilot") })

        // 2. Verify Extended Cleaning categories are found
        #expect(items.contains { $0.category == .mailDownloads })
        #expect(items.contains { $0.category == .iosDeviceBackup })
        #expect(items.contains { $0.category == .partialDownload })
        #expect(items.contains { $0.category == .windowsMetadata })
        #expect(items.contains { $0.category == .crashDump })
        #expect(items.contains { $0.category == .shellSessions })
        #expect(items.contains { $0.category == .dynamicWallpaperCache })
        #expect(items.contains { $0.category == .quickTimeAutosave })
        #expect(items.contains { $0.category == .appVersionCache && $0.ownerApp.contains("EdgeUpdater") })
        #expect(items.contains { $0.category == .appVersionCache && $0.categoryLKey == .cachesCategoryAppVersion })
        #expect(items.contains { $0.title.contains("Microsoft Teams (Classic)") })
        #expect(items.contains { $0.title.contains("JetBrains Air") })
        #expect(items.contains { $0.title.contains("icedtea-web") })

        // 3. Test filter groups
        let browserItems = items.filter { $0.filterGroup == .browsers }
        #expect(browserItems.count >= 3)

        let mailBackupItems = items.filter { $0.filterGroup == .mailAndBackups }
        #expect(mailBackupItems.count >= 2)

        let sysLogItems = items.filter { $0.filterGroup == .systemAndLogs }
        #expect(sysLogItems.count >= 3)

        let updateItems = items.filter { $0.filterGroup == .updatesAndInstallers }
        #expect(!updateItems.isEmpty)

        // 4. Test ProtectionRules with allowUserCacheCleaning
        let defaultProt = ProtectionRules()
        let userCacheProt = ProtectionRules(allowUserCacheCleaning: true)

        let safariCachePath = safariCache.path
        #expect(defaultProt.evaluate(path: safariCachePath).isProtected == true)
        #expect(userCacheProt.evaluate(path: safariCachePath).isProtected == false)
    }
}

@Suite("macOS System Tweaks & Maintenance Rebuild Tests")
struct SystemTweaksTests {
    @Test("SystemTweakManager: loads definitions and reads defaults from mock store")
    func loadDefinitionsAndDefaults() {
        let mockStore = MockPreferenceStore()
        let manager = SystemTweakManager(store: mockStore)
        let tweaks = manager.loadAllTweaks()

        #expect(tweaks.count == 30)
        #expect(tweaks.contains(where: { $0.id == "finder.showHiddenFiles" }))
        #expect(tweaks.contains(where: { $0.id == "finder.showFullPathInTitle" }))
        #expect(tweaks.contains(where: { $0.id == "finder.hideDesktopIcons" }))
        #expect(tweaks.contains(where: { $0.id == "dock.instantAutohide" }))
        #expect(tweaks.contains(where: { $0.id == "disk.dontWriteNetworkStores" }))
        #expect(tweaks.contains(where: { $0.id == "disk.dontWriteUSBStores" }))
        #expect(tweaks.contains(where: { $0.id == "screenshot.disableShadow" }))
        #expect(tweaks.contains(where: { $0.id == "system.windowDragOnGesture" }))
        #expect(tweaks.contains(where: { $0.id == "system.pressAndHoldRepeat" }))
        #expect(!tweaks.contains(where: { $0.id == "system.textEditBlankDocument" || $0.id == "system.musicHalfStars" }))
        #expect(!tweaks.contains(where: { $0.id == "system.safariDevelopMenu" }))
        #expect(tweaks.contains(where: { $0.id == "system.disableWindowAnimations" }))
    }

    @Test("SystemTweakManager: applies tweaks, writes to store, and triggers service restarts")
    func applyTweaksAndRestartServices() {
        let mockStore = MockPreferenceStore()
        let manager = SystemTweakManager(store: mockStore)

        let updated = manager.applyTweak(id: "finder.showHiddenFiles", enabled: true)
        #expect(updated?.isEnabled == true)
        #expect(mockStore.readBool(domain: "com.apple.finder", key: "AppleShowAllFiles", defaultValue: false) == true)
        #expect(mockStore.restartedServices.contains(.finder))

        _ = manager.applyTweak(id: "dock.staticOnly", enabled: true)
        #expect(mockStore.readBool(domain: "com.apple.dock", key: "static-only", defaultValue: false) == true)
        #expect(mockStore.restartedServices.contains(.dock))

        _ = manager.applyTweak(id: "dock.instantAutohide", enabled: true)
        #expect(mockStore.readValue(domain: "com.apple.dock", key: "autohide-delay") == .double(0))
        #expect(mockStore.restartedServices.contains(.dock))

        _ = manager.applyTweak(id: "system.suppressCrashDialog", enabled: true)
        #expect(mockStore.readString(domain: "com.apple.CrashReporter", key: "DialogType", defaultValue: "") == "none")

        _ = manager.applyTweak(id: "system.windowDragOnGesture", enabled: true)
        #expect(mockStore.readBool(domain: "NSGlobalDomain", key: "NSWindowShouldDragOnGesture", defaultValue: false) == true)

        _ = manager.applyTweak(id: "system.pressAndHoldRepeat", enabled: true)
        #expect(mockStore.readBool(domain: "NSGlobalDomain", key: "ApplePressAndHoldEnabled", defaultValue: true) == false)

    }

    @Test("SystemTweakManager: resets all tweaks to default values")
    func resetAllToDefaults() {
        let mockStore = MockPreferenceStore(initialBools: [
            "com.apple.finder:AppleShowAllFiles": true,
            "com.apple.dock:static-only": true
        ])
        let manager = SystemTweakManager(store: mockStore)

        let reset = manager.restoreAllToDefaults()
        #expect(reset.first(where: { $0.id == "finder.showHiddenFiles" })?.isEnabled == false)
        #expect(mockStore.readBool(domain: "com.apple.finder", key: "AppleShowAllFiles", defaultValue: true) == false)
        #expect(mockStore.readBool(domain: "com.apple.dock", key: "static-only", defaultValue: true) == false)
    }

    @Test("SystemPreferenceStore: NSGlobalDomain resolves to the global preferences domain")
    func globalDomainMapping() {
        #expect(SystemPreferenceStore.preferencesDomain(for: "NSGlobalDomain") == kCFPreferencesAnyApplication)
        #expect(SystemPreferenceStore.preferencesDomain(for: "com.apple.dock") as String == "com.apple.dock")
    }

    @Test("SystemTweakManager: Finder, Dock, screenshot and system additions write their keys and reset")
    func extendedTweaksRoundTrip() {
        let mockStore = MockPreferenceStore()
        let manager = SystemTweakManager(store: mockStore)

        // Anahtar yokken macOS varsayılanı okunur: önizleme açık, diğerleri kapalı.
        let initial = Dictionary(uniqueKeysWithValues: manager.loadAllTweaks().map { ($0.id, $0.isEnabled) })
        #expect(initial["screenshot.showThumbnail"] == true)
        #expect(initial["screenshot.showCursor"] == false)
        #expect(initial["dock.lockContents"] == false)
        #expect(initial["system.disableAppNap"] == false)

        let cases: [(id: String, domain: String, key: String, enabled: Bool, service: SystemTweakItem.RestartService)] = [
            ("finder.pathBarFromHome", "com.apple.finder", "PathBarRootAtHome", true, .finder),
            ("dock.lockContents", "com.apple.dock", "contents-immutable", true, .dock),
            ("dock.lockSize", "com.apple.dock", "size-immutable", true, .dock),
            ("dock.stackHoverHighlight", "com.apple.dock", "mouse-over-hilite-stack", true, .dock),
            ("screenshot.showThumbnail", "com.apple.screencapture", "show-thumbnail", false, .systemUIServer),
            ("screenshot.showCursor", "com.apple.screencapture", "showsCursor", true, .systemUIServer),
            ("system.expandedSaveDialog", "NSGlobalDomain", "NSNavPanelExpandedStateForSaveMode", true, .none),
            ("system.disableAppNap", "NSGlobalDomain", "NSAppSleepDisabled", true, .none)
        ]
        for c in cases {
            let updated = manager.applyTweak(id: c.id, enabled: c.enabled)
            #expect(updated?.isEnabled == c.enabled, "\(c.id)")
            #expect(updated?.restartService == c.service, "\(c.id)")
            #expect(mockStore.readBool(domain: c.domain, key: c.key, defaultValue: !c.enabled) == c.enabled, "\(c.id)")
        }

        let reset = Dictionary(uniqueKeysWithValues: manager.restoreAllToDefaults().map { ($0.id, $0.isEnabled) })
        #expect(reset["screenshot.showThumbnail"] == true)
        #expect(reset["dock.lockContents"] == false)
        #expect(mockStore.readBool(domain: "com.apple.screencapture", key: "show-thumbnail", defaultValue: false) == true)
        #expect(mockStore.readBool(domain: "NSGlobalDomain", key: "NSAppSleepDisabled", defaultValue: true) == false)
    }

    @Test("PreferenceValue: equivalents written with a different defaults type still match")
    func preferenceValueMatching() {
        #expect(PreferenceValue.double(0).matches(.string("0")))
        #expect(PreferenceValue.double(0).matches(.int(0)))
        #expect(PreferenceValue.int(5).matches(.double(5)))
        #expect(PreferenceValue.bool(true).matches(.int(1)))
        #expect(PreferenceValue.bool(false).matches(.string("NO")))
        #expect(PreferenceValue.string("genie").matches(.string("Genie")))
        #expect(!PreferenceValue.string("genie").matches(.int(0)))
        #expect(!PreferenceValue.double(0).matches(.double(0.5)))
    }

    @Test("SystemTweakManager: value toggles write numbers, read legacy strings and Safari is read-only")
    func valueToggles() {
        let mockStore = MockPreferenceStore(
            initialBools: ["com.apple.Safari.SandboxBroker:ShowDevelopMenu": true],
            initialStrings: ["com.apple.dock:autohide-delay": "0"]
        )
        let manager = SystemTweakManager(store: mockStore)

        // Eski sürümün `-string 0` olarak yazdığı gecikme açık görünmeye devam eder.
        let initial = Dictionary(uniqueKeysWithValues: manager.loadAllTweaks().map { ($0.id, $0.isEnabled) })
        #expect(initial["dock.instantAutohide"] == true)
        #expect(initial["dock.instantAnimation"] == false)
        #expect(initial["dock.showRecents"] == true)
        #expect(initial["finder.quickLookNoAnimation"] == false)

        _ = manager.applyTweak(id: "dock.instantAnimation", enabled: true)
        #expect(mockStore.readValue(domain: "com.apple.dock", key: "autohide-time-modifier") == .double(0))
        _ = manager.applyTweak(id: "finder.quickLookNoAnimation", enabled: true)
        #expect(mockStore.readValue(domain: "NSGlobalDomain", key: "QLPanelAnimationDuration") == .double(0))
        _ = manager.applyTweak(id: "dock.instantAnimation", enabled: false)
        #expect(mockStore.readValue(domain: "com.apple.dock", key: "autohide-time-modifier") == nil)

        _ = manager.applyTweak(id: "dock.showRecents", enabled: false)
        #expect(mockStore.readBool(domain: "com.apple.dock", key: "show-recents", defaultValue: true) == false)

        // Safari dışarıdan açılan ayarı uygulamaz: Curatare durumu yalnızca okur, Tümünü Sıfırla da ona dokunmaz.
        #expect(manager.safariDevelopMenuShown() == true)
        #expect(manager.applyTweak(id: "system.safariDevelopMenu", enabled: false) == nil)
        _ = manager.restoreAllToDefaults()
        #expect(mockStore.readBool(domain: "com.apple.Safari.SandboxBroker", key: "ShowDevelopMenu", defaultValue: false) == true)
    }

    @Test("SystemTweakManager: choice tweaks select defaults, write typed values and reset")
    func choiceTweaks() {
        let mockStore = MockPreferenceStore(initialStrings: [
            "com.apple.dock:mineffect": "scale",
            "NSGlobalDomain:NSRecentDocumentsLimit": "5"
        ])
        let manager = SystemTweakManager(store: mockStore)

        let initial = Dictionary(uniqueKeysWithValues: manager.loadChoiceTweaks().map { ($0.id, $0.selectedOptionID) })
        #expect(initial.count == 8)
        #expect(initial["dock.minimizeEffect"] == "scale")
        #expect(initial["system.recentDocumentsLimit"] == "5")
        #expect(initial["dock.recentAppsCount"] == "default")
        #expect(initial["finder.columnAutoSizing"] == "default")

        let suck = manager.applyChoiceTweak(id: "dock.minimizeEffect", optionID: "suck")
        #expect(suck?.selectedOptionID == "suck")
        #expect(mockStore.readValue(domain: "com.apple.dock", key: "mineffect") == .string("suck"))
        #expect(mockStore.restartedServices.contains(.dock))

        // Varsayılan seçenek (Cin) anahtarı siler.
        _ = manager.applyChoiceTweak(id: "dock.minimizeEffect", optionID: "genie")
        #expect(mockStore.readValue(domain: "com.apple.dock", key: "mineffect") == nil)

        _ = manager.applyChoiceTweak(id: "dock.recentAppsCount", optionID: "10")
        #expect(mockStore.readValue(domain: "com.apple.dock", key: "show-recent-count") == .int(10))
        _ = manager.applyChoiceTweak(id: "finder.columnAutoSizing", optionID: "off")
        #expect(mockStore.readValue(domain: "com.apple.finder", key: "_FXEnableColumnAutoSizing") == .bool(false))
        #expect(manager.applyChoiceTweak(id: "dock.recentAppsCount", optionID: "7") == nil)

        // Listede olmayan bir değer hiçbir seçeneği işaretlemez.
        mockStore.writeValue(domain: "com.apple.dock", key: "show-recent-count", value: .int(7))
        #expect(manager.loadChoiceTweaks().first(where: { $0.id == "dock.recentAppsCount" })?.selectedOptionID == nil)

        _ = manager.restoreAllToDefaults()
        #expect(manager.loadChoiceTweaks().allSatisfy { $0.selectedOptionID == $0.defaultOptionID })
        #expect(mockStore.readValue(domain: "NSGlobalDomain", key: "NSRecentDocumentsLimit") == nil)
    }

    @Test("SystemTweakManager: screenshot name prefix is sanitized, written and removed when empty")
    func screenshotNamePrefixRoundTrip() {
        let mockStore = MockPreferenceStore()
        let manager = SystemTweakManager(store: mockStore)

        #expect(manager.screenshotNamePrefix() == "")
        #expect(manager.setScreenshotNamePrefix("  Ekran/Resmi:  ") == "EkranResmi")
        #expect(mockStore.readString(domain: "com.apple.screencapture", key: "name", defaultValue: "") == "EkranResmi")
        #expect(mockStore.restartedServices.contains(.systemUIServer))
        #expect(ScreenshotNamePrefix.sanitized(String(repeating: "a", count: 80)).count == ScreenshotNamePrefix.maxLength)

        #expect(manager.setScreenshotNamePrefix(" / ") == "")
        #expect(mockStore.readValue(domain: "com.apple.screencapture", key: "name") == nil)

        manager.setScreenshotNamePrefix("Shot")
        _ = manager.restoreAllToDefaults()
        #expect(manager.screenshotNamePrefix() == "")
    }

    @Test("SystemTweakManager: screenshot folder keeps legacy paths, writes a chosen folder and resets to the Desktop")
    func screenshotLocationRoundTrip() {
        // Eski "İndirilenler'e kaydet" anahtarının yazdığı yol okunmaya devam eder.
        let mockStore = MockPreferenceStore(initialStrings: ["com.apple.screencapture:location": "/Users/test/Downloads"])
        let manager = SystemTweakManager(store: mockStore)
        #expect(manager.screenshotLocation() == "/Users/test/Downloads")
        #expect(!manager.loadAllTweaks().contains(where: { $0.key == "location" }))

        manager.setScreenshotLocation("/Users/test/Pictures/Shots")
        #expect(mockStore.readString(domain: "com.apple.screencapture", key: "location", defaultValue: "") == "/Users/test/Pictures/Shots")
        #expect(mockStore.restartedServices.contains(.systemUIServer))

        manager.setScreenshotLocation(nil)
        #expect(manager.screenshotLocation() == nil)
        #expect(mockStore.readValue(domain: "com.apple.screencapture", key: "location") == nil)

        manager.setScreenshotLocation("/Users/test/Pictures/Shots")
        _ = manager.restoreAllToDefaults()
        #expect(manager.screenshotLocation() == nil)
    }

    @Test("SystemTweakManager: Finder animation, toolbar title, tooltip and power button tweaks")
    func remainingUserLevelTweaks() {
        // Terminal'den `-bool false` ile kapatılmış animasyon "animasyonsuz" olarak açık görünür.
        let mockStore = MockPreferenceStore(initialBools: ["com.apple.finder:AnimateInfoPanes": false])
        let manager = SystemTweakManager(store: mockStore)

        let initial = Dictionary(uniqueKeysWithValues: manager.loadAllTweaks().map { ($0.id, $0.isEnabled) })
        #expect(initial["finder.noWindowZoomAnimation"] == false)
        #expect(initial["finder.noInfoPaneAnimation"] == true)
        #expect(initial["system.toolbarTitleNoDelay"] == false)

        _ = manager.applyTweak(id: "finder.noWindowZoomAnimation", enabled: true)
        #expect(mockStore.readValue(domain: "com.apple.finder", key: "AnimateWindowZoom") == .bool(false))
        #expect(mockStore.restartedServices.contains(.finder))
        _ = manager.applyTweak(id: "finder.noWindowZoomAnimation", enabled: false)
        #expect(mockStore.readValue(domain: "com.apple.finder", key: "AnimateWindowZoom") == nil)

        _ = manager.applyTweak(id: "system.toolbarTitleNoDelay", enabled: true)
        #expect(mockStore.readValue(domain: "NSGlobalDomain", key: "NSToolbarTitleViewRolloverDelay") == .double(0))

        let tooltip = manager.applyChoiceTweak(id: "system.toolTipDelay", optionID: "100 ms")
        #expect(tooltip?.selectedOptionID == "100 ms")
        #expect(mockStore.readValue(domain: "NSGlobalDomain", key: "NSInitialToolTipDelay") == .int(100))

        _ = manager.applyChoiceTweak(id: "system.powerButtonSleep", optionID: "off")
        #expect(mockStore.readValue(domain: "com.apple.loginwindow", key: "PowerButtonSleepsSystem") == .bool(false))

        _ = manager.restoreAllToDefaults()
        #expect(mockStore.readValue(domain: "com.apple.finder", key: "AnimateInfoPanes") == nil)
        #expect(mockStore.readValue(domain: "NSGlobalDomain", key: "NSInitialToolTipDelay") == nil)
        #expect(mockStore.readValue(domain: "com.apple.loginwindow", key: "PowerButtonSleepsSystem") == nil)
    }

    @Test("MoleOptimizationTask: includes extended maintenance tasks")
    func defaultOptimizationTasks() {
        let tasks = MoleOptimizationTask.defaultTasks
        #expect(tasks.count == 12)
        #expect(tasks.contains(where: { $0.kind == .spotlightIndexRebuild }))
        #expect(tasks.contains(where: { $0.kind == .diagnosticReportsPrune }))
        #expect(tasks.contains(where: { $0.kind == .localSnapshotsThin }))
        #expect(tasks.contains(where: { $0.kind == .mailEnvelopeIndexReset }))
        #expect(tasks.contains(where: { $0.kind == .cupsQueueClear }))
        #expect(tasks.contains(where: { $0.kind == .apfsVolumeVerify }))
        // Yönetici komutu isteyen DNS görevi varsayılan çalıştırmada uyarı açmasın diye seçili gelmez.
        #expect(tasks.first(where: { $0.kind == .dnsCacheFlush })?.isSelected == false)
        #expect(Set(MoleOptimizationTask.ActionKind.allCases.map(\.titleKey)).count == MoleOptimizationTask.ActionKind.allCases.count)
    }

    @Test("MoleBridge: DNS flush hands over a transparent sudo command instead of claiming success")
    func dnsFlushNeedsAdmin() async {
        let outcomes = await MoleBridge(engine: nil).runOptimizationTasks([MoleOptimizationTask(kind: .dnsCacheFlush)])
        #expect(outcomes.count == 1)
        guard case .needsAdmin(let command)? = outcomes.first?.status else {
            Issue.record("DNS flush should need an administrator command")
            return
        }
        #expect(command.contains("sudo dscacheutil -flushcache"))
        #expect(command.contains("sudo killall -HUP mDNSResponder"))
        #expect(command.hasSuffix("echo TAMAM"))
    }

    @Test("MoleBridge: stale saved states skip Apple apps, open apps and states with recently written contents")
    func staleSavedStates() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("curatare-saved-state-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let old = Date().addingTimeInterval(-40 * 24 * 60 * 60)
        func makeState(_ name: String, folderDate: Date, childDate: Date) throws {
            let folder = root.appendingPathComponent(name, isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let child = folder.appendingPathComponent("windows.plist")
            try Data("{}".utf8).write(to: child)
            try fm.setAttributes([.modificationDate: childDate], ofItemAtPath: child.path)
            try fm.setAttributes([.modificationDate: folderDate], ofItemAtPath: folder.path)
        }
        try makeState("com.example.Old.savedState", folderDate: old, childDate: old)
        try makeState("com.example.Fresh.savedState", folderDate: Date(), childDate: Date())
        try makeState("com.example.RecentlyWritten.savedState", folderDate: old, childDate: Date())
        try makeState("com.apple.Terminal.savedState", folderDate: old, childDate: old)
        try makeState("com.example.Running.savedState", folderDate: old, childDate: old)
        let note = root.appendingPathComponent("notes.txt")
        try Data("x".utf8).write(to: note)
        try fm.setAttributes([.modificationDate: old], ofItemAtPath: note.path)

        let candidates = MoleBridge.staleSavedStates(
            in: root,
            olderThan: Date().addingTimeInterval(-MoleBridge.savedStateMaxAge),
            isRunning: { $0 == "com.example.Running" }
        )
        #expect(candidates.map(\.bundleID) == ["com.example.Old"])
        #expect(candidates.first?.category == "SavedState")
        #expect(MoleOptimizationTask.defaultTasks.first(where: { $0.kind == .savedStatePrune })?.isSelected == false)
    }

    @Test("MoleOptimizationOutcome: APFS verification only succeeds when diskutil reports the volume OK")
    func apfsVerifyOutcome() {
        let ok = MoleOptimizationOutcome.apfsVerify(ProcessResult(
            exitCode: 0,
            stdout: "The volume /dev/rdisk3s1 appears to be OK\nFinished file system verification on disk3s1",
            stderr: ""
        ))
        #expect(ok.status == .done)

        let corrupt = MoleOptimizationOutcome.apfsVerify(ProcessResult(
            exitCode: 1,
            stdout: "Checking the object map\n",
            stderr: "Error: -69845: File system verify or repair failed"
        ))
        #expect(corrupt.status == .failed)
        #expect(corrupt.detail.contains("-69845"))

        // Çıkış kodu 0 olsa da "appears to be OK" satırı yoksa başarı sayılmaz.
        let unclear = MoleOptimizationOutcome.apfsVerify(ProcessResult(exitCode: 0, stdout: "Started verification", stderr: ""))
        #expect(unclear.status == .failed)
    }

    @Test("SystemSecurityStatus and HiddenSystemUtilities validation")
    func securityAndHiddenUtilities() async {
        let sec = await MoleBridge.fetchSecurityStatus()
        #expect(!sec.xprotectVersion.isEmpty)

        let utils = HiddenSystemUtility.defaultUtilities
        #expect(utils.count >= 7)
        #expect(utils.contains(where: { $0.id == "wirelessDiagnostics" }))
        #expect(utils.contains(where: { $0.id == "directoryUtility" }))
        #expect(utils.contains(where: { $0.id == "colorSyncUtility" }))
        #expect(utils.contains(where: { $0.id == "archiveUtility" }))
        #expect(utils.contains(where: { $0.id == "keychainAccess" }))
        #expect(utils.contains(where: { $0.id == "feedbackAssistant" }))
        #expect(utils.contains(where: { $0.id == "screenSharing" }))

        // Verify category icons and filter groups for audioUnits and previousMusicLibraries
        let au = HeavyCacheItem(
            category: .audioUnitsCache,
            title: "com.apple.audiounits.cache",
            ownerApp: "Audio Units",
            url: URL(fileURLWithPath: "/tmp/com.apple.audiounits.cache"),
            sizeBytes: 1024,
            explanation: "Audio Units plug-in cache"
        )
        #expect(au.filterGroup == .mediaAndWallpapers)
        #expect(au.iconName == "waveform")
        #expect(au.categoryLKey == .cachesCategoryAudioUnits)

        let music = HeavyCacheItem(
            category: .previousMusicLibraries,
            title: "Previous iTunes Libraries",
            ownerApp: "Apple Music",
            url: URL(fileURLWithPath: "/tmp/Previous iTunes Libraries"),
            sizeBytes: 2048,
            explanation: "Obsolete music backup"
        )
        #expect(music.filterGroup == .mediaAndWallpapers)
        #expect(music.iconName == "music.note.list")
        #expect(music.categoryLKey == .cachesCategoryPreviousMusicLibraries)

        let xcodeArch = HeavyCacheItem(
            category: .xcodeArchives,
            title: "Archives",
            ownerApp: "Xcode",
            url: URL(fileURLWithPath: "/tmp/XcodeArchives"),
            sizeBytes: 50000000,
            explanation: "Xcode Build Archives"
        )
        #expect(xcodeArch.filterGroup == .updatesAndInstallers)
        #expect(xcodeArch.iconName == "archivebox.circle")
        #expect(xcodeArch.categoryLKey == .cachesCategoryXcodeArchives)
    }

    @Test("FileChecksumCalculator: computes MD5, SHA-1, SHA-256 and verifies expected hash")
    func checksumCalculator() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sampleFile = tempDir.appendingPathComponent("test.txt")
        let content = "Curatare Checksum Test Data\n"
        try content.write(to: sampleFile, atomically: true, encoding: .utf8)

        let result = try FileChecksumCalculator.computeHashes(for: sampleFile)
        #expect(result.fileName == "test.txt")
        #expect(result.fileSize == Int64(content.utf8.count))
        #expect(!result.md5.isEmpty)
        #expect(!result.sha1.isEmpty)
        #expect(!result.sha256.isEmpty)

        // Verify matches
        #expect(result.verify(expected: result.md5).isMatch == true)
        #expect(result.verify(expected: result.sha1.uppercased()).isMatch == true)
        #expect(result.verify(expected: result.sha256).isMatch == true)
        #expect(result.verify(expected: "invalidhash").isMatch == false)
    }

    @Test("SystemCenterCollector: fetches hardware, memory, volumes, and OS identity")
    func systemCenterCollector() async {
        let hw = await SystemCenterCollector.fetchHardware()
        #expect(!hw.modelIdentifier.isEmpty)
        #expect(!hw.architecture.isEmpty)

        let mem = await SystemCenterCollector.fetchMemory()
        #expect(!mem.physicalMemory.isEmpty)
        #expect(mem.usedMemoryBytes > 0)

        let vols = await SystemCenterCollector.fetchVolumes()
        #expect(vols.totalCapacityBytes > 0)
        #expect(!vols.volumes.isEmpty)

        let os = await SystemCenterCollector.fetchOSAndIdentity()
        #expect(!os.osVersionAndBuild.isEmpty)
        #expect(!os.darwinKernel.isEmpty)
        #expect(!os.userName.isEmpty)
    }
}

@Suite("System Center Formatting Tests")
struct SystemCenterFormattingTests {
    @Test("Identity dump is split into lines with the caller's localized groups label")
    func identityFormatting() {
        let raw = "uid=501(kullanici) gid=20(staff) groups=20(staff),12(everyone),80(admin)"
        let tr = SystemCenterCollector.formatIdentity(raw, groupsLabel: "Gruplar:")
        #expect(tr == "uid=501(kullanici) gid=20(staff)\nGruplar:\n  • 20(staff)\n  • 12(everyone)\n  • 80(admin)")

        let ro = SystemCenterCollector.formatIdentity(raw, groupsLabel: "Grupuri:")
        #expect(ro.contains("\nGrupuri:\n"))
        #expect(!ro.contains("Gruplar"))

        // `groups=` yoksa çıktı olduğu gibi kalır.
        #expect(SystemCenterCollector.formatIdentity("uid=0(root)", groupsLabel: "Groups:") == "uid=0(root)")
    }

    @Test("Profile kinds, formats and volume kinds map to localized keys present in every table")
    func localizedTitleKeys() {
        let table = StringTable()
        let keys = SystemProfilerProfileKind.allCases.map(\.titleKey)
            + SystemProfilerFormat.allCases.map(\.titleKey)
            + [SystemCenterVolumeKind.bootSnapshot.titleKey, SystemCenterVolumeKind.data.titleKey]
        for key in keys {
            for code in AppLanguage.supportedCodes {
                let value = table.string(key, language: code)
                #expect(value != key.rawValue, "Missing \(code) translation for \(key.rawValue)")
            }
        }
        #expect(table.string(SystemProfilerProfileKind.hardware.titleKey, language: "en") == "Hardware Overview")
        #expect(table.string(SystemCenterVolumeKind.data.titleKey, language: "ro") == "Volum de date APFS")
    }

    @Test("Uninstaller leftover kinds map to distinct keys read from each language's own table")
    func uninstallerKindLabels() {
        let table = StringTable()
        let keys = AssociatedFile.LocationKind.allCases.map(\.titleKey)
        #expect(Set(keys).count == AssociatedFile.LocationKind.allCases.count)
        for key in keys {
            for code in AppLanguage.supportedCodes {
                #expect(table.string(key, language: code) != key.rawValue, "Missing \(code) translation for \(key.rawValue)")
            }
        }
        #expect(table.string(AssociatedFile.LocationKind.caches.titleKey, language: "tr") == "Önbellek")
        #expect(table.string(AssociatedFile.LocationKind.caches.titleKey, language: "en") == "Caches")
        #expect(table.string(AssociatedFile.LocationKind.caches.titleKey, language: "ro") == "Cache-uri")
    }
}

@Suite("Disk Health & Screenshot Format Tests")
struct DiskHealthAndScreenshotFormatTests {
    @Test("S.M.A.R.T. status and media name are read from diskutil info output")
    func smartStatusParsing() {
        let output = """
           Device Identifier:         disk0
           Device / Media Name:       APPLE SSD AP1024Q
           Protocol:                  Apple Fabric
           SMART Status:              Verified
        """
        #expect(SystemCenterCollector.diskInfoValue(for: "Device / Media Name", in: output) == "APPLE SSD AP1024Q")
        #expect(DiskSmartStatus(diskutilValue: SystemCenterCollector.diskInfoValue(for: "SMART Status", in: output)) == .verified)

        #expect(DiskSmartStatus(diskutilValue: "Failing") == .failing)
        #expect(DiskSmartStatus(diskutilValue: "Not Supported") == .notSupported)
        #expect(DiskSmartStatus(diskutilValue: "  ") == .unavailable)
        #expect(DiskSmartStatus(diskutilValue: "About to Fail") == .other("About to Fail"))
        // Satır yoksa durum bilinmiyor; uydurma "Doğrulandı" gösterilmez.
        #expect(DiskSmartStatus(diskutilValue: SystemCenterCollector.diskInfoValue(for: "SMART Status", in: "Protocol: USB")) == .unavailable)
    }

    @Test("Screenshot format is read, written, reset to PNG and restarts SystemUIServer")
    func screenshotFormatRoundTrip() {
        let store = MockPreferenceStore()
        let manager = SystemTweakManager(store: store)
        #expect(manager.screenshotFormat() == .png)

        manager.setScreenshotFormat(.heic)
        #expect(store.readString(domain: "com.apple.screencapture", key: "type", defaultValue: "") == "heic")
        #expect(manager.screenshotFormat() == .heic)
        #expect(store.restartedServices.last == .systemUIServer)

        // PNG seçilince anahtar silinir (macOS varsayılanı).
        manager.setScreenshotFormat(.png)
        #expect(store.readString(domain: "com.apple.screencapture", key: "type", defaultValue: "missing") == "missing")

        // Terminal ile yazılmış değerler: "jpeg" JPG sayılır, listede olmayan biçim seçici dışında kalır.
        store.writeString(domain: "com.apple.screencapture", key: "type", value: "jpeg")
        #expect(manager.screenshotFormat() == .jpg)
        store.writeString(domain: "com.apple.screencapture", key: "type", value: "tiff")
        #expect(manager.screenshotFormat() == nil)

        manager.setScreenshotFormat(.pdf)
        _ = manager.restoreAllToDefaults(restartServices: false)
        #expect(manager.screenshotFormat() == .png)
    }

    @Test("Dock spacers are added and removed through preferences, other tiles stay, nothing is written when unreadable")
    func dockSpacersThroughPreferences() {
        let store = MockPreferenceStore()
        let manager = SystemTweakManager(store: store)

        // Dock dizisi okunamıyorsa ekleme hiçbir şey yazmaz ve Dock yeniden başlatılmaz.
        #expect(manager.addDockSpacer() == false)
        #expect(store.readDictionaryArray(domain: "com.apple.dock", key: "persistent-apps") == nil)
        #expect(manager.removeDockSpacers() == false)
        #expect(store.restartedServices.isEmpty)

        let appTile: [String: Any] = ["tile-type": "file-tile", "tile-data": ["file-label": "Safari"]]
        let folderTile: [String: Any] = ["tile-type": "directory-tile", "tile-data": ["file-label": "Downloads"]]
        store.writeDictionaryArray(domain: "com.apple.dock", key: "persistent-apps", value: [appTile])
        store.writeDictionaryArray(domain: "com.apple.dock", key: "persistent-others", value: [folderTile, ["tile-type": "flex-spacer-tile"]])

        #expect(manager.addDockSpacer())
        #expect(manager.addDockSpacer(small: true))
        let added = store.readDictionaryArray(domain: "com.apple.dock", key: "persistent-apps") ?? []
        #expect(added.compactMap { $0["tile-type"] as? String } == ["file-tile", "spacer-tile", "small-spacer-tile"])
        #expect(store.restartedServices == [.dock, .dock])

        #expect(manager.removeDockSpacers())
        let apps = store.readDictionaryArray(domain: "com.apple.dock", key: "persistent-apps") ?? []
        let others = store.readDictionaryArray(domain: "com.apple.dock", key: "persistent-others") ?? []
        #expect(apps.compactMap { $0["tile-type"] as? String } == ["file-tile"])
        #expect(others.compactMap { $0["tile-type"] as? String } == ["directory-tile"])
        #expect((apps.first?["tile-data"] as? [String: Any])?["file-label"] as? String == "Safari")
        #expect(store.restartedServices == [.dock, .dock, .dock])

        // Boşluk kalmadıysa Dock yeniden başlatılmaz.
        #expect(manager.removeDockSpacers() == false)
        #expect(store.restartedServices.count == 3)
    }
}

@Suite("Duplicate Downloads Finder Tests (APFS clone aware)")
struct DuplicateFileFinderTests {
    private static let size = 256 * 1024
    private let finder = DuplicateFileFinder(minimumFileSize: 128 * 1024)

    private static func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("curatare-duplicates-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func randomData(count: Int = size) -> Data {
        Data((0..<count).map { _ in UInt8.random(in: 0...255) })
    }

    @Test("Finds independent identical copies, counts APFS clones and hard links as one copy")
    func findsDuplicatesAndMergesClones() throws {
        let fm = FileManager.default
        let folder = try Self.makeFolder()
        defer { try? fm.removeItem(at: folder) }

        let payload = Self.randomData()
        let original = folder.appendingPathComponent("setup.dmg")
        let copy = folder.appendingPathComponent("setup (1).dmg")
        let nested = folder.appendingPathComponent("Archive/setup.dmg")
        try payload.write(to: original)
        try payload.write(to: copy)
        try fm.createDirectory(at: nested.deletingLastPathComponent(), withIntermediateDirectories: true)
        try payload.write(to: nested)

        // APFS klonu: aynı veri blokları, ek yer kaplamaz
        let clone = folder.appendingPathComponent("setup copy.dmg")
        let cloned = clonefile(original.path, clone.path, 0) == 0
        try fm.setAttributes([.creationDate: Date(timeIntervalSince1970: 1_700_000_000)], ofItemAtPath: original.path)
        if cloned {
            let originalID = try #require(DuplicateFileFinder.cloneID(atPath: original.path))
            #expect(DuplicateFileFinder.cloneID(atPath: clone.path) == originalID)
            #expect(DuplicateFileFinder.cloneID(atPath: copy.path) != originalID)
        }

        // Yalnızca birbirinin klonu ve sabit bağlantısı olan dosyalar yineleme sayılmaz
        let solo = folder.appendingPathComponent("video.mov")
        try Self.randomData().write(to: solo)
        try fm.linkItem(at: solo, to: folder.appendingPathComponent("video-link.mov"))
        _ = clonefile(solo.path, folder.appendingPathComponent("video copy.mov").path, 0)

        // Eşik altı, gizli ve yarım kalmış indirmeler atlanır
        let small = Data(repeating: 7, count: 1024)
        try small.write(to: folder.appendingPathComponent("note-a.txt"))
        try small.write(to: folder.appendingPathComponent("note-b.txt"))
        try payload.write(to: folder.appendingPathComponent(".hidden.dmg"))
        try payload.write(to: folder.appendingPathComponent("setup.dmg.crdownload"))

        let result = finder.scan(directory: folder)
        #expect(result.accessDenied == false)
        #expect(result.groups.count == 1)
        let group = try #require(result.groups.first)
        #expect(group.fileSize == Int64(Self.size))
        #expect(group.sha256 == SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined())
        #expect(group.copies.count == 3)
        #expect(group.reclaimableBytes == Int64(Self.size) * 2)
        #expect(group.copies.allSatisfy { !$0.isSelected })

        // En eski kopya önde; klonu aynı satırda paylaşılan yol olarak durur
        let keeper = group.copies[0]
        #expect(keeper.url.resolvingSymlinksInPath() == original.resolvingSymlinksInPath())
        #expect(keeper.sharedURLs.map(\.lastPathComponent) == (cloned ? ["setup copy.dmg"] : []))
        let names = Set(group.copies.flatMap(\.allURLs).map(\.lastPathComponent))
        #expect(names.isSuperset(of: ["setup.dmg", "setup (1).dmg"]))
        #expect(!names.contains(".hidden.dmg") && !names.contains("setup.dmg.crdownload"))

        // Salt okunur: tarama hiçbir dosyayı taşımaz ya da değiştirmez
        for url in [original, copy, nested, solo] {
            #expect(fm.fileExists(atPath: url.path))
        }
    }

    @Test("Ignores singletons, including same-size files with different content")
    func ignoresSingletons() throws {
        let folder = try Self.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }

        try Self.randomData().write(to: folder.appendingPathComponent("a.zip"))
        try Self.randomData().write(to: folder.appendingPathComponent("b.zip"))
        try Self.randomData(count: Self.size + 1).write(to: folder.appendingPathComponent("c.zip"))

        let result = finder.scan(directory: folder)
        #expect(result.groups.isEmpty)
        #expect(result.examinedFileCount == 3)
        #expect(result.accessDenied == false)

        let missing = finder.scan(directory: folder.appendingPathComponent("Missing"))
        #expect(missing.groups.isEmpty)
        #expect(missing.accessDenied == false)
    }

    @Test("Honors cancellation before and during the scan")
    func honorsCancellation() throws {
        let folder = try Self.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let payload = Self.randomData(count: 4 << 20)
        for index in 0..<3 {
            try payload.write(to: folder.appendingPathComponent("movie-\(index).mp4"))
        }

        let token = ScanCancellationToken()
        token.cancel()
        let cancelled = finder.scan(directory: folder, isCancelled: { token.isCancelled })
        #expect(cancelled.groups.isEmpty)
        #expect(cancelled.examinedFileCount == 0)

        // İptal geldikten sonra tarama birkaç denetim içinde durur ve yarım sonuç döndürmez.
        var calls = 0
        var callsAfterCancel = 0
        let midway = finder.scan(directory: folder) {
            calls += 1
            guard calls > 4 else { return false }
            callsAfterCancel += 1
            return true
        }
        #expect(midway.groups.isEmpty)
        #expect(callsAfterCancel <= 3)
        #expect(finder.scan(directory: folder).groups.first?.copies.count == 3)
    }

    @Test("Trash candidates keep one copy and skip files that changed after the scan")
    func trashCandidatesGuardKeeper() throws {
        let fm = FileManager.default
        let folder = try Self.makeFolder()
        defer { try? fm.removeItem(at: folder) }
        let payload = Self.randomData()
        let first = folder.appendingPathComponent("report.pdf")
        let second = folder.appendingPathComponent("report (1).pdf")
        let third = folder.appendingPathComponent("report (2).pdf")
        for url in [first, second, third] {
            try payload.write(to: url)
        }

        var group = try #require(finder.scan(directory: folder).groups.first)
        for index in group.copies.indices {
            group.copies[index].isSelected = index > 0
        }
        let candidates = DuplicateFileFinder.trashCandidates(from: [group])
        #expect(candidates.urls.count == 2)
        #expect(candidates.skippedCount == 0)
        #expect(candidates.urls.map(\.size) == [Int64(Self.size), Int64(Self.size)])
        #expect(!candidates.urls.contains { $0.url.lastPathComponent == group.copies[0].url.lastPathComponent })

        // Seçili bir kopya taramadan sonra değişti: o yol alınmaz
        try Data("edited".utf8).write(to: group.copies[1].url)
        let afterEdit = DuplicateFileFinder.trashCandidates(from: [group])
        #expect(afterEdit.urls.count == 1)
        #expect(afterEdit.skippedCount == 1)

        // Tutulacak kopya silindi: grubun hiçbir kopyası alınmaz
        try fm.removeItem(at: group.copies[0].url)
        let withoutKeeper = DuplicateFileFinder.trashCandidates(from: [group])
        #expect(withoutKeeper.urls.isEmpty)
        #expect(withoutKeeper.skippedCount == 2)
    }
}

@Suite("Portable Rules Export & Import Tests (roadmap 2c)")
struct PortableRulesTests {
    private let aliceHome = URL(fileURLWithPath: "/Users/curatare-alice", isDirectory: true)
    private let bobHome = URL(fileURLWithPath: "/Users/curatare-bob", isDirectory: true)

    @Test("Round trip keeps entries, writes home paths as ~/ and opens them in the new Mac's home folder")
    func roundTripAcrossHomes() throws {
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let document = PortableRules.makeDocument(
            whitelist: ["/Users/curatare-alice/Applications/Keep.app", "/Users/curatare-alice/Documents/Keep/*", "/Volumes/Work/Shared", " ", "# yorum"],
            purgePaths: ["~/Projects", "/Users/curatare-alice/Code", "/Users/curatare-alice/Code/", "/Volumes/Work/Repos"],
            homeDirectory: aliceHome,
            exportedAt: exportedAt
        )
        #expect(document.version == PortableRulesDocument.currentVersion)
        #expect(document.whitelist == ["~/Applications/Keep.app", "~/Documents/Keep/*", "/Volumes/Work/Shared"])
        #expect(document.purgePaths == ["~/Projects", "~/Code", "/Volumes/Work/Repos"])

        let data = try PortableRules.encode(document)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["format"] as? String == PortableRulesDocument.formatIdentifier)
        #expect(json["version"] as? Int == PortableRulesDocument.currentVersion)

        let decoded = try PortableRules.decode(data)
        #expect(decoded == document)

        let validation = PortableRules.validate(decoded, homeDirectory: bobHome)
        #expect(validation.rejected.isEmpty)
        #expect(validation.whitelist == ["/Users/curatare-bob/Applications/Keep.app", "/Users/curatare-bob/Documents/Keep/*", "/Volumes/Work/Shared"])
        #expect(validation.purgePaths == ["~/Projects", "~/Code", "/Volumes/Work/Repos"])
    }

    @Test("Missing fields get defaults, unknown future fields and non-text entries are tolerated")
    func backwardAndForwardCompatibility() throws {
        let legacy = try PortableRules.decode(Data(#"{"whitelist": ["~/Keep"]}"#.utf8))
        #expect(legacy.version == 1)
        #expect(legacy.whitelist == ["~/Keep"])
        #expect(legacy.purgePaths.isEmpty)
        #expect(legacy.hasWhitelistSection)
        #expect(!legacy.hasPurgePathsSection)

        let future = try PortableRules.decode(Data("""
        {
          "format": "\(PortableRulesDocument.formatIdentifier)",
          "version": 7,
          "exportedAt": "not a date",
          "futureRules": {"nested": [1, 2, {"deep": true}]},
          "whitelist": ["~/Keep", 42, null, {"path": "~/x"}, ["~/y"]],
          "purgePaths": "~/NotAList"
        }
        """.utf8))
        #expect(future.version == 7)
        #expect(future.isNewerThanSupported)
        #expect(future.exportedAt == nil)
        #expect(future.whitelist == ["~/Keep"])
        #expect(future.nonTextWhitelistEntries == 4)
        #expect(future.hasPurgePathsSection)
        #expect(future.purgePaths.isEmpty)
        #expect(future.nonTextPurgePathEntries == 1)

        let validation = PortableRules.validate(future, homeDirectory: bobHome)
        #expect(validation.isNewerThanSupported)
        #expect(validation.whitelist == ["/Users/curatare-bob/Keep"])
        #expect(validation.rejected.filter { $0.reason == .notText }.count == 5)

        #expect(throws: PortableRulesError.unrecognizedFormat("com.example.other")) {
            try PortableRules.decode(Data(#"{"format": "com.example.other", "whitelist": []}"#.utf8))
        }
        #expect(throws: PortableRulesError.unreadable) { try PortableRules.decode(Data("not json".utf8)) }
        #expect(throws: PortableRulesError.unreadable) { try PortableRules.decode(Data(#"["~/Keep"]"#.utf8)) }
        let oversized = Data(repeating: 0x20, count: PortableRules.maximumFileSize + 1)
        #expect(throws: PortableRulesError.fileTooLarge(maximumBytes: PortableRules.maximumFileSize)) {
            try PortableRules.decode(oversized)
        }
    }

    @Test("Rejects do-not-touch entries, unsafe purge locations and malformed paths with a reason")
    func validationRejectsUnsafeEntries() {
        let document = PortableRulesDocument(
            whitelist: [
                "~/Documents/Keep",
                "/Applications/Keep.app",
                "~/Library/Caches/com.apple.Safari",
                "~/Library/Application Support/com.babadogantech.arhivar",
                "~/Library/Caches/org.sparkle-project.Sparkle",
                "~/.ssh",
                "relative/path",
                "~curatare-alice/Keep",
            ],
            purgePaths: [
                "~/Projects",
                "~/projects/",
                "/Volumes/Work/Repos",
                "~/Library/CloudStorage/Dropbox/Code",
                "~/Code/com.apple.sample",
                "~/.codex/worktrees",
                "/",
                "~",
                "/Users",
                "/Applications/Xcode.app",
                "/System/Library/Frameworks",
                "/opt/homebrew",
                "~/Library/Caches/Build",
                "~/.Trash/Curatare-2026-01-01-000000",
                "~/Projects/*",
                "~/Pro\njects",
            ]
        )
        // Kullanıcı beyaz listesi ve "izin ver" seçenekleri yok sayılır; yalnızca yerleşik liste uygulanır.
        let rules = ProtectionRules(userWhitelistPatterns: ["/Users/curatare-bob/Documents/Keep"], allowUserCacheCleaning: true)
        let validation = PortableRules.validate(document, homeDirectory: bobHome, rules: rules)

        #expect(validation.whitelist == ["/Users/curatare-bob/Documents/Keep", "/Applications/Keep.app"])
        #expect(validation.purgePaths == ["~/Projects", "/Volumes/Work/Repos", "~/Library/CloudStorage/Dropbox/Code"])

        func reason(_ section: PortableRuleRejection.Section, _ entry: String) -> PortableRuleRejection.Reason? {
            validation.rejected.first { $0.section == section && $0.entry == entry }?.reason
        }
        func isProtected(_ section: PortableRuleRejection.Section, _ entry: String) -> Bool {
            if case .protected(let detail) = reason(section, entry) { return !detail.isEmpty }
            return false
        }

        #expect(isProtected(.whitelist, "~/Library/Caches/com.apple.Safari"))
        #expect(isProtected(.whitelist, "~/Library/Application Support/com.babadogantech.arhivar"))
        #expect(isProtected(.whitelist, "~/Library/Caches/org.sparkle-project.Sparkle"))
        #expect(isProtected(.whitelist, "~/.ssh"))
        #expect(reason(.whitelist, "relative/path") == .notAbsolute)
        #expect(reason(.whitelist, "~curatare-alice/Keep") == .notAbsolute)

        #expect(isProtected(.purgePaths, "~/Code/com.apple.sample"))
        #expect(isProtected(.purgePaths, "~/.codex/worktrees"))
        for broad in ["/", "~", "/Users", "/Applications/Xcode.app", "/System/Library/Frameworks", "/opt/homebrew",
                      "~/Library/Caches/Build", "~/.Trash/Curatare-2026-01-01-000000"] {
            #expect(reason(.purgePaths, broad) == .tooBroad, "Expected \(broad) to be too broad")
        }
        #expect(reason(.purgePaths, "~/Projects/*") == .wildcardNotAllowed)
        #expect(reason(.purgePaths, "~/Pro\njects") == .invalidCharacters)
        // "~/projects/" aynı klasörün kopyasıdır; reddedilmez, yalnızca bir kez eklenir.
        #expect(reason(.purgePaths, "~/projects/") == nil)
        #expect(validation.rejected.count == 18)
        #expect(Set(validation.rejected.map(\.id)).count == validation.rejected.count)

        // Her reddetme gerekçesi ve bölüm adı çevrilmiş bir metne bağlıdır.
        let table = StringTable()
        for rejection in validation.rejected {
            for code in AppLanguage.supportedCodes {
                #expect(table.string(rejection.reason.titleKey, language: code) != rejection.reason.titleKey.rawValue)
                #expect(table.string(rejection.section.titleKey, language: code) != rejection.section.titleKey.rawValue)
            }
        }
    }

    @Test("Merge only adds new entries; replace drops entries missing from the file and keeps absent sections")
    func mergeAndReplacePlans() throws {
        let validation = PortableRules.validate(
            PortableRulesDocument(whitelist: ["~/B", "~/C"], purgePaths: ["~/Projects", "~/New"]),
            homeDirectory: bobHome
        )
        let currentWhitelist = ["/Users/curatare-bob/A", "/Users/curatare-bob/B"]
        let currentPurge = ["~/Old", "/Users/curatare-bob/Projects"]

        let merge = PortableRulesImportPlan(validation: validation, currentWhitelist: currentWhitelist, currentPurgePaths: currentPurge, mode: .merge, homeDirectory: bobHome)
        #expect(merge.whitelistToAdd == ["/Users/curatare-bob/C"])
        #expect(merge.whitelistToRemove.isEmpty)
        #expect(merge.resultingWhitelist == ["/Users/curatare-bob/A", "/Users/curatare-bob/B", "/Users/curatare-bob/C"])
        #expect(merge.purgePathsToAdd == ["~/New"])
        #expect(merge.purgePathsToRemove.isEmpty)
        #expect(merge.resultingPurgePaths == ["~/Old", "/Users/curatare-bob/Projects", "~/New"])
        #expect(merge.hasChanges)

        let replace = PortableRulesImportPlan(validation: validation, currentWhitelist: currentWhitelist, currentPurgePaths: currentPurge, mode: .replace, homeDirectory: bobHome)
        #expect(replace.whitelistToAdd == ["/Users/curatare-bob/C"])
        #expect(replace.whitelistToRemove == ["/Users/curatare-bob/A"])
        #expect(replace.resultingWhitelist == ["/Users/curatare-bob/B", "/Users/curatare-bob/C"])
        #expect(replace.purgePathsToRemove == ["~/Old"])
        #expect(replace.resultingPurgePaths == ["/Users/curatare-bob/Projects", "~/New"])

        // Dosyada purge bölümü yoksa "Değiştir" mevcut purge yollarına dokunmaz.
        let whitelistOnly = PortableRules.validate(try PortableRules.decode(Data(#"{"whitelist": ["~/B"]}"#.utf8)), homeDirectory: bobHome)
        let partial = PortableRulesImportPlan(validation: whitelistOnly, currentWhitelist: currentWhitelist, currentPurgePaths: currentPurge, mode: .replace, homeDirectory: bobHome)
        #expect(partial.whitelistToRemove == ["/Users/curatare-bob/A"])
        #expect(!partial.changesPurgePaths)
        #expect(partial.resultingPurgePaths == currentPurge)

        let unchanged = PortableRulesImportPlan(validation: validation, currentWhitelist: merge.resultingWhitelist, currentPurgePaths: merge.resultingPurgePaths, mode: .merge, homeDirectory: bobHome)
        #expect(!unchanged.hasChanges)
    }

    @Test("Mole purge_paths file keeps comments, follows a symlink and is not created for an empty list")
    func molePurgePathsFile() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("curatare-portable-\(UUID().uuidString)", isDirectory: true)
        defer { try? fm.removeItem(at: home) }
        try fm.createDirectory(at: home, withIntermediateDirectories: true)

        let file = MolePurgePathsFile(homeDirectory: home)
        #expect(file.load().isEmpty)
        try file.save([])
        #expect(!fm.fileExists(atPath: file.url.path))

        try fm.createDirectory(at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "# Mole purge paths\n~/Old\n\n  # keep this note\n/Volumes/Work\n".write(to: file.url, atomically: true, encoding: .utf8)
        #expect(file.load() == ["~/Old", "/Volumes/Work"])

        try file.save(["~/Projects", "~/New"])
        #expect(file.load() == ["~/Projects", "~/New"])
        let content = try String(contentsOf: file.url, encoding: .utf8)
        #expect(content == "# Mole purge paths\n  # keep this note\n~/Projects\n~/New\n")

        // Dotfiles deposundaki dosyaya bağlantı korunur; yazılan, bağlantının gösterdiği dosyadır.
        let dotfiles = home.appendingPathComponent("dotfiles/purge_paths")
        try fm.createDirectory(at: dotfiles.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: file.url, to: dotfiles)
        try fm.createSymbolicLink(at: file.url, withDestinationURL: dotfiles)
        try file.save(["~/Linked"])
        #expect(try fm.destinationOfSymbolicLink(atPath: file.url.path) == dotfiles.path)
        #expect(file.load() == ["~/Linked"])
        #expect(try String(contentsOf: dotfiles, encoding: .utf8).hasSuffix("~/Linked\n"))
    }
}
