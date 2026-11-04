// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - 7. Tarihli Çöp Turları ve Geri Yükleme (`TrashHistoryView` - Master-Detail)

public struct TrashHistoryView: View {
    @Bindable public var model: AppModel
    @State private var showingConfirmPurgeAll = false
    @State private var batchToPurge: TrashBatchManifest?
    @State private var itemToPurge: (batch: TrashBatchManifest, item: TrashedItemRecord)?
    @State private var showingConfirmPurgeSelected = false
    @State private var itemSearchText: String = ""

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBar

            if model.trashBatches.isEmpty {
                ContentUnavailableView(
                    model.L(.trashHistoryEmptyTitle),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(model.L(.trashHistoryEmptyMessage))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    masterBatchesPane
                        .frame(minWidth: 320, idealWidth: model.settings.trashMasterPaneWidth, maxWidth: 460)
                        .padding(.trailing, 3)
                    detailInspectionPane
                        .frame(minWidth: 400, idealWidth: 540, maxWidth: .infinity)
                        .padding(.leading, 3)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .confirmationDialog(
            model.L(.trashConfirmPurgeAllTitle),
            isPresented: $showingConfirmPurgeAll,
            titleVisibility: .visible
        ) {
            Button(model.L(.trashPurgeAllButton), role: .destructive) {
                model.purgeAllTrashBatches()
            }
            Button(model.L(.buttonCancel), role: .cancel) {}
        } message: {
            Text(model.LF(
                .trashConfirmPurgeAllMessage,
                Int64(model.trashBatches.count),
                DiskSpace.formatBytes(model.trashBatches.map(\.totalBytes).reduce(0, +))
            ))
        }
        .confirmationDialog(
            model.L(.trashConfirmPurgeSingleTitle),
            isPresented: Binding(
                get: { batchToPurge != nil },
                set: { if !$0 { batchToPurge = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let batch = batchToPurge {
                Button(model.L(.trashPurgeSingleButton), role: .destructive) {
                    model.purgeTrashBatch(batch)
                    batchToPurge = nil
                }
            }
            Button(model.L(.buttonCancel), role: .cancel) {
                batchToPurge = nil
            }
        } message: {
            if let batch = batchToPurge {
                Text(model.LF(.trashConfirmPurgeSingleMessage, batch.id, Int64(batch.items.count)))
            }
        }
        .confirmationDialog(
            model.L(.trashConfirmPurgeSingleItemTitle),
            isPresented: Binding(
                get: { itemToPurge != nil },
                set: { if !$0 { itemToPurge = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = itemToPurge {
                Button(model.L(.trashPurgeSingleItemTooltip), role: .destructive) {
                    model.purgeTrashedItem(batch: target.batch, item: target.item)
                    itemToPurge = nil
                }
            }
            Button(model.L(.buttonCancel), role: .cancel) {
                itemToPurge = nil
            }
        } message: {
            if let target = itemToPurge {
                Text(model.LF(.trashConfirmPurgeSingleItemMessage, target.item.trashedRelativePath))
            }
        }
        .confirmationDialog(
            model.L(.trashConfirmPurgeSelectedItemsTitle),
            isPresented: $showingConfirmPurgeSelected,
            titleVisibility: .visible
        ) {
            if let batch = model.selectedTrashBatch {
                Button(model.L(.trashPurgeSingleButton), role: .destructive) {
                    model.purgeSelectedTrashedItems(batch: batch)
                }
            }
            Button(model.L(.buttonCancel), role: .cancel) {}
        } message: {
            Text(model.LF(.trashConfirmPurgeSelectedItemsMessage, Int64(model.selectedTrashedItemIDs.count)))
        }
    }

    // MARK: - Üst Başlık

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.L(.trashHistoryTitle))
                    .font(.title2.bold())
                Text(model.L(.trashHistorySubtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.refreshTrashBatches()
            } label: {
                Label(model.L(.buttonRefresh), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glassProminent)
        }
    }

    // MARK: - Sol Panel: Temizlik Turları Listesi (Master)

    private var masterBatchesPane: some View {
        VStack(spacing: 0) {
            masterFilterBar
            Divider()
            if model.filteredTrashBatches.isEmpty {
                ContentUnavailableView(
                    model.L(.trashHistoryEmptyTitle),
                    systemImage: "magnifyingglass",
                    description: Text(model.L(.trashHistoryEmptyMessage))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $model.selectedTrashBatchID) {
                    ForEach(model.filteredTrashBatches) { batch in
                        batchRow(batch)
                            .tag(batch.id)
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

    private var masterFilterBar: some View {
        VStack(spacing: 8) {
            Picker("", selection: $model.trashHistoryFilter) {
                Text(model.L(.trashFilterAll)).tag(TrashHistoryFilterKind.all)
                Text(model.L(.trashFilterPending)).tag(TrashHistoryFilterKind.pendingRestore)
                Text(model.L(.trashFilterRestored)).tag(TrashHistoryFilterKind.restored)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField(model.L(.searchPrompt), text: $model.trashHistorySearchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !model.trashHistorySearchText.isEmpty {
                    Button {
                        model.trashHistorySearchText = ""
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func batchRow(_ batch: TrashBatchManifest) -> some View {
        HStack(spacing: 10) {
            Image(systemName: batch.isRestored ? "arrow.uturn.backward.circle.fill" : "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(batch.isRestored ? .green : .accentColor)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.displayTitle(for: batch))
                        .font(.body.weight(.medium))
                    if batch.isRestored {
                        Text(model.L(.trashBatchRestoredBadge))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15), in: Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(batch.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(DiskSpace.formatBytes(batch.totalBytes))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(batch.items.count)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())

            Button(role: .destructive) {
                batchToPurge = batch
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.borderless)
            .help(model.L(.trashPurgeSingleButton))
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button {
                model.restoreTrashBatch(batch)
            } label: {
                Label(model.L(.buttonRestore), systemImage: "arrow.uturn.backward")
            }
            .disabled(batch.isRestored)

            Button {
                model.revealInFinder(URL(fileURLWithPath: batch.batchDirectoryPath))
            } label: {
                Label(model.L(.buttonShowInFinder), systemImage: "folder")
            }

            Button {
                model.copyToClipboard(batch.id)
            } label: {
                Label(model.L(.contextMenuCopyName), systemImage: "doc.on.doc")
            }

            Button {
                model.copyToClipboard(batch.batchDirectoryPath)
            } label: {
                Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                batchToPurge = batch
            } label: {
                Label(model.L(.trashPurgeSingleButton), systemImage: "trash.slash")
            }
        }
    }

    private var masterBottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.LF(.trashBatchCountFiltered, Int64(model.filteredTrashBatches.count), Int64(model.trashBatches.count)))
                    .font(.caption2.weight(.semibold))
                Text(DiskSpace.formatBytes(model.filteredTrashBatches.map(\.totalBytes).reduce(0, +)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                showingConfirmPurgeAll = true
            } label: {
                Label(model.L(.trashPurgeAllButton), systemImage: "trash.slash.fill")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(model.trashBatches.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Sağ Panel: Tur Ayrıntıları ve Dosya İnceleme (Detail)

    private var detailInspectionPane: some View {
        Group {
            if let batch = model.selectedTrashBatch {
                VStack(spacing: 0) {
                    detailHeader(batch)
                    Divider()
                    detailFilesList(batch)
                }
            } else {
                ContentUnavailableView(
                    model.L(.trashEmptySelectionTitle),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(model.L(.trashEmptySelectionSubtitle))
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

    private func detailHeader(_ batch: TrashBatchManifest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: batch.isRestored ? "arrow.uturn.backward.circle.fill" : "trash.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(batch.isRestored ? Color.green : Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.displayTitle(for: batch))
                            .font(.title3.bold())
                        if batch.isRestored {
                            Text(model.L(.trashBatchRestoredBadge))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15), in: Capsule())
                        }
                    }

                    Text(model.LF(.trashBatchIDLabel, batch.id))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(batch.batchDirectoryPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Button {
                        model.restoreTrashBatch(batch)
                    } label: {
                        Label(model.L(.buttonRestore), systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(batch.isRestored)

                    HStack(spacing: 8) {
                        Button {
                            model.revealInFinder(URL(fileURLWithPath: batch.batchDirectoryPath))
                        } label: {
                            Label(model.L(.buttonShowInFinder), systemImage: "folder")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)

                        Button(role: .destructive) {
                            batchToPurge = batch
                        } label: {
                            Label(model.L(.trashPurgeSingleButton), systemImage: "trash.slash")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                }
                // Düğmeler kendi genişliğini korur; uzun kimlik ve yol metni soldaki sütunda sarılır.
                .fixedSize()
            }

            HStack(spacing: 12) {
                badgeStat(label: model.L(.trashStatItemCount), value: "\(batch.items.count)")
                badgeStat(label: model.L(.trashStatTotalSize), value: DiskSpace.formatBytes(batch.totalBytes))
                badgeStat(label: model.L(.trashStatDate), value: batch.createdAt.formatted(date: .numeric, time: .shortened))
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func detailFilesList(_ batch: TrashBatchManifest) -> some View {
        VStack(spacing: 0) {
            let filteredItems = batch.items.filter { item in
                if itemSearchText.isEmpty { return true }
                let q = itemSearchText.lowercased()
                return item.trashedRelativePath.lowercased().contains(q) || item.originalPath.lowercased().contains(q)
            }
            let allSelected = !filteredItems.isEmpty && filteredItems.allSatisfy { model.selectedTrashedItemIDs.contains($0.id) }

            HStack(spacing: 8) {
                Button {
                    model.toggleSelectAllTrashedItems(in: batch)
                } label: {
                    Image(systemName: allSelected ? "checkmark.square.fill" : (model.selectedTrashedItemIDs.isEmpty ? "square" : "minus.square.fill"))
                        .font(.body)
                        .foregroundStyle(allSelected || !model.selectedTrashedItemIDs.isEmpty ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(allSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll))
                .keyboardShortcut("a", modifiers: .command)

                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField(model.L(.trashFilterItemsPlaceholder), text: $itemSearchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    if !itemSearchText.isEmpty {
                        Button {
                            itemSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))

                Spacer()

                if !model.selectedTrashedItemIDs.isEmpty {
                    Button(role: .destructive) {
                        showingConfirmPurgeSelected = true
                    } label: {
                        Label(
                            model.LF(.trashPurgeSelectedItemsButton, Int64(model.selectedTrashedItemIDs.count)),
                            systemImage: "trash.slash.fill"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)

            Divider()

            List(filteredItems) { item in
                let isSelected = model.selectedTrashedItemIDs.contains(item.id)
                HStack(spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { isSelected },
                        set: { _ in model.toggleTrashedItemSelection(id: item.id) }
                    ))
                    .labelsHidden()

                    let isDir = item.originalPath.hasSuffix("/") || (try? URL(fileURLWithPath: item.originalPath).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    Image(systemName: isDir ? "folder.fill" : "doc.fill")
                        .foregroundStyle(isDir ? Color.accentColor : Color.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.trashedRelativePath)
                            .font(.callout.weight(.medium))
                        Text(item.originalPath)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(DiskSpace.formatBytes(item.sizeBytes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button {
                        let fullTrashURL = URL(fileURLWithPath: batch.batchDirectoryPath).appendingPathComponent(item.trashedRelativePath)
                        model.revealInFinder(fullTrashURL)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help(model.L(.buttonShowInFinder))

                    Button(role: .destructive) {
                        itemToPurge = (batch, item)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.borderless)
                    .help(model.L(.trashPurgeSingleItemTooltip))
                }
                .padding(.vertical, 3)
                .contextMenu {
                    Button(role: .destructive) {
                        itemToPurge = (batch, item)
                    } label: {
                        Label(model.L(.trashPurgeSingleItemTooltip), systemImage: "trash")
                    }

                    Divider()

                    Button {
                        let fullTrashURL = URL(fileURLWithPath: batch.batchDirectoryPath).appendingPathComponent(item.trashedRelativePath)
                        model.revealInFinder(fullTrashURL)
                    } label: {
                        Label(model.L(.buttonShowInFinder), systemImage: "folder")
                    }

                    Button {
                        model.copyToClipboard(item.originalPath)
                    } label: {
                        Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
                    }

                    Button {
                        let fullTrashURL = URL(fileURLWithPath: batch.batchDirectoryPath).appendingPathComponent(item.trashedRelativePath)
                        model.copyToClipboard(fullTrashURL.path)
                    } label: {
                        Label("Çöp Yolunu Kopyala", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button {
                        model.toggleTrashedItemSelection(id: item.id)
                    } label: {
                        Label(
                            isSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll),
                            systemImage: isSelected ? "checkmark.square" : "square"
                        )
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }

    private func badgeStat(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
