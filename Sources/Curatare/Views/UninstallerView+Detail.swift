// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - Sağ Panel: Detaylı İnceleme ve İlişkili Dosyalar

extension UninstallerView {
    func inspectedBundleView(_ bundle: InstalledBundle) -> some View {
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

    func handleDrop(providers: [NSItemProvider]) -> Bool {
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
