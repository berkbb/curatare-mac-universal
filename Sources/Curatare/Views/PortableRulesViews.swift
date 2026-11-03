// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Taşınabilir Kurallar (Ayarlar → Koruma): özel koruma listesi ve Mole purge yolları

/// Dışa aktarma ve içe aktarma sonucunu bildiren uyarı.
private struct PortableRulesAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Seçilen dosyanın doğrulanmış içeriği ve iki kip için hazırlanmış planlar.
private struct PendingPortableRulesImport: Identifiable {
    let id = UUID()
    let fileName: String
    let validation: PortableRulesValidation
    let mergePlan: PortableRulesImportPlan
    let replacePlan: PortableRulesImportPlan

    func plan(for mode: PortableRulesImportMode) -> PortableRulesImportPlan {
        mode == .merge ? mergePlan : replacePlan
    }
}

struct PortableRulesSection: View {
    @Bindable var model: AppModel
    @State private var purgePathCount = 0
    @State private var pendingImport: PendingPortableRulesImport?
    @State private var finishedImport: PortableRulesAlert?
    @State private var resultAlert: PortableRulesAlert?

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.L(.rulesPortableDesc))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label(
                        model.LF(.rulesPortableCounts, model.settings.customWhitelistPaths.count, purgePathCount),
                        systemImage: "doc.badge.gearshape"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        exportRules()
                    } label: {
                        Label(model.L(.rulesExportButton), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)

                    Button {
                        chooseImportFile()
                    } label: {
                        Label(model.L(.rulesImportButton), systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
            .onAppear { refreshPurgePathCount() }
            .sheet(item: $pendingImport, onDismiss: {
                refreshPurgePathCount()
                if let finishedImport {
                    resultAlert = finishedImport
                    self.finishedImport = nil
                }
            }) { pending in
                PortableRulesImportSheet(model: model, pending: pending) { result in
                    finishedImport = result
                }
            }
            .alert(
                resultAlert?.title ?? "",
                isPresented: Binding(
                    get: { resultAlert != nil },
                    set: { if !$0 { resultAlert = nil } }
                ),
                presenting: resultAlert
            ) { _ in
                Button(model.L(.buttonOK)) { resultAlert = nil }
            } message: { alert in
                Text(alert.message)
            }
        } header: {
            Text(model.L(.rulesPortableHeader))
        }
    }

    private func refreshPurgePathCount() {
        purgePathCount = model.molePurgePathsFile.load().count
    }

    private func exportRules() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        let day = Date().formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        panel.nameFieldStringValue = "\(model.L(.rulesExportFileName))-\(day).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.exportPortableRules(to: url)
            resultAlert = PortableRulesAlert(title: model.L(.rulesPortableHeader), message: model.LF(.rulesExportDone, url.lastPathComponent))
        } catch {
            model.log.error(.app, "Portable rules export failed", detail: error.localizedDescription)
            resultAlert = PortableRulesAlert(title: model.L(.errorTitle), message: model.LF(.rulesExportFailed, error.localizedDescription))
        }
    }

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let validation = try model.validatePortableRules(at: url)
            pendingImport = PendingPortableRulesImport(
                fileName: url.lastPathComponent,
                validation: validation,
                mergePlan: model.portableRulesImportPlan(for: validation, mode: .merge),
                replacePlan: model.portableRulesImportPlan(for: validation, mode: .replace)
            )
        } catch {
            let message = model.portableRulesErrorMessage(error)
            model.log.warning(.app, "Portable rules file rejected", detail: message)
            resultAlert = PortableRulesAlert(title: model.L(.errorTitle), message: model.LF(.rulesImportFailed, message))
        }
    }
}

// MARK: - İçe Aktarma Önizlemesi

private struct PortableRulesImportSheet: View {
    @Bindable var model: AppModel
    let pending: PendingPortableRulesImport
    let onFinish: (PortableRulesAlert) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mode: PortableRulesImportMode = .merge

    private var plan: PortableRulesImportPlan { pending.plan(for: mode) }
    private var rejected: [PortableRuleRejection] { pending.validation.rejected }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.L(.rulesImportTitle))
                        .font(.title3.weight(.semibold))
                    Text(model.LF(.rulesImportSource, pending.fileName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Label(model.L(.rulesImportSafetyNote), systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if pending.validation.isNewerThanSupported {
                Label(model.LF(.rulesImportNewerVersion, pending.validation.sourceVersion), systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Picker(model.L(.rulesImportModeLabel), selection: $mode) {
                ForEach(PortableRulesImportMode.allCases) { mode in
                    Text(model.L(mode.titleKey)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(model.L(mode.noteKey))
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !plan.hasChanges {
                        Label(model.L(.rulesPreviewNothing), systemImage: "checkmark.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    pathGroup(model.LF(.rulesPreviewWhitelistAdd, plan.whitelistToAdd.count), plan.whitelistToAdd, systemImage: "plus.circle.fill", tint: .green)
                    pathGroup(model.LF(.rulesPreviewWhitelistRemove, plan.whitelistToRemove.count), plan.whitelistToRemove, systemImage: "minus.circle.fill", tint: .orange)
                    pathGroup(model.LF(.rulesPreviewPurgeAdd, plan.purgePathsToAdd.count), plan.purgePathsToAdd, systemImage: "plus.circle.fill", tint: .green)
                    pathGroup(model.LF(.rulesPreviewPurgeRemove, plan.purgePathsToRemove.count), plan.purgePathsToRemove, systemImage: "minus.circle.fill", tint: .orange)
                    if !rejected.isEmpty {
                        rejectedGroup
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
            }

            HStack {
                Spacer()
                Button(model.L(.buttonCancel), role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(model.L(.rulesImportButton)) {
                    applyImport()
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!plan.hasChanges)
            }
        }
        .padding(20)
        .frame(width: 580, height: 540)
    }

    @ViewBuilder
    private func pathGroup(_ title: String, _ paths: [String], systemImage: String, tint: Color) -> some View {
        if !paths.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.medium))
                ForEach(paths, id: \.self) { path in
                    Label {
                        Text(path)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: systemImage)
                            .foregroundStyle(tint)
                    }
                }
            }
        }
    }

    private var rejectedGroup: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.LF(.rulesPreviewRejected, rejected.count))
                .font(.callout.weight(.medium))
            ForEach(rejected) { rejection in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(model.L(rejection.section.titleKey))
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                            if !rejection.entry.isEmpty {
                                Text(rejection.entry)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Text(reasonText(rejection.reason))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func reasonText(_ reason: PortableRuleRejection.Reason) -> String {
        if case .protected(let detail) = reason {
            return model.LF(.rulesRejectProtected, detail)
        }
        return model.L(reason.titleKey)
    }

    private func applyImport() {
        let plan = plan
        do {
            try model.applyPortableRulesImport(plan)
            onFinish(PortableRulesAlert(
                title: model.L(.rulesImportDoneTitle),
                message: model.LF(
                    .rulesImportDoneMessage,
                    plan.whitelistToAdd.count,
                    plan.whitelistToRemove.count,
                    plan.purgePathsToAdd.count,
                    plan.purgePathsToRemove.count,
                    rejected.count
                )
            ))
        } catch {
            model.log.error(.app, "Portable rules import failed", detail: error.localizedDescription)
            onFinish(PortableRulesAlert(title: model.L(.errorTitle), message: model.LF(.rulesImportFailed, error.localizedDescription)))
        }
        dismiss()
    }
}
