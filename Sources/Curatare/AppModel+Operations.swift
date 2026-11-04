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
        busyMessage = nil
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
}
