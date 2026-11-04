// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

public enum StudioSection: String, CaseIterable, Identifiable, Sendable {
    case home
    case libraryAudit
    case uninstaller
    case homebrew
    case devAndAI
    case browserAndCaches
    case diskAnalyzer
    case systemStatus
    case trashHistory

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .home: "house"
        case .libraryAudit: "checklist.checked"
        case .uninstaller: "trash.slash.circle"
        case .homebrew: "mug.fill"
        case .devAndAI: "hammer.circle"
        case .browserAndCaches: "globe.badge.chevron.backward"
        case .diskAnalyzer: "chart.pie.fill"
        case .systemStatus: "gauge.with.dots.needle.67percent"
        case .trashHistory: "clock.arrow.circlepath"
        }
    }

    public var titleKey: LKey {
        switch self {
        case .home: .navHome
        case .libraryAudit: .navLibraryAudit
        case .uninstaller: .navUninstaller
        case .homebrew: .navHomebrew
        case .devAndAI: .navDevAndAI
        case .browserAndCaches: .navBrowserAndCaches
        case .diskAnalyzer: .navDiskAnalyzer
        case .systemStatus: .navSystemStatus
        case .trashHistory: .navTrashHistory
        }
    }
}

public enum EngineUpdateUIState: Sendable, Equatable {
    case idle
    case checking
    case installing
    case upToDate(String)
    case available(latest: String)
    case installed(String)
    case failed(String)
}

public enum AppUpdateUIState: Sendable, Equatable {
    case idle
    case checking
    case upToDate(String)
    case available(latest: AppRelease)
    case noReleases(repo: String)
    case failed(String)
    case unconfigured
}

public enum PendingTrashConfirmation: Sendable, Equatable {
    case auditFindings(count: Int, bytes: Int64)
    case uninstall(bundle: InstalledBundle, count: Int, bytes: Int64)
    case devAI(count: Int, bytes: Int64)
    case duplicateDownloads(count: Int, bytes: Int64)
}

public enum DevAISubTab: String, CaseIterable, Sendable {
    case overview
    case languageEcosystems
}

/// Disk Analizi alt sekmeleri. Bilerek kaydedilmez: İndirilenler taraması (macOS klasör izni ister)
/// açılışta geri yüklenen bir sekmeden değil, yalnızca kullanıcı bu oturumda sekmeyi açınca başlar.
public enum DiskAnalyzerSubTab: String, CaseIterable, Sendable {
    case usage
    case duplicateDownloads
}

public enum LanguageEcosystemOriginTab: String, CaseIterable, Sendable {
    case cleanableAll
    case userStandalone
    case homebrew
    case macosSystem
}

public struct AlertItem: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let actionTitle: String?
    public let action: (@Sendable () -> Void)?
    public let cancelTitle: String?
    public let cancelAction: (@Sendable () -> Void)?

    public init(
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (@Sendable () -> Void)? = nil,
        cancelTitle: String? = nil,
        cancelAction: (@Sendable () -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.cancelTitle = cancelTitle
        self.cancelAction = cancelAction
    }
}
