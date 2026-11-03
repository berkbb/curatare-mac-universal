// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - 5b. Disk Analizi → Yinelenen İndirmeler (`DuplicateFileFinder`)

/// `~/Downloads` içindeki, birbirinin APFS klonu olmayan aynı içerikli dosyalar. Salt okunurdur;
/// tek eylem seçili fazla kopyaları tarihli Çöp'e taşımaktır. Tarama sekme açılınca ya da Tara ile başlar.
struct DuplicateDownloadsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            folderBar
            content
            if let groups = model.duplicateScan?.groups, !groups.isEmpty {
                actionBar
            }
        }
        .loadOnFirstVisit(isLoaded: model.hasScannedDuplicateDownloads, isBusy: model.isBusy) {
            await model.scanDuplicateDownloads()
        }
    }

    private var appLocale: Locale {
        Locale(identifier: model.settings.resolvedLanguageCode)
    }

    private var folderBar: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
            Text(model.downloadsDirectoryURL.path)
                .font(.caption.monospaced())
            Spacer()
            if let groups = model.duplicateScan?.groups, !groups.isEmpty {
                Text(model.LF(.duplicatesReclaimable, DiskSpace.formatBytes(groups.map(\.reclaimableBytes).saturatingSum())))
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var content: some View {
        if let scan = model.duplicateScan {
            if scan.accessDenied {
                ContentUnavailableView {
                    Label(model.L(.duplicatesAccessDeniedTitle), systemImage: "lock.shield")
                } description: {
                    Text(model.L(.duplicatesAccessDeniedMessage))
                } actions: {
                    Button(model.L(.settingsOpenSystemSettings)) {
                        FullDiskAccess.openSystemSettings()
                    }
                    .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if scan.groups.isEmpty {
                ContentUnavailableView(
                    model.L(.duplicatesNoneTitle),
                    systemImage: "doc.on.doc",
                    description: Text(model.LF(
                        .duplicatesNoneMessage,
                        Int64(scan.examinedFileCount),
                        DiskSpace.formatBytes(model.duplicateFinder.minimumFileSize)
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                groupList(scan.groups)
            }
        } else if model.isBusy {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                model.L(.duplicatesNotScannedTitle),
                systemImage: "doc.on.doc",
                description: Text(model.L(.duplicatesNotScannedMessage))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func groupList(_ groups: [DuplicateFileGroup]) -> some View {
        List {
            ForEach(groups) { group in
                Section {
                    ForEach(group.copies) { copy in
                        copyRow(copy, in: group)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(group.copies[0].url.lastPathComponent)
                            .font(.subheadline.weight(.semibold))
                        Text(model.LF(.duplicatesGroupDetail, Int64(group.copies.count), DiskSpace.formatBytes(group.fileSize)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(group.sha256.prefix(12))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .help(group.sha256)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func copyRow(_ copy: DuplicateFileCopy, in group: DuplicateFileGroup) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { copy.isSelected },
                set: { _ in model.toggleDuplicateCopySelection(groupID: group.id, copyID: copy.id) }
            ))
            .labelsHidden()
            .disabled(!model.canSelectDuplicateCopy(groupID: group.id, copyID: copy.id))
            .help(model.L(.duplicatesKeepOneHelp))

            Image(nsImage: AppIconCache.shared.icon(for: copy.url.path, size: 28))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(copy.url.lastPathComponent)
                        .font(.body.weight(.medium))
                    if copy.id == group.copies.first?.id {
                        Text(model.L(.duplicatesOldestBadge))
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                Text(copy.url.deletingLastPathComponent().path)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Text(model.LF(.duplicatesCreated, copy.createdAt.formatted(Date.FormatStyle(date: .long, time: .shortened).locale(appLocale))))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if !copy.sharedURLs.isEmpty {
                    Text(model.LF(.duplicatesSharedWith, copy.sharedURLs.map(\.lastPathComponent).joined(separator: ", ")))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Text(DiskSpace.formatBytes(group.fileSize))
                .font(.callout.monospacedDigit())

            Button {
                model.revealInFinder(copy.url)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help(model.L(.buttonShowInFinder))
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                model.revealInFinder(copy.url)
            } label: {
                Label(model.L(.buttonShowInFinder), systemImage: "folder")
            }
            Button {
                model.copyToClipboard(copy.url.path)
            } label: {
                Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
            }
            Button {
                model.copyToClipboard(copy.url.lastPathComponent)
            } label: {
                Label(model.L(.contextMenuCopyName), systemImage: "doc.on.doc")
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(model.allDuplicateExtrasSelected ? model.L(.buttonDeselectAll) : model.L(.duplicatesSelectExtras)) {
                model.toggleSelectAllDuplicateExtras()
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .fixedSize()

            if model.selectedDuplicateCopyCount > 0 {
                Text(model.LF(.duplicatesSelectedSummary, Int64(model.selectedDuplicateCopyCount), DiskSpace.formatBytes(model.selectedDuplicateBytes)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.requestMoveDuplicatesToDatedTrash()
            } label: {
                Label(model.L(.buttonMoveToDatedTrash), systemImage: "trash")
            }
            .buttonStyle(.glassProminent)
            .fixedSize()
            .disabled(model.isBusy || model.selectedDuplicateCopyCount == 0)
        }
    }
}
