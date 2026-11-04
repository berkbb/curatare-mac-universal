// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - 1. Library Denetimi (A–E)

extension AppModel {
    public var filteredAuditFindings: [LibraryFinding] {
        guard let report = auditReport else { return [] }
        let byGroup = selectedAuditGroup.map { report.findings(for: $0) } ?? report.findings
        let q = auditSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return byGroup }
        return byGroup.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.matchedIdentifier.lowercased().contains(q) ||
            $0.librarySubfolder.lowercased().contains(q) ||
            $0.explanation.lowercased().contains(q)
        }
    }

    public func toggleAuditFindingSelection(id: String) {
        guard let report = auditReport else { return }
        var updated = report.findings
        if let idx = updated.firstIndex(where: { $0.id == id }) {
            updated[idx].isSelected.toggle()
            auditReport = LibraryAuditReport(
                scannedAt: report.scannedAt,
                installedCount: report.installedCount,
                findings: updated,
                orphanedReceipts: report.orphanedReceipts,
                sudoCommand: report.sudoCommand
            )
        }
    }

    public func setAllAuditFindingsSelected(_ selected: Bool) {
        guard let report = auditReport else { return }
        let visibleIDs = Set(filteredAuditFindings.map(\.id))
        let updated = report.findings.map { item -> LibraryFinding in
            var copy = item
            if visibleIDs.contains(item.id) && !item.requiresSudo {
                copy.isSelected = selected
            }
            return copy
        }
        auditReport = LibraryAuditReport(
            scannedAt: report.scannedAt,
            installedCount: report.installedCount,
            findings: updated,
            orphanedReceipts: report.orphanedReceipts,
            sudoCommand: report.sudoCommand
        )
    }

    public func runLibraryAudit() async {
        let scanner = libraryScanner.localized(to: settings.resolvedLanguageCode)
        let whitelist = settings.customWhitelistPaths
        await performCancellableOperation(
            inline: true,
            operation: { token in
                scanner.scanAll(customWhitelist: whitelist, isCancelled: { token.isCancelled })
            },
            onComplete: { report in
                self.auditReport = report
                self.log.info(.audit, "Library audit completed: \(report.findings.count) findings (\(DiskSpace.formatBytes(report.totalReclaimableBytes)))")
            }
        )
    }

    public func moveSelectedAuditFindingsToDatedTrash() {
        guard let report = auditReport else { return }
        let selected = report.findings.filter { $0.isSelected && !$0.requiresSudo }
        guard !selected.isEmpty else { return }

        let candidates = selected.map { f in
            DatedTrashMoveCandidate(
                url: f.url,
                category: "LibraryAudit:Group\(f.group.rawValue):\(f.librarySubfolder)",
                bundleID: f.matchedIdentifier,
                precomputedSize: f.sizeBytes
            )
        }

        do {
            let protection = ProtectionRules(
                userWhitelistPatterns: settings.customWhitelistPaths,
                allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps
            ).localized(to: settings.resolvedLanguageCode)
            let manifest = try trashService.moveToDatedTrash(
                candidates: candidates,
                title: L(.trashTitleLibraryAudit),
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            let movedPaths = Set(manifest.items.map(\.originalPath))
            let remaining = report.findings.filter { !movedPaths.contains($0.url.path) }
            auditReport = LibraryAuditReport(
                scannedAt: Date(),
                installedCount: report.installedCount,
                findings: remaining,
                orphanedReceipts: report.orphanedReceipts,
                sudoCommand: LibraryScanner.generateSudoCommand(for: remaining, orphanedReceipts: report.orphanedReceipts)
            )
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "Moved \(manifest.items.count) Library items to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    public func requestMoveAuditFindingsToDatedTrash() {
        guard let report = auditReport else { return }
        let selected = report.findings.filter { $0.isSelected && !$0.requiresSudo }
        guard !selected.isEmpty else { return }
        let total = selected.map(\.sizeBytes).saturatingSum()
        if settings.confirmBeforeTrashMove {
            pendingTrashConfirmation = .auditFindings(count: selected.count, bytes: total)
        } else {
            moveSelectedAuditFindingsToDatedTrash()
        }
    }
}
