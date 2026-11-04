// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - Liste Satırı (İkon, Başlık, Yol, Sürüm ve Rozetler)

extension UninstallerView {
    var userBundles: [InstalledBundle] {
        let home = NSHomeDirectory()
        return model.filteredBundles.filter { $0.url.path.hasPrefix(home) }
    }

    var systemBundles: [InstalledBundle] {
        let home = NSHomeDirectory()
        return model.filteredBundles.filter { !$0.url.path.hasPrefix(home) }
    }

    func bundleRow(_ bundle: InstalledBundle) -> some View {
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

    func abbreviatedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
