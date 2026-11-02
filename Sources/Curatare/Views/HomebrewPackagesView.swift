// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

/// Homebrew Stüdyosu: Sistem Homebrew durum kartları, bakım kısayolları ve Master-Detail paket yöneticisi.
public struct HomebrewStudioView: View {
    @Bindable public var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBar

            // `homebrewStatus` ilk tarama bitene kadar `.notInstalled` varsayılanındadır; o sürede
            // "Homebrew kurulu değil" kartı yerine yükleme göstergesi gösterilir.
            if model.hasScannedHomebrew && !model.homebrewStatus.isInstalled {
                notInstalledCard
            } else if !model.hasScannedHomebrew && model.isBusy {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                maintenanceAndStatsHeader
                HomebrewPackagesMasterDetailView(model: model)
            }
        }
        .padding(16)
        .loadOnFirstVisit(isLoaded: model.hasScannedHomebrew, isBusy: model.isBusy) {
            await model.scanHomebrewStudio()
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.L(.homebrewStudioTitle))
                    .font(.title2.bold())
                Text(model.L(.homebrewStudioSubtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if model.isBusy {
                Button(role: .cancel) {
                    model.cancelActiveOperation()
                } label: {
                    Label(model.L(.buttonCancel), systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.glass)
            } else {
                Button {
                    Task { await model.scanHomebrewStudio() }
                } label: {
                    Label(model.L(.buttonRefresh), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private var notInstalledCard: some View {
        ContentUnavailableView {
            Label(model.L(.homebrewNotInstalledTitle), systemImage: "mug")
        } description: {
            Text(model.L(.homebrewNotInstalledDesc))
        } actions: {
            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "https://brew.sh") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(model.L(.homebrewInstallSiteButton), systemImage: "safari")
                }
                .buttonStyle(.glassProminent)

                Button {
                    Task { await model.scanHomebrewStudio() }
                } label: {
                    Label(model.L(.buttonRefresh), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private var maintenanceAndStatsHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                statCard(
                    title: "Homebrew",
                    value: model.homebrewStatus.version ?? "v4.x",
                    subtitle: model.homebrewStatus.executableURL?.path ?? "/opt/homebrew/bin/brew",
                    icon: "mug.fill",
                    color: .orange
                )

                statCard(
                    title: model.L(.homebrewFilterFormulae),
                    value: "\(model.homebrewPackages.filter { $0.kind == .formula }.count)",
                    subtitle: DiskSpace.formatBytes(model.homebrewPackages.filter { $0.kind == .formula }.map(\.sizeBytes).reduce(0, +)),
                    icon: "terminal",
                    color: .orange
                )

                statCard(
                    title: model.L(.homebrewFilterCasks),
                    value: "\(model.homebrewPackages.filter { $0.kind == .cask }.count)",
                    subtitle: DiskSpace.formatBytes(model.homebrewPackages.filter { $0.kind == .cask }.map(\.sizeBytes).reduce(0, +)),
                    icon: "macwindow",
                    color: .blue
                )

                statCard(
                    title: model.L(.homebrewFilterOrphans),
                    value: "\(model.homebrewPackages.filter { $0.isDependency }.count)",
                    subtitle: DiskSpace.formatBytes(model.homebrewPackages.filter { $0.isDependency }.map { $0.sizeBytes }.reduce(0, +)),
                    icon: "leaf",
                    color: .green
                )
            }

            HStack(spacing: 10) {
                Label("Homebrew Bakımı:", systemImage: "wrench.and.screwdriver")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button {
                    Task { await model.executeHomebrewAutoremove() }
                } label: {
                    Label("brew autoremove --prune=all", systemImage: "leaf.arrow.triangle.pull")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(model.isBusy)

                Button {
                    Task { await model.executeHomebrewCleanup(pruneAll: true, scrub: true) }
                } label: {
                    Label("brew cleanup --prune=all", systemImage: "sparkles")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help("brew cleanup --prune=all -s")
                .disabled(model.isBusy)

                Button {
                    Task { await model.executeHomebrewServicesCleanup() }
                } label: {
                    Label("brew services cleanup", systemImage: "gearshape.arrow.triangle.2.circlepath")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(model.isBusy)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            if model.homebrewStatus.cacheSizeBytes > 0 || !model.homebrewStatus.cleanableItems.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "archivebox.circle.fill")
                        .foregroundStyle(.orange)
                    Text(model.LF(.devAIHomebrewCacheLabel, DiskSpace.formatBytes(model.homebrewStatus.cacheSizeBytes)))
                        .font(.caption.weight(.medium))
                    if let est = model.homebrewStatus.estimatedSpaceFreed {
                        Text("(\(est))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await model.executeHomebrewCleanup(pruneAll: true, scrub: true) }
                    } label: {
                        Label(model.L(.devAIHomebrewCleanupFullButton), systemImage: "sparkles")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    .help("brew cleanup --prune=all -s")
                    .disabled(model.isBusy)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(subtitle)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
}

/// Homebrew kurulu paket ve Cask yönetimini sağlayan Master-Detail görünümü.
public struct HomebrewPackagesMasterDetailView: View {
    @Bindable public var model: AppModel
    @State private var showingConfirmBatchUninstall = false
    @State private var packageToUninstall: HomebrewPackage?

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        HSplitView {
            masterListPane
                .frame(minWidth: 320, idealWidth: 380, maxWidth: 460)
                .padding(.trailing, 3)
            detailInspectionPane
                .frame(minWidth: 380, idealWidth: 500, maxWidth: .infinity)
                .padding(.leading, 3)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            model.L(.homebrewConfirmUninstallTitle),
            isPresented: $showingConfirmBatchUninstall,
            titleVisibility: .visible
        ) {
            Button(model.LF(.homebrewUninstallSelectedButton, model.selectedHomebrewPackagesCount), role: .destructive) {
                Task { await model.uninstallSelectedHomebrewPackages() }
            }
            Button(model.L(.buttonCancel), role: .cancel) {}
        } message: {
            Text(model.LF(.homebrewConfirmUninstallMessage, model.selectedHomebrewPackagesCount))
        }
        .confirmationDialog(
            model.L(.homebrewConfirmUninstallTitle),
            isPresented: Binding(
                get: { packageToUninstall != nil },
                set: { if !$0 { packageToUninstall = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pkg = packageToUninstall {
                Button(model.L(.homebrewUninstallButton), role: .destructive) {
                    Task { await model.uninstallHomebrewPackage(pkg, zap: model.homebrewZapCasks) }
                }
            }
            Button(model.L(.buttonCancel), role: .cancel) {
                packageToUninstall = nil
            }
        } message: {
            if let pkg = packageToUninstall {
                Text(model.LF(.homebrewConfirmUninstallMessage, 1) + " (\(pkg.name))")
            }
        }
    }

    // MARK: - Sol Panel: Paket Listesi (Master)

    private var masterListPane: some View {
        VStack(spacing: 0) {
            masterHeader
            Divider()
            if model.filteredHomebrewPackages.isEmpty {
                emptySearchOrScanView
            } else {
                List(selection: $model.selectedHomebrewPackageID) {
                    ForEach(model.filteredHomebrewPackages) { pkg in
                        packageRow(pkg)
                            .tag(pkg.id)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            Divider()
            masterBottomBar
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var masterHeader: some View {
        VStack(spacing: 8) {
            Picker("", selection: $model.homebrewPackageFilter) {
                Text(model.L(.homebrewFilterAll)).tag(HomebrewFilterKind.all)
                Text(model.L(.homebrewFilterFormulae)).tag(HomebrewFilterKind.formulae)
                Text(model.L(.homebrewFilterCasks)).tag(HomebrewFilterKind.casks)
                Text(model.L(.homebrewFilterOrphans)).tag(HomebrewFilterKind.orphans)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField(model.L(.searchPrompt), text: $model.homebrewPackageSearchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    if !model.homebrewPackageSearchText.isEmpty {
                        Button {
                            model.homebrewPackageSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.8)
                }

                Button {
                    Task { await model.scanHomebrewPackages() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help(model.L(.buttonRefresh))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func packageRow(_ pkg: HomebrewPackage) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { pkg.isSelected },
                set: { newValue in
                    if let idx = model.homebrewPackages.firstIndex(where: { $0.id == pkg.id }) {
                        model.homebrewPackages[idx].isSelected = newValue
                    }
                }
            ))
            .labelsHidden()

            Image(systemName: pkg.kind == .cask ? "macwindow" : "terminal")
                .font(.title3)
                .foregroundStyle(pkg.kind == .cask ? Color.blue : Color.orange)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pkg.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Text(pkg.version)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }

                if !pkg.description.isEmpty {
                    Text(pkg.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Text(pkg.kind == .cask ? model.L(.homebrewBadgeCask) : model.L(.homebrewBadgeFormula))
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(pkg.kind == .cask ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(pkg.kind == .cask ? Color.blue : Color.orange)

                    if pkg.isDependency {
                        Text(model.L(.homebrewBadgeDependency))
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }

                    if pkg.sizeBytes > 0 {
                        Text(DiskSpace.formatBytes(pkg.sizeBytes))
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectHomebrewPackage(pkg)
        }
        .contextMenu {
            Button(role: .destructive) {
                packageToUninstall = pkg
            } label: {
                Label(model.L(.homebrewUninstallButton), systemImage: "trash")
            }

            if pkg.kind == .cask {
                Button(role: .destructive) {
                    model.homebrewZapCasks = true
                    packageToUninstall = pkg
                } label: {
                    Label(model.L(.contextMenuZapUninstall), systemImage: "bolt.shield")
                }
            }

            Divider()

            if let path = pkg.path, !path.isEmpty {
                Button {
                    model.revealInFinder(URL(fileURLWithPath: path))
                } label: {
                    Label(model.L(.buttonShowInFinder), systemImage: "folder")
                }
                Button {
                    model.copyToClipboard(path)
                } label: {
                    Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
                }
            }

            if let hp = pkg.homepage, let url = URL(string: hp) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label(model.L(.contextMenuOpenHomepage), systemImage: "safari")
                }
            }

            Button {
                model.copyToClipboard(pkg.name)
            } label: {
                Label(model.L(.contextMenuCopyName), systemImage: "doc.on.doc")
            }

            Divider()

            Button {
                if let idx = model.homebrewPackages.firstIndex(where: { $0.id == pkg.id }) {
                    model.homebrewPackages[idx].isSelected.toggle()
                }
            } label: {
                Label(
                    pkg.isSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll),
                    systemImage: pkg.isSelected ? "checkmark.circle.fill" : "circle"
                )
            }
        }
    }

    private var masterBottomBar: some View {
        HStack(spacing: 8) {
            Button {
                model.toggleSelectAllHomebrewPackages()
            } label: {
                Image(systemName: "checklist")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .help(model.L(.buttonSelectAll))
            .keyboardShortcut("a", modifiers: .command)

            Text("\(model.filteredHomebrewPackages.count) paket")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if model.selectedHomebrewPackagesCount > 0 {
                Button(role: .destructive) {
                    showingConfirmBatchUninstall = true
                } label: {
                    Label(
                        model.LF(.homebrewUninstallSelectedButton, model.selectedHomebrewPackagesCount),
                        systemImage: "trash"
                    )
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var emptySearchOrScanView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mug")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(model.homebrewPackages.isEmpty ? model.L(.homebrewPackagesTitle) : model.L(.devAINoItems))
                .font(.headline)
            if model.homebrewPackages.isEmpty {
                Button(model.L(.menuScanNow)) {
                    Task { await model.scanHomebrewPackages() }
                }
                .buttonStyle(.glassProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sağ Panel: Paket Detay İncelemesi (Detail)

    private var detailInspectionPane: some View {
        Group {
            if let pkg = model.selectedHomebrewPackage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        heroHeader(pkg)
                        Divider()
                        packageMetadataCard(pkg)
                        if !pkg.dependencies.isEmpty {
                            dependenciesCard(pkg.dependencies)
                        }
                        if let caveats = pkg.caveats, !caveats.isEmpty {
                            caveatsCard(caveats)
                        }
                        caskOptionsCard(pkg)
                        actionButtonsBar(pkg)
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    model.L(.homebrewEmptySelectionTitle),
                    systemImage: "mug.fill",
                    description: Text(model.L(.homebrewEmptySelectionSubtitle))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func heroHeader(_ pkg: HomebrewPackage) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(pkg.kind == .cask ? Color.blue.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: pkg.kind == .cask ? "macwindow" : "terminal")
                    .font(.system(size: 28))
                    .foregroundStyle(pkg.kind == .cask ? Color.blue : Color.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pkg.name)
                    .font(.title2.weight(.bold))

                HStack(spacing: 8) {
                    Text(pkg.id)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)

                    Text(pkg.version)
                        .font(.caption.weight(.semibold).monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())

                    Text(pkg.kind == .cask ? model.L(.homebrewBadgeCask) : model.L(.homebrewBadgeFormula))
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(pkg.kind == .cask ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(pkg.kind == .cask ? Color.blue : Color.orange)
                }

                if !pkg.description.isEmpty {
                    Text(pkg.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }

            Spacer()

            if let homepage = pkg.homepage, let url = URL(string: homepage) {
                Link(destination: url) {
                    Label("Web", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
    }

    private func packageMetadataCard(_ pkg: HomebrewPackage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.L(.homebrewInstallPathTitle))
                .font(.headline)

            if let path = pkg.path {
                HStack {
                    Text(path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        model.revealInFinder(URL(fileURLWithPath: path))
                    } label: {
                        Label(model.L(.buttonShowInFinder), systemImage: "folder")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            }

            if pkg.sizeBytes > 0 {
                HStack {
                    Text(model.L(.homebrewSizeLabel))
                        .font(.callout)
                    Spacer()
                    Text(DiskSpace.formatBytes(pkg.sizeBytes))
                        .font(.callout.weight(.semibold).monospacedDigit())
                }
            }

            HStack {
                Text(model.L(.homebrewBadgeInstalledOnRequest))
                    .font(.callout)
                Spacer()
                Text(pkg.isInstalledOnRequest ? model.L(.buttonOK) : model.L(.homebrewBadgeDependency))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(pkg.isInstalledOnRequest ? Color.primary : Color.orange)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func dependenciesCard(_ deps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.L(.homebrewDependenciesTitle))
                .font(.headline)

            FlowLayout(spacing: 6) {
                ForEach(deps, id: \.self) { dep in
                    Text(dep)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func caveatsCard(_ caveats: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.orange)
                Text("Caveats")
                    .font(.headline)
            }
            Text(caveats)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func caskOptionsCard(_ pkg: HomebrewPackage) -> some View {
        if pkg.kind == .cask {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $model.homebrewZapCasks) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.L(.homebrewZapOption))
                            .font(.callout.weight(.medium))
                        Text("--zap")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func actionButtonsBar(_ pkg: HomebrewPackage) -> some View {
        HStack {
            Spacer()
            Button(role: .destructive) {
                packageToUninstall = pkg
            } label: {
                Label(model.L(.homebrewUninstallButton), systemImage: "trash")
            }
            .buttonStyle(.glassProminent)
            .controlSize(.regular)
        }
        .padding(.top, 8)
    }
}

/// Basit akış (wrap) yerleşim görünümü.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
