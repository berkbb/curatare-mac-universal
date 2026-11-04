// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - 3. Geliştirme ve Yapay Zekâ Temizliği

extension AppModel {
    public func scanDevAndAI() async {
        let scanners = extendedScanners.localized(to: settings.resolvedLanguageCode)
        let currentWorkspace = Bundle.main.bundleURL.deletingLastPathComponent().path
        await performCancellableOperation(
            inline: true,
            // Homebrew durumu (`brew cleanup --dry-run`, ~7 sn) burada taranmaz: bu sekme onu göstermez ve
            // Homebrew sekmesi ilk açılışta kendi taramasını yapar. Taranması sekmeyi ~11 sn'den ~3,5 sn'ye uzatıyordu.
            operation: { token in
                async let repos = scanners.scanGitHubBuildArtifacts(excludeRepoPath: currentWorkspace, isCancelled: { token.isCancelled })
                async let ai = scanners.scanAIFootprint(isCancelled: { token.isCancelled })
                async let ecosystems = scanners.scanLanguageEcosystemItems(isCancelled: { token.isCancelled })
                return await (repos, ai, ecosystems)
            },
            onComplete: { (r, a, e) in
                self.repoArtifacts = r
                self.aiFootprintItems = a
                self.languageEcosystemItems = e
                self.hasScannedDevAndAI = true
                self.hasScannedLanguageEcosystems = true
                self.log.info(.audit, "Dev & Project Artifacts scan completed: \(r.count) build dirs, \(a.count) AI items, \(e.count) ecosystem items")
            }
        )
    }

    public func scanLanguageEcosystems() async {
        let scanners = extendedScanners.localized(to: settings.resolvedLanguageCode)
        await performCancellableOperation(
            inline: true,
            operation: { token in
                scanners.scanLanguageEcosystemItems(isCancelled: { token.isCancelled })
            },
            onComplete: { items in
                self.languageEcosystemItems = items
                self.hasScannedLanguageEcosystems = true
                self.log.info(.audit, "Language ecosystems scan completed: \(items.count) items found")
            }
        )
    }

    public func executeHomebrewCleanup(pruneAll: Bool = true, scrub: Bool = true) async {
        guard homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.executeCleanup(pruneAll: pruneAll, scrub: scrub)
                return await scanner.scan()
            },
            onComplete: { (status: HomebrewStatus) in
                self.homebrewStatus = status
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                self.log.info(.engine, "Homebrew cleanup completed (pruneAll: \(pruneAll), scrub: \(scrub))")
            }
        )
    }

    public func executeHomebrewAutoremove() async {
        guard homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.executeAutoremove()
                return await scanner.scan()
            },
            onComplete: { (status: HomebrewStatus) in
                self.homebrewStatus = status
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                self.log.info(.engine, "Homebrew autoremove completed")
            }
        )
    }

    public func executeHomebrewServicesCleanup() async {
        guard homebrewStatus.isInstalled else { return }
        await performCancellableOperation(
            operation: { _ in
                let scanner = HomebrewScanner()
                _ = try? await scanner.executeServicesCleanup()
                return await scanner.scan()
            },
            onComplete: { (status: HomebrewStatus) in
                self.homebrewStatus = status
                if self.settings.playSoundEffects {
                    AppSoundEffects.playTrashSound()
                }
                self.log.info(.engine, "Homebrew services cleanup completed")
            }
        )
    }
}
