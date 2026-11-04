// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - Sol Panel Başlığı (Tür Menüsü, Arama Kutusu ve Yenileme)

extension UninstallerView {
    var uninstallerNavigationHeader: some View {
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
}
