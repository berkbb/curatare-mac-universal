// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

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
