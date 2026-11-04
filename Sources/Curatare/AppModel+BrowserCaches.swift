// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - 4. Tarayıcı, Önbellekler ve Time Machine

extension AppModel {
    public var filteredHeavyCaches: [HeavyCacheItem] {
        heavyCacheItems.filter { item in
            if selectedCacheFilterGroup != .all && item.filterGroup != selectedCacheFilterGroup {
                return false
            }
            if let cat = selectedCacheCategory, item.category != cat {
                return false
            }
            return true
        }
    }

    public func scanBrowserAndCaches() async {
        let scanners = extendedScanners.localized(to: settings.resolvedLanguageCode)
        let language = settings.resolvedLanguageCode
        await performCancellableOperation(
            inline: true,
            operation: { token in
                let caches = scanners.scanHeavyCachesAndInstallers(language: language, isCancelled: { token.isCancelled })
                guard !token.isCancelled else { return ([HeavyCacheItem](), [TimeMachineSnapshot]()) }
                let snapshots = await scanners.listTimeMachineSnapshots()
                return (caches, snapshots)
            },
            onComplete: { (caches, snapshots) in
                self.heavyCacheItems = caches
                self.timeMachineSnapshots = snapshots
            }
        )
    }

    public func toggleSelectAllHeavyCaches() {
        let items = filteredHeavyCaches
        guard !items.isEmpty else { return }
        let allSelected = items.allSatisfy(\.isSelected)
        let target = !allSelected
        let itemIDs = Set(items.map(\.id))
        for i in heavyCacheItems.indices where itemIDs.contains(heavyCacheItems[i].id) {
            heavyCacheItems[i].isSelected = target
        }
    }

    public func moveSelectedCachesToDatedTrash() {
        let selected = filteredHeavyCaches.filter(\.isSelected)
        guard !selected.isEmpty else { return }
        let activeGradle = extendedScanners.discoverActiveGradleVersions()
        let protection = ProtectionRules(
            activeGradleVersions: activeGradle,
            userWhitelistPatterns: settings.customWhitelistPaths,
            allowDeveloperCacheCleaning: true,
            allowUserCacheCleaning: true
        ).localized(to: settings.resolvedLanguageCode)
        let candidates = selected.map { item in
            DatedTrashMoveCandidate(
                url: item.url,
                category: "HeavyCache:\(item.category.rawValue)",
                processName: item.processToVerify,
                precomputedSize: item.sizeBytes
            )
        }

        do {
            let manifest = try trashService.moveToDatedTrash(
                candidates: candidates,
                title: L(.trashTitleBrowserCaches),
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            let moved = Set(manifest.items.map(\.originalPath))
            heavyCacheItems.removeAll { moved.contains($0.url.path) }
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "Moved \(manifest.items.count) cache items to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    public func thinTimeMachineSnapshots() async {
        let scanners = extendedScanners.localized(to: settings.resolvedLanguageCode)
        await performCancellableOperation(
            operation: { token in
                _ = try? await scanners.thinTimeMachineSnapshots()
                guard !token.isCancelled else { return [TimeMachineSnapshot]() }
                return await scanners.listTimeMachineSnapshots()
            },
            onComplete: { snapshots in
                self.timeMachineSnapshots = snapshots
            }
        )
    }
}
