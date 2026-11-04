// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - 2. Uygulama Kaldırıcı

extension AppModel {
    public var filteredBundles: [InstalledBundle] {
        var byKind = installedBundles.filter { $0.kind == selectedUninstallerKind }
        if !settings.showProtectedApps {
            byKind = byKind.filter { !$0.isProtected }
        }
        let q = uninstallerSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return byKind }
        return byKind.filter {
            $0.name.lowercased().contains(q) || $0.bundleID.lowercased().contains(q) || $0.url.path.lowercased().contains(q)
        }
    }

    public var selectedBundle: InstalledBundle? {
        guard let id = selectedBundleID else { return nil }
        return installedBundles.first { $0.id == id }
    }

    public func scanUninstallerBundles() async {
        let uninstaller = appUninstaller
        let whitelist = settings.customWhitelistPaths
        let allowProtected = settings.allowUninstallingProtectedApps
        let language = settings.resolvedLanguageCode
        await performCancellableOperation(
            inline: true,
            operation: { token in
                let protection = ProtectionRules(
                    userWhitelistPatterns: whitelist,
                    allowUninstallingProtectedApps: allowProtected
                ).localized(to: language)
                // Liste paket boyutunu göstermez; boyut, seçilen paket incelenirken `discoverAssociatedFiles`
                // içinde hesaplanır. Tüm paketleri baştan gezmek (Xcode ~10 GB) listeyi ~30 sn geciktiriyordu.
                return uninstaller.scanInstalledBundles(
                    protectionRules: protection,
                    computeBundleSizes: false,
                    isCancelled: { token.isCancelled }
                )
            },
            onComplete: { bundles in
                self.installedBundles = bundles
                self.hasScannedUninstaller = true
                if let id = self.selectedBundleID, let existing = self.installedBundles.first(where: { $0.id == id }) {
                    self.selectBundle(existing)
                } else if let first = self.filteredBundles.first {
                    self.selectBundle(first)
                }
            }
        )
    }

    public func selectBundle(_ bundle: InstalledBundle) {
        selectedBundleID = bundle.id
        inspectingBundle = bundle
        isInspectingBundleLoading = true
        associatedFiles = []

        inspectionTask?.cancel()
        let uninstaller = appUninstaller
        let protection = ProtectionRules(
            userWhitelistPatterns: settings.customWhitelistPaths,
            allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps
        ).localized(to: settings.resolvedLanguageCode)
        inspectionTask = Task { @MainActor [weak self] in
            let files = await Task.detached(priority: .userInitiated) {
                uninstaller.discoverAssociatedFiles(
                    for: bundle,
                    includeBundleItself: true,
                    protectionRules: protection,
                    isCancelled: { Task.isCancelled }
                )
            }.value

            guard !Task.isCancelled, let self, self.inspectingBundle?.id == bundle.id else { return }
            self.associatedFiles = files
            self.isInspectingBundleLoading = false
        }
    }

    public func closeInspection() {
        inspectionTask?.cancel()
        inspectionTask = nil
        isInspectingBundleLoading = false
        if let droppedID = lastDroppedBundleID {
            installedBundles.removeAll { $0.id == droppedID }
            lastDroppedBundleID = nil
        }
        inspectingBundle = nil
        selectedBundleID = nil
        associatedFiles = []
    }

    public func handleDroppedURLs(_ urls: [URL]) {
        guard let first = urls.first else { return }
        selectedSection = .uninstaller
        let protection = ProtectionRules(
            userWhitelistPatterns: settings.customWhitelistPaths,
            allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps
        ).localized(to: settings.resolvedLanguageCode)
        let ext = first.pathExtension.lowercased()
        let kind: BundleKind = (ext == "wdgt" || ext == "appex") ? .widget : (ext == "app" ? .application : .plugin)
        guard let inspected = appUninstaller.inspectBundle(at: first, kind: kind, protectionRules: protection) else { return }
        if !installedBundles.contains(where: { $0.id == inspected.id }) {
            installedBundles.insert(inspected, at: 0)
            lastDroppedBundleID = inspected.id
        }
        selectedUninstallerKind = inspected.kind
        selectBundle(inspected)
        log.info(.uninstall, "Loaded bundle into uninstaller", detail: inspected.url.path)
    }

    public func toggleAssociatedFileSelection(id: String) {
        if let idx = associatedFiles.firstIndex(where: { $0.id == id }) {
            associatedFiles[idx].isSelected.toggle()
        }
    }

    public func requestUninstallSelectedBundleToDatedTrash() {
        guard let bundle = inspectingBundle ?? selectedBundle, !bundle.isProtected else { return }
        let selected = associatedFiles.filter { $0.isSelected && !$0.requiresSudo }
        guard !selected.isEmpty else { return }
        let total = selected.map(\.sizeBytes).saturatingSum()
        if settings.confirmBeforeTrashMove {
            pendingTrashConfirmation = .uninstall(bundle: bundle, count: selected.count, bytes: total)
        } else {
            uninstallSelectedBundleToDatedTrash()
        }
    }

    public func uninstallSelectedBundleToDatedTrash() {
        guard let bundle = inspectingBundle ?? selectedBundle, !bundle.isProtected else { return }
        if settings.protectRunningApps && bundle.isRunning {
            presentError(DatedTrashError.processRunning(name: bundle.name, path: bundle.url.path))
            return
        }
        do {
            let protection = ProtectionRules(
                userWhitelistPatterns: settings.customWhitelistPaths,
                allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps
            ).localized(to: settings.resolvedLanguageCode)
            let manifest = try appUninstaller.uninstallToDatedTrash(
                bundle: bundle,
                associatedFiles: associatedFiles,
                trashService: trashService,
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps,
                language: settings.resolvedLanguageCode
            )
            installedBundles.removeAll { $0.id == bundle.id }
            inspectingBundle = nil
            selectedBundleID = filteredBundles.first?.id
            associatedFiles = []
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.uninstall, "Uninstalled \(bundle.name) to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }

    public func quitRunningApp(_ bundle: InstalledBundle) {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            ($0.bundleIdentifier?.caseInsensitiveCompare(bundle.bundleID) == .orderedSame) ||
            ($0.bundleURL?.path == bundle.url.path)
        }) {
            app.terminate()
            showToast(LF(.toastAppTerminated, bundle.name))
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await scanUninstallerBundles()
            }
        }
    }
}
