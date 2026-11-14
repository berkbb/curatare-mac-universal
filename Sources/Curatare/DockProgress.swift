// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit

/// `NSDockTile` ve testlerdeki sahte Dock döşemesi için ortak yüzey.
@MainActor
public protocol DockTileSurface: AnyObject {
    var size: NSSize { get }
    var badgeLabel: String? { get set }
    var contentView: NSView? { get set }
    func display()
}

extension NSDockTile: DockTileSurface {}

/// Dock simgesi altındaki ilerleme çubuğunun anlık durumu (`percent == nil` ise belirsiz tarama/işlem çubuğu).
public struct DockTileState: Equatable, Sendable {
    public var showsBar: Bool
    public var percent: Int?

    public init(showsBar: Bool = false, percent: Int? = nil) {
        self.showsBar = showsBar
        self.percent = percent
    }

    public var isEmpty: Bool { !showsBar }
}

/// Curatare Dock simgesinin altında yalnızca ilerleme çubuğunu çizer; metin ya da sayısal rozet basmaz.
@MainActor
public final class DockProgress {
    private let injectedTile: (any DockTileSurface)?
    private var tileView: DockTileView?
    public private(set) var lastState = DockTileState()

    /// Gerçek uygulamada `NSApp?.dockTile` kullanılır; testler `NSApplication.shared` başlatmadan kendi yüzeyini verir.
    public init(tile: (any DockTileSurface)? = nil) {
        self.injectedTile = tile
    }

    /// Etkinlik durumuna göre Dock simgesi altındaki ilerleme çubuğunu günceller veya gizler.
    public func update(fraction: Double?, active: Bool, enabled: Bool = true) {
        let tile: (any DockTileSurface)? = injectedTile ?? NSApp?.dockTile
        guard let tile else { return }

        let clampedPercent: Int? = if active, let fraction, fraction.isFinite {
            min(100, max(0, Int((fraction * 100).rounded())))
        } else {
            nil
        }
        let state = enabled ? DockTileState(showsBar: active, percent: clampedPercent) : DockTileState()
        if state == lastState { return }
        lastState = state

        tile.badgeLabel = nil
        if state.isEmpty {
            tile.contentView = nil
        } else {
            let view = tileView ?? DockTileView(frame: NSRect(origin: .zero, size: tile.size))
            view.frame = NSRect(origin: .zero, size: tile.size)
            tileView = view
            view.state = state
            view.needsDisplay = true
            tile.contentView = view
        }
        tile.display()
    }
}

/// Uygulama simgesini koruyarak yalnızca alt kenarda yuvarlatılmış ilerleme çubuğunu çizen Dock görünümü.
public final class DockTileView: NSView {
    public var state = DockTileState()

    override public func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        NSColor.clear.setFill()
        bounds.fill(using: .copy)
        NSApp?.applicationIconImage?.draw(in: bounds)
        guard state.showsBar else { return }

        let unit = max(bounds.width / 128, 0.25)
        let barRect = NSRect(x: 8 * unit, y: 8 * unit, width: 112 * unit, height: 22 * unit)
        let radius = barRect.height / 2

        NSColor(calibratedWhite: 0.08, alpha: 0.85).setFill()
        NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius).fill()

        NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
        let border = NSBezierPath(roundedRect: barRect.insetBy(dx: 0.5 * unit, dy: 0.5 * unit), xRadius: radius, yRadius: radius)
        border.lineWidth = max(1, unit)
        border.stroke()

        let inset = 3 * unit
        let inner = barRect.insetBy(dx: inset, dy: inset)
        let fraction = CGFloat(state.percent ?? 100) / 100
        guard fraction > 0 else { return }

        let alpha: CGFloat = state.percent == nil ? 0.55 : 1.0
        let fillWidth = max(inner.height, inner.width * fraction)
        let fillRect = NSRect(x: inner.minX, y: inner.minY, width: min(inner.width, fillWidth), height: inner.height)
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: inner.height / 2, yRadius: inner.height / 2)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.22, green: 0.82, blue: 0.45, alpha: alpha),
            NSColor(calibratedRed: 0.08, green: 0.65, blue: 0.34, alpha: alpha),
        ])
        gradient?.draw(in: fillPath, angle: 90)
    }
}
