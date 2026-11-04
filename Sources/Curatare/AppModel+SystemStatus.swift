// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - 6. Sistem Durumu, Bakım ve İnce Ayarlar (`status-go`, `optimize` & `SystemTweaks`)

extension AppModel {
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
        guard tweakManager.addDockSpacer(small: small) else {
            showToast(L(.toastDockSpacerFailed))
            log.warning(.engine, "Dock preferences could not be read; spacer not added")
            return
        }
        showToast(L(.toastDockSpacerAdded))
        log.info(.engine, "Added spacer to Dock (small: \(small))")
    }

    public func removeDockSpacers() {
        guard tweakManager.removeDockSpacers() else {
            showToast(L(.toastNoDockSpacers))
            return
        }
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
        screenshotLocation = tweakManager.screenshotLocation()
        refreshSafariDevelopMenuState()
    }

    public func refreshSafariDevelopMenuState() {
        safariDevelopMenuShown = tweakManager.safariDevelopMenuShown()
    }

    /// Geliştir menüsü Safari'nin kendi ayarından değiştirilir; burada yalnızca Safari açılır.
    public func openSafari() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SafariDevelopMenu.bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// `nil` kayıt klasörünü macOS varsayılanına (Masaüstü) döndürür.
    public func setScreenshotLocation(_ path: String?) {
        tweakManager.setScreenshotLocation(path)
        screenshotLocation = tweakManager.screenshotLocation()
        showToast(LF(.toastTweakApplied, L(.tweakScreenshotLocationTitle)))
        log.info(.engine, "Screenshot location updated")
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
        screenshotLocation = tweakManager.screenshotLocation()
        safariDevelopMenuShown = tweakManager.safariDevelopMenuShown()
        showToast(L(.toastTweaksReset))
        log.info(.engine, "All system tweaks reset to defaults")
    }

    public func runSelectedOptimizations() async {
        let bridge = MoleBridge(engine: engineInfo)
        let tasks = optimizationTasks
        let language = settings.resolvedLanguageCode
        await performCancellableOperation(
            operation: { _ in
                await bridge.runOptimizationTasks(tasks, language: language)
            },
            onComplete: { outcomes in
                self.reportOptimizationOutcomes(outcomes)
                await self.refreshSystemStatus()
            }
        )
    }

    /// Tamamlanan görevleri bildirimle sayar; başarısız görevleri ve yönetici komutu gerekenleri tek uyarıda gösterir.
    func reportOptimizationOutcomes(_ outcomes: [MoleOptimizationOutcome]) {
        var failedTitles: [String] = []
        var adminCommands: [String] = []
        for outcome in outcomes {
            switch outcome.status {
            case .done:
                log.info(.engine, outcome.detail)
            case .failed:
                log.warning(.engine, outcome.detail)
                failedTitles.append(L(outcome.kind.titleKey))
            case .needsAdmin(let command):
                log.info(.engine, outcome.detail)
                adminCommands.append(command)
            }
        }
        let doneCount = outcomes.filter { $0.status == .done }.count
        let needsAttention = !failedTitles.isEmpty || !adminCommands.isEmpty
        // Hiçbir görev tamamlanmadıysa uyarının arkasında "0 bakım görevi tamamlandı" gösterilmez.
        if doneCount > 0 || !needsAttention {
            showToast(LF(.toastOptimizationDone, Int64(doneCount)))
        }

        guard needsAttention else { return }
        var lines = failedTitles.map { LF(.optimizeFailedLine, $0) }
        guard !adminCommands.isEmpty else {
            alertItem = AlertItem(title: L(.optimizeAttentionTitle), message: lines.joined(separator: "\n\n"))
            return
        }
        let command = adminCommands.joined(separator: "\n")
        lines.append(LF(.optimizeAdminLine, command))
        alertItem = AlertItem(
            title: L(.optimizeAttentionTitle),
            message: lines.joined(separator: "\n\n"),
            actionTitle: L(.optimizeCopyCommand),
            action: { [weak self] in
                Task { @MainActor in
                    guard let self else { return }
                    self.copyToClipboard(command, label: self.L(.optimizeCommandCopied))
                }
            },
            cancelTitle: L(.buttonClose),
            cancelAction: {}
        )
    }
}
