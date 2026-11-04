// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - SmartDelete (~/.Trash İzleyicisi)

extension AppModel {
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
                verifyRunningProcess: false,
                language: settings.resolvedLanguageCode
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
}
