// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Foundation

/// macOS Tam Disk Erişimi (Full Disk Access / TCC) denetleyicisi.
///
/// Safari, Mail veya sistem konteynerleri gibi TCC korumalı
/// kullanıcı kitaplığı dizinlerinin okunabilirliğini test eder ve kullanıcıyı
/// gerektiğinde macOS Sistem Ayarları paneline yönlendirir.
public enum FullDiskAccess: Sendable {
    /// Uygulamanın Tam Disk Erişimi olup olmadığını sınar.
    public static var isGranted: Bool {
        let home = NSHomeDirectory()
        let testPaths = [
            home + "/Library/Safari/Bookmarks.plist",
            home + "/Library/Containers/com.apple.mail/Data/Library/Mail",
            home + "/Library/Suggestions",
        ]
        let fm = FileManager.default
        for path in testPaths {
            if fm.isReadableFile(atPath: path) {
                return true
            }
        }
        return false
    }

    /// Kullanıcıyı doğrudan macOS "Sistem Ayarları > Gizlilik ve Güvenlik > Tam Disk Erişimi" paneline yönlendirir.
    @MainActor
    public static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
