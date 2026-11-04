// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - 6. Canlı Sistem Durumu, Bakım ve İnce Ayarlar (`status-go`, `optimize` & `SystemTweaks`) Görünümü
public struct SystemStatusView: View {
    @Bindable public var model: AppModel

    @State var selectedTweakCategory: SystemTweakCategory? = nil

    @State var screenshotNameDraft = ""
    @Environment(\.controlActiveState) var controlActiveState

    /// `status-go` bir turda ~3 sn sürer (~1,9 sn CPU); daha sık yoklama panoyu açık tutan kullanıcıda bir çekirdeği sürekli meşgul eder.
    static let liveMetricsInterval: Duration = .seconds(15)

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBar

            switch model.systemStatusSubTab {
            case .systemCenter:
                systemCenterView
            case .dashboard:
                dashboardView
            case .tweaks:
                tweaksView
            case .checksum:
                checksumCalculatorView
            }
        }
        .padding(16)
        .task {
            // Görünümden bağımsız görev: yükleme sürerken sekmeden çıkılırsa yarıda kesilmez.
            Task { await model.loadSystemStatusIfNeeded() }
        }
    }

    // Başlık + Yenile üst satırda, 4'lü segment kendi satırında: uzun tr/en/ro etiketleri
    // alt başlığın üstüne taşmaz ve Yenile düğmesinin altında kırpılmaz.
    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.L(.statusTitle))
                        .font(.title2.bold())
                    Text(model.L(.statusSubtitle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)

                if model.isLoadingSystemStatus {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 6)
                }

                Button {
                    Task { await model.refreshSystemStatus() }
                } label: {
                    Label(model.L(.buttonRefresh), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glassProminent)
                .fixedSize()
                .disabled(model.isLoadingSystemStatus)
            }

            Picker("", selection: $model.systemStatusSubTab) {
                Text(model.L(.statusTabSystemCenter)).tag(SystemStatusSubTab.systemCenter)
                Text(model.L(.statusTabDashboard)).tag(SystemStatusSubTab.dashboard)
                Text(model.L(.statusTabTweaks)).tag(SystemStatusSubTab.tweaks)
                Text(model.L(.statusTabChecksum)).tag(SystemStatusSubTab.checksum)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }
}
