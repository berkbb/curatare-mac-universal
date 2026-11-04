// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

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
