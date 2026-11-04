// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - 5. Disk Analizi (`analyze-go`) ve Yinelenen İndirmeler (`DuplicateFileFinder`)

extension AppModel {
    public var hasScannedDuplicateDownloads: Bool { duplicateScan != nil }

    public var downloadsDirectoryURL: URL { homeDirectoryURL.appendingPathComponent("Downloads", isDirectory: true) }

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

    /// `~/Downloads` okunduğunda macOS klasör izni sorar; bu yüzden yalnızca sekme açılınca ya da Tara ile çağrılır.
    public func scanDuplicateDownloads() async {
        let finder = duplicateFinder
        let folder = downloadsDirectoryURL
        await performCancellableOperation(
            message: L(.duplicatesScanning),
            inline: true,
            operation: { token in
                finder.scan(directory: folder, isCancelled: { token.isCancelled })
            },
            onComplete: { result in
                self.duplicateScan = result
                self.log.info(.audit, "Duplicate downloads scan completed: \(result.groups.count) groups in \(result.examinedFileCount) files")
            }
        )
    }

    public var selectedDuplicateCopyCount: Int {
        (duplicateScan?.groups ?? []).reduce(0) { $0 + $1.copies.filter(\.isSelected).count }
    }

    public var selectedDuplicateBytes: Int64 {
        (duplicateScan?.groups ?? []).map(\.selectedBytes).saturatingSum()
    }

    /// Bir gruptaki son seçilmemiş kopya seçilemez: her içerikten en az bir kopya yerinde kalır.
    public func canSelectDuplicateCopy(groupID: String, copyID: String) -> Bool {
        guard let group = duplicateScan?.groups.first(where: { $0.id == groupID }),
              let copy = group.copies.first(where: { $0.id == copyID }) else { return false }
        return copy.isSelected || group.copies.filter { !$0.isSelected }.count > 1
    }

    public func toggleDuplicateCopySelection(groupID: String, copyID: String) {
        guard canSelectDuplicateCopy(groupID: groupID, copyID: copyID),
              let g = duplicateScan?.groups.firstIndex(where: { $0.id == groupID }),
              let c = duplicateScan?.groups[g].copies.firstIndex(where: { $0.id == copyID }) else { return }
        duplicateScan?.groups[g].copies[c].isSelected.toggle()
    }

    /// Her grupta en eski kopya dışındaki tüm kopyalar seçili mi.
    public var allDuplicateExtrasSelected: Bool {
        guard let groups = duplicateScan?.groups, !groups.isEmpty else { return false }
        return groups.allSatisfy { group in
            group.copies.enumerated().allSatisfy { $0.element.isSelected == ($0.offset > 0) }
        }
    }

    /// Her grupta en eski kopya dışındakileri seçer; hepsi zaten seçiliyse seçimi kaldırır.
    public func toggleSelectAllDuplicateExtras() {
        guard var scan = duplicateScan, !scan.groups.isEmpty else { return }
        let select = !allDuplicateExtrasSelected
        for g in scan.groups.indices {
            for c in scan.groups[g].copies.indices {
                scan.groups[g].copies[c].isSelected = select && c > 0
            }
        }
        duplicateScan = scan
    }

    public func requestMoveDuplicatesToDatedTrash() {
        let count = selectedDuplicateCopyCount
        guard count > 0 else { return }
        if settings.confirmBeforeTrashMove {
            pendingTrashConfirmation = .duplicateDownloads(count: count, bytes: selectedDuplicateBytes)
        } else {
            moveSelectedDuplicatesToDatedTrash()
        }
    }

    /// Seçili fazla kopyaları (ve veri paylaşan klonlarını) tarihli Çöp'e taşır; dosyalar hiçbir zaman yerinde yeniden yazılmaz.
    public func moveSelectedDuplicatesToDatedTrash() {
        guard let groups = duplicateScan?.groups else { return }
        let (targets, skippedCount) = DuplicateFileFinder.trashCandidates(from: groups)
        if skippedCount > 0 {
            log.warning(.trash, "Skipped \(skippedCount) duplicate paths that changed after the scan")
        }
        guard !targets.isEmpty else {
            if skippedCount > 0 { showToast(LF(.duplicatesSkippedChanged, Int64(skippedCount))) }
            return
        }
        let candidates = targets.map { target in
            DatedTrashMoveCandidate(url: target.url, category: "DuplicateDownload", precomputedSize: target.size)
        }
        do {
            let protection = ProtectionRules(userWhitelistPatterns: settings.customWhitelistPaths)
                .localized(to: settings.resolvedLanguageCode)
            let manifest = try trashService.moveToDatedTrash(
                candidates: candidates,
                title: L(.trashTitleDuplicateDownloads),
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            let moved = Set(manifest.items.map(\.originalPath))
            if var scan = duplicateScan {
                for g in scan.groups.indices {
                    scan.groups[g].copies.removeAll { copy in copy.allURLs.contains { moved.contains($0.path) } }
                }
                scan.groups.removeAll { $0.copies.count < 2 }
                duplicateScan = scan
            }
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(skippedCount > 0
                ? LF(.duplicatesMovedWithSkipped, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id, Int64(skippedCount))
                : LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "Moved \(manifest.items.count) duplicate downloads to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }
}
