// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - Ayarlar Penceresi (`SettingsView`) — Arhivar & Copiator ile Bire Bir Uyumlu

public struct SettingsView: View {
    @Bindable public var model: AppModel
    @State private var confirmReset = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        TabView {
            Tab(model.L(.settingsGeneral), systemImage: "gearshape") {
                GeneralSettingsView(model: model)
            }

            Tab(model.L(.settingsProtection), systemImage: "shield.lefthalf.filled") {
                ProtectionSettingsView(model: model)
            }

            Tab(model.L(.settingsShortcuts), systemImage: "command") {
                ShortcutsSettingsView(model: model)
            }

            Tab(model.L(.settingsAdvanced), systemImage: "wrench.and.screwdriver") {
                AdvancedSettingsView(model: model, confirmReset: $confirmReset)
            }
        }
        .frame(width: 640)
        .frame(minHeight: 580, idealHeight: 640)
        .alert(model.L(.updateSection), isPresented: Binding(
            get: { model.updateAlertMessage != nil },
            set: { if !$0 { model.updateAlertMessage = nil } }
        )) {
            Button(model.L(.buttonOK)) {
                model.updateAlertMessage = nil
            }
        } message: {
            Text(model.updateAlertMessage ?? "")
        }
    }
}

// MARK: - 1. Genel Ayarlar (Dil, Görünüm, Çöp Sepeti Onayları ve Bildirimler)

private struct GeneralSettingsView: View {
    @Bindable var model: AppModel
    @State private var showRestartAlert = false

    var body: some View {
        Form {
            // Dil ve Görünüm Tercihleri
            Section {
                Picker(model.L(.settingsLanguage), selection: $model.settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text("\(language.flag)  \(language.nativeName ?? model.L(.languageSystem))")
                            .tag(language)
                    }
                }
                .onChange(of: model.settings.language) { _, _ in
                    showRestartAlert = true
                }

                Picker(model.L(.settingsAppearance), selection: $model.settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(model.L(appearance.titleKey), systemImage: icon(for: appearance))
                            .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(model.L(.restartMenuBarNotice))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Davranış ve Bildirimler
            Section(model.L(.settingsInterfaceSection)) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(model.L(.settingsProtectRunningApps), isOn: $model.settings.protectRunningApps)
                    Text(model.L(.settingsProtectRunningAppsNote))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(model.L(.settingsConfirmation), isOn: $model.settings.confirmBeforeTrashMove)
                    Text(model.L(.settingsConfirmationNote))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(model.L(.settingsPlaySoundEffects), isOn: $model.settings.playSoundEffects)
                    Text(model.L(.settingsPlaySoundEffectsDesc))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(model.L(.settingsShowMenuBarIcon), isOn: $model.settings.showMenuBarIcon)
                    Text(model.L(.settingsShowMenuBarIconDesc))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Toggle(model.L(.settingsShowDockProgress), isOn: $model.settings.showDockProgress)
            }
        }
        .formStyle(.grouped)
        .alert(model.L(.restartWarningTitle), isPresented: $showRestartAlert) {
            Button(model.L(.buttonOK), role: .cancel) {}
        } message: {
            Text(model.L(.restartWarningMessage))
        }
    }

