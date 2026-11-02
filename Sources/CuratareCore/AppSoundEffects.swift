// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import Foundation

/// macOS yerel ses efektleri (Curatare özgün Çöp'e taşıma ve geri yükleme sesleri).
public enum AppSoundEffects {
    /// macOS CoreAudio yerel dock çöp ses efekti (`drag to trash.aif`).
    public static let systemTrashSoundURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/drag to trash.aif")

    @MainActor
    public static func playTrashSound() {
        if let bundled = Bundle.main.url(forResource: "curatare_trash", withExtension: "aiff") ??
                         Bundle.main.url(forResource: "curatare_trash", withExtension: "aif"),
           let sound = NSSound(contentsOf: bundled, byReference: true) {
            sound.play()
        } else if FileManager.default.fileExists(atPath: systemTrashSoundURL.path),
           let sound = NSSound(contentsOf: systemTrashSoundURL, byReference: true) {
            sound.play()
        } else if let fallback = NSSound(named: "Trash") {
            fallback.play()
        } else {
            NSSound.beep()
        }
    }

    @MainActor
    public static func playRestoreSound() {
        if let bundled = Bundle.main.url(forResource: "curatare_restore", withExtension: "aiff") ??
                         Bundle.main.url(forResource: "curatare_restore", withExtension: "aif"),
           let sound = NSSound(contentsOf: bundled, byReference: true) {
            sound.play()
        } else if let sound = NSSound(named: "Pop") {
            sound.play()
        } else if let glass = NSSound(named: "Glass") {
            glass.play()
        }
    }
}
