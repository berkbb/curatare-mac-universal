// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - Dil ve Ekosistem Master-Detail Yönetimi

extension AppModel {
    public var systemRuntimeItems: [LanguageEcosystemItem] {
        languageEcosystemItems.filter { $0.isSystemProtected }
    }

    public var cleanableEcosystemItems: [LanguageEcosystemItem] {
        languageEcosystemItems.filter { !$0.isSystemProtected }
    }

    public var filteredCleanableEcosystemItems: [LanguageEcosystemItem] {
        guard let filter = selectedEcosystemFilter else { return cleanableEcosystemItems }
        return cleanableEcosystemItems.filter { $0.ecosystem == filter }
    }

    public var selectedEcosystemItemsCount: Int {
        cleanableEcosystemItems.filter(\.isSelected).count
    }

    public var selectedEcosystemItemsTotalBytes: Int64 {
        cleanableEcosystemItems.filter(\.isSelected).map(\.sizeBytes).reduce(0, +)
    }

    public func toggleSelectAllEcosystemItems() {
        let items = filteredCleanableEcosystemItems
        let allSelected = items.allSatisfy(\.isSelected)
        let filteredIDs = Set(items.map(\.id))
        for i in languageEcosystemItems.indices {
            if filteredIDs.contains(languageEcosystemItems[i].id) && !languageEcosystemItems[i].isSystemProtected {
                languageEcosystemItems[i].isSelected = !allSelected
            }
        }
    }

    public var selectedLanguageEcosystemItem: LanguageEcosystemItem? {
        if let id = selectedLanguageEcosystemItemID {
            return languageEcosystemItems.first { $0.id == id }
        }
        return filteredLanguageEcosystemItems.first
    }

    public var filteredLanguageEcosystemItems: [LanguageEcosystemItem] {
        var list = languageEcosystemItems

        // 1. Menşe / Koruma Ayrımı
        switch languageEcosystemOriginTab {
        case .cleanableAll:
            list = list.filter { !$0.isSystemProtected }
        case .userStandalone:
            list = list.filter { $0.origin == .userStandalone && !$0.isSystemProtected }
        case .homebrew:
            list = list.filter { $0.origin == .homebrew && !$0.isSystemProtected }
        case .macosSystem:
            list = list.filter { $0.origin == .macosSystem || $0.isSystemProtected }
        }

        // 2. Alt Ekosistem / Dil Filtresi (Yalnızca temizlenebilir sekmelerde uygulanır)
        if languageEcosystemOriginTab != .macosSystem {
            switch languageEcosystemFilter {
            case .all:
                break
            case .python:
                list = list.filter { $0.ecosystem == .python }
            case .nodeJS:
                list = list.filter { $0.ecosystem == .javascriptNode }
            case .rust:
                list = list.filter { $0.ecosystem == .rust }
            case .goLang:
                list = list.filter { $0.ecosystem == .goLang }
            case .ruby:
                list = list.filter { $0.ecosystem == .ruby }
            case .jvm:
                list = list.filter { $0.ecosystem == .jvm }
            case .dotnet:
                list = list.filter { $0.ecosystem == .dotnet }
            case .swift:
                list = list.filter { $0.ecosystem == .swift }
            case .dart:
                list = list.filter { $0.ecosystem == .dartFlutter }
            case .versionManagers:
                list = list.filter { $0.ecosystem == .versionManager }
            case .otherEcosystems:
                list = list.filter { $0.ecosystem == .otherEcosystem }
            case .systemRuntimes:
                list = list.filter { $0.isSystemProtected }
            }
        }

        // 3. Arama Metni Filtresi
        if !languageEcosystemSearchText.isEmpty {
            let q = languageEcosystemSearchText.trimmingCharacters(in: .whitespaces).lowercased()
            list = list.filter {
                $0.toolName.lowercased().contains(q) ||
                $0.path.lowercased().contains(q) ||
                $0.explanation.lowercased().contains(q) ||
                $0.ecosystem.titleTR.lowercased().contains(q) ||
                $0.origin.titleTR.lowercased().contains(q)
            }
        }
        return list
    }

    public var selectedCleanableEcosystemItemsCount: Int {
        filteredLanguageEcosystemItems.filter { !$0.isSystemProtected && $0.isSelected }.count
    }

    public var selectedCleanableEcosystemItemsTotalBytes: Int64 {
        filteredLanguageEcosystemItems.filter { !$0.isSystemProtected && $0.isSelected }.map(\.sizeBytes).reduce(0, +)
    }

    public func selectLanguageEcosystemItem(_ item: LanguageEcosystemItem) {
        selectedLanguageEcosystemItemID = item.id
    }

    public func toggleSelectAllFilteredEcosystemItems() {
        guard languageEcosystemOriginTab != .macosSystem else { return }
        let cleanable = filteredLanguageEcosystemItems.filter { !$0.isSystemProtected }
        guard !cleanable.isEmpty else { return }
        let allSelected = cleanable.allSatisfy(\.isSelected)
        let filteredIDs = Set(cleanable.map(\.id))
        for i in languageEcosystemItems.indices {
            if filteredIDs.contains(languageEcosystemItems[i].id) && !languageEcosystemItems[i].isSystemProtected {
                languageEcosystemItems[i].isSelected = !allSelected
            }
        }
    }

    public func inspectCacheSubdirectories(for item: LanguageEcosystemItem) -> [CacheSubdirectoryInfo] {
        ExtendedScanners.inspectCacheSubdirectories(at: item.url)
    }

    public func moveSingleEcosystemItemToDatedTrash(_ item: LanguageEcosystemItem) {
        guard !item.isSystemProtected else { return }
        let candidate = DatedTrashMoveCandidate(
            url: item.url,
            category: "Ecosystem:\(item.ecosystem.rawValue):\(item.toolName)",
            precomputedSize: item.sizeBytes
        )
        do {
            let protection = ProtectionRules(
                userWhitelistPatterns: settings.customWhitelistPaths,
                allowUninstallingProtectedApps: settings.allowUninstallingProtectedApps,
                allowDeveloperCacheCleaning: true
            ).localized(to: settings.resolvedLanguageCode)
            let manifest = try trashService.moveToDatedTrash(
                candidates: [candidate],
                title: LF(.trashTitleEcosystem, item.toolName),
                protectionRules: protection,
                verifyRunningProcess: settings.protectRunningApps
            )
            let moved = Set(manifest.items.map(\.originalPath))
            languageEcosystemItems.removeAll { item in moved.contains(item.url.path) }
            trashBatches = trashService.listBatches()
            if settings.playSoundEffects {
                AppSoundEffects.playTrashSound()
            }
            showToast(LF(.toastMovedToDatedTrash, Int64(manifest.items.count), DiskSpace.formatBytes(manifest.totalBytes), manifest.id))
            log.info(.trash, "Moved \(item.toolName) cache to dated Trash", detail: manifest.id)
        } catch {
            presentError(error)
        }
    }
}
