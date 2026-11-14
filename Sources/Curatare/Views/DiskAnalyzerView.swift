// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - 5. Etkileşimli Disk Analizi (`analyze-go`) Görünümü

public struct DiskAnalyzerView: View {
    @Bindable public var model: AppModel
    @State private var selectedEntryID: MoleDiskEntry.ID?
    @State private var pendingSelectionID: MoleDiskEntry.ID?

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBar

            switch model.diskAnalyzerSubTab {
            case .usage:
                usageContent
                    .loadOnFirstVisit(isLoaded: model.diskAnalysis != nil, isBusy: model.isBusy) {
                        await model.analyzeFolder()
                    }
            case .duplicateDownloads:
                DuplicateDownloadsView(model: model)
            }
        }
        .padding(16)
    }

    // Başlık ve düğmeler üst satırda, alt sekme seçici kendi satırında (Sistem Durumu ile aynı düzen).
    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    switch model.diskAnalyzerSubTab {
                    case .usage:
                        Text(model.L(.diskTitle))
                            .font(.title2.bold())
                        Text(model.L(.diskSubtitle))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    case .duplicateDownloads:
                        Text(model.L(.duplicatesTitle))
                            .font(.title2.bold())
                        Text(model.LF(.duplicatesSubtitle, DiskSpace.formatBytes(model.duplicateFinder.minimumFileSize)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 16)
                switch model.diskAnalyzerSubTab {
                case .usage:
                    Button(model.L(.diskNavigateUp)) {
                        Task { await model.navigateUpDiskAnalyzer() }
                    }
                    .buttonStyle(.glass)
                    .fixedSize()
                    .disabled(model.currentAnalyzedURL.path == "/")
                    Button(model.L(.diskChooseFolder)) {
                        chooseFolder()
                    }
                    .buttonStyle(.glass)
                    .fixedSize()
                    Button {
                        Task { await model.analyzeFolder() }
                    } label: {
                        Label(model.L(.buttonScan), systemImage: "chart.pie")
                    }
                    .buttonStyle(.glassProminent)
                    .fixedSize()
                case .duplicateDownloads:
                    Button {
                        Task { await model.scanDuplicateDownloads() }
                    } label: {
                        Label(model.L(.buttonScan), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.glassProminent)
                    .fixedSize()
                }
            }

            Picker("", selection: $model.diskAnalyzerSubTab) {
                Text(model.L(.diskTabUsage)).tag(DiskAnalyzerSubTab.usage)
                Text(model.L(.diskTabDuplicateDownloads)).tag(DiskAnalyzerSubTab.duplicateDownloads)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var usageContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
                Text(model.currentAnalyzedURL.path)
                    .font(.caption.monospaced())
                Spacer()
                if let analysis = model.diskAnalysis {
                    Text(model.LF(.diskTotalSize, DiskSpace.formatBytes(analysis.totalSize)))
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))

            if let analysis = model.diskAnalysis, !analysis.entries.isEmpty {
                let maxSize = max(1, analysis.entries.first?.size ?? 1)
                List(analysis.entries, selection: $selectedEntryID) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.isDir ? "folder.fill" : "doc.fill")
                            .foregroundStyle(entry.isDir ? .blue : .secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                                .font(.body.weight(.medium))
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor.opacity(0.65))
                                    .frame(width: max(4, geo.size.width * CGFloat(Double(entry.size) / Double(maxSize))), height: 6)
                            }
                            .frame(height: 6)
                        }

                        Spacer()

                        Text(DiskSpace.formatBytes(entry.size))
                            .font(.callout.monospacedDigit())

                        if entry.isDir {
                            Button {
                                Task { await model.analyzeFolder(URL(fileURLWithPath: entry.path)) }
                            } label: {
                                Image(systemName: "chevron.right.circle")
                            }
                            .buttonStyle(.borderless)
                        }

                        Button {
                            model.revealInFinder(URL(fileURLWithPath: entry.path))
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button {
                            model.revealInFinder(URL(fileURLWithPath: entry.path))
                        } label: {
                            Label(model.L(.buttonShowInFinder), systemImage: "folder")
                        }
                        if entry.isDir {
                            Button {
                                Task { await model.analyzeFolder(URL(fileURLWithPath: entry.path)) }
                            } label: {
                                Label(model.L(.diskInspectFolder), systemImage: "arrow.down.right.circle")
                            }
                        }
                        Button {
                            model.copyToClipboard(entry.path)
                        } label: {
                            Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
                        }
                        Button {
                            model.copyToClipboard(entry.name)
                        } label: {
                            Label(model.L(.contextMenuCopyName), systemImage: "doc.on.doc")
                        }
                    }
                }
                .listStyle(.inset)
                .onKeyPress(keys: [.rightArrow, .return], phases: .down) { press in
                    guard press.modifiers.intersection([.command, .option, .control]).isEmpty,
                          let target = model.diskAnalyzerTargetFolder(for: selectedEntryID) else {
                        return .ignored
                    }
                    Task { await model.analyzeFolder(target) }
                    return .handled
                }
            } else if model.isBusy {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    model.L(.diskEmptyFolder),
                    systemImage: "externaldrive",
                    description: Text(model.currentAnalyzedURL.path)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onKeyPress(.leftArrow, phases: .down) { press in
            guard press.modifiers.intersection([.command, .option, .control]).isEmpty,
                  model.canNavigateUpDiskAnalyzer() else {
                return .ignored
            }
            Task { await model.navigateUpDiskAnalyzer() }
            return .handled
        }
        .onChange(of: model.currentAnalyzedURL) { oldURL, newURL in
            selectedEntryID = nil
            pendingSelectionID = oldURL.standardizedFileURL.deletingLastPathComponent().path == newURL.standardizedFileURL.path
                ? oldURL.standardizedFileURL.path
                : nil
        }
        .onChange(of: model.diskAnalysis) { _, analysis in
            guard let pending = pendingSelectionID else { return }
            if analysis?.entries.contains(where: { $0.id == pending }) == true {
                selectedEntryID = pending
            }
            pendingSelectionID = nil
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.analyzeFolder(url) }
        }
    }
}
