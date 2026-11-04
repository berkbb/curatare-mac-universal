// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - Sistem İnce Ayarları (macOS Parametreleri) Paneli

extension SystemStatusView {
    var tweaksView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("", selection: $selectedTweakCategory) {
                    Text(model.L(.tweaksCategoryAll)).tag(SystemTweakCategory?.none)
                    ForEach(SystemTweakCategory.allCases) { cat in
                        Label(model.L(cat.titleKey), systemImage: cat.iconSystemName).tag(SystemTweakCategory?.some(cat))
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Spacer()

                if selectedTweakCategory == .dock || selectedTweakCategory == nil {
                    Button {
                        model.addDockSpacer(small: false)
                    } label: {
                        Label(model.L(.buttonAddDockSpacer), systemImage: "plus.rectangle.on.rectangle")
                    }
                    .buttonStyle(.glass)

                    Button {
                        model.removeDockSpacers()
                    } label: {
                        Label(model.L(.buttonRemoveDockSpacers), systemImage: "trash")
                    }
                    .buttonStyle(.glass)
                }

                Button {
                    model.resetAllSystemTweaks()
                } label: {
                    Label(model.L(.tweaksResetAllButton), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.glass)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(visibleTweakCategories) { cat in
                        ForEach(model.systemTweaks.filter { $0.category == cat }) { tweak in
                            tweakCard(tweak)
                        }
                        ForEach(model.systemChoiceTweaks.filter { $0.category == cat }) { tweak in
                            choiceTweakCard(tweak)
                        }
                        if cat == .screenshot {
                            screenshotFormatCard
                            screenshotNameCard
                            screenshotLocationCard
                        }
                        if cat == .system {
                            safariDevelopMenuCard
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollContentBackground(.hidden)
        }
    }

    /// Çok seçenekli tek ince ayar: ekran resmi biçimi (açık/kapalı ayarlardan farklı olarak dört değerli).
    private var screenshotFormatCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "photo.badge.arrow.down")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.L(.tweakScreenshotFormatTitle))
                        .font(.body.weight(.medium))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { model.screenshotFormat },
                        set: { if let format = $0 { model.setScreenshotFormat(format) } }
                    )) {
                        ForEach(ScreenshotFormat.allCases) { format in
                            Text(format.displayName).tag(Optional(format))
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }

                Text(model.L(.tweakScreenshotFormatDesc))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                restartNoticeRow(.tweaksRestartNoticeSystemUI)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    /// Ekran resmi dosya adı öneki; boş bırakılıp uygulanırsa anahtar silinir ve macOS varsayılanı geri gelir.
    private var screenshotNameCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "character.cursor.ibeam")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.L(.tweakScreenshotNameTitle))
                        .font(.body.weight(.medium))
                    Spacer()
                    TextField(model.L(.tweakOptionSystemDefault), text: $screenshotNameDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onSubmit(applyScreenshotNameDraft)
                    Button(model.L(.tweakScreenshotNameApply), action: applyScreenshotNameDraft)
                        .buttonStyle(.glass)
                        .disabled(!screenshotNameDraftChanged)
                }

                Text(model.L(.tweakScreenshotNameDesc))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                restartNoticeRow(.tweaksRestartNoticeSystemUI)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .onAppear { screenshotNameDraft = model.screenshotNamePrefix }
        .onChange(of: model.screenshotNamePrefix) { _, prefix in screenshotNameDraft = prefix }
    }

    /// Ekran resmi kayıt klasörü; varsayılana dönünce anahtar silinir ve macOS Masaüstü'ne kaydeder.
    private var screenshotLocationCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "folder")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.L(.tweakScreenshotLocationTitle))
                        .font(.body.weight(.medium))
                    Spacer()
                    Button(model.L(.tweakScreenshotLocationChoose), action: chooseScreenshotFolder)
                        .buttonStyle(.glass)
                    Button(model.L(.tweakScreenshotLocationReset)) {
                        model.setScreenshotLocation(nil)
                    }
                    .buttonStyle(.glass)
                    .disabled(model.screenshotLocation == nil)
                }

                Group {
                    if let location = model.screenshotLocation {
                        Text((location as NSString).abbreviatingWithTildeInPath)
                            .font(.callout.monospaced())
                    } else {
                        Text(model.L(.tweakScreenshotLocationDefault))
                            .font(.callout)
                    }
                }
                .textSelection(.enabled)

                Text(model.L(.tweakScreenshotLocationDesc))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                restartNoticeRow(.tweaksRestartNoticeSystemUI)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    /// Safari Geliştir menüsünün durumu; Safari dışarıdan açılan ayarı uygulamadığı için değiştirmek Safari'ye bırakılır.
    /// Pencere yeniden etkinleşince durum tazelenir; kullanıcı Safari'de değiştirip döndüğünde kart güncel olur.
    private var safariDevelopMenuCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "safari")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.L(.tweakSafariDevelopMenuTitle))
                        .font(.body.weight(.medium))
                    Spacer()
                    Label(
                        model.L(model.safariDevelopMenuShown ? .tweakOptionOn : .tweakOptionOff),
                        systemImage: model.safariDevelopMenuShown ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.callout)
                    .foregroundStyle(model.safariDevelopMenuShown ? Color.green : Color.secondary)
                    Button(model.L(.tweakSafariOpenButton), action: model.openSafari)
                        .buttonStyle(.glass)
                }

                Text(model.L(.tweakSafariDevelopMenuDesc))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .onAppear { model.refreshSafariDevelopMenuState() }
        .onChange(of: controlActiveState) { _, _ in model.refreshSafariDevelopMenuState() }
    }

    private func chooseScreenshotFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if let current = model.screenshotLocation {
            panel.directoryURL = URL(fileURLWithPath: (current as NSString).expandingTildeInPath, isDirectory: true)
        }
        if panel.runModal() == .OK, let url = panel.url {
            model.setScreenshotLocation(url.path)
        }
    }

    private var screenshotNameDraftChanged: Bool {
        ScreenshotNamePrefix.sanitized(screenshotNameDraft) != model.screenshotNamePrefix
    }

    private func applyScreenshotNameDraft() {
        guard screenshotNameDraftChanged else { return }
        model.setScreenshotNamePrefix(screenshotNameDraft)
    }

    private var visibleTweakCategories: [SystemTweakCategory] {
        selectedTweakCategory.map { [$0] } ?? SystemTweakCategory.allCases
    }

    /// Birkaç değerden birini seçtiren ince ayar; sayı seçenekleri her dilde aynı yazılır.
    private func choiceTweakCard(_ tweak: SystemChoiceTweak) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: tweak.category.iconSystemName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.L(tweak.titleKey))
                        .font(.body.weight(.medium))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { tweak.selectedOptionID },
                        set: { if let optionID = $0 { model.applyChoiceTweak(id: tweak.id, optionID: optionID) } }
                    )) {
                        ForEach(tweak.options) { option in
                            Text(option.titleKey.map { model.L($0) } ?? option.id).tag(Optional(option.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }

                Text(model.L(tweak.descriptionKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let notice = tweak.restartService.noticeKey {
                    restartNoticeRow(notice)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private func restartNoticeRow(_ notice: LKey) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle")
            Text(model.L(notice))
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.top, 2)
    }

    private func tweakCard(_ tweak: SystemTweakItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: tweak.category.iconSystemName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.L(tweak.titleKey))
                        .font(.body.weight(.medium))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { tweak.isEnabled },
                        set: { model.applySystemTweak(id: tweak.id, enabled: $0) }
                    ))
                    .labelsHidden()
                }

                Text(model.L(tweak.descriptionKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let notice = tweak.restartService.noticeKey {
                    restartNoticeRow(notice)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    func metricCard(title: String, value: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    func taskTitle(_ kind: MoleOptimizationTask.ActionKind) -> String {
        model.L(kind.titleKey)
    }
}
