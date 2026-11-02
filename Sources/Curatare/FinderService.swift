// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Foundation

/// Finder Hizmetler menüsündeki "Curatare ile Kaldır" (`uninstallWithCuratare`) çağrısını karşılar.
@MainActor
public final class FinderService: NSObject {
    private unowned let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    @objc public func uninstallWithCuratare(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        model.handleDroppedURLs(urls)
    }
}
