// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore
import Foundation
import Observation

// MARK: - Uygulama İkon Belleği (Zero-Lag Icon Cache)

@MainActor
public final class AppIconCache {
    public static let shared = AppIconCache()
    private var cache = NSCache<NSString, NSImage>()

    public func icon(for path: String, size: CGFloat = 28) -> NSImage {
        let key = "\(path)_\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let rawIcon = NSWorkspace.shared.icon(forFile: path)
        let icon = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            rawIcon.draw(in: rect)
            return true
        }
        cache.setObject(icon, forKey: key)
        return icon
    }
}