    private func icon(for appearance: AppAppearance) -> String {
        switch appearance {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
}

// MARK: - 2. Temizlik ve Koruma (SmartDelete, Uygulama Koruması, Beyaz Liste, Anayasal Kurallar)

private struct ProtectionSettingsView: View {
    @Bindable var model: AppModel
    @State private var selectedWhitelistPath: String?

    var body: some View {
        Form {
            // 1. Akıllı Silme (SmartDelete)
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(model.L(.settingsSmartDelete), isOn: Binding(
                        get: { model.settings.smartDeleteEnabled },
                        set: {
                            model.settings.smartDeleteEnabled = $0
                            model.configureSmartDeleteWatcher()
                        }
                    ))
                    Text(model.L(.settingsSmartDeleteNote))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(model.L(.settingsTabSmartDelete))
            }

            // 1.5. Tam Disk Erişimi Tanılaması (Full Disk Access Diagnostics)
            Section {
                HStack(spacing: 12) {
                    Image(systemName: FullDiskAccess.isGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.title2)
                        .foregroundStyle(FullDiskAccess.isGranted ? Color.green : Color.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(FullDiskAccess.isGranted ? model.L(.settingsFullDiskAccessGranted) : model.L(.settingsFullDiskAccessMissing))
                            .font(.callout.weight(.medium))
                        Text(model.L(.settingsFullDiskAccessDesc))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !FullDiskAccess.isGranted {
                        Button(model.L(.settingsOpenSystemSettings)) {
                            FullDiskAccess.openSystemSettings()
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                }
            } header: {
                Text(model.L(.settingsFullDiskAccessHeader))
            }

            // 2. Uygulama Koruma Seçenekleri
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(model.L(.settingsProtectRunningApps), isOn: $model.settings.protectRunningApps)
                    Text(model.L(.settingsProtectRunningAppsNote))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(model.L(.settingsShowProtectedApps), isOn: $model.settings.showProtectedApps)
                    Text(model.L(.settingsShowProtectedAppsNote))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Toggle(model.L(.settingsAllowUninstallingProtectedApps), isOn: $model.settings.allowUninstallingProtectedApps)
                        .onChange(of: model.settings.allowUninstallingProtectedApps) { _, _ in
                            Task { await model.scanUninstallerBundles() }
                        }
                    Text(model.L(.settingsAllowUninstallingProtectedAppsNote))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text(model.L(.settingsProtection))
            } footer: {
                Text(model.L(.settingsProtectRunningAppsFooter))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // 3. Güvende Tutulacak Ek Uygulamalar (Beyaz Liste)
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.L(.settingsAddAppsToKeepSafe))
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 1) {
                                if model.settings.customWhitelistPaths.isEmpty {
                                    Text(model.L(.settingsWhitelistEmpty))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, minHeight: 65, alignment: .center)
                                } else {
                                    ForEach(model.settings.customWhitelistPaths, id: \.self) { path in
                                        let isSelected = selectedWhitelistPath == path
                                        HStack(spacing: 8) {
                                            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                                .resizable()
                                                .frame(width: 18, height: 18)

                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
                                                    .font(.callout.weight(.medium))
                                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                                                    .lineLimit(1)
                                                Text(path)
                                                    .font(.caption2.monospaced())
                                                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }

                                            Spacer()
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isSelected ? Color.accentColor : Color.clear)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedWhitelistPath = path
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 75)
                        .background(Color(nsColor: .controlBackgroundColor))

                        Divider()

                        HStack {
                            HStack(spacing: 0) {
                                Button {
                                    chooseWhitelistItems()
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.caption.bold())
                                        .frame(width: 24, height: 18)
                                }
                                .buttonStyle(.plain)
                                .help(model.L(.settingsWhitelistAdd))

                                Divider()
                                    .frame(height: 12)

                                Button {
                                    if let path = selectedWhitelistPath {
                                        model.settings.removeWhitelistPath(path)
                                        selectedWhitelistPath = nil
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.caption.bold())
                                        .frame(width: 24, height: 18)
                                }
                                .buttonStyle(.plain)
                                .disabled(selectedWhitelistPath == nil)
                                .help(model.L(.settingsWhitelistRemove))
                            }
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.8)
                            }
                            .padding(3)

                            Spacer()
                        }
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                    }
                }
            }

            // 4. Anayasal Koruma Kuralları
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                        Text(model.L(.settingsProtectedRulesTitle))
                            .font(.callout.weight(.medium))
                    }
                    Text(model.L(.settingsProtectedRulesDesc))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .formStyle(.grouped)
    }

    private func chooseWhitelistItems() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK {
            for url in panel.urls {
                model.settings.addWhitelistPath(url.path)
            }
        }
    }
}

private struct ShortcutsSettingsView: View {
    @Bindable var model: AppModel
    @State private var recordingAction: ShortcutAction?
    @State private var keyMonitor: Any?
    @State private var conflictMessage: String?

