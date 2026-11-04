// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - Homebrew Paket Yöneticisi & Master-Detail

extension AppModel {
    /// `brew` yürütülebilir dosyası var mı (iki dosya varlık denetimi; tarama gerektirmez).
    public var isHomebrewAvailable: Bool { homebrewStatus.isInstalled || HomebrewScanner.locateBrew() != nil }

    public var selectedHomebrewPackage: HomebrewPackage? {
        if let id = selectedHomebrewPackageID {
            return homebrewPackages.first { $0.id == id }
        }
        return filteredHomebrewPackages.first
    }

    public var filteredHomebrewPackages: [HomebrewPackage] {
        var list = homebrewPackages
        switch homebrewPackageFilter {
        case .all:
            break
        case .formulae:
            list = list.filter { $0.kind == .formula }
        case .casks:
            list = list.filter { $0.kind == .cask }
        case .orphans:
            list = list.filter { $0.isDependency }
        }

        if !homebrewPackageSearchText.isEmpty {
            let query = homebrewPackageSearchText.trimmingCharacters(in: .whitespaces).lowercased()
            list = list.filter {
                $0.name.lowercased().contains(query) ||
                $0.id.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.version.lowercased().contains(query)
            }
        }
        return list
    }

    public var selectedHomebrewPackagesCount: Int {
        homebrewPackages.filter(\.isSelected).count
    }

    public var selectedHomebrewPackagesTotalBytes: Int64 {
        homebrewPackages.filter(\.isSelected).map(\.sizeBytes).reduce(0, +)
    }

    public func selectHomebrewPackage(_ package: HomebrewPackage) {
        selectedHomebrewPackageID = package.id
    }

    public func toggleSelectAllHomebrewPackages() {
        let allSelected = filteredHomebrewPackages.allSatisfy(\.isSelected)
        let filteredIDs = Set(filteredHomebrewPackages.map(\.id))
        for i in homebrewPackages.indices {
            if filteredIDs.contains(homebrewPackages[i].id) {
                homebrewPackages[i].isSelected = !allSelected
            }
        }
    }

    public func scanHomebrewStudio() async {
        let scanner = HomebrewScanner()
        guard scanner.brewPath != nil else {
            self.homebrewStatus = .notInstalled
            self.homebrewPackages = []
            self.hasScannedHomebrew = true
            return
        }

        await performCancellableOperation(
            inline: true,
            operation: { token in
                async let pkgsTask = scanner.scanPackages(isCancelled: { token.isCancelled })
                async let statusTask = scanner.scan(isCancelled: { token.isCancelled })
                let (packages, status) = await (pkgsTask, statusTask)
                return (status, packages)
            },
            onComplete: { (res: (HomebrewStatus, [HomebrewPackage])) in
                self.homebrewStatus = res.0
                self.homebrewPackages = res.1
                self.hasScannedHomebrew = true
                if self.selectedHomebrewPackageID == nil || !res.1.contains(where: { $0.id == self.selectedHomebrewPackageID }) {
                    self.selectedHomebrewPackageID = res.1.first?.id
                }
                self.log.info(.audit, "Homebrew studio scanned: installed=\(res.0.isInstalled), \(res.1.count) packages")
            }
        )
    }

    public func scanHomebrewPackages() async {
        await scanHomebrewStudio()
    }

