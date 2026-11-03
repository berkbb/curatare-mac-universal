// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - 5. Etkileşimli Disk Analizi (`analyze-go`) Görünümü

public struct DiskAnalyzerView: View {
    @Bindable public var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.L(.diskTitle))
                        .font(.title2.bold())
                    Text(model.L(.diskSubtitle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.L(.diskNavigateUp)) {
                    Task { await model.navigateUpDiskAnalyzer() }
                }
                .buttonStyle(.glass)
                .disabled(model.currentAnalyzedURL.path == "/")
                Button(model.L(.diskChooseFolder)) {
                    chooseFolder()
                }
                .buttonStyle(.glass)
                Button {
                    Task { await model.analyzeFolder() }
                } label: {
                    Label(model.L(.buttonScan), systemImage: "chart.pie")
                }
                .buttonStyle(.glassProminent)
            }

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
                List(analysis.entries) { entry in
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
        .padding(16)
        .loadOnFirstVisit(isLoaded: model.diskAnalysis != nil, isBusy: model.isBusy) {
            await model.analyzeFolder()
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

// MARK: - 6. Canlı Sistem Durumu, Bakım ve İnce Ayarlar (`status-go`, `optimize` & `SystemTweaks`) Görünümü

public struct SystemStatusView: View {
    @Bindable public var model: AppModel
    @State private var selectedTweakCategory: SystemTweakCategory? = nil
    @State private var screenshotNameDraft = ""
    @Environment(\.controlActiveState) private var controlActiveState

    /// `status-go` bir turda ~3 sn sürer (~1,9 sn CPU); daha sık yoklama panoyu açık tutan kullanıcıda bir çekirdeği sürekli meşgul eder.
    private static let liveMetricsInterval: Duration = .seconds(15)

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerBar

            switch model.systemStatusSubTab {
            case .systemCenter:
                systemCenterView
            case .dashboard:
                dashboardView
            case .tweaks:
                tweaksView
            case .checksum:
                checksumCalculatorView
            }
        }
        .padding(16)
        .task {
            // Görünümden bağımsız görev: yükleme sürerken sekmeden çıkılırsa yarıda kesilmez.
            Task { await model.loadSystemStatusIfNeeded() }
        }
    }

    // Başlık + Yenile üst satırda, 4'lü segment kendi satırında: uzun tr/en/ro etiketleri
    // alt başlığın üstüne taşmaz ve Yenile düğmesinin altında kırpılmaz.
    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.L(.statusTitle))
                        .font(.title2.bold())
                    Text(model.L(.statusSubtitle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)

                if model.isLoadingSystemStatus {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 6)
                }

                Button {
                    Task { await model.refreshSystemStatus() }
                } label: {
                    Label(model.L(.buttonRefresh), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glassProminent)
                .fixedSize()
                .disabled(model.isLoadingSystemStatus)
            }

            Picker("", selection: $model.systemStatusSubTab) {
                Text(model.L(.statusTabSystemCenter)).tag(SystemStatusSubTab.systemCenter)
                Text(model.L(.statusTabDashboard)).tag(SystemStatusSubTab.dashboard)
                Text(model.L(.statusTabTweaks)).tag(SystemStatusSubTab.tweaks)
                Text(model.L(.statusTabChecksum)).tag(SystemStatusSubTab.checksum)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    // MARK: - Sistem Merkezi (Desktop/t Referansı: Donanım, Bellek, Birimler, Sistem, Profil)

    private var systemCenterView: some View {
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

    // MARK: - Uygulama Diline Göre Biçimlendirme (Sistem Merkezi değerleri çekirdekte ham tutulur)

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

    // MARK: - Canlı Göstergeler & Güvenli Bakım Paneli

    private var dashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Canlı Gösterge Kartları
                HStack(spacing: 12) {
                    metricCard(
                        title: model.L(.statusHealthScore),
                        value: "\(model.systemStatus.healthScore)/100",
                        subtitle: model.systemStatus.platform.isEmpty ? "macOS" : model.systemStatus.platform,
                        systemImage: "heart.text.square.fill",
                        tint: .green
                    )
                    let cpu = model.systemStatus.cpu
                    let cpuSub = (cpu.pCoreCount > 0 && cpu.eCoreCount > 0) ? "\(cpu.pCoreCount)P + \(cpu.eCoreCount)E" : model.LF(.statusCoresCount, Int64(cpu.logicalCPU))
                    metricCard(
                        title: model.L(.statusCPU),
                        value: String(format: "%.1f%%", model.systemStatus.cpu.usage),
                        subtitle: cpuSub,
                        systemImage: "cpu.fill",
                        tint: .blue
                    )
                    memoryMetricCard
                    let rootDisk = model.systemStatus.disks.first
                    metricCard(
                        title: model.L(.statusDisk),
                        value: String(format: "%.0f%%", rootDisk?.usedPercent ?? 0),
                        subtitle: "\(DiskSpace.formatBytes(rootDisk?.used ?? 0)) / \(DiskSpace.formatBytes(rootDisk?.total ?? 0))",
                        systemImage: "internaldrive.fill",
                        tint: .orange
                    )
                }

                // Donanım ve Çekirdek Kimlik Şeridi
                hardwareIdentityStrip

                // macOS Güvenlik Durumu Kartı
                securityStatusGrid

                Divider()

                // Gelişmiş Bakım ve Onarım Görevleri
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.L(.optimizeSectionTitle))
                                .font(.headline)
                            Text(model.L(.optimizeSectionSubtitle))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await model.runSelectedOptimizations() }
                        } label: {
                            Label(model.L(.optimizeRunButton), systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(model.isBusy)
                    }

                    List($model.optimizationTasks) { $task in
                        Toggle(taskTitle(task.kind), isOn: $task.isSelected)
                    }
                    .frame(minHeight: 280)
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }

                Divider()

                // Gizli macOS Sistem İzlenceleri Başlatıcı
                hiddenUtilitiesSection
            }
            .padding(.vertical, 2)
        }
        .scrollContentBackground(.hidden)
        .task(id: controlActiveState) {
            // Canlı ölçümler yalnızca pano görünür ve uygulama etkinken tazelenir; sekmeden çıkınca döngü iptal olur.
            guard controlActiveState != .inactive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.liveMetricsInterval)
                guard !Task.isCancelled, !model.isLoadingSystemStatus else { continue }
                await model.refreshLiveMetrics()
            }
        }
    }

    private var memoryMetricCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "memorychip.fill")
                    .foregroundStyle(.purple)
                Text(model.L(.statusMemory))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                memoryPressureBadge
            }
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.0f%%", model.systemStatus.memory.usedPercent))
                    .font(.title2.bold().monospacedDigit())
                Spacer()
                Button {
                    Task { await model.purgeMemory() }
                } label: {
                    Label(model.L(.buttonPurgeMemory), systemImage: "sparkles")
                        .font(.caption2.weight(.medium))
                }
                .buttonStyle(.glass)
                .help(model.L(.buttonPurgeMemory))
            }
            HStack {
                Text("\(DiskSpace.formatBytes(model.systemStatus.memory.used)) / \(DiskSpace.formatBytes(model.systemStatus.memory.total))")
                Spacer()
                Text(model.LF(.statusSwapUsed, DiskSpace.formatBytes(model.systemStatus.memory.swapUsed)))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var hardwareIdentityStrip: some View {
        HStack(spacing: 12) {
            Label(model.L(.statusHardwareIdentity), systemImage: "macbook.and.iphone")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Divider().frame(height: 12)
            if !model.systemStatus.buildID.isEmpty {
                Text(model.LF(.sysBuildLabel, model.systemStatus.buildID))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            if !model.systemStatus.darwinKernel.isEmpty {
                Text(model.LF(.sysDarwinLabel, model.systemStatus.darwinKernel))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(model.systemStatus.host)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }

    private var memoryPressureBadge: some View {
        let p = model.systemStatus.memory.pressure.lowercased()
        let text: String
        let color: Color
        if p == "critical" {
            text = model.L(.statusPressureCritical)
            color = .red
        } else if p == "warn" {
            text = model.L(.statusPressureWarn)
            color = .orange
        } else {
            text = model.L(.statusPressureNormal)
            color = .green
        }
        return Text(text)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var securityStatusGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(model.L(.statusSecurityOverviewTitle), systemImage: "lock.shield.fill")
                    .font(.headline)
                Spacer()
                Text(model.systemStatus.platform)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                securityTile(
                    title: model.L(.statusSecuritySIP),
                    status: model.securityStatus.sipEnabled ? model.L(.statusEnabled) : model.L(.statusDisabled),
                    systemImage: model.securityStatus.sipEnabled ? "checkmark.shield.fill" : "xmark.shield.fill",
                    tint: model.securityStatus.sipEnabled ? .green : .red
                )
                securityTile(
                    title: model.L(.statusSecurityFileVault),
                    status: model.securityStatus.fileVaultEnabled ? model.L(.statusEnabled) : model.L(.statusDisabled),
                    systemImage: model.securityStatus.fileVaultEnabled ? "lock.shield.fill" : "lock.open.trianglebadge.exclamationmark.fill",
                    tint: model.securityStatus.fileVaultEnabled ? .green : .orange
                )
                securityTile(
                    title: model.L(.statusSecurityGatekeeper),
                    status: model.securityStatus.gatekeeperEnabled ? model.L(.statusEnabled) : model.L(.statusDisabled),
                    systemImage: model.securityStatus.gatekeeperEnabled ? "person.badge.shield.checkmark.fill" : "person.badge.shield.exclamationmark.fill",
                    tint: model.securityStatus.gatekeeperEnabled ? .green : .red
                )
                securityTile(
                    title: model.L(.statusSecurityXProtect),
                    status: model.securityStatus.xprotectVersion.isEmpty ? model.L(.statusEnabled) : "v\(model.securityStatus.xprotectVersion)",
                    systemImage: "shield.lefthalf.filled",
                    tint: .blue
                )
                securityTile(
                    title: model.L(.statusXProtectRemediator),
                    status: model.securityStatus.remediatorVersion.isEmpty ? model.L(.statusEnabled) : "v\(model.securityStatus.remediatorVersion)",
                    systemImage: "cross.case.fill",
                    tint: .teal
                )
                securityTile(
                    title: model.L(.statusLockdownMode),
                    status: model.securityStatus.lockdownModeEnabled ? model.L(.statusEnabled) : model.L(.statusDisabled),
                    systemImage: model.securityStatus.lockdownModeEnabled ? "exclamationmark.shield.fill" : "shield.slash.fill",
                    tint: model.securityStatus.lockdownModeEnabled ? .yellow : .secondary
                )
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private func securityTile(title: String, status: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Spacer()
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var hiddenUtilitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.L(.hiddenUtilitiesTitle))
                    .font(.headline)
                Text(model.L(.hiddenUtilitiesSubtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 10)], spacing: 10) {
                ForEach(model.hiddenUtilities) { util in
                    hiddenUtilityCard(util)
                }
            }
        }
    }

    private func hiddenUtilityCard(_ util: HiddenSystemUtility) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: util.iconName)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.L(util.titleKey))
                        .font(.body.weight(.semibold))
                    Spacer()
                    Button {
                        model.launchSystemUtility(util)
                    } label: {
                        Label(model.L(.buttonLaunchUtility), systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.glass)
                    .disabled(!util.isAvailable)
                }

                Text(model.L(util.descriptionKey))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }

    // MARK: - Sistem İnce Ayarları (macOS Parametreleri) Paneli

    private var tweaksView: some View {
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

    private func metricCard(title: String, value: String, subtitle: String, systemImage: String, tint: Color) -> some View {
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

    private func taskTitle(_ kind: MoleOptimizationTask.ActionKind) -> String {
        model.L(kind.titleKey)
    }

    // MARK: - Dosya Sağlama Toplamı (Checksum / Hash) Hesaplayıcı Paneli

    private var checksumCalculatorView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.L(.checksumTitle))
                    .font(.title3.bold())
                Text(model.L(.checksumSubtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Drop & Select Zone
            VStack(spacing: 12) {
                Image(systemName: "number.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.accentColor)

                Text(model.checksumResult?.fileName ?? model.L(.checksumDropPrompt))
                    .font(.headline)

                if let res = model.checksumResult {
                    Text(DiskSpace.formatBytes(res.fileSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(model.L(.checksumChooseFile)) {
                    chooseFileForChecksum()
                }
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            )
            .dropDestination(for: URL.self) { urls, _ in
                guard let first = urls.first else { return false }
                model.computeChecksum(for: first)
                return true
            }

            if model.isCalculatingChecksum {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(model.L(.statusScanning))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let result = model.checksumResult {
                VStack(alignment: .leading, spacing: 12) {
                    checksumRow(title: "MD5", hash: result.md5)
                    checksumRow(title: "SHA-1", hash: result.sha1)
                    checksumRow(title: "SHA-256", hash: result.sha256)

                    Divider()

                    // Compare & Verify
                    VStack(alignment: .leading, spacing: 6) {
                        TextField(model.L(.checksumComparePlaceholder), text: $model.checksumExpectedHash)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption.monospaced())

                        if !model.checksumExpectedHash.trimmingCharacters(in: .whitespaces).isEmpty {
                            let (isMatch, algo) = result.verify(expected: model.checksumExpectedHash)
                            if isMatch, let algo = algo {
                                Label(model.LF(.checksumMatch, algo), systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            } else {
                                Label(model.L(.checksumMismatch), systemImage: "xmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                .padding(14)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }

            Spacer()
        }
    }

    private func checksumRow(title: String, hash: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.bold))
                .frame(width: 64, alignment: .leading)
            Text(hash)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Spacer()
            Button {
                model.copyToClipboard(hash, label: "\(model.L(.buttonCopied)): \(title)")
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
        }
    }

    private func chooseFileForChecksum() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.computeChecksum(for: url)
        }
    }
}

// MARK: - 7. Tarihli Çöp Turları ve Geri Yükleme (`TrashHistoryView` - Master-Detail)

public struct TrashHistoryView: View {
    @Bindable public var model: AppModel
    @State private var showingConfirmPurgeAll = false
    @State private var batchToPurge: TrashBatchManifest?
    @State private var itemToPurge: (batch: TrashBatchManifest, item: TrashedItemRecord)?
    @State private var showingConfirmPurgeSelected = false
    @State private var itemSearchText: String = ""

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBar

            if model.trashBatches.isEmpty {
                ContentUnavailableView(
                    model.L(.trashHistoryEmptyTitle),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(model.L(.trashHistoryEmptyMessage))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    masterBatchesPane
                        .frame(minWidth: 320, idealWidth: model.settings.trashMasterPaneWidth, maxWidth: 460)
                        .padding(.trailing, 3)
                    detailInspectionPane
                        .frame(minWidth: 400, idealWidth: 540, maxWidth: .infinity)
                        .padding(.leading, 3)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .confirmationDialog(
            model.L(.trashConfirmPurgeAllTitle),
            isPresented: $showingConfirmPurgeAll,
            titleVisibility: .visible
        ) {
            Button(model.L(.trashPurgeAllButton), role: .destructive) {
                model.purgeAllTrashBatches()
            }
            Button(model.L(.buttonCancel), role: .cancel) {}
        } message: {
            Text(model.LF(
                .trashConfirmPurgeAllMessage,
                Int64(model.trashBatches.count),
                DiskSpace.formatBytes(model.trashBatches.map(\.totalBytes).reduce(0, +))
            ))
        }
        .confirmationDialog(
            model.L(.trashConfirmPurgeSingleTitle),
            isPresented: Binding(
                get: { batchToPurge != nil },
                set: { if !$0 { batchToPurge = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let batch = batchToPurge {
                Button(model.L(.trashPurgeSingleButton), role: .destructive) {
                    model.purgeTrashBatch(batch)
                    batchToPurge = nil
                }
            }
            Button(model.L(.buttonCancel), role: .cancel) {
                batchToPurge = nil
            }
        } message: {
            if let batch = batchToPurge {
                Text(model.LF(.trashConfirmPurgeSingleMessage, batch.id, Int64(batch.items.count)))
            }
        }
        .confirmationDialog(
            model.L(.trashConfirmPurgeSingleItemTitle),
            isPresented: Binding(
                get: { itemToPurge != nil },
                set: { if !$0 { itemToPurge = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = itemToPurge {
                Button(model.L(.trashPurgeSingleItemTooltip), role: .destructive) {
                    model.purgeTrashedItem(batch: target.batch, item: target.item)
                    itemToPurge = nil
                }
            }
            Button(model.L(.buttonCancel), role: .cancel) {
                itemToPurge = nil
            }
        } message: {
            if let target = itemToPurge {
                Text(model.LF(.trashConfirmPurgeSingleItemMessage, target.item.trashedRelativePath))
            }
        }
        .confirmationDialog(
            model.L(.trashConfirmPurgeSelectedItemsTitle),
            isPresented: $showingConfirmPurgeSelected,
            titleVisibility: .visible
        ) {
            if let batch = model.selectedTrashBatch {
                Button(model.L(.trashPurgeSingleButton), role: .destructive) {
                    model.purgeSelectedTrashedItems(batch: batch)
                }
            }
            Button(model.L(.buttonCancel), role: .cancel) {}
        } message: {
            Text(model.LF(.trashConfirmPurgeSelectedItemsMessage, Int64(model.selectedTrashedItemIDs.count)))
        }
    }

    // MARK: - Üst Başlık

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.L(.trashHistoryTitle))
                    .font(.title2.bold())
                Text(model.L(.trashHistorySubtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.refreshTrashBatches()
            } label: {
                Label(model.L(.buttonRefresh), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glassProminent)
        }
    }

    // MARK: - Sol Panel: Temizlik Turları Listesi (Master)

    private var masterBatchesPane: some View {
        VStack(spacing: 0) {
            masterFilterBar
            Divider()
            if model.filteredTrashBatches.isEmpty {
                ContentUnavailableView(
                    model.L(.trashHistoryEmptyTitle),
                    systemImage: "magnifyingglass",
                    description: Text(model.L(.trashHistoryEmptyMessage))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $model.selectedTrashBatchID) {
                    ForEach(model.filteredTrashBatches) { batch in
                        batchRow(batch)
                            .tag(batch.id)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
            Divider()
            masterBottomBar
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var masterFilterBar: some View {
        VStack(spacing: 8) {
            Picker("", selection: $model.trashHistoryFilter) {
                Text(model.L(.trashFilterAll)).tag(TrashHistoryFilterKind.all)
                Text(model.L(.trashFilterPending)).tag(TrashHistoryFilterKind.pendingRestore)
                Text(model.L(.trashFilterRestored)).tag(TrashHistoryFilterKind.restored)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField(model.L(.searchPrompt), text: $model.trashHistorySearchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !model.trashHistorySearchText.isEmpty {
                    Button {
                        model.trashHistorySearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func batchRow(_ batch: TrashBatchManifest) -> some View {
        HStack(spacing: 10) {
            Image(systemName: batch.isRestored ? "arrow.uturn.backward.circle.fill" : "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(batch.isRestored ? .green : .accentColor)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.displayTitle(for: batch))
                        .font(.body.weight(.medium))
                    if batch.isRestored {
                        Text(model.L(.trashBatchRestoredBadge))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15), in: Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(batch.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(DiskSpace.formatBytes(batch.totalBytes))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(batch.items.count)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())

            Button(role: .destructive) {
                batchToPurge = batch
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.borderless)
            .help(model.L(.trashPurgeSingleButton))
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button {
                model.restoreTrashBatch(batch)
            } label: {
                Label(model.L(.buttonRestore), systemImage: "arrow.uturn.backward")
            }
            .disabled(batch.isRestored)

            Button {
                model.revealInFinder(URL(fileURLWithPath: batch.batchDirectoryPath))
            } label: {
                Label(model.L(.buttonShowInFinder), systemImage: "folder")
            }

            Button {
                model.copyToClipboard(batch.id)
            } label: {
                Label(model.L(.contextMenuCopyName), systemImage: "doc.on.doc")
            }

            Button {
                model.copyToClipboard(batch.batchDirectoryPath)
            } label: {
                Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                batchToPurge = batch
            } label: {
                Label(model.L(.trashPurgeSingleButton), systemImage: "trash.slash")
            }
        }
    }

    private var masterBottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.LF(.trashBatchCountFiltered, Int64(model.filteredTrashBatches.count), Int64(model.trashBatches.count)))
                    .font(.caption2.weight(.semibold))
                Text(DiskSpace.formatBytes(model.filteredTrashBatches.map(\.totalBytes).reduce(0, +)))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                showingConfirmPurgeAll = true
            } label: {
                Label(model.L(.trashPurgeAllButton), systemImage: "trash.slash.fill")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(model.trashBatches.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Sağ Panel: Tur Ayrıntıları ve Dosya İnceleme (Detail)

    private var detailInspectionPane: some View {
        Group {
            if let batch = model.selectedTrashBatch {
                VStack(spacing: 0) {
                    detailHeader(batch)
                    Divider()
                    detailFilesList(batch)
                }
            } else {
                ContentUnavailableView(
                    model.L(.trashEmptySelectionTitle),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(model.L(.trashEmptySelectionSubtitle))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailHeader(_ batch: TrashBatchManifest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: batch.isRestored ? "arrow.uturn.backward.circle.fill" : "trash.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(batch.isRestored ? Color.green : Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.displayTitle(for: batch))
                            .font(.title3.bold())
                        if batch.isRestored {
                            Text(model.L(.trashBatchRestoredBadge))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15), in: Capsule())
                        }
                    }

                    Text(model.LF(.trashBatchIDLabel, batch.id))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(batch.batchDirectoryPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Button {
                        model.restoreTrashBatch(batch)
                    } label: {
                        Label(model.L(.buttonRestore), systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(batch.isRestored)

                    HStack(spacing: 8) {
                        Button {
                            model.revealInFinder(URL(fileURLWithPath: batch.batchDirectoryPath))
                        } label: {
                            Label(model.L(.buttonShowInFinder), systemImage: "folder")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)

                        Button(role: .destructive) {
                            batchToPurge = batch
                        } label: {
                            Label(model.L(.trashPurgeSingleButton), systemImage: "trash.slash")
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                }
                // Düğmeler kendi genişliğini korur; uzun kimlik ve yol metni soldaki sütunda sarılır.
                .fixedSize()
            }

            HStack(spacing: 12) {
                badgeStat(label: model.L(.trashStatItemCount), value: "\(batch.items.count)")
                badgeStat(label: model.L(.trashStatTotalSize), value: DiskSpace.formatBytes(batch.totalBytes))
                badgeStat(label: model.L(.trashStatDate), value: batch.createdAt.formatted(date: .numeric, time: .shortened))
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private func detailFilesList(_ batch: TrashBatchManifest) -> some View {
        VStack(spacing: 0) {
            let filteredItems = batch.items.filter { item in
                if itemSearchText.isEmpty { return true }
                let q = itemSearchText.lowercased()
                return item.trashedRelativePath.lowercased().contains(q) || item.originalPath.lowercased().contains(q)
            }
            let allSelected = !filteredItems.isEmpty && filteredItems.allSatisfy { model.selectedTrashedItemIDs.contains($0.id) }

            HStack(spacing: 8) {
                Button {
                    model.toggleSelectAllTrashedItems(in: batch)
                } label: {
                    Image(systemName: allSelected ? "checkmark.square.fill" : (model.selectedTrashedItemIDs.isEmpty ? "square" : "minus.square.fill"))
                        .font(.body)
                        .foregroundStyle(allSelected || !model.selectedTrashedItemIDs.isEmpty ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(allSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll))
                .keyboardShortcut("a", modifiers: .command)

                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField(model.L(.trashFilterItemsPlaceholder), text: $itemSearchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                    if !itemSearchText.isEmpty {
                        Button {
                            itemSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))

                Spacer()

                if !model.selectedTrashedItemIDs.isEmpty {
                    Button(role: .destructive) {
                        showingConfirmPurgeSelected = true
                    } label: {
                        Label(
                            model.LF(.trashPurgeSelectedItemsButton, Int64(model.selectedTrashedItemIDs.count)),
                            systemImage: "trash.slash.fill"
                        )
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)

            Divider()

            List(filteredItems) { item in
                let isSelected = model.selectedTrashedItemIDs.contains(item.id)
                HStack(spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { isSelected },
                        set: { _ in model.toggleTrashedItemSelection(id: item.id) }
                    ))
                    .labelsHidden()

                    let isDir = item.originalPath.hasSuffix("/") || (try? URL(fileURLWithPath: item.originalPath).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    Image(systemName: isDir ? "folder.fill" : "doc.fill")
                        .foregroundStyle(isDir ? Color.accentColor : Color.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.trashedRelativePath)
                            .font(.callout.weight(.medium))
                        Text(item.originalPath)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(DiskSpace.formatBytes(item.sizeBytes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Button {
                        let fullTrashURL = URL(fileURLWithPath: batch.batchDirectoryPath).appendingPathComponent(item.trashedRelativePath)
                        model.revealInFinder(fullTrashURL)
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help(model.L(.buttonShowInFinder))

                    Button(role: .destructive) {
                        itemToPurge = (batch, item)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.borderless)
                    .help(model.L(.trashPurgeSingleItemTooltip))
                }
                .padding(.vertical, 3)
                .contextMenu {
                    Button(role: .destructive) {
                        itemToPurge = (batch, item)
                    } label: {
                        Label(model.L(.trashPurgeSingleItemTooltip), systemImage: "trash")
                    }

                    Divider()

                    Button {
                        let fullTrashURL = URL(fileURLWithPath: batch.batchDirectoryPath).appendingPathComponent(item.trashedRelativePath)
                        model.revealInFinder(fullTrashURL)
                    } label: {
                        Label(model.L(.buttonShowInFinder), systemImage: "folder")
                    }

                    Button {
                        model.copyToClipboard(item.originalPath)
                    } label: {
                        Label(model.L(.contextMenuCopyPath), systemImage: "doc.on.doc")
                    }

                    Button {
                        let fullTrashURL = URL(fileURLWithPath: batch.batchDirectoryPath).appendingPathComponent(item.trashedRelativePath)
                        model.copyToClipboard(fullTrashURL.path)
                    } label: {
                        Label("Çöp Yolunu Kopyala", systemImage: "doc.on.doc")
                    }

                    Divider()

                    Button {
                        model.toggleTrashedItemSelection(id: item.id)
                    } label: {
                        Label(
                            isSelected ? model.L(.buttonDeselectAll) : model.L(.buttonSelectAll),
                            systemImage: isSelected ? "checkmark.square" : "square"
                        )
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
        }
    }

    private func badgeStat(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
