// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI
import UniformTypeIdentifiers

public struct ContentView: View {
    @Bindable public var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var isDropTargeted = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        } detail: {
            ZStack {
                VStack(spacing: 0) {
                    if model.selectedSection != .home {
                        UpdateBanner(model: model)
                            .padding(.top, 8)
                            .padding(.horizontal, 16)
                        safetyHeaderBanner
                    }
                    if let event = model.smartDeleteEvent {
                        smartDeleteBanner(event)
                    }
                    if let err = model.activeErrorMessage {
                        errorBar(err)
                    }
                    detailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if model.isBusy {
                    ProgressOverlay(model: model)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                if let toast = model.toastMessage {
                    VStack {
                        Spacer()
                        ToastView(message: toast)
                            .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.2), value: model.isBusy)
            .animation(.smooth(duration: 0.25), value: model.toastMessage)
        }
        .confirmationDialog(
            model.L(.confirmTrashTitle),
            isPresented: Binding(
                get: { model.pendingTrashConfirmation != nil },
                set: { if !$0 { model.cancelPendingTrashMove() } }
            ),
            titleVisibility: .visible
        ) {
            Button(model.L(.buttonMoveToDatedTrash), role: .destructive) {
                model.executePendingTrashMove()
            }
            Button(model.L(.buttonCancel), role: .cancel) {
                model.cancelPendingTrashMove()
            }
        } message: {
            if let pending = model.pendingTrashConfirmation {
                Text(model.confirmationMessage(for: pending))
            }
        }
        .alert(
            model.alertItem?.title ?? "",
            isPresented: Binding(get: { model.alertItem != nil }, set: { if !$0 { model.alertItem = nil } }),
            presenting: model.alertItem
        ) { alert in
            if let actionTitle = alert.actionTitle, let action = alert.action {
                Button(actionTitle, action: action)
                Button(alert.cancelTitle ?? model.L(.buttonCancel), role: .cancel) { alert.cancelAction?() }
            } else {
                Button(model.L(.buttonOK)) {}
            }
        } message: { alert in
            Text(alert.message)
        }
        .navigationTitle(windowTitle)
        .navigationSubtitle(windowSubtitle)
        .toolbar { mainToolbar }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var windowTitle: String {
        switch model.selectedSection {
        case .home:
            model.L(.appName)
        default:
            model.L(model.selectedSection.titleKey)
        }
    }

    private var windowSubtitle: String {
        "Mole \(model.engineInfo?.version ?? "1.67.0") · \(model.L(.statusHealthScore)) \(model.systemStatus.healthScore)/100"
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if model.isBusy {
                Button(role: .cancel) {
                    model.cancelActiveOperation()
                } label: {
                    Label(model.L(.buttonCancel), systemImage: "xmark.circle")
                }
                .help(model.L(.buttonCancel))
                .keyboardShortcut(.cancelAction)
            } else {
                Button {
                    model.selectedSection = .libraryAudit
                    Task { await model.runLibraryAudit() }
                } label: {
                    Label(model.L(.menuScanNow), systemImage: "checklist.checked")
                }
                .help(model.L(.menuScanNow))

                Button {
                    model.selectedSection = .uninstaller
                    model.chooseBundleForUninstaller()
                } label: {
                    Label(model.L(.navUninstaller), systemImage: "trash.slash.circle")
                }
                .help(model.L(.navUninstaller))

                Button {
                    model.selectedSection = .diskAnalyzer
                    Task { await model.analyzeFolder() }
                } label: {
                    Label(model.L(.navDiskAnalyzer), systemImage: "chart.pie.fill")
                }
                .help(model.L(.navDiskAnalyzer))
            }
        }

        ToolbarSpacer(.fixed, placement: .primaryAction)

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                openWindow(id: WindowID.log)
            } label: {
                Label(model.L(.menuShowLog), systemImage: "text.alignleft")
            }
            .help(model.L(.menuShowLog))

            SettingsLink {
                Label(model.L(.buttonOpenSettings), systemImage: "gearshape")
            }
            .help(model.L(.buttonOpenSettings))
        }
    }

    private var sidebar: some View {
        List(selection: $model.selectedSection) {
            Section(model.L(.sidebarSectionStudio)) {
                ForEach([
                    StudioSection.home,
                    .libraryAudit,
                    .uninstaller,
                    .homebrew,
                    .devAndAI,
                    .browserAndCaches,
                ]) { section in
                    Label(model.L(section.titleKey), systemImage: section.systemImage)
                        .tag(section)
                }
            }
            Section(model.L(.sidebarSectionSystem)) {
                ForEach([
                    StudioSection.diskAnalyzer,
                    .systemStatus,
                    .trashHistory,
                ]) { section in
                    HStack {
                        Label(model.L(section.titleKey), systemImage: section.systemImage)
                        if section == .trashHistory && !model.trashBatches.isEmpty {
                            Spacer()
                            Text("\(model.trashBatches.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // İki cümle tek paragraf olarak akar; dar pencerede "…" ile kırpılmak yerine alt satıra sarar.
    // `fixedSize(vertical:)` kullanılmaz: dar genişlik yoklamasında metin binlerce punto yüksekliğe
    // şişip tüm pencere içeriğini (kenar çubuğu dahil) görünür alanın dışına itiyordu.
    private var safetyHeaderBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "shield.checkmark.fill")
                .foregroundStyle(.green)
                .font(.callout)
            Text(safetyBannerText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
    }

    private var safetyBannerText: AttributedString {
        var datedTrash = AttributedString(model.L(.safetyBannerDatedTrash))
        datedTrash.font = .caption.weight(.medium)
        var separator = AttributedString("  ·  ")
        separator.font = .caption
        separator.foregroundColor = .secondary
        var protected = AttributedString(model.L(.safetyBannerProtected))
        protected.font = .caption2
        protected.foregroundColor = .secondary
        return datedTrash + separator + protected
    }

    private func smartDeleteBanner(_ event: TrashedAppEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.badge.clock")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.LF(.smartDeleteBannerTitle, event.bundle.name))
                    .font(.subheadline.weight(.semibold))
                Text(model.LF(.smartDeleteBannerDetail, Int64(event.orphanedFiles.count), DiskSpace.formatBytes(event.totalOrphanBytes)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(model.L(.smartDeleteCleanButton)) {
                model.acceptSmartDeleteEvent()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.small)
            Button(model.L(.smartDeleteDismissButton)) {
                model.dismissSmartDeleteEvent()
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }

    private func errorBar(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(text)
                .font(.caption.weight(.medium))
            Spacer()
            Button(model.L(.buttonClose)) {
                model.activeErrorMessage = nil
            }
            .buttonStyle(.plain)
            .font(.caption2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.12))
    }

    @ViewBuilder
    private var detailContent: some View {
        switch model.selectedSection {
        case .home:
            WelcomeView(model: model, isDropTargeted: $isDropTargeted)
        case .libraryAudit:
            LibraryAuditView(model: model)
        case .uninstaller:
            UninstallerView(model: model)
        case .homebrew:
            HomebrewStudioView(model: model)
        case .devAndAI:
            DevAICleanupView(model: model)
        case .browserAndCaches:
            BrowserCachesView(model: model)
        case .diskAnalyzer:
            DiskAnalyzerView(model: model)
        case .systemStatus:
            SystemStatusView(model: model)
        case .trashHistory:
            TrashHistoryView(model: model)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let nsurl = item as? URL {
                url = nsurl
            } else {
                url = nil
            }
            if let url {
                Task { @MainActor in
                    model.handleDroppedURLs([url])
                }
            }
        }
        return true
    }
}

// MARK: - Karşılama Ekranı (`WelcomeView`) — Arhivar & Copiator ile Bire Bir Uyumlu

public struct WelcomeView: View {
    @Bindable public var model: AppModel
    @Binding public var isDropTargeted: Bool

    public init(model: AppModel, isDropTargeted: Binding<Bool>) {
        self.model = model
        self._isDropTargeted = isDropTargeted
    }

    public var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 16)

            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)

                Text(model.L(.welcomeTitle))
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text(model.L(.welcomeSubtitle))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 640)
            }

            moleFivePillarsGrid

            DropZone(isTargeted: isDropTargeted, model: model)
                .frame(maxWidth: 620, minHeight: 120, maxHeight: 145)
                .onTapGesture {
                    model.chooseBundleForUninstaller()
                }

            Spacer(minLength: 8)

            EngineStatusView(model: model)

            UpdateBanner(model: model)
                .frame(maxWidth: 620)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.10), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .task {
            if model.engineUpdateState == .idle && model.settings.checkUpdatesAtLaunch {
                await model.checkMoleUpdate(interactive: false)
            }
        }
    }

    private var moleFivePillarsGrid: some View {
        VStack(spacing: 12) {
            Text(model.L(.welcomePillarsHeader))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 8) {
                pillarButton(
                    title: model.L(.welcomePillarCleanTitle),
                    desc: model.L(.welcomePillarCleanDesc),
                    systemImage: "checklist.checked",
                    tint: .blue,
                    isProminent: true
                ) {
                    model.selectedSection = .libraryAudit
                    Task { await model.runLibraryAudit() }
                }

                pillarButton(
                    title: model.L(.welcomePillarUninstallTitle),
                    desc: model.L(.welcomePillarUninstallDesc),
                    systemImage: "trash.slash.circle.fill",
                    tint: .red,
                    isProminent: false
                ) {
                    model.selectedSection = .uninstaller
                }

                pillarButton(
                    title: model.L(.welcomePillarOptimizeTitle),
                    desc: model.L(.welcomePillarOptimizeDesc),
                    systemImage: "wand.and.stars",
                    tint: .purple,
                    isProminent: false
                ) {
                    model.selectedSection = .systemStatus
                }

                pillarButton(
                    title: model.L(.welcomePillarAnalyzeTitle),
                    desc: model.L(.welcomePillarAnalyzeDesc),
                    systemImage: "chart.pie.fill",
                    tint: .orange,
                    isProminent: false
                ) {
                    model.selectedSection = .diskAnalyzer
                    Task { await model.analyzeFolder() }
                }

                pillarButton(
                    title: model.L(.welcomePillarStatusTitle),
                    desc: model.L(.welcomePillarStatusDesc),
                    systemImage: "heart.text.square.fill",
                    tint: .green,
                    isProminent: false
                ) {
                    model.selectedSection = .systemStatus
                    Task { await model.refreshSystemStatus() }
                }
            }
        }
        .frame(maxWidth: 860)
    }

    private func pillarButton(
        title: String,
        desc: String,
        systemImage: String,
        tint: Color,
        isProminent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(tint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isProminent ? tint.opacity(0.4) : Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DropZone: View {
    let isTargeted: Bool
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.down.app.dashed")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                .symbolEffect(.bounce, value: isTargeted)

            Text(model.L(.welcomeDropTitle))
                .font(.headline)

            Text(model.L(.welcomeDropSubtitle))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.28),
                    style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 1.5, dash: [8, 6])
                )
        }
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .animation(.spring(duration: 0.25), value: isTargeted)
    }
}

