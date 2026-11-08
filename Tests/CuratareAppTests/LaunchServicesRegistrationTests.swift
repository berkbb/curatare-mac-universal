// SPDX-License-Identifier: GPL-3.0-or-later
@testable import Curatare
import Foundation
import Testing

/// Yeniden kayıt yalnızca derleme değişince ve yalnızca gerçek Curatare paketinde yapılır.
@Suite("Launch Services Registration Tests")
struct LaunchServicesRegistrationTests {
    @Test("Re-registers only when the build number changes")
    func reRegistersOnlyWhenTheBuildChanges() {
        #expect(LaunchServicesRegistration.needsRegistration(lastBuild: nil, currentBuild: "2"))
        #expect(LaunchServicesRegistration.needsRegistration(lastBuild: "1", currentBuild: "2"))
        #expect(LaunchServicesRegistration.needsRegistration(lastBuild: "3", currentBuild: "2"), "geri dönüşte de kayıt yenilenir")
        #expect(!LaunchServicesRegistration.needsRegistration(lastBuild: "2", currentBuild: "2"))
    }

    @Test("The test bundle is never registered")
    @MainActor
    func testBundleIsNeverRegistered() {
        let (defaults, cleanup) = TestDefaults.make()
        defer { cleanup() }
        // Bundle.main testlerde xctest'tir: kimlik Curatare değil, hiçbir şey kaydedilmez ve derleme yazılmaz.
        LaunchServicesRegistration.registerIfBuildChanged(bundle: .main, defaults: defaults)
        #expect(defaults.string(forKey: LaunchServicesRegistration.registeredBuildKey) == nil)
    }
}
