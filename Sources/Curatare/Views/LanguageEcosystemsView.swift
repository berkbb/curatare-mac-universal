// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

/// Dil ve ekosistem paket yöneticileri (pip, uv, npm, bun, cargo, gradle, nuget, spm vb.)
/// ile korumalı macOS sistem çalışma zamanlarını yöneten Master-Detail görünümü.
public struct LanguageEcosystemsMasterDetailView: View {
    @Bindable public var model: AppModel
    @State private var showingConfirmBatchMove = false
    @State private var itemToMove: LanguageEcosystemItem?

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
            model.L(.ecosystemsConfirmMoveTitle),
            isPresented: $showingConfirmBatchMove,
            titleVisibility: .visible
        ) {
            Button(
                model.LF(.ecosystemsMoveSelectedButton, model.selectedCleanableEcosystemItemsCount),
                role: .destructive
            ) {
                model.requestMoveDevAndAIToDatedTrash()
            }
            Button(model.L(.buttonCancel), role: .cancel) {}
        } message: {
            Text(model.LF(
                .ecosystemsConfirmMoveMessage,
                model.selectedCleanableEcosystemItemsCount,
                DiskSpace.formatBytes(model.selectedCleanableEcosystemItemsTotalBytes)
            ))
        }
        .confirmationDialog(
            model.L(.ecosystemsConfirmMoveTitle),
            isPresented: Binding(
                get: { itemToMove != nil },
                set: { if !$0 { itemToMove = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let item = itemToMove {
                Button(model.L(.ecosystemsMoveSingleButton), role: .destructive) {
                    model.moveSingleEcosystemItemToDatedTrash(item)
                    itemToMove = nil
                }
            }
            Button(model.L(.buttonCancel), role: .cancel) {
                itemToMove = nil
            }
        } message: {
            if let item = itemToMove {
                Text(model.LF(.ecosystemsConfirmMoveMessage, 1, DiskSpace.formatBytes(item.sizeBytes)) + " (\(item.toolName))")
            }
        }
        .loadOnFirstVisit(isLoaded: model.hasScannedLanguageEcosystems, isBusy: model.isBusy) {
            await model.scanLanguageEcosystems()
        }
    }

    // MARK: - Sol Panel: Ekosistem ve Paket Listesi (Master)

    private var masterListPane: some View {
        VStack(spacing: 0) {
            masterHeader
            Divider()
            if model.languageEcosystemOriginTab == .macosSystem {
                macOSSecurityBanner
                Divider()
            }
            if model.filteredLanguageEcosystemItems.isEmpty {
                emptySearchOrScanView
            } else {
                List(selection: $model.selectedLanguageEcosystemItemID) {
                    ForEach(model.filteredLanguageEcosystemItems) { item in
                        ecosystemRow(item)
                            .tag(item.id)
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

    private var macOSSecurityBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title3)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.L(.ecosystemsMacOSBannerTitle))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
                Text(model.L(.ecosystemsMacOSBannerDesc))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08))
    }

    private var masterHeader: some View {
        VStack(spacing: 8) {
            Picker("", selection: $model.languageEcosystemOriginTab) {
                Text(model.L(.ecosystemsOriginAll)).tag(LanguageEcosystemOriginTab.cleanableAll)
                Text(model.L(.ecosystemsOriginUser)).tag(LanguageEcosystemOriginTab.userStandalone)
                Text(model.L(.ecosystemsOriginHomebrew)).tag(LanguageEcosystemOriginTab.homebrew)
                Text(model.L(.ecosystemsOriginMacOS)).tag(LanguageEcosystemOriginTab.macosSystem)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField(model.L(.searchPrompt), text: $model.languageEcosystemSearchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    if !model.languageEcosystemSearchText.isEmpty {
                        Button {
                            model.languageEcosystemSearchText = ""
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
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                if model.languageEcosystemOriginTab != .macosSystem {
                    Picker("", selection: $model.languageEcosystemFilter) {
                        Text(model.L(.ecosystemsFilterAll)).tag(LanguageEcosystemFilterKind.all)
                        Text(model.L(.ecosystemsFilterPython)).tag(LanguageEcosystemFilterKind.python)
                        Text(model.L(.ecosystemsFilterNode)).tag(LanguageEcosystemFilterKind.nodeJS)
                        Text(model.L(.ecosystemsFilterRust)).tag(LanguageEcosystemFilterKind.rust)
                        Text(model.L(.ecosystemsFilterGo)).tag(LanguageEcosystemFilterKind.goLang)
                        Text(model.L(.ecosystemsFilterRuby)).tag(LanguageEcosystemFilterKind.ruby)
                        Text(model.L(.ecosystemsFilterJVM)).tag(LanguageEcosystemFilterKind.jvm)
                        Text(model.L(.ecosystemsFilterDotNet)).tag(LanguageEcosystemFilterKind.dotnet)
                        Text(model.L(.ecosystemsFilterSwift)).tag(LanguageEcosystemFilterKind.swift)
                        Text(model.L(.ecosystemsFilterDart)).tag(LanguageEcosystemFilterKind.dart)
                        Text(model.L(.ecosystemsFilterVersionManagers)).tag(LanguageEcosystemFilterKind.versionManagers)
                        Text(model.L(.ecosystemsFilterOther)).tag(LanguageEcosystemFilterKind.otherEcosystems)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }

                Button {
                    Task { await model.scanLanguageEcosystems() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .help(model.L(.buttonRefresh))
            }
        }
        .padding(10)
    }

    private func ecosystemRow(_ item: LanguageEcosystemItem) -> some View {
        HStack(spacing: 8) {
            if item.isSystemProtected {
                Image(systemName: "lock.shield.fill")
                    .font(.body)
                    .foregroundStyle(.green)
                    .frame(width: 20)
            } else {
                Toggle("", isOn: Binding(
                    get: { item.isSelected },
                    set: { newVal in
                        if let idx = model.languageEcosystemItems.firstIndex(where: { $0.id == item.id }) {
                            model.languageEcosystemItems[idx].isSelected = newVal
                        }
                    }
                ))
                .labelsHidden()
                .frame(width: 20)
            }

            ecosystemIcon(for: item)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.toolName)
                        .font(.body.weight(.semibold))

                    if item.isSystemProtected {
                        Text(model.L(.devAISystemRuntimeProtected))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    } else if item.origin == .homebrew {
                        Text(model.L(.ecosystemsBadgeHomebrew))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15), in: Capsule())
                    } else {
                        Text(model.L(.ecosystemsBadgeUser))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                }

                Text(item.path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isSystemProtected {
                Text(model.L(.devAIEcosystemProtectedBadge))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Text(DiskSpace.formatBytes(item.sizeBytes))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectLanguageEcosystemItem(item)
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
                model.copyToClipboard(item.toolName)
            } label: {
                Label(model.L(.contextMenuCopyName), systemImage: "doc.on.doc")
            }

            if !item.isSystemProtected {
                Divider()

                Button {
                    if let idx = model.languageEcosystemItems.firstIndex(where: { $0.id == item.id }) {
                        model.languageEcosystemItems[idx].isSelected.toggle()
                    }
                } label: {
                    Label(
                        item.isSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll),
                        systemImage: item.isSelected ? "checkmark.circle.fill" : "circle"
                    )
                }

                Button(role: .destructive) {
                    itemToMove = item
                } label: {
                    Label(model.L(.ecosystemsMoveSingleButton), systemImage: "trash")
                }
            }
        }
    }

    private var masterBottomBar: some View {
        HStack {
            if model.languageEcosystemOriginTab == .macosSystem {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text(model.L(.ecosystemsBadgeMacOS))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(model.L(.devAISystemRuntimeProtected))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    model.toggleSelectAllFilteredEcosystemItems()
                } label: {
                    Text(model.L(.devAIEcosystemSelectAll))
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("a", modifiers: .command)

                Spacer()

                Button {
                    showingConfirmBatchMove = true
                } label: {
                    Label(
                        model.LF(.ecosystemsMoveSelectedButton, model.selectedCleanableEcosystemItemsCount),
                        systemImage: "trash"
                    )
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
                .disabled(model.selectedCleanableEcosystemItemsCount == 0 || model.isBusy)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var emptySearchOrScanView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "shippingbox")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(model.L(.devAINoItems))
                .font(.headline)
            Text(model.L(.devAIEcosystemsSubtitle))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sağ Panel: Detay İnceleme (Detail)

    private var detailInspectionPane: some View {
        Group {
            if let item = model.selectedLanguageEcosystemItem {
                itemDetailView(item)
            } else {
                ContentUnavailableView(
                    model.L(.ecosystemsEmptyTitle),
                    systemImage: "shippingbox.circle",
                    description: Text(model.L(.ecosystemsEmptySubtitle))
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

    private func itemDetailView(_ item: LanguageEcosystemItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Hero Başlık
                heroHeader(item)
                Divider()

                // 2. Dizin Yolu ve Hızlı Eylemler
                pathAndActionsSection(item)
                Divider()

                // 3. Açıklama & Amaç
                explanationSection(item)
                Divider()

                // 4. Alt Dizin / Dosya İncelemesi
                subdirectoriesSection(item)
                Divider()

                // 5. Güvenlik & Çöp Durumu
                footerActionSection(item)
            }
            .padding(20)
        }
    }

    private func heroHeader(_ item: LanguageEcosystemItem) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(item.isSystemProtected ? Color.green.opacity(0.15) : Color.blue.opacity(0.12))
                    .frame(width: 54, height: 54)
                if item.isSystemProtected {
                    Image(systemName: "lock.shield.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                } else {
                    ecosystemIcon(for: item)
                        .font(.title)
                        .foregroundStyle(.blue)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.toolName)
                    .font(.title2.bold())
                Text(item.isSystemProtected ? model.L(.ecosystemsOriginMacOS) : item.ecosystem.titleTR)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if item.isSystemProtected {
                        Label(model.L(.devAISystemRuntimeProtected), systemImage: "checkmark.shield.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    } else {
                        if item.origin == .homebrew {
                            Text(model.L(.ecosystemsBadgeHomebrew))
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        } else {
                            Text(model.L(.ecosystemsBadgeUser))
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12), in: Capsule())
                                .foregroundStyle(.blue)
                        }

                        Label(DiskSpace.formatBytes(item.sizeBytes), systemImage: "internaldrive")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
            Spacer()
        }
    }

    private func pathAndActionsSection(_ item: LanguageEcosystemItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.L(.homebrewInstallPathTitle))
                .font(.headline)

            HStack {
                Text(item.url.path)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.url.path, forType: .string)
                    model.showToast(model.L(.buttonCopied) + ": " + item.url.path)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.glass)
                .help(model.L(.buttonCopyCommand))

                Button {
                    model.revealInFinder(item.url)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.glass)
                .help(model.L(.buttonShowInFinder))
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func explanationSection(_ item: LanguageEcosystemItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.explanation)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func subdirectoriesSection(_ item: LanguageEcosystemItem) -> some View {
        let subdirs = model.inspectCacheSubdirectories(for: item)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.L(.ecosystemsContentsTitle))
                    .font(.headline)
                Spacer()
                Text("\(subdirs.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
            }

            if subdirs.isEmpty {
                Text(item.isSystemProtected ? "Sistem ikilisi (tek dosya)" : "Alt dizin bulunamadı")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(spacing: 6) {
                    ForEach(subdirs) { sub in
                        HStack {
                            Image(systemName: sub.isDirectory ? "folder.fill" : "doc.fill")
                                .font(.caption)
                                .foregroundStyle(sub.isDirectory ? .blue : .secondary)
                            Text(sub.name)
                                .font(.callout.monospaced())
                            Spacer()
                            Text(DiskSpace.formatBytes(sub.sizeBytes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func footerActionSection(_ item: LanguageEcosystemItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.isSystemProtected {
                HStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text(model.L(.ecosystemsProtectedNotice))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text(model.L(.ecosystemsCleanableNotice))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                HStack {
                    Spacer()
                    Button(role: .destructive) {
                        itemToMove = item
                    } label: {
                        Label(model.L(.ecosystemsMoveSingleButton), systemImage: "trash")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.regular)
                    .disabled(model.isBusy)
                }
            }
        }
    }

    @ViewBuilder
    private func ecosystemIcon(for item: LanguageEcosystemItem) -> some View {
        switch item.ecosystem {
        case .macosSystemRuntime:
            Image(systemName: "applelogo")
                .foregroundStyle(.secondary)
        case .python:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .foregroundStyle(.yellow)
        case .javascriptNode:
            Image(systemName: "curlybraces")
                .foregroundStyle(.green)
        case .rust:
            Image(systemName: "gearshape.2.fill")
                .foregroundStyle(.orange)
        case .goLang:
            Image(systemName: "figure.walk.motion")
                .foregroundStyle(.cyan)
        case .ruby:
            Image(systemName: "suit.diamond.fill")
                .foregroundStyle(.red)
        case .php:
            Image(systemName: "ellipsis.curlybraces")
                .foregroundStyle(.indigo)
        case .jvm:
            Image(systemName: "cup.and.saucer.fill")
                .foregroundStyle(.brown)
        case .dotnet:
            Image(systemName: "square.grid.2x2.fill")
                .foregroundStyle(.purple)
        case .swift:
            Image(systemName: "swift")
                .foregroundStyle(.orange)
        case .dartFlutter:
            Image(systemName: "wind")
                .foregroundStyle(.blue)
        case .versionManager:
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.teal)
        case .otherEcosystem:
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.secondary)
        }
    }
}