private struct EngineStatusView: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            if let info = model.engineInfo {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(model.LF(.engineReady, info.version, Int64(model.systemStatus.healthScore)))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await model.checkMoleUpdate(interactive: true) }
                } label: {
                    Label(model.L(.updateCheck), systemImage: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.glass)
                .controlSize(.mini)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.L(.engineMissing))
                        .font(.caption.weight(.medium))
                    Text(model.L(.engineMissingDetail))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}

private struct UpdateBanner: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            appBanner
            engineBanner
        }
    }

    @ViewBuilder
    private var appBanner: some View {
        if case .available(let release) = model.appUpdateUIState {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                Text(model.LF(.appUpdateAvailable, release.version))
                    .font(.callout)

                Spacer(minLength: 8)

                Link(model.L(.appUpdateDownload), destination: release.htmlURL)
                    .buttonStyle(.glassProminent)
            }
            .padding(14)
            .frame(maxWidth: 560)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }
    }

    @ViewBuilder
    private var engineBanner: some View {
        switch model.engineUpdateState {
        case .available(let latest):
            if !model.updateBannerDismissed {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.LF(.updateBannerTitle, latest))
                            .font(.callout.weight(.semibold))
                        Text(model.LF(.updateBannerMessage, model.engineInfo?.version ?? "1.67.0"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button(model.L(.updateInstall)) {
                        Task { await model.installMoleUpdate(force: true) }
                    }
                    .buttonStyle(.glassProminent)

                    Button(model.L(.updateLater)) {
                        model.updateBannerDismissed = true
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(14)
                .frame(maxWidth: 560)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
            }
        case .installing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(model.L(.updateInstalling))
                    .font(.callout)
            }
            .padding(14)
            .glassEffect(.regular, in: .capsule)
        case .installed(let version):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(model.LF(.updateInstalled, version))
                    .font(.callout)
            }
            .padding(14)
            .glassEffect(.regular, in: .capsule)
        default:
            EmptyView()
        }
    }
}

// MARK: - Liquid Glass İlerleme Katmanı (`ProgressOverlay`) ve Bildirim (`ToastView`)

struct ProgressOverlay: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)

                Text(model.busyMessage ?? model.L(.statusScanning))
                    .font(.headline)

                Text(model.L(.safetyBannerDatedTrash))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                Button(role: .cancel) {
                    model.cancelActiveOperation()
                } label: {
                    Label(model.L(.buttonCancel), systemImage: "xmark.circle.fill")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.glass)
                .keyboardShortcut(.cancelAction)
            }
            .padding(28)
            .frame(width: 360)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
            .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
        }
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.callout.weight(.medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
    }
}
