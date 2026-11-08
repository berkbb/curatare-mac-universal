// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import SwiftUI

public enum WindowID {
    public static let main = "main"
    public static let about = "about"
    public static let log = "log"
}

@main
struct CuratareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel(startBackgroundWatchers: true)
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window(model.L(.appName), id: WindowID.main) {
            ContentView(model: model)
                .environment(\.locale, model.settings.locale)
                .preferredColorScheme(model.settings.appearance.colorScheme)
                // Kaldırıcının liste + ayrıntı düzeni ve uzun tr/ro etiketleri 1180 pt altında sıkışıp taşar.
                .frame(minWidth: 1180, minHeight: 700)
                .onAppear {
                    appDelegate.model = model
                    NSApp.servicesProvider = FinderService(model: model)
                    NSApp.appearance = model.settings.appearance.nsAppearance
                    model.windowDidAppear()
                }
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            AppCommands(model: model, openWindow: openWindow)
        }

        Settings {
            SettingsView(model: model)
                .environment(\.locale, model.settings.locale)
                .preferredColorScheme(model.settings.appearance.colorScheme)
        }

        Window(model.L(.menuAbout), id: WindowID.about) {
            AboutView(model: model)
                .environment(\.locale, model.settings.locale)
                .preferredColorScheme(model.settings.appearance.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        .commandsRemoved()

        Window(model.L(.logTitle), id: WindowID.log) {
            LogView(model: model)
                .environment(\.locale, model.settings.locale)
                .preferredColorScheme(model.settings.appearance.colorScheme)
        }
        .defaultSize(width: 960, height: 560)
        .restorationBehavior(.disabled)
        .commandsRemoved()

        MenuBarExtra(isInserted: $model.settings.showMenuBarIcon) {
            MenuBarQuickPanel(model: model)
                .environment(\.locale, model.settings.locale)
                .preferredColorScheme(model.settings.appearance.colorScheme)
        } label: {
            Label(model.L(.appName), systemImage: "sparkles.rectangle.stack.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

struct AppCommands: Commands {
    @Bindable var model: AppModel
    let openWindow: OpenWindowAction

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(model.L(.menuAbout)) {
                openWindow(id: WindowID.about)
            }
            Divider()
            Button(model.L(.menuUpdateMole)) {
                Task { await model.installMoleUpdate(force: false) }
            }
            Button(model.L(.menuCheckAppUpdates)) {
                Task { await model.checkAppUpdate(interactive: true) }
            }
        }

        CommandGroup(replacing: .newItem) {
            ForEach([
                ShortcutAction.scanAudit,
                .uninstaller,
                .devAI,
                .browserCaches,
                .diskAnalyzer,
                .systemStatus,
                .trashHistory,
            ]) { action in
                let sc = model.settings.shortcut(for: action)
                Button(model.L(action.labelKey)) {
                    openWindow(id: WindowID.main)
                    NSApp.activate(ignoringOtherApps: true)
                    model.performShortcut(action)
                }
                .keyboardShortcut(sc.keyEquivalent, modifiers: sc.eventModifiers)
            }
        }

        CommandGroup(before: .windowList) {
            let logSC = model.settings.shortcut(for: .showLog)
            Button(model.L(.menuShowLog)) {
                openWindow(id: WindowID.log)
            }
            .keyboardShortcut(logSC.keyEquivalent, modifiers: logSC.eventModifiers)
            Divider()
        }

        CommandGroup(replacing: .help) {
            Link(model.L(.menuWebsite), destination: AppLinks.repository)
            Link(model.L(.menuEngineManual), destination: AppLinks.engineManual)
        }
    }
}

private struct MenuBarQuickPanel: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.L(.appName))
                        .font(.headline)
                    Text("\(model.L(.statusHealthScore)): \(model.systemStatus.healthScore)/100 · Mole \(model.engineVersionText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                miniMetric(title: model.L(.menuBarMetricCPU), value: String(format: "%.0f%%", model.systemStatus.cpu.usage), icon: "cpu")
                miniMetric(title: model.L(.menuBarMetricRAM), value: String(format: "%.0f%%", model.systemStatus.memory.usedPercent), icon: "memorychip")
                let diskPct = model.systemStatus.disks.first?.usedPercent ?? 0
                miniMetric(title: model.L(.menuBarMetricDisk), value: String(format: "%.0f%%", diskPct), icon: "internaldrive")
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    openWindow(id: WindowID.main)
                    NSApp.activate(ignoringOtherApps: true)
                    model.selectedSection = .libraryAudit
                    Task { await model.runLibraryAudit() }
                } label: {
                    Label(model.L(.menuScanNow), systemImage: "checklist.checked")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.glassProminent)

                Button {
                    openWindow(id: WindowID.main)
                    NSApp.activate(ignoringOtherApps: true)
                    model.selectedSection = .uninstaller
                } label: {
                    Label(model.L(.navUninstaller), systemImage: "trash.slash.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.glass)

                Button {
                    openWindow(id: WindowID.log)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label(model.L(.menuShowLog), systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.glass)
            }

            Divider()

            HStack {
                Button(model.L(.menuOpenCuratare)) {
                    openWindow(id: WindowID.main)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))

                Spacer()

                Button(model.L(.menuQuit)) {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func miniMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ChildProcessGuard.install()
        // Yeni derlemenin ilk açılışında Launch Services kaydı tazelenir (uygulama paketi türü, Finder servisi, simge).
        LaunchServicesRegistration.registerIfBuildChanged()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ChildProcessGuard.terminateAll()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        model?.handleDroppedURLs(urls)
    }
}
