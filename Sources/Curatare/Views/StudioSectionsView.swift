// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - 1. Kitaplık Kalıntıları (Library Leftovers) Görünümü

public struct LibraryAuditView: View {
    @Bindable public var model: AppModel
    @State private var copiedSudo = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            groupFilterBar
            groupSummaryBanner
            Divider()
            findingsContent
            if let sudoCmd = model.auditReport?.sudoCommand {
                sudoCommandBox(sudoCmd)
            }
            footerToolbar
        }
        .padding(16)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.L(.auditTitle))
                    .font(.title2.bold())
                Text(model.L(.auditSubtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let report = model.auditReport {
                Text(model.LF(.auditInstalledCount, Int64(report.installedCount)))
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            if model.isBusy {
                Button(role: .cancel) {
                    model.cancelActiveOperation()
                } label: {
                    Label(model.L(.buttonCancel), systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.glass)
            } else {
                Button {
                    Task { await model.runLibraryAudit() }
                } label: {
                    Label(model.L(.buttonScan), systemImage: "magnifyingglass")
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private var groupFilterBar: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    groupFilterPill(nil, label: model.L(.auditGroupAll), icon: "tray.2.fill", color: .accentColor)
                    groupFilterPill(.groupA, label: model.L(.auditGroupA), icon: groupIcon(.groupA), color: groupColor(.groupA))
                    groupFilterPill(.groupB, label: model.L(.auditGroupB), icon: groupIcon(.groupB), color: groupColor(.groupB))
                    groupFilterPill(.groupC, label: model.L(.auditGroupC), icon: groupIcon(.groupC), color: groupColor(.groupC))
                    groupFilterPill(.groupD, label: model.L(.auditGroupD), icon: groupIcon(.groupD), color: groupColor(.groupD))
                    groupFilterPill(.groupE, label: model.L(.auditGroupE), icon: groupIcon(.groupE), color: groupColor(.groupE))
                }
                .padding(.vertical, 2)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField(model.L(.searchPrompt), text: $model.auditSearchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !model.auditSearchText.isEmpty {
                    Button {
                        model.auditSearchText = ""
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
            .frame(width: 180)
        }
    }

    @ViewBuilder
    private func groupFilterPill(_ group: AuditGroup?, label: String, icon: String, color: Color) -> some View {
        let isSelected = model.selectedAuditGroup == group
        let count = group == nil
            ? (model.auditReport?.findings.count ?? 0)
            : (model.auditReport?.findings(for: group!).count ?? 0)

        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                model.selectedAuditGroup = group
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : color)
                Text(label)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.25) : color.opacity(0.18), in: Capsule())
                        .foregroundStyle(isSelected ? Color.white : color)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var groupSummaryBanner: some View {
        let details = activeGroupDetails
        let count = model.selectedAuditGroup == nil
            ? (model.auditReport?.findings.count ?? 0)
            : (model.auditReport?.findings(for: model.selectedAuditGroup!).count ?? 0)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(details.color.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: details.icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(details.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(details.title)
                        .font(.callout.weight(.semibold))
                    Text(details.scope)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
                Text(details.desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let report = model.auditReport {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.LF(.auditItemsCount, Int64(count)))
                        .font(.callout.weight(.bold).monospacedDigit())
                        .foregroundStyle(count > 0 ? details.color : .secondary)
                    let bytes = model.selectedAuditGroup == nil
                        ? report.totalReclaimableBytes
                        : report.findings(for: model.selectedAuditGroup!).map(\.sizeBytes).saturatingSum()
                    Text(DiskSpace.formatBytes(bytes))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(details.color.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(details.color.opacity(0.18), lineWidth: 1)
        }
    }

    private var activeGroupDetails: (title: String, scope: String, desc: String, icon: String, color: Color) {
        guard let group = model.selectedAuditGroup else {
            return (
                title: model.L(.auditTitle),
                scope: model.L(.auditGroupScopeAll),
                desc: model.L(.auditSubtitle),
                icon: "tray.2.fill",
                color: .accentColor
            )
        }
        switch group {
        case .groupA:
            return (
                title: model.L(.auditGroupFullA),
                scope: model.L(.auditGroupScopeA),
                desc: model.L(.auditGroupADesc),
                icon: groupIcon(.groupA),
                color: groupColor(.groupA)
            )
        case .groupB:
            return (
                title: model.L(.auditGroupFullB),
                scope: model.L(.auditGroupScopeB),
                desc: model.L(.auditGroupBDesc),
                icon: groupIcon(.groupB),
                color: groupColor(.groupB)
            )
        case .groupC:
            return (
                title: model.L(.auditGroupFullC),
                scope: model.L(.auditGroupScopeC),
                desc: model.L(.auditGroupCDesc),
                icon: groupIcon(.groupC),
                color: groupColor(.groupC)
            )
        case .groupD:
            return (
                title: model.L(.auditGroupFullD),
                scope: model.L(.auditGroupScopeD),
                desc: model.L(.auditGroupDDesc),
                icon: groupIcon(.groupD),
                color: groupColor(.groupD)
            )
        case .groupE:
            return (
                title: model.L(.auditGroupFullE),
                scope: model.L(.auditGroupScopeE),
                desc: model.L(.auditGroupEDesc),
                icon: groupIcon(.groupE),
                color: groupColor(.groupE)
            )
        }
    }

    @ViewBuilder
    private var findingsContent: some View {
        let items = model.filteredAuditFindings
        if items.isEmpty {
            if model.auditReport == nil {
                auditWelcomeCard
            } else {
                ContentUnavailableView(
                    model.L(.auditNoFindingsTitle),
                    systemImage: "checkmark.seal",
                    description: Text(model.L(.auditNoFindingsMessage))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            List(items) { item in
                HStack(spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { item.isSelected },
                        set: { _ in model.toggleAuditFindingSelection(id: item.id) }
                    ))
                    .labelsHidden()
                    .disabled(item.requiresSudo)

                    Text(item.group.rawValue)
                        .font(.caption.bold())
                        .frame(width: 22, height: 22)
                        .background(groupColor(item.group).opacity(0.2), in: Circle())
                        .foregroundStyle(groupColor(item.group))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(OpenSafety.visibleName(item.displayName))
                                .font(.body.weight(.medium))
                            Text(item.librarySubfolder)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                            if item.requiresSudo {
                                Text(model.L(.auditRequiresSudoBadge))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.15), in: Capsule())
                            }
                        }
                        Text("\(item.explanation) · \(item.url.path)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(DiskSpace.formatBytes(item.sizeBytes))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button {
                        model.revealInFinder(item.url)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help(model.L(.buttonShowInFinder))
                }
                .padding(.vertical, 2)
                .contextMenu {
                    Button {
                        model.revealInFinder(item.url)
                    } label: {
                        Label(model.L(.buttonShowInFinder), systemImage: "folder")
                    }

                    Button {
                        model.copyToClipboard(item.url.path)
                    } label: {
                        Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
                    }

                    Button {
                        model.copyToClipboard(item.displayName)
                    } label: {
                        Label(model.L(.contextMenuCopyName), systemImage: "doc.on.doc")
                    }

                    if !item.requiresSudo {
                        Divider()

                        Button {
                            model.toggleAuditFindingSelection(id: item.id)
                        } label: {
                            Label(
                                item.isSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll),
                                systemImage: item.isSelected ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    /// Kısa pencerede açıklama ve grup kartları kırpılmasın diye kaydırılır; yer varsa Spacer'lar ortalar.
    private var auditWelcomeCard: some View {
        GeometryReader { proxy in
            ScrollView {
                auditWelcomeContent
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var auditWelcomeContent: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 68, height: 68)
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 6) {
                Text(model.L(.auditWelcomeTitle))
                    .font(.title3.weight(.bold))
                Text(model.L(.auditWelcomeDesc))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 540)
            }

            HStack(spacing: 10) {
                groupIntroCard(group: .groupA, code: "A", title: model.L(.auditGroupA))
                groupIntroCard(group: .groupB, code: "B", title: model.L(.auditGroupB))
                groupIntroCard(group: .groupC, code: "C", title: model.L(.auditGroupC))
                groupIntroCard(group: .groupD, code: "D", title: model.L(.auditGroupD))
                groupIntroCard(group: .groupE, code: "E", title: model.L(.auditGroupE))
            }
            .frame(maxWidth: 620)

            Button {
                Task { await model.runLibraryAudit() }
            } label: {
                Label(model.L(.auditWelcomeButton), systemImage: "magnifyingglass")
                    .font(.body.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(model.isBusy)

            HStack(spacing: 6) {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text(model.L(.auditWelcomeSafetyBadge))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(16)
    }

    private func groupIntroCard(group: AuditGroup, code: String, title: String) -> some View {
        let color = groupColor(group)
        let icon = groupIcon(group)
        return Button {
            model.selectedAuditGroup = group
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func groupIcon(_ group: AuditGroup) -> String {
        switch group {
        case .groupA: "app.dashed"
        case .groupB: "hammer.fill"
        case .groupC: "terminal.fill"
        case .groupD: "bolt.slash.fill"
        case .groupE: "lock.shield.fill"
        }
    }

    private func sudoCommandBox(_ cmd: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(model.L(.auditSudoSectionTitle), systemImage: "terminal")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button(copiedSudo ? model.L(.buttonCopied) : model.L(.buttonCopyCommand)) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)
                    copiedSudo = true
                }
                .controlSize(.small)
            }
            Text(model.L(.auditSudoSectionHint))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(cmd)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var footerToolbar: some View {
        let selectedItems = (model.auditReport?.findings ?? []).filter { $0.isSelected && !$0.requiresSudo }
        let selectedBytes = selectedItems.map(\.sizeBytes).saturatingSum()
        let visibleNonSudo = model.filteredAuditFindings.filter { !$0.requiresSudo }
        let allAuditSelected = !visibleNonSudo.isEmpty && visibleNonSudo.allSatisfy(\.isSelected)

        return HStack {
            Button(model.L(.buttonSelectAll)) {
                model.setAllAuditFindingsSelected(!allAuditSelected)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .keyboardShortcut("a", modifiers: .command)
            .disabled(visibleNonSudo.isEmpty)

            Button(model.L(.buttonDeselectAll)) {
                model.setAllAuditFindingsSelected(false)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(selectedItems.isEmpty)

            Spacer()

            Text(model.LF(.auditSelectedSummary, Int64(selectedItems.count), DiskSpace.formatBytes(selectedBytes)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                model.requestMoveAuditFindingsToDatedTrash()
            } label: {
                Label(model.L(.buttonMoveToDatedTrash), systemImage: "trash")
            }
            .buttonStyle(.glassProminent)
            .disabled(selectedItems.isEmpty || model.isBusy)
        }
    }

    private func groupColor(_ group: AuditGroup) -> Color {
        switch group {
        case .groupA: .purple
        case .groupB: .orange
        case .groupC: .blue
        case .groupD: .teal
        case .groupE: .red
        }
    }
}

// MARK: - 2. Uygulama Kaldırıcı Görünümü (Liste Yanda, Detay Sağda)

public struct UninstallerView: View {
    @Bindable public var model: AppModel
    @State private var isDropTargeted = false
    @State private var masterWidth: CGFloat = 320
    @State private var isDraggingDivider = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        HStack(spacing: 6) {
            // SOL PANEL: Uygulama Listesi (Arama, Tür Seçici, Kullanıcı & Sistem Bölümleri)
            VStack(spacing: 8) {
                uninstallerNavigationHeader

                if model.filteredBundles.isEmpty && !model.hasScannedUninstaller && model.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.filteredBundles.isEmpty {
                    ContentUnavailableView(
                        model.L(.uninstallerSelectAppHint),
                        systemImage: "magnifyingglass"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: Binding(
                        get: { model.selectedBundleID },
                        set: { id in
                            if let id, let bundle = model.installedBundles.first(where: { $0.id == id }) {
                                model.selectBundle(bundle)
                            }
                        }
                    )) {
                        if !userBundles.isEmpty {
                            Section(model.L(.uninstallerSectionUserApps)) {
                                ForEach(userBundles) { bundle in
                                    bundleRow(bundle)
                                        .tag(bundle.id)
                                }
                            }
                        }
                        if !systemBundles.isEmpty {
                            Section(model.L(.uninstallerSectionSystemApps)) {
                                ForEach(systemBundles) { bundle in
                                    bundleRow(bundle)
                                        .tag(bundle.id)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 6)
            .frame(width: masterWidth)
            .frame(maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // RESIZABLE DIVIDER (Master-Detail Boyutlandırma Çubuğu)
            ZStack {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.65))
                    .frame(width: 1)

                Rectangle()
                    .fill(isDraggingDivider ? Color.accentColor : Color.clear)
                    .frame(width: 3)

                Capsule()
                    .fill(isDraggingDivider ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 4, height: 36)
            }
            .frame(width: 9)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isDraggingDivider = true
                        let newWidth = masterWidth + value.translation.width
                        masterWidth = min(max(newWidth, 240), 620)
                    }
                    .onEnded { _ in
                        isDraggingDivider = false
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.smooth(duration: 0.2)) {
                    masterWidth = 320
                }
            }

            // SAĞ PANEL: Seçilen Uygulama ve İlişkili Dosyalar
            VStack(alignment: .leading, spacing: 12) {
                if let bundle = model.selectedBundle ?? model.inspectingBundle {
                    inspectedBundleView(bundle)
                } else {
                    ContentUnavailableView(
                        model.L(.uninstallerSelectToView),
                        systemImage: "arrow.left.and.line.vertical.and.arrow.right",
                        description: Text(model.L(.uninstallerSelectAppHint))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(16)
            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(14)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .loadOnFirstVisit(isLoaded: model.hasScannedUninstaller, isBusy: model.isBusy) {
            await model.scanUninstallerBundles()
        }
    }

    // MARK: - Sol Panel Başlığı (Tür Menüsü, Arama Kutusu ve Yenileme)

    private var uninstallerNavigationHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Menu {
                    Button(model.L(.uninstallerTabApps)) {
                        model.selectedUninstallerKind = .application
                        if let first = model.filteredBundles.first { model.selectBundle(first) }
                    }
                    Button(model.L(.uninstallerTabWidgets)) {
                        model.selectedUninstallerKind = .widget
                        if let first = model.filteredBundles.first { model.selectBundle(first) }
                    }
                    Button(model.L(.uninstallerTabPlugins)) {
                        model.selectedUninstallerKind = .plugin
                        if let first = model.filteredBundles.first { model.selectBundle(first) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(currentKindTitle)
                            .font(.headline)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                if model.isHomebrewAvailable {
                    Button {
                        model.selectedSection = .homebrew
                        if model.homebrewPackages.isEmpty {
                            Task { await model.scanHomebrewPackages() }
                        }
                    } label: {
                        Label("Homebrew", systemImage: "mug")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help(model.L(.homebrewPackagesTitle))
                }

                if model.isBusy {
                    Button(role: .cancel) {
                        model.cancelActiveOperation()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help(model.L(.buttonCancel))
                } else {
                    Button {
                        Task { await model.scanUninstallerBundles() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .help(model.L(.buttonRefresh))
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(model.L(.searchPrompt), text: $model.uninstallerSearchText)
                    .textFieldStyle(.plain)
                if !model.uninstallerSearchText.isEmpty {
                    Button {
                        model.uninstallerSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private var currentKindTitle: String {
        switch model.selectedUninstallerKind {
        case .application: model.L(.uninstallerTabApps)
        case .widget: model.L(.uninstallerTabWidgets)
        case .plugin: model.L(.uninstallerTabPlugins)
        }
    }

    // MARK: - Liste Satırı (İkon, Başlık, Yol, Sürüm ve Rozetler)

    private var userBundles: [InstalledBundle] {
        let home = NSHomeDirectory()
        return model.filteredBundles.filter { $0.url.path.hasPrefix(home) }
    }

    private var systemBundles: [InstalledBundle] {
        let home = NSHomeDirectory()
        return model.filteredBundles.filter { !$0.url.path.hasPrefix(home) }
    }

    private func bundleRow(_ bundle: InstalledBundle) -> some View {
        Button {
            model.selectBundle(bundle)
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: AppIconCache.shared.icon(for: bundle.url.path, size: 28))
                    .resizable()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bundle.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text(abbreviatedPath(bundle.url.path))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if bundle.isWrapperIOSApp {
                    Text(model.L(.uninstallerWrapperBadge))
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.indigo.opacity(0.15), in: Capsule())
                }
                if bundle.isRunning {
                    Text(model.L(.uninstallerRunningBadge))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                }
                if bundle.isProtected {
                    Text(model.L(.uninstallerProtectedBadge))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }

                Text(bundle.version)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                NSWorkspace.shared.open(bundle.url)
            } label: {
                Label(model.L(.contextMenuLaunchApp), systemImage: "arrow.up.forward.app")
            }

            Button {
                model.revealInFinder(bundle.url)
            } label: {
                Label(model.L(.buttonShowInFinder), systemImage: "folder")
            }

            Button {
                model.copyToClipboard(bundle.url.path)
            } label: {
                Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
            }

            if !bundle.bundleID.isEmpty {
                Button {
                    model.copyToClipboard(bundle.bundleID)
                } label: {
                    Label(model.L(.contextMenuCopyName), systemImage: "doc.on.doc")
                }
            }

            if !bundle.isProtected {
                Divider()

                Button {
                    model.selectBundle(bundle)
                } label: {
                    Label(model.L(.uninstallerSelectToView), systemImage: "magnifyingglass")
                }
            }
        }
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    // MARK: - Sağ Panel: Detaylı İnceleme ve İlişkili Dosyalar

    private func inspectedBundleView(_ bundle: InstalledBundle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(nsImage: AppIconCache.shared.icon(for: bundle.url.path, size: 44))
                    .resizable()
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(bundle.name)
                            .font(.title3.bold())
                        Text(model.LF(.bundleVersionLabel, bundle.version))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if bundle.isRunning {
                            Text(model.L(.uninstallerRunningBadge))
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                        }
                        if bundle.isProtected {
                            Text(model.L(.uninstallerProtectedBadge))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    Text("\(bundle.bundleID) · \(bundle.url.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.revealInFinder(bundle.url)
                } label: {
                    Label(model.L(.buttonShowInFinder), systemImage: "folder")
                }
                .buttonStyle(.glass)
                .controlSize(.small)

                Button(role: .cancel) {
                    model.closeInspection()
                } label: {
                    Label(model.L(.buttonCancel), systemImage: "xmark.circle")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
            }

            Divider()

            if bundle.isRunning {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.L(.uninstallerRunningAppWarningTitle))
                            .font(.subheadline.weight(.semibold))
                        Text(model.L(.uninstallerRunningAppWarningMessage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        model.quitRunningApp(bundle)
                    } label: {
                        Label(model.L(.uninstallerQuitAppButton), systemImage: "xmark.circle")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.orange.opacity(0.28), lineWidth: 1)
                }
            }

            if bundle.isSystemImmutable {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.L(.uninstallerSystemImmutableNotice))
                            .font(.subheadline.weight(.semibold))
                        Text(model.L(.uninstallerSystemImmutableDesc))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                }
            } else if bundle.isProtected {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.L(.uninstallerProtectedBadge))
                            .font(.subheadline.weight(.semibold))
                        Text(model.L(.uninstallerProtectedUnlockNotice))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.orange.opacity(0.28), lineWidth: 1)
                }
            } else if model.settings.allowUninstallingProtectedApps && bundle.bundleID.lowercased().hasPrefix("com.apple.") {
                HStack(spacing: 12) {
                    Image(systemName: "lock.open.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bundle.name)
                            .font(.subheadline.weight(.semibold))
                        Text(model.L(.uninstallerProtectedUnlockedBanner))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.accentColor.opacity(0.28), lineWidth: 1)
                }
            } else if bundle.isMountedVolume {
                HStack(spacing: 12) {
                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bundle.name)
                            .font(.subheadline.weight(.semibold))
                        Text(model.L(.uninstallerMountedVolumeNotice))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.blue.opacity(0.28), lineWidth: 1)
                }
            }

            Text(model.L(.uninstallerAssociatedTitle))
                .font(.subheadline.weight(.semibold))

            if model.isInspectingBundleLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    VStack(spacing: 4) {
                        Text(bundle.name)
                            .font(.headline)
                        Text(model.L(.uninstallerScanningAssociated))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 240, maxHeight: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            } else if model.associatedFiles.isEmpty {
                ContentUnavailableView(
                    model.L(.auditNoFindingsTitle),
                    systemImage: "checkmark.circle",
                    description: Text(model.L(.auditNoFindingsMessage))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.associatedFiles) { file in
                    HStack(spacing: 10) {
                        Toggle("", isOn: Binding(
                            get: { file.isSelected },
                            set: { _ in model.toggleAssociatedFileSelection(id: file.id) }
                        ))
                        .labelsHidden()
                        .disabled(bundle.isProtected || file.requiresSudo)

                        Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                            .resizable()
                            .frame(width: 20, height: 20)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(file.url.lastPathComponent)
                                    .font(.callout.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                                // Tür etiketi ve sudo işareti kırpılmaz; yer darsa dosya adı alt satıra sarılır.
                                Text(model.L(file.kind.titleKey))
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(.quaternary, in: Capsule())
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                                if file.requiresSudo {
                                    Label("sudo", systemImage: "lock.fill")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.orange)
                                        .fixedSize()
                                }
                            }
                            Text(abbreviatedPath(file.url.path))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(DiskSpace.formatBytes(file.sizeBytes))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Button {
                            model.quickLookPreview(file.url)
                        } label: {
                            Image(systemName: "eye")
                        }
                        .buttonStyle(.borderless)
                        .help(model.L(.buttonQuickLook))

                        Button {
                            model.revealInFinder(file.url)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                        .help(model.L(.buttonShowInFinder))
                    }
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button {
                            model.revealInFinder(file.url)
                        } label: {
                            Label(model.L(.buttonShowInFinder), systemImage: "folder")
                        }

                        Button {
                            model.quickLookPreview(file.url)
                        } label: {
                            Label(model.L(.buttonQuickLook), systemImage: "eye")
                        }

                        Button {
                            model.copyToClipboard(file.url.path)
                        } label: {
                            Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
                        }

                        if !bundle.isProtected && !file.requiresSudo {
                            Divider()

                            Button {
                                model.toggleAssociatedFileSelection(id: file.id)
                            } label: {
                                Label(
                                    file.isSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll),
                                    systemImage: file.isSelected ? "checkmark.circle.fill" : "circle"
                                )
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }

            // Düğmeler kendi genişliğini korur; tek satıra sığmazsa çubuk iki satıra bölünür, hiçbir etiket kırpılmaz.
            VStack {
                let selected = model.associatedFiles.filter { $0.isSelected && !$0.requiresSudo }
                let total = selected.map(\.sizeBytes).saturatingSum()
                let visibleSelectable = model.associatedFiles.filter { !$0.requiresSudo }
                let allAssociatedSelected = !visibleSelectable.isEmpty && visibleSelectable.allSatisfy(\.isSelected)

                let selectionButtons = HStack(spacing: 8) {
                    Button(model.L(.buttonSelectAll)) {
                        let target = !allAssociatedSelected
                        for i in model.associatedFiles.indices where !model.associatedFiles[i].requiresSudo {
                            model.associatedFiles[i].isSelected = target
                        }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .keyboardShortcut("a", modifiers: .command)
                    .disabled(model.isInspectingBundleLoading || visibleSelectable.isEmpty)

                    Button(model.L(.buttonDeselectAll)) {
                        for i in model.associatedFiles.indices {
                            model.associatedFiles[i].isSelected = false
                        }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .disabled(model.isInspectingBundleLoading || selected.isEmpty)
                }
                .fixedSize()
                let summary = Group {
                    if model.isInspectingBundleLoading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(model.L(.uninstallerScanningAssociated))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(model.LF(.auditSelectedSummary, Int64(selected.count), DiskSpace.formatBytes(total)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                let actionButtons = HStack(spacing: 8) {
                    Button(role: .cancel) {
                        model.closeInspection()
                    } label: {
                        Label(model.L(.buttonCancel), systemImage: "xmark.circle")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)

                    Button {
                        model.requestUninstallSelectedBundleToDatedTrash()
                    } label: {
                        Label(model.L(.buttonMoveToDatedTrash), systemImage: "trash")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(bundle.isProtected || bundle.isSystemImmutable || selected.isEmpty || model.isBusy || model.isInspectingBundleLoading || (model.settings.protectRunningApps && bundle.isRunning))
                }
                .fixedSize()
                ViewThatFits(in: .horizontal) {
                    HStack {
                        selectionButtons
                        Spacer()
                        summary
                        actionButtons
                    }
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack {
                            selectionButtons
                            Spacer()
                            summary
                        }
                        actionButtons
                    }
                }
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.file-url") }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
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

// MARK: - 3. Geliştirme ve Yapay Zekâ Temizliği Görünümü

public struct DevAICleanupView: View {
    @Bindable public var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    private var subTabTitle: String {
        switch model.devAISubTab {
        case .overview:
            return model.L(.devAITitle)
        case .languageEcosystems:
            return model.L(.ecosystemsTitle)
        }
    }

    private var subTabSubtitle: String {
        switch model.devAISubTab {
        case .overview:
            return model.L(.devAISubtitle)
        case .languageEcosystems:
            return model.L(.ecosystemsSubtitle)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subTabTitle)
                        .font(.title2.bold())
                    Text(subTabSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)

                Picker("", selection: $model.devAISubTab) {
                    Text(model.L(.devAITabOverview)).tag(DevAISubTab.overview)
                    Text(model.L(.devAITabLanguageEcosystems)).tag(DevAISubTab.languageEcosystems)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                if model.isBusy {
                    Button(role: .cancel) {
                        model.cancelActiveOperation()
                    } label: {
                        Label(model.L(.buttonCancel), systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.glass)
                } else {
                    Button {
                        Task { await model.scanDevAndAI() }
                    } label: {
                        Label(model.L(.buttonScan), systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.glassProminent)
                }
            }

            if model.devAISubTab == .languageEcosystems {
                LanguageEcosystemsMasterDetailView(model: model)
            } else if !model.hasScannedDevAndAI && model.isBusy {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.repoArtifacts.isEmpty && model.aiFootprintItems.isEmpty && model.cleanableEcosystemItems.isEmpty {
                ContentUnavailableView(
                    model.L(.devAINoItems),
                    systemImage: "hammer.circle",
                    description: Text(model.L(.safetyBannerProtected))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !model.cleanableEcosystemItems.isEmpty {
                        Section {
                            ForEach($model.languageEcosystemItems) { $item in
                                if !item.isSystemProtected && (model.selectedEcosystemFilter == nil || item.ecosystem == model.selectedEcosystemFilter) {
                                    HStack(spacing: 10) {
                                        Toggle("", isOn: $item.isSelected)
                                            .labelsHidden()
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(item.toolName)
                                                    .font(.body.weight(.semibold))
                                                Text(item.ecosystem.titleTR)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                                            }
                                            Text(item.path)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                            Text(item.explanation)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                        Spacer()
                                        Text(DiskSpace.formatBytes(item.sizeBytes))
                                            .font(.callout.monospacedDigit())
                                        Button {
                                            model.revealInFinder(item.url)
                                        } label: {
                                            Image(systemName: "folder")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        } header: {
                            HStack {
                                Label(model.L(.devAISectionEcosystems), systemImage: "shippingbox.circle.fill")
                                Spacer()
                                Picker("", selection: $model.selectedEcosystemFilter) {
                                    Text(model.L(.devAIEcosystemFilterAll)).tag(Optional<LanguageEcosystemItem.Ecosystem>.none)
                                    ForEach(LanguageEcosystemItem.Ecosystem.allCases.filter { $0 != .macosSystemRuntime }, id: \.self) { eco in
                                        Text(eco.titleTR).tag(Optional(eco))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(maxWidth: 160)

                                if !model.filteredCleanableEcosystemItems.isEmpty {
                                    Button {
                                        model.toggleSelectAllEcosystemItems()
                                    } label: {
                                        Text(model.filteredCleanableEcosystemItems.allSatisfy(\.isSelected) ? model.L(.devAIEcosystemDeselectAll) : model.L(.devAIEcosystemSelectAll))
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }

                                Button {
                                    model.devAISubTab = .languageEcosystems
                                } label: {
                                    Label(model.L(.ecosystemsOpenManagerButton), systemImage: "square.split.2x1")
                                }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                            }
                        }
                    }

                    if !model.repoArtifacts.isEmpty {
                        Section(model.L(.devAISectionGitHub)) {
                            ForEach($model.repoArtifacts) { $item in
                                HStack(spacing: 10) {
                                    Toggle("", isOn: $item.isSelected)
                                        .labelsHidden()
                                        .disabled(item.containsTrackedFiles)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("\(item.repoName) / \(item.relativePath)")
                                                .font(.body.weight(.medium))
                                            if item.containsTrackedFiles {
                                                Text(model.L(.devAITrackedWarning))
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                                    .padding(.horizontal, 6)
                                                    .background(Color.orange.opacity(0.15), in: Capsule())
                                            }
                                        }
                                        Text(item.artifactURL.path)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(DiskSpace.formatBytes(item.sizeBytes))
                                        .font(.callout.monospacedDigit())
                                    Button {
                                        model.revealInFinder(item.artifactURL)
                                    } label: {
                                        Image(systemName: "folder")
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .contextMenu {
                                    Button {
                                        model.revealInFinder(item.artifactURL)
                                    } label: {
                                        Label(model.L(.buttonShowInFinder), systemImage: "folder")
                                    }

                                    Button {
                                        model.copyToClipboard(item.artifactURL.path)
                                    } label: {
                                        Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
                                    }

                                    if !item.containsTrackedFiles {
                                        Divider()

                                        Button {
                                            $item.isSelected.wrappedValue.toggle()
                                        } label: {
                                            Label(
                                                item.isSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll),
                                                systemImage: item.isSelected ? "checkmark.circle.fill" : "circle"
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !model.aiFootprintItems.isEmpty {
                        Section(model.L(.devAISectionAI)) {
                            ForEach($model.aiFootprintItems) { $item in
                                HStack(spacing: 10) {
                                    Toggle("", isOn: $item.isSelected)
                                        .labelsHidden()
                                        .disabled(item.isCloudOnly || item.url == nil)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(item.title)
                                                .font(.body.weight(.medium))
                                            if item.isCloudOnly {
                                                Text(model.L(.devAICloudModelBadge))
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .background(.quaternary, in: Capsule())
                                            }
                                        }
                                        Text(item.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(DiskSpace.formatBytes(item.sizeBytes))
                                        .font(.callout.monospacedDigit())
                                }
                                .contextMenu {
                                    if let url = item.url {
                                        Button {
                                            model.revealInFinder(url)
                                        } label: {
                                            Label(model.L(.buttonShowInFinder), systemImage: "folder")
                                        }

                                        Button {
                                            model.copyToClipboard(url.path)
                                        } label: {
                                            Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
                                        }
                                    }

                                    if !item.isCloudOnly && item.url != nil {
                                        Divider()

                                        Button {
                                            $item.isSelected.wrappedValue.toggle()
                                        } label: {
                                            Label(
                                                item.isSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll),
                                                systemImage: item.isSelected ? "checkmark.circle.fill" : "circle"
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }

            if model.devAISubTab == .overview {
                HStack {
                    let hasSelectables = model.repoArtifacts.contains(where: { !$0.containsTrackedFiles })
                        || model.aiFootprintItems.contains(where: { !$0.isCloudOnly && $0.url != nil })
                    if hasSelectables {
                        let allSelected = model.repoArtifacts.filter({ !$0.containsTrackedFiles }).allSatisfy(\.isSelected)
                            && model.aiFootprintItems.filter({ !$0.isCloudOnly && $0.url != nil }).allSatisfy(\.isSelected)
                        Button(allSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll)) {
                            model.toggleSelectAllDevAndAIOverview()
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .keyboardShortcut("a", modifiers: .command)
                    }

                    Spacer()
                    Button {
                        model.requestMoveDevAndAIToDatedTrash()
                    } label: {
                        Label(model.L(.buttonMoveToDatedTrash), systemImage: "trash")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(model.isBusy)
                }
            }
        }
        .padding(16)
        .loadOnFirstVisit(isLoaded: model.hasScannedDevAndAI, isBusy: model.isBusy) {
            await model.scanDevAndAI()
        }
    }
}

// MARK: - 4. Tarayıcı, Önbellekler ve Time Machine Görünümü

public struct BrowserCachesView: View {
    @Bindable public var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.L(.cachesTitle))
                        .font(.title2.bold())
                    Text(model.L(.cachesSubtitle))
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
                        Task { await model.scanBrowserAndCaches() }
                    } label: {
                        Label(model.L(.buttonScan), systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.glassProminent)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    cacheFilterPill(.all, label: model.L(.cachesFilterAll), icon: "tray.2.fill")
                    cacheFilterPill(.browsers, label: model.L(.cachesFilterBrowsers), icon: "globe")
                    cacheFilterPill(.mailAndBackups, label: model.L(.cachesFilterMailBackups), icon: "envelope.fill")
                    cacheFilterPill(.systemAndLogs, label: model.L(.cachesFilterSystemLogs), icon: "gearshape.2.fill")
                    cacheFilterPill(.mediaAndWallpapers, label: model.L(.cachesFilterMedia), icon: "photo.stack.fill")
                    cacheFilterPill(.updatesAndInstallers, label: model.L(.cachesFilterUpdatesInstallers), icon: "arrow.down.circle.fill")
                }
                .padding(.vertical, 2)
            }

            List {
                ForEach(model.filteredHeavyCaches) { item in
                    let isSelectedBinding = Binding<Bool>(
                        get: { item.isSelected },
                        set: { newValue in
                            if let idx = model.heavyCacheItems.firstIndex(where: { $0.id == item.id }) {
                                model.heavyCacheItems[idx].isSelected = newValue
                            }
                        }
                    )
                    HStack(spacing: 12) {
                        Toggle("", isOn: isSelectedBinding)
                            .labelsHidden()

                        Image(systemName: item.iconName)
                            .font(.title3)
                            .foregroundStyle(item.filterGroup == .browsers ? .blue : (item.filterGroup == .mailAndBackups ? .purple : (item.filterGroup == .mediaAndWallpapers ? .pink : .orange)))
                            .frame(width: 28, height: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.title)
                                    .font(.body.weight(.medium))
                                Text(item.ownerApp)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.secondary.opacity(0.12), in: Capsule())
                                Text(model.L(item.categoryLKey))
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(item.category == .appVersionCache ? Color.orange.opacity(0.16) : Color.blue.opacity(0.12), in: Capsule())
                                    .foregroundStyle(item.category == .appVersionCache ? Color.orange : Color.blue)
                            }
                            Text("\(item.explanation) · \(item.url.path)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(DiskSpace.formatBytes(item.sizeBytes))
                            .font(.callout.monospacedDigit())
                        Button {
                            model.revealInFinder(item.url)
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                    }
                    .contextMenu {
                        Button {
                            model.revealInFinder(item.url)
                        } label: {
                            Label(model.L(.buttonShowInFinder), systemImage: "folder")
                        }

                        Button {
                            model.copyToClipboard(item.url.path)
                        } label: {
                            Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
                        }

                        Button {
                            model.copyToClipboard(item.title)
                        } label: {
                            Label(model.L(.contextMenuCopyName), systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button {
                            isSelectedBinding.wrappedValue.toggle()
                        } label: {
                            Label(
                                item.isSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll),
                                systemImage: item.isSelected ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                }
            }
            .listStyle(.inset)

            // Time Machine Yerel Anlık Görüntüler Bölümü
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.L(.timeMachineSectionTitle))
                        .font(.caption.weight(.semibold))
                    Text("\(model.L(.timeMachineSectionSubtitle)) (\(model.LF(.timeMachineSnapshotCount, Int64(model.timeMachineSnapshots.count))))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.L(.timeMachineThinButton)) {
                    Task { await model.thinTimeMachineSnapshots() }
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .disabled(model.isBusy)
            }
            .padding(10)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))

            HStack {
                let hasCaches = !model.filteredHeavyCaches.isEmpty
                if hasCaches {
                    let allCachesSelected = model.filteredHeavyCaches.allSatisfy(\.isSelected)
                    Button(allCachesSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll)) {
                        model.toggleSelectAllHeavyCaches()
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .keyboardShortcut("a", modifiers: .command)
                }

                Spacer()
                Button {
                    model.moveSelectedCachesToDatedTrash()
                } label: {
                    Label(model.L(.buttonMoveToDatedTrash), systemImage: "trash")
                }
                .buttonStyle(.glassProminent)
                .disabled(model.filteredHeavyCaches.filter(\.isSelected).isEmpty || model.isBusy)
            }
        }
        .padding(16)
    }

    private func cacheFilterPill(_ group: HeavyCacheItem.FilterGroup, label: String, icon: String) -> some View {
        let isSelected = model.selectedCacheFilterGroup == group
        return Button {
            model.selectedCacheFilterGroup = group
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.12),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