    public func uninstallHomebrewPackage(_ package: HomebrewPackage, zap: Bool = false) async {
        guard homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.uninstallPackage(id: package.id, isCask: package.kind == .cask, zap: zap)
                async let remainingTask = scanner.scanPackages()
                async let statusTask = scanner.scan()
                let (remaining, status) = await (remainingTask, statusTask)
                return (remaining, status)
            },
            onComplete: { (res: ([HomebrewPackage], HomebrewStatus)) in
                self.homebrewPackages = res.0
                self.homebrewStatus = res.1
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                if self.selectedHomebrewPackageID == package.id {
                    self.selectedHomebrewPackageID = self.homebrewPackages.first?.id
                }
                self.log.info(.uninstall, "Uninstalled Homebrew package: \(package.id)")
            }
        )
    }

    public func uninstallSelectedHomebrewPackages() async {
        let selected = homebrewPackages.filter(\.isSelected)
        guard !selected.isEmpty, homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.uninstallPackages(packages: selected, zapCasks: self.homebrewZapCasks)
                async let remainingTask = scanner.scanPackages()
                async let statusTask = scanner.scan()
                let (remaining, status) = await (remainingTask, statusTask)
                return (remaining, status)
            },
            onComplete: { (res: ([HomebrewPackage], HomebrewStatus)) in
                self.homebrewPackages = res.0
                self.homebrewStatus = res.1
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                self.selectedHomebrewPackageID = self.homebrewPackages.first?.id
                self.log.info(.uninstall, "Uninstalled \(selected.count) selected Homebrew packages")
            }
        )
    }

    public func moveSelectedDevAndAIToDatedTrash() {
        var candidates: [DatedTrashMoveCandidate] = []
        for repo in repoArtifacts where repo.isSelected && !repo.containsTrackedFiles {
            candidates.append(DatedTrashMoveCandidate(
                url: repo.artifactURL,
                category: "GitHubBuild:\(repo.repoName)",
                precomputedSize: repo.sizeBytes
            ))
        }
        for ai in aiFootprintItems where ai.isSelected && !ai.isCloudOnly {
            if let url = ai.url {
                candidates.append(DatedTrashMoveCandidate(
                    url: url,
                    category: "AIFootprint:\(ai.kind.rawValue)",
                    precomputedSize: ai.sizeBytes
                ))
            }
        }
        for eco in languageEcosystemItems where eco.isSelected && !eco.isSystemProtected {
            candidates.append(DatedTrashMoveCandidate(
                url: eco.url,
                category: "Ecosystem:\(eco.ecosystem.rawValue):\(eco.toolName)",
                precomputedSize: eco.sizeBytes
            ))
        }
        guard !candidates.isEmpty else { return }

        do {
            let protection = ProtectionRules(
                userWhitelistPatterns: settings.customWhitelistPaths,
                allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps,
                allowDeveloperCacheCleaning: true
            ).localized(to: settings.resolvedLanguageCode)
            let manifest = try trashService.moveToDatedTrash(
                candidates: candidates,
                title: L(.trashTitleDevAI),
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            let moved = Set(manifest.items.map(\.originalPath))
            repoArtifacts.removeAll { moved.contains($0.artifactURL.path) }
            aiFootprintItems.removeAll { item in item.url.map { moved.contains($0.path) } ?? false }
            languageEcosystemItems.removeAll { item in moved.contains(item.url.path) }
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "Moved \(manifest.items.count) Dev/AI items to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    public func toggleSelectAllDevAndAIOverview() {
        let selectableRepos = repoArtifacts.indices.filter { !repoArtifacts[$0].containsTrackedFiles }
        let selectableAIs = aiFootprintItems.indices.filter { !aiFootprintItems[$0].isCloudOnly && aiFootprintItems[$0].url != nil }
        guard !selectableRepos.isEmpty || !selectableAIs.isEmpty else { return }

        let allSelected = selectableRepos.allSatisfy { repoArtifacts[$0].isSelected }
            && selectableAIs.allSatisfy { aiFootprintItems[$0].isSelected }
        let target = !allSelected
        for i in selectableRepos {
            repoArtifacts[i].isSelected = target
        }
        for i in selectableAIs {
            aiFootprintItems[i].isSelected = target
        }
    }

    public func requestMoveDevAndAIToDatedTrash() {
        var count = 0
        var bytes: Int64 = 0
        for repo in repoArtifacts where repo.isSelected && !repo.containsTrackedFiles {
            count += 1
            bytes = bytes.saturatingAdding(repo.sizeBytes)
        }
        for ai in aiFootprintItems where ai.isSelected && !ai.isCloudOnly {
            count += 1
            bytes = bytes.saturatingAdding(ai.sizeBytes)
        }
        for eco in languageEcosystemItems where eco.isSelected && !eco.isSystemProtected {
            count += 1
            bytes = bytes.saturatingAdding(eco.sizeBytes)
        }
        guard count > 0 else { return }
        if settings.confirmBeforeTrashMove {
            pendingTrashConfirmation = .devAI(count: count, bytes: bytes)
        } else {
            moveSelectedDevAndAIToDatedTrash()
        }
    }

    public func executePendingTrashMove() {
        guard let pending = pendingTrashConfirmation else { return }
        pendingTrashConfirmation = nil
        switch pending {
        case .auditFindings:
            moveSelectedAuditFindingsToDatedTrash()
        case .uninstall:
            uninstallSelectedBundleToDatedTrash()
        case .devAI:
            moveSelectedDevAndAIToDatedTrash()
        case .duplicateDownloads:
            moveSelectedDuplicatesToDatedTrash()
        }
    }

    public func cancelPendingTrashMove() {
        pendingTrashConfirmation = nil
    }

    public func confirmationMessage(for pending: PendingTrashConfirmation) -> String {
        switch pending {
        case .auditFindings(let count, let bytes):
            return LF(.confirmTrashMessage, Int64(count), DiskSpace.formatBytes(bytes))
        case .uninstall(let bundle, let count, let bytes):
            return LF(.confirmUninstallMessage, bundle.name, Int64(count), DiskSpace.formatBytes(bytes))
        case .devAI(let count, let bytes), .duplicateDownloads(let count, let bytes):
            return LF(.confirmTrashMessage, Int64(count), DiskSpace.formatBytes(bytes))
        }
    }
}
