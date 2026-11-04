// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - Mole Motoru ve GitHub Güncelleyicisi

extension AppModel {
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
}
