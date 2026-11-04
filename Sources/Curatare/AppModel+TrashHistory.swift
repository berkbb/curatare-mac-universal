// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - 7. Tarihli Çöp Turları ve Geri Yükleme

extension AppModel {
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
                displayTitle(for: $0).lowercased().contains(q) ||
                $0.batchDirectoryPath.lowercased().contains(q) ||
                $0.items.contains(where: { $0.trashedRelativePath.lowercased().contains(q) || $0.originalPath.lowercased().contains(q) })
            }
        }
        return list
    }

    /// Çöp turu başlığı kullanıcının dilinde. Bu sürümden önce kaydedilen turların başlıkları İngilizce saklandı;
    /// bilinen eski başlıklar çeviri anahtarlarına eşlenir. Yeni turlar zaten çevrilmiş başlıkla kaydedilir.
    public func displayTitle(for batch: TrashBatchManifest) -> String {
        let legacy: [String: LKey] = [
            "Library Audit (Groups A–E)": .trashTitleLibraryAudit,
            "Developer & AI Cleanup": .trashTitleDevAI,
            "Browser & Heavy Caches Cleanup": .trashTitleBrowserCaches,
            "Saved Application State Prune": .trashTitleSavedState,
            "Diagnostic Reports Prune": .trashTitleDiagnosticReports,
            "Apple Mail Envelope Index Reset": .trashTitleMailEnvelopeIndex
        ]
        if let key = legacy[batch.title] { return L(key) }
        for (prefix, key) in [("Ecosystem Cleanup: ", LKey.trashTitleEcosystem), ("Uninstall ", LKey.trashTitleUninstall)]
        where batch.title.hasPrefix(prefix) {
            return LF(key, String(batch.title.dropFirst(prefix.count)))
        }
        return batch.title
    }

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
}
