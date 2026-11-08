// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit
import CuratareCore

/// Curatare'nin Launch Services kaydını güncel tutar.
///
/// Launch Services bir uygulamanın belge türlerini (uygulama paketlerini sürükleyip bırakma için bildirilen türler), Finder
/// servisini ve simgesini paket kaydından okur; paket yenilenince (yeni sürüm kurulunca) bu kayıt her zaman kendiliğinden
/// tazelenmez. Derleme numarası değişen ilk açılışta paket yeniden kaydedilir (`lsregister -f` ile aynı etki).
enum LaunchServicesRegistration {
    /// Son kaydedilen derleme numarası. Bir ayar değildir; ayarları sıfırlamak onu silmez.
    static let registeredBuildKey = "registeredBuild"

    /// Derleme değiştiyse (ilk açılış, yükseltme ya da geri dönüş) paket yeniden kaydedilir.
    nonisolated static func needsRegistration(lastBuild: String?, currentBuild: String) -> Bool {
        lastBuild != currentBuild
    }

    /// Yalnızca gerçek Curatare paketi (testlerde `Bundle.main` xctest'tir) ve yalnızca derleme değiştiğinde.
    static func registerIfBuildChanged(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        guard bundle.bundleIdentifier == AppLog.subsystem else { return }
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        guard needsRegistration(lastBuild: defaults.string(forKey: registeredBuildKey), currentBuild: build) else { return }
        if register(bundle: bundle) {
            defaults.set(build, forKey: registeredBuildKey)
            AppLog.shared.info(.app, "Re-registered with Launch Services for build \(build)")
        }
    }

    /// Paketi Launch Services'a yeniden kaydeder. Başarısızlık günlüğe yazılır.
    @discardableResult
    static func register(bundle: Bundle = .main) -> Bool {
        let status = LSRegisterURL(bundle.bundleURL as CFURL, true)
        if status != noErr {
            AppLog.shared.warning(.app, "Launch Services registration failed", detail: "LSRegisterURL status \(status)")
        }
        return status == noErr
    }
}
