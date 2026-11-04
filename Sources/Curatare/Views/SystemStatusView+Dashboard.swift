// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

// MARK: - Canlı Göstergeler & Güvenli Bakım Paneli

extension SystemStatusView {
    var dashboardView: some View {
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
}
