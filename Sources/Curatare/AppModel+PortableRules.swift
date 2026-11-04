// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - Taşınabilir Kurallar (özel koruma listesi ve Mole purge yolları)

extension AppModel {
    /// Mole'un purge yolları dosyası; testlerde geçici ev klasörüne yönelir.
    public var molePurgePathsFile: MolePurgePathsFile { MolePurgePathsFile(homeDirectory: homeDirectoryURL) }

    /// Özel koruma listesini ve Mole purge yollarını taşınabilir JSON olarak yazar.
    public func exportPortableRules(to url: URL) throws {
        let document = PortableRules.makeDocument(
            whitelist: settings.customWhitelistPaths,
            purgePaths: molePurgePathsFile.load(),
            homeDirectory: homeDirectoryURL
        )
        try PortableRules.encode(document).write(to: url, options: .atomic)
        log.info(.app, "Portable rules exported (\(document.whitelist.count) whitelist, \(document.purgePaths.count) purge paths)", detail: url.path)
    }

    /// Dosyayı okur ve her girişi yerleşik koruma listesine karşı denetler; hiçbir ayarı değiştirmez.
    public func validatePortableRules(at url: URL) throws -> PortableRulesValidation {
        let document = try PortableRules.readDocument(at: url)
        let rules = ProtectionRules().localized(to: settings.resolvedLanguageCode)
        return PortableRules.validate(document, homeDirectory: homeDirectoryURL, rules: rules)
    }

    public func portableRulesImportPlan(for validation: PortableRulesValidation, mode: PortableRulesImportMode) -> PortableRulesImportPlan {
        PortableRulesImportPlan(
            validation: validation,
            currentWhitelist: settings.customWhitelistPaths,
            currentPurgePaths: molePurgePathsFile.load(),
            mode: mode,
            homeDirectory: homeDirectoryURL
        )
    }

    /// Onaylanan planı uygular: yalnızca koruma listesi ayarı ve Mole purge yolları dosyası değişir,
    /// hiçbir dosya silinmez veya taşınmaz. Yazılması başarısız olabilecek purge dosyası önce yazılır.
    public func applyPortableRulesImport(_ plan: PortableRulesImportPlan) throws {
        if plan.changesPurgePaths {
            try molePurgePathsFile.save(plan.resultingPurgePaths)
        }
        if plan.changesWhitelist {
            settings.customWhitelistPaths = plan.resultingWhitelist
        }
        log.info(
            .app,
            "Portable rules imported (\(plan.mode.rawValue)): whitelist +\(plan.whitelistToAdd.count) -\(plan.whitelistToRemove.count), purge paths +\(plan.purgePathsToAdd.count) -\(plan.purgePathsToRemove.count)"
        )
    }

    /// Taşınabilir kural hatalarının kullanıcının dilindeki açıklaması.
    public func portableRulesErrorMessage(_ error: Error) -> String {
        switch error {
        case PortableRulesError.fileTooLarge(let maximumBytes):
            LF(.rulesErrorTooLarge, DiskSpace.formatBytes(Int64(maximumBytes)))
        case PortableRulesError.unreadable:
            L(.rulesErrorUnreadable)
        case PortableRulesError.unrecognizedFormat(let format):
            LF(.rulesErrorUnrecognizedFormat, format)
        default:
            error.localizedDescription
        }
    }

    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func quickLookPreview(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    public func showToast(_ text: String) {
        toastMessage = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            if self?.toastMessage == text {
                self?.toastMessage = nil
            }
        }
    }

    public func presentError(_ error: Error) {
        switch error {
        case DatedTrashError.protectedTarget(let path, let reason):
            activeErrorMessage = LF(.errorProtectedTarget, path, reason)
        case DatedTrashError.processRunning(let name, let path):
            activeErrorMessage = LF(.errorProcessRunning, name, path)
        default:
            activeErrorMessage = error.localizedDescription
        }
        log.error(.app, "Operation failed", detail: activeErrorMessage)
    }
}
