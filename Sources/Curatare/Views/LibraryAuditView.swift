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
