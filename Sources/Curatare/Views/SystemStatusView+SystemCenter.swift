// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - Sistem Merkezi (Desktop/t Referansı: Donanım, Bellek, Birimler, Sistem, Profil)

extension SystemStatusView {
    var systemCenterView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 5 Alt Sekme Barı
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SystemCenterTab.allCases) { tab in
                        let isSelected = model.systemCenterTab == tab
                        Button {
                            model.systemCenterTab = tab
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.iconName)
                                    .font(.caption)
                                Text(model.L(tab.titleKey))
                                    .font(.callout.weight(isSelected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                isSelected ? Color.accentColor : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            // Seçili Alt Sekmenin İçeriği
            ScrollView {
                VStack(spacing: 12) {
                    switch model.systemCenterTab {
                    case .hardware:
                        hardwareCenterView
                    case .memory:
                        memoryCenterView
                    case .volumes:
                        volumesCenterView
                    case .system:
                        osAndIdentityCenterView
                    case .profile:
                        profileCenterView
                    }
                }
                .padding(.bottom, 16)
            }
        }
    }

    private var hardwareCenterView: some View {
        let hw = model.systemCenterHardware ?? SystemCenterHardware()
        return VStack(spacing: 12) {
            // Kart 1: Model
            infoCard {
                infoRow(label: model.L(.sysCenterModelName), value: hw.modelName)
                Divider()
                infoRow(label: model.L(.sysCenterModelIdentifier), value: hw.modelIdentifier)
            }

            // Kart 2: İşlemci & Mimari
            infoCard {
                infoRow(label: model.L(.sysCenterChip), value: hw.chip)
                Divider()
                infoRow(label: model.L(.sysCenterArchitecture), value: hw.architecture.uppercased())
                Divider()
                infoRow(label: model.L(.sysCenterTotalCores), value: totalCoresText(hw))
            }

            // Kart 3: Grafik & Ekran
            infoCard {
                infoRow(label: model.L(.sysCenterGPU), value: hw.gpu.isEmpty || !hw.gpuIsBuiltIn ? hw.gpu : model.LF(.sysCenterGPUBuiltIn, hw.gpu))
                Divider()
                infoRow(label: model.L(.sysCenterGPUCores), value: hw.gpuCores > 0 ? "\(hw.gpuCores)" : "")
                Divider()
                infoRow(label: model.L(.sysCenterResolution), value: hw.resolution)
            }

            // Kart 4: Firmware & Donanım UUID
            infoCard {
                infoRow(label: model.L(.sysCenterSystemFirmware), value: hw.systemFirmwareVersion)
                Divider()
                infoRow(label: model.L(.sysCenterHardwareUUID), value: hw.hardwareUUID, copyable: true)
            }

            // Kart 5: Depolama & Seri No
            infoCard {
                infoRow(label: model.L(.sysCenterPhysicalDisk), value: hw.physicalDisk)
                Divider()
                smartStatusRow(hw.smartStatus)
                Divider()
                infoRow(label: model.L(.sysCenterSerialNumber), value: hw.serialNumber, copyable: true)
            }
        }
    }

    private var memoryCenterView: some View {
        let mem = model.systemCenterMemory ?? SystemCenterMemory()
        return VStack(spacing: 12) {
            // Kart 1: Fiziksel Bellek ve Türü
            infoCard {
                infoRow(label: model.L(.sysCenterPhysicalMemory), value: mem.physicalMemory)
                Divider()
                infoRow(label: model.L(.sysCenterMemoryType), value: mem.memoryType)
            }

            // Kart 2: Kullanım & Bellek Baskısı
            infoCard {
                infoRow(label: model.L(.sysCenterUsedMemory), value: DiskSpace.formatBytes(mem.usedMemoryBytes))
                Divider()
                infoRow(label: model.L(.sysCenterWiredMemory), value: DiskSpace.formatBytes(mem.wiredMemoryBytes))
                Divider()
                infoRow(label: model.L(.sysCenterCachedFiles), value: DiskSpace.formatBytes(mem.cachedFilesBytes))
                Divider()
                HStack {
                    Text(model.L(.sysCenterMemoryPressure))
                        .foregroundStyle(.secondary)
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))
                            Capsule()
                                .fill(mem.pressurePercent > 70 ? Color.red : (mem.pressurePercent > 45 ? Color.orange : Color.green))
                                .frame(width: max(8, geo.size.width * CGFloat(mem.pressurePercent) / 100.0))
                        }
                    }
                    .frame(width: 140, height: 10)
                    Text("\(mem.pressurePercent)%")
                        .font(.callout.monospacedDigit().weight(.medium))
                        .frame(width: 45, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }

            // Kart 3: Takas (Swap)
            infoCard {
                infoRow(label: model.L(.sysCenterSwapUsed), value: DiskSpace.formatBytes(mem.swapUsedBytes))
                Divider()
                HStack {
                    Text(model.L(.sysCenterSwapCount))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(mem.swapFileCount)")
                        .font(.callout.monospacedDigit().weight(.medium))
                    Button {
                        model.revealSwapDirectory()
                    } label: {
                        Label(model.L(.sysCenterShowInFinder), systemImage: "folder")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }

            // Kart 4: Sayfalama ve Temizleme
            infoCard {
                infoRow(label: model.L(.sysCenterPageIns), value: DiskSpace.formatBytes(mem.pageInsBytes))
                Divider()
                infoRow(label: model.L(.sysCenterPageOuts), value: DiskSpace.formatBytes(mem.pageOutsBytes))
                Divider()
                infoRow(label: model.L(.sysCenterActiveMemory), value: DiskSpace.formatBytes(mem.activeBytes))
                Divider()
                HStack {
                    Text(model.L(.sysCenterInactiveMemory))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(DiskSpace.formatBytes(mem.inactiveBytes))
                        .font(.callout.monospacedDigit().weight(.medium))
                    Button {
                        Task { await model.purgeMemory() }
                    } label: {
                        Label(model.L(.sysCenterPurgeAction), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    .disabled(model.isBusy)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var volumesCenterView: some View {
        let vols = model.systemCenterVolumes ?? SystemCenterVolumes()
        return VStack(spacing: 12) {
            // Kart 1: Kapasite ve Kullanılabilirlik
            infoCard {
                infoRow(
                    label: model.L(.sysCenterCapacity),
                    value: bytesWithExactCount(vols.totalCapacityBytes)
                )
                Divider()
                infoRow(
                    label: model.L(.sysCenterAvailable),
                    value: bytesWithExactCount(vols.availableBytes)
                )
            }

            // Kartlar: Her bir APFS Birimi (Başlatma ve Veri)
            ForEach(vols.volumes) { vol in
                infoCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.L(vol.kind.titleKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(vol.name.isEmpty ? "—" : vol.name)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.bottom, 2)
                    Divider()

                    HStack {
                        Text(model.L(.sysCenterUsedSpace))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(bytesWithExactCount(vol.usedBytes))
                            .font(.callout.monospacedDigit())
                    }
                    .padding(.vertical, 2)

                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                                Capsule()
                                    .fill(vol.usedPercent > 85 ? Color.red : Color.green)
                                    .frame(width: max(8, geo.size.width * CGFloat(vol.usedPercent) / 100.0))
                            }
                        }
                        .frame(height: 10)
                        Text("\(vol.usedPercent)%")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                    Divider()

                    infoRow(label: model.L(.sysCenterBsdNode), value: vol.bsdNode)
                    Divider()
                    infoRow(label: model.L(.sysCenterMountPoint), value: vol.mountPoint)
                }
            }

            // Kart: Son Doğrulama
            infoCard {
                HStack {
                    Text(model.L(.sysCenterLastVerification))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(vols.refreshedAt.map { $0.formatted(Date.FormatStyle(date: .long, time: .shortened).locale(appLocale)) } ?? "—")
                        .font(.callout.weight(.medium))
                    Button {
                        Task {
                            await model.loadSystemCenterInfo(force: true)
                        }
                    } label: {
                        Label(model.L(.buttonRefresh), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var osAndIdentityCenterView: some View {
        let os = model.systemCenterOS ?? SystemCenterOSAndIdentity()
        return VStack(spacing: 12) {
            // Kart 1: İşletim Sistemi & Çekirdek
            infoCard {
                infoRow(label: model.L(.sysCenterOSVersion), value: "\(os.osMarketingName) \(os.osVersionAndBuild)")
                Divider()
                infoRow(label: model.L(.sysCenterKernelVersion), value: os.darwinKernel)
            }

            // Kart 2: Sistem Runtimeları
            infoCard {
                infoRow(label: model.L(.sysCenterFinderVersion), value: os.finderVersion)
                Divider()
                infoRow(label: model.L(.sysCenterAppleScriptVersion), value: os.appleScriptVersion)
                Divider()
                infoRow(label: model.L(.sysCenterSQLiteVersion), value: os.sqliteVersion)
            }

            // Kart 3: Bilgisayar & Kullanıcı
            infoCard {
                infoRow(label: model.L(.sysCenterComputerName), value: os.computerName)
                Divider()
                infoRow(label: model.L(.sysCenterUserName), value: os.userName)
                Divider()
                infoRow(label: model.L(.sysCenterUserUUID), value: os.userUUID, copyable: true)
            }

            // Kart 4: Açık Kalma Süresi (Uptime)
            infoCard {
                HStack {
                    Text(model.L(.sysCenterUptime))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedUptime(os.uptimeSeconds))
                        .font(.callout.monospacedDigit().weight(.medium))
                    Button {
                        Task { await model.loadSystemCenterInfo(force: true) }
                    } label: {
                        Label(model.L(.buttonRefresh), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }

            // Kart 5: Kimlik (id dökümü)
            infoCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.L(.sysCenterIdentityTitle))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(os.identityDump.isEmpty ? "—" : SystemCenterCollector.formatIdentity(os.identityDump, groupsLabel: model.L(.sysCenterGroupsLabel)))
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var profileCenterView: some View {
        VStack(spacing: 12) {
            infoCard {
                Text(model.L(.sysCenterProfileDesc))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                Divider()

                HStack {
                    Text(model.L(.sysCenterProfileKind))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $model.selectedProfileKind) {
                        ForEach(SystemProfilerProfileKind.allCases) { kind in
                            Text(model.L(kind.titleKey)).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 240)
                }
                .padding(.vertical, 4)
                Divider()

                HStack {
                    Text(model.L(.sysCenterFileFormat))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $model.selectedProfileFormat) {
                        ForEach(SystemProfilerFormat.allCases) { fmt in
                            Text(model.L(fmt.titleKey)).tag(fmt)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 240)
                }
                .padding(.vertical, 4)
            }

            // Büyük Çıktı / Görüntüleme Kutusu
            VStack(alignment: .leading, spacing: 8) {
                if model.isGeneratingProfile {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(model.L(.sysCenterProfileLoading))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(minHeight: 220)
                } else if model.systemCenterProfileText.isEmpty {
                    ContentUnavailableView(
                        model.L(.sysCenterProfileEmptyTitle),
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(model.L(.sysCenterProfileEmptyMessage))
                    )
                    .frame(minHeight: 220)
                } else {
                    ScrollView {
                        Text(model.systemCenterProfileText)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 220, maxHeight: 380)
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 12))

            // Aksiyon Butonları
            HStack {
                Spacer()
                Button {
                    Task { await model.generateSystemProfile() }
                } label: {
                    Label(model.L(.sysCenterButtonShowProfile), systemImage: "eye")
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
                .disabled(model.isGeneratingProfile)

                Button {
                    model.saveSystemProfile()
                } label: {
                    Label(model.L(.sysCenterButtonSaveProfile), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.glassProminent)
                .controlSize(.regular)
                .disabled(model.systemCenterProfileText.isEmpty)
            }
        }
    }

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
        }
    }

    private var appLocale: Locale {
        Locale(identifier: model.settings.resolvedLanguageCode)
    }

    private func totalCoresText(_ hw: SystemCenterHardware) -> String {
        guard let total = Int64(hw.totalCores) else { return hw.totalCores }
        guard hw.performanceCores > 0, hw.efficiencyCores > 0 else { return hw.totalCores }
        return model.LF(.sysCenterCoresBreakdown, total, Int64(hw.performanceCores), Int64(hw.efficiencyCores))
    }

    /// "494,38 GB (494.384.795.648 bayt)" biçimi; değer okunamadıysa "—".
    private func bytesWithExactCount(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        return model.LF(.sysCenterBytesValue, DiskSpace.formatBytes(bytes), bytes.formatted(.number.locale(appLocale)))
    }

    private func formattedUptime(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "—" }
        let formatter = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = appLocale
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds >= 86_400 ? [.day, .hour, .minute] : [.hour, .minute]
        return formatter.string(from: seconds) ?? "—"
    }

    /// S.M.A.R.T. satırı: doğrulandı yeşil, arızalanıyor kırmızı (yedekleme uyarısıyla), desteklenmiyor ikincil.
    private func smartStatusRow(_ status: DiskSmartStatus) -> some View {
        let text: String
        let systemImage: String
        let tint: Color
        switch status {
        case .verified:
            (text, systemImage, tint) = (model.L(.sysCenterSmartVerified), "checkmark.seal.fill", .green)
        case .failing:
            (text, systemImage, tint) = (model.L(.sysCenterSmartFailing), "exclamationmark.triangle.fill", .red)
        case .notSupported:
            (text, systemImage, tint) = (model.L(.sysCenterSmartNotSupported), "minus.circle", .secondary)
        case .unavailable:
            (text, systemImage, tint) = ("—", "questionmark.circle", .secondary)
        case .other(let raw):
            (text, systemImage, tint) = (raw, "exclamationmark.circle", .orange)
        }
        return HStack {
            Text(model.L(.sysCenterSmartStatus))
                .foregroundStyle(.secondary)
            Spacer()
            Label(text, systemImage: systemImage)
                .font(.callout.weight(.medium))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 4)
    }

    private func infoRow(label: String, value: String, copyable: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.callout.monospacedDigit().weight(.medium))
            if copyable && !value.isEmpty {
                Button {
                    model.copyToClipboard(value)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}
