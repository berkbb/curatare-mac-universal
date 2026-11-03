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
        isGranted(homeDirectoryURL: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
    }

    /// Yalnızca Tam Disk Erişimiyle okunabilen yolları dener. Bu yollar izin yoksa sessizce reddedilir;
    /// başka uygulamaların konteynerleri ("diğer uygulamaların verileri" sorusu) bilerek denenmez.
    public static func isGranted(homeDirectoryURL: URL) -> Bool {
        let home = homeDirectoryURL.path
        let testPaths = [
            home + "/Library/Application Support/com.apple.TCC/TCC.db",
            home + "/Library/Safari/Bookmarks.plist",
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
