// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

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
}