    var body: some View {
        Form {
            Section {
                ForEach(ShortcutAction.allCases) { action in
                    shortcutRow(action)
                }
            } header: {
                Text(model.L(.settingsShortcutsDesc))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } footer: {
                if let msg = conflictMessage {
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section(model.L(.settingsShortcutRefTitle)) {
                HStack(spacing: 16) {
                    refItem(model.L(.shortcutRefCut), keys: "⌘X")
                    Divider()
                        .frame(height: 14)
                    refItem(model.L(.shortcutRefCopy), keys: "⌘C")
                }
                HStack(spacing: 16) {
                    refItem(model.L(.shortcutRefPaste), keys: "⌘V")
                    Divider()
                        .frame(height: 14)
                    refItem(model.L(.shortcutRefSelectAll), keys: "⌘A")
                }
            }

            Section {
                Button(model.L(.shortcutResetAll)) {
                    model.settings.resetShortcuts()
                    conflictMessage = nil
                }
            }
        }
        .formStyle(.grouped)
        .onDisappear { stopRecording() }
    }

    private func shortcutRow(_ action: ShortcutAction) -> some View {
        let sc = model.settings.shortcut(for: action)
        let isRecording = recordingAction == action
        let isDefault = sc == action.defaultShortcut

        return HStack {
            Text(model.L(action.labelKey))
            Spacer()

            Button {
                if isRecording { stopRecording() } else { startRecording(action) }
            } label: {
                Text(isRecording ? model.L(.shortcutPressKeys) : sc.displayString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isRecording ? Color.accentColor : .primary)
                    .frame(minWidth: 96)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)

            Button {
                model.settings.shortcuts[action] = action.defaultShortcut
                conflictMessage = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .disabled(isDefault)
            .help(model.L(.shortcutReset))
        }
    }

    private func refItem(_ label: String, keys: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private func startRecording(_ action: ShortcutAction) {
        stopRecording()
        recordingAction = action
        conflictMessage = nil
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasCmd = flags.contains(.command)
            let hasCtrl = flags.contains(.control)
            let hasOpt = flags.contains(.option)
            let hasShift = flags.contains(.shift)

            guard hasCmd || hasCtrl else { return nil }
            guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else { return nil }

            let newSC = KeyboardShortcutData(
                key: chars.lowercased(),
                command: hasCmd,
                shift: hasShift,
                option: hasOpt,
                control: hasCtrl
            )

            for other in ShortcutAction.allCases where other != action {
                if model.settings.shortcut(for: other) == newSC {
                    conflictMessage = model.LF(.shortcutConflict, model.L(other.labelKey))
                    stopRecording()
                    return nil
                }
            }

            model.settings.shortcuts[action] = newSC
            conflictMessage = nil
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        recordingAction = nil
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

private struct AdvancedSettingsView: View {
    @Bindable var model: AppModel
    @Binding var confirmReset: Bool

    var body: some View {
        Form {
            Section(model.L(.settingsEngine)) {
                LabeledContent(model.L(.settingsEnginePath)) {
                    Text(model.engineInfo?.url.path ?? model.L(.settingsEngineNotFound))
                        .lineLimit(1)
                        .truncationMode(.head)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                LabeledContent(model.L(.settingsEngineVersion)) {
                    engineVersionLabel
                }
                Toggle(model.L(.settingsEngineUseCustom), isOn: useCustomEngine)
                if !model.settings.customEnginePath.isEmpty {
                    LabeledContent("mole") {
                        HStack {
                            Text(model.settings.customEnginePath)
                                .lineLimit(1)
                                .truncationMode(.head)
                                .foregroundStyle(.secondary)
                            Button(model.L(.buttonChoose)) {
                                chooseEngine()
                            }
                        }
                    }
                }
                Button(model.L(.settingsEngineCheck)) {
                    Task { await model.refreshEngine() }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(model.L(.settingsSandbox), isOn: $model.settings.sandboxEngine)
                        .disabled(!SandboxProfile.isAvailable)
                    Text(model.L(.settingsSandboxNote))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                updateStatus
                HStack {
                    Button(model.L(.updateCheck)) {
                        Task { await model.checkMoleUpdate(interactive: true) }
                    }
                    .disabled(model.engineUpdateState == .checking || isInstalling)

                    if case .available = model.engineUpdateState {
                        Button(model.L(.updateInstall)) {
                            Task { await model.installMoleUpdate(force: true) }
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
            } header: {
                Text(model.L(.updateSection))
            } footer: {
                Text(model.L(.updateSource))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(model.L(.appUpdateSection)) {
                LabeledContent(model.L(.settingsEngineVersion), value: "\(AppInfo.version) (\(AppInfo.build))")
                appUpdateStatus
                HStack {
                    Button(model.L(.updateCheck)) {
                        Task { await model.checkAppUpdate(interactive: true) }
                    }
                    .disabled(model.appUpdateUIState == .checking)

                    if case .available = model.appUpdateUIState {
                        Button(model.L(.appUpdateDownload)) {
                            model.openAppDownload()
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                Toggle(model.L(.updateAutoCheck), isOn: $model.settings.checkUpdatesAtLaunch)
                    .onChange(of: model.settings.checkUpdatesAtLaunch) {
                        model.settings.updateConsentAsked = true
                    }
            }

            Section {
                Button(model.L(.settingsReset), role: .destructive) {
                    confirmReset = true
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(model.L(.settingsResetConfirm), isPresented: $confirmReset) {
            Button(model.L(.settingsReset), role: .destructive) {
                model.settings.resetToDefaults()
                model.configureSmartDeleteWatcher()
                Task { await model.refreshEngine() }
            }
            Button(model.L(.buttonCancel), role: .cancel) {}
        }
    }

    private var isInstalling: Bool {
        if case .installing = model.engineUpdateState { return true }
        return false
    }

    @ViewBuilder
    private var engineVersionLabel: some View {
        if let info = model.engineInfo {
            Label(info.version, systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        } else {
            Label(model.L(.settingsEngineNotFound), systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch model.engineUpdateState {
        case .idle:
            Label(model.LF(.updateUpToDate, model.engineInfo?.version ?? "1.82.0"), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .checking:
            Label { Text(model.L(.updateChecking)) } icon: { ProgressView().controlSize(.small) }
        case .available(let latest):
            Label(model.LF(.updateAvailable, latest), systemImage: "arrow.down.circle.fill")
                .foregroundStyle(.tint)
        case .upToDate(let version):
            Label(model.LF(.updateUpToDate, version), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .installing:
            Label { Text(model.L(.updateInstalling)) } icon: { ProgressView().controlSize(.small) }
        case .installed(let version):
            Label(model.LF(.updateInstalled, version), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(model.LF(.updateFailed, message), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var appUpdateStatus: some View {
        switch model.appUpdateUIState {
        case .idle:
            EmptyView()
        case .checking:
            Label { Text(model.L(.updateCheckingApp)) } icon: { ProgressView().controlSize(.small) }
        case .available(let release):
            Label(model.LF(.appUpdateAvailable, release.version), systemImage: "arrow.down.circle.fill")
                .foregroundStyle(.tint)
        case .upToDate(let version):
            Label(model.LF(.appUpdateUpToDate, version), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .noReleases:
            Label(model.L(.appUpdateNoReleases), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .failed(let message):
            Label(model.LF(.appUpdateAlertFailed, message), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .unconfigured:
            Label(model.L(.appUpdateAlertUnconfigured), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private var useCustomEngine: Binding<Bool> {
        Binding(
            get: { !model.settings.customEnginePath.isEmpty },
            set: { enabled in
                if enabled {
                    chooseEngine()
                } else {
                    model.settings.customEnginePath = ""
                    Task { await model.refreshEngine() }
                }
            }
        )
    }

    private func chooseEngine() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/bin")
        if panel.runModal() == .OK, let url = panel.url {
            model.settings.customEnginePath = url.path
            Task { await model.refreshEngine() }
        }
    }
}

// MARK: - Günlük Penceresi (`LogView`) — Arhivar & Copiator ile Bire Bir Uyumlu

public struct LogView: View {
    @Bindable public var model: AppModel
    @State private var entries: [AppLog.Entry] = []
    @State private var selection: AppLog.Entry.ID?
    @State private var problemsOnly = false
    @State private var search = ""
    @State private var observerID: UUID?

    public init(model: AppModel) {
        self.model = model
    }

    private var filtered: [AppLog.Entry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            if problemsOnly && !entry.level.isProblem { return false }
            guard !query.isEmpty else { return true }
            return entry.message.localizedStandardContains(query)
                || (entry.detail?.localizedStandardContains(query) ?? false)
                || categoryTitle(entry.category).localizedStandardContains(query)
                || levelTitle(entry.level).localizedStandardContains(query)
                || String(entry.process).contains(query)
        }
    }

    private var selectedEntry: AppLog.Entry? {
        guard let selection else { return nil }
        return entries.first { $0.id == selection }
    }

    public var body: some View {
        VSplitView {
            table
                .frame(minHeight: 220)
            detailPane
                .frame(minHeight: 110, idealHeight: 150)
        }
        .navigationTitle(model.L(.logTitle))
        .navigationSubtitle(subtitle)
        .searchable(text: $search, placement: .toolbar, prompt: model.L(.logSearchPrompt))
        .toolbar { toolbarContent }
        .frame(minWidth: 760, minHeight: 420)
        .onAppear(perform: startObserving)
        .onDisappear(perform: stopObserving)
    }

    private var subtitle: String {
        let total = entries.count
        let shown = filtered.count
        if shown == total {
            return model.LF(.logTotalCount, Int64(total))
        }
        return model.LF(.logFilterCount, Int64(shown), Int64(total))
    }

    @ViewBuilder
    private var table: some View {
        if filtered.isEmpty {
            ContentUnavailableView(
                model.L(.logEmptyTitle),
                systemImage: "text.justify.left",
                description: Text(model.L(.logEmptyMessage))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Table(filtered, selection: $selection) {
                TableColumn(model.L(.logColumnTime)) { entry in
                    Text(Self.timeFormatter.string(from: entry.date))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .width(min: 145, ideal: 160, max: 185)

                TableColumn(model.L(.logColumnType)) { entry in
                    Label(levelTitle(entry.level), systemImage: symbol(for: entry.level))
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(color(for: entry.level))
                }
                .width(min: 80, ideal: 92, max: 115)

                TableColumn(model.L(.logColumnCategory)) { entry in
                    Text(categoryTitle(entry.category))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .width(min: 95, ideal: 115, max: 140)

                TableColumn(model.L(.logColumnProcess)) { entry in
                    Text("Curatare (\(entry.process))")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .width(min: 100, ideal: 118, max: 135)

                TableColumn(model.L(.logColumnMessage)) { entry in
                    Text(entry.message)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(entry.text)
                }
            }
            .contextMenu(forSelectionType: AppLog.Entry.ID.self) { ids in
                if let id = ids.first, let entry = entries.first(where: { $0.id == id }) {
                    Button(model.L(.buttonCopyCommand)) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(formattedLine(for: entry), forType: .string)
                    }
                }
            }
        }
    }

    private var detailPane: some View {
        ScrollView {
            Group {
                if let entry = selectedEntry {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Label(levelTitle(entry.level), systemImage: symbol(for: entry.level))
                                .foregroundStyle(color(for: entry.level))
                                .font(.caption.weight(.semibold))
                            Text(categoryTitle(entry.category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("PID \(entry.process)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Self.timeFormatter.string(from: entry.date))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.text)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text(model.L(.logEmptyMessage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
        }
        .background(.background.secondary)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Picker("", selection: $problemsOnly) {
                Text(model.L(.logAllMessages)).tag(false)
                Text(model.L(.logProblems)).tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            Button {
                if let url = model.log.fileURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } label: {
                Label(model.L(.logOpenInConsole), systemImage: "folder")
            }
            .help(model.L(.logOpenInConsole))

            Button {
                model.log.clear()
                selection = nil
            } label: {
                Label(model.L(.logClear), systemImage: "trash")
            }
            .disabled(entries.isEmpty)
            .help(model.L(.logClear))
        }
    }

    private func startObserving() {
        entries = model.log.entries
        observerID = model.log.observe { [log = model.log] in
            let snapshot = log.entries
            Task { @MainActor in
                entries = snapshot
            }
        }
    }

    private func stopObserving() {
        if let observerID {
            model.log.removeObserver(observerID)
            self.observerID = nil
        }
    }

    private func formattedLine(for entry: AppLog.Entry) -> String {
        let head = "\(Self.timeFormatter.string(from: entry.date)) [\(levelTitle(entry.level))] [\(categoryTitle(entry.category))] Curatare(\(entry.process)): \(entry.message)"
        if let detail = entry.detail {
            return head + "\n" + detail
        }
        return head
    }

    private func symbol(for level: AppLog.Level) -> String {
        switch level {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private func color(for level: AppLog.Level) -> Color {
        switch level {
        case .info: .secondary
        case .warning: .orange
        case .error: .red
        }
    }

    private func levelTitle(_ level: AppLog.Level) -> String {
        switch level {
        case .info: model.L(.logLevelInfo)
        case .warning: model.L(.logLevelWarning)
        case .error: model.L(.logLevelError)
        }
    }

    private func categoryTitle(_ category: AppLog.Category) -> String {
        switch category {
        case .app: model.L(.logCategoryApp)
        case .engine: model.L(.logCategoryEngine)
        case .audit: model.L(.logCategoryAudit)
        case .uninstall: model.L(.logCategoryUninstall)
        case .trash: model.L(.logCategoryTrash)
        case .update: model.L(.logCategoryUpdate)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Hakkında Penceresi (`AboutView`) & Lisans Görüntüleyici (`LicenseViewerSheet`) — Arhivar & Copiator ile Bire Bir Uyumlu

public struct AboutView: View {
    @Bindable public var model: AppModel
    @State private var license: LicenseDocument?

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 116, height: 116)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 5)

            VStack(spacing: 5) {
                Text(model.L(.appName))
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text(model.LF(.aboutVersion, AppInfo.version, AppInfo.build))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text(model.L(.appTagline))
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(maxWidth: 520)
                    .padding(.top, 2)
            }

            Divider()
                .padding(.horizontal, 50)

            VStack(spacing: 8) {
                Label(
                    model.LF(.aboutPoweredBy, model.engineInfo?.version ?? "1.67.0"),
                    systemImage: "cpu"
                )
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(nil)

                Text(model.L(.aboutEngineCredit))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(maxWidth: 520)
            }
            .padding(.horizontal, 16)

            GlassEffectContainer(spacing: 8) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Link(destination: AppLinks.repository) {
                            Label(model.L(.aboutRepository), systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                        .buttonStyle(.glass)

                        Link(destination: AppLinks.engineWebsite) {
                            Label(model.L(.aboutEngineWebsite), systemImage: "globe")
                        }
                        .buttonStyle(.glass)

                        Link(destination: AppLinks.engineManual) {
                            Label(model.L(.menuEngineManual), systemImage: "book")
                        }
                        .buttonStyle(.glass)
                    }

                    HStack(spacing: 10) {
                        ForEach(LicenseDocument.allCases) { document in
                            Button {
                                license = document
                            } label: {
                                Label(model.L(document.titleKey), systemImage: document.systemImage)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
                .controlSize(.small)
            }

            Text(model.L(.aboutCopyright))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 36)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 600)
        .containerBackground(.thickMaterial, for: .window)
        .windowMinimizeBehavior(.disabled)
        .sheet(item: $license) { item in
            LicenseViewerSheet(item: item, model: model)
        }
    }
}

private struct LicenseViewerSheet: View {
    let item: LicenseDocument
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(model.L(item.titleKey), systemImage: item.systemImage)
                    .font(.headline)
                Spacer()
                Button(model.L(.buttonClose)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            ScrollView {
                Text(item.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
        .frame(width: 640, height: 480)
    }
}
