// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - İptal Edilebilir İşlem Yürütücüsü

extension AppModel {
    public func cancelActiveOperation() {
        guard isBusy else { return }
        activeCancelToken?.cancel()
        activeCancelHandler?()
        activeCancelToken = nil
        activeCancelHandler = nil
        activeOperationID = nil
        isBusy = false
        isBusyInline = false
        busyMessage = nil
        syncDockProgress()
        presentPendingConsentIfIdle()
        showToast(L(.toastScanCancelled))
        log.info(.app, "Operation cancelled by user")
    }

    func performCancellableOperation<T: Sendable>(
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
        syncDockProgress()

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
                syncDockProgress()
                presentPendingConsentIfIdle()
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

    public func clearDockProgress() {
        dockProgressDelayTask?.cancel()
        dockProgressDelayTask = nil
        dockProgress.update(fraction: nil, active: false, enabled: settings.showDockProgress)
    }

    /// Etkin işlem durumunu ve `settings.showDockProgress` tercihini Dock simgesine yansıtır.
    /// Kısa süren sekme içi salt okunur taramalar için kısa bir gecikme uygular ki Dock çubuğu yanıp sönmesin.
    public func syncDockProgress(respectInlineDelay: Bool = true) {
        dockProgressDelayTask?.cancel()
        dockProgressDelayTask = nil

        guard isBusy, settings.showDockProgress else {
            dockProgress.update(fraction: nil, active: false, enabled: settings.showDockProgress)
            return
        }

        guard isBusyInline, respectInlineDelay, dockProgressInlineDelay > .zero else {
            dockProgress.update(fraction: nil, active: true, enabled: true)
            return
        }

        let delay = dockProgressInlineDelay
        dockProgressDelayTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self, self.isBusy, self.settings.showDockProgress else { return }
            self.dockProgress.update(fraction: nil, active: true, enabled: true)
        }
    }
}
