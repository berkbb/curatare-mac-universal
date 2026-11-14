// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
@testable import Curatare
import CuratareCore
import Foundation
import Testing

@MainActor
private final class FakeDockTile: DockTileSurface {
    var size = NSSize(width: 128, height: 128)
    var badgeLabel: String? = "old"
    var contentView: NSView?
    var displayCount = 0

    func display() {
        displayCount += 1
    }
}

@MainActor
@Suite("Curatare Dock Progress Tests")
struct DockProgressTests {
    private func makeIsolatedModel() -> (AppModel, FakeDockTile, () -> Void) {
        let (defaults, cleanupDefaults) = TestDefaults.make()
        let settings = AppSettings(defaults: defaults)
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("curatare-dock-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let model = AppModel(settings: settings, homeDirectoryURL: home)
        let tile = FakeDockTile()
        model.dockProgress = DockProgress(tile: tile)
        return (model, tile, {
            cleanupDefaults()
            try? FileManager.default.removeItem(at: home)
        })
    }

    @Test("DockProgress maps fractions cleanly, handles indeterminate and NaN safely, and deduplicates redraws")
    func stateAndDeduplication() {
        let tile = FakeDockTile()
        let dock = DockProgress(tile: tile)

        dock.update(fraction: nil, active: false, enabled: true)
        #expect(tile.displayCount == 0)

        dock.update(fraction: nil, active: true, enabled: true)
        #expect(dock.lastState == DockTileState(showsBar: true, percent: nil))
        #expect(tile.badgeLabel == nil)
        #expect(tile.contentView is DockTileView)
        #expect(tile.displayCount == 1)

        dock.update(fraction: .nan, active: true, enabled: true)
        #expect(tile.displayCount == 1)

        dock.update(fraction: -0.25, active: true, enabled: true)
        #expect(dock.lastState == DockTileState(showsBar: true, percent: 0))
        #expect(tile.displayCount == 2)

        dock.update(fraction: 0.426, active: true, enabled: true)
        #expect(dock.lastState == DockTileState(showsBar: true, percent: 43))
        #expect(tile.displayCount == 3)

        dock.update(fraction: 1.5, active: true, enabled: true)
        #expect(dock.lastState == DockTileState(showsBar: true, percent: 100))
        #expect(tile.displayCount == 4)

        dock.update(fraction: 0.5, active: true, enabled: false)
        #expect(dock.lastState.isEmpty)
        #expect(tile.contentView == nil)
        #expect(tile.displayCount == 5)
    }

    @Test("DockTileView renders visible green progress bar pixels when active")
    func pixelRendering() {
        let size = NSSize(width: 128, height: 128)
        let view = DockTileView(frame: NSRect(origin: .zero, size: size))
        view.state = DockTileState(showsBar: true, percent: 60)

        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            Issue.record("bitmapImageRepForCachingDisplay returned nil")
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)

        var greenPixels = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                   color.alphaComponent > 0.2,
                   color.greenComponent > color.redComponent + 0.15 {
                    greenPixels += 1
                }
            }
        }
        #expect(greenPixels > 100)

        view.state = DockTileState(showsBar: false, percent: nil)
        view.cacheDisplay(in: view.bounds, to: rep)
        var residualGreen = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB),
                   color.alphaComponent > 0.2,
                   color.greenComponent > color.redComponent + 0.15 {
                    residualGreen += 1
                }
            }
        }
        #expect(residualGreen == 0)
    }

    @Test("Heavy operations show Dock bar immediately and clear on completion")
    func heavyOperationUpdatesDock() async {
        let (model, tile, cleanup) = makeIsolatedModel()
        defer { cleanup() }

        var observedActiveDuringWork = false
        await model.performCancellableOperation(message: "Heavy", inline: false) { _ in
            try? await Task.sleep(for: .milliseconds(30))
            return true
        } onComplete: { _ in
            observedActiveDuringWork = tile.contentView != nil && model.dockProgress.lastState == DockTileState(showsBar: true, percent: nil)
        }

        #expect(observedActiveDuringWork)
        #expect(tile.contentView == nil)
        #expect(model.dockProgress.lastState.isEmpty)
    }

    @Test("Short inline scans skip Dock bar; longer inline scans display it without flickering")
    func inlineDebounceAndLongScan() async {
        let (model, tile, cleanup) = makeIsolatedModel()
        defer { cleanup() }
        model.dockProgressInlineDelay = .milliseconds(80)

        await model.performCancellableOperation(message: "Quick inline", inline: true) { _ in
            try? await Task.sleep(for: .milliseconds(10))
            return 1
        } onComplete: { _ in }
        #expect(tile.displayCount == 0)
        #expect(tile.contentView == nil)

        model.dockProgressInlineDelay = .milliseconds(20)
        let finishGate = ScanCancellationToken()
        let workerTask = Task {
            await model.performCancellableOperation(message: "Slow inline", inline: true) { token in
                while !token.isCancelled && !Task.isCancelled && !finishGate.isCancelled {
                    try? await Task.sleep(for: .milliseconds(10))
                }
                return 2
            } onComplete: { _ in }
        }

        for _ in 0..<100 {
            if tile.displayCount >= 1 && tile.contentView != nil { break }
            try? await Task.sleep(for: .milliseconds(15))
        }
        #expect(tile.contentView != nil)
        finishGate.cancel()
        await workerTask.value

        #expect(tile.displayCount >= 2)
        #expect(tile.contentView == nil)
        #expect(model.dockProgress.lastState.isEmpty)
    }

    @Test("Cancelling an inline scan resets both isBusy and isBusyInline and clears Dock bar")
    func cancellationResetsInlineAndDock() async {
        let (model, tile, cleanup) = makeIsolatedModel()
        defer { cleanup() }
        model.dockProgressInlineDelay = .milliseconds(20)

        let task = Task {
            await model.performCancellableOperation(message: "Inline scan", inline: true) { token in
                while !token.isCancelled && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(15))
                }
                return ()
            } onComplete: { _ in }
        }

        for _ in 0..<50 {
            if model.isBusy && tile.contentView != nil { break }
            try? await Task.sleep(for: .milliseconds(15))
        }
        #expect(model.isBusy == true)
        #expect(model.isBusyInline == true)
        #expect(tile.contentView != nil)

        model.cancelActiveOperation()
        #expect(model.isBusy == false)
        #expect(model.isBusyInline == false)
        #expect(tile.contentView == nil)
        #expect(model.dockProgress.lastState.isEmpty)

        await task.value
    }

    @Test("Toggling or resetting showDockProgress mid-operation updates Dock progress immediately")
    func settingToggleAndResetLiveUpdates() async {
        let (model, tile, cleanup) = makeIsolatedModel()
        defer { cleanup() }

        let task = Task {
            await model.performCancellableOperation(message: "Heavy", inline: false) { token in
                while !token.isCancelled && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(15))
                }
                return ()
            } onComplete: { _ in }
        }

        for _ in 0..<40 {
            if model.isBusy { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(tile.contentView != nil)

        model.settings.showDockProgress = false
        #expect(tile.contentView == nil)

        model.settings.resetToDefaults()
        #expect(model.settings.showDockProgress == true)
        #expect(tile.contentView != nil)

        model.cancelActiveOperation()
        await task.value
        #expect(tile.contentView == nil)
    }
}
