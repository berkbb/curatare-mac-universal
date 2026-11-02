# AGENTS.md — Primary Constitution & L3 Persona Governance (`Curatare`)

> **Repository:** `curatare-mac-universal` (`com.babadogantech.curatare`)
> **Platform:** macOS 26 (Tahoe) and later — Universal Binary (`arm64` + `x86_64`)
> **Language & Stack:** Swift 6.2 (`swift-tools-version: 6.2`), SwiftUI (Liquid Glass), AppKit
> **Core Engine:** `Mole` (`tw93/mole` CLI + universal `analyze-go` & `status-go` helpers, bundled under `Contents/Resources/mole/` with `Contents/MacOS/mole` entry symlink, updatable from GitHub releases via `Scripts/update-mole.sh`)
> **License:** GPL-3.0-or-later
> **Memory Tier:** L3 Persona & Constitutional Governance (TencentDB Agent Memory Architecture)

---

## 1. Mission & Identity

**Curatare** (Romanian *Curățare* = Cleaning) is a native, high-assurance macOS system cleaner, library orphan auditor, application/plugin uninstaller, developer & AI cache cleaner, disk usage analyzer, and system maintenance studio. It unites three pillars in a single macOS 26 Liquid Glass application aligned with its sibling apps (**Arhivar**, **Copiator**, **Descarcator**):

1. **Mole Engine (`tw93/mole`)** — Fast deep cleaning (`mole clean`), project artifact purging (`mole purge`), installer discovery (`mole installer`), universal binary slimming (`mole slim`), system health & maintenance (`mole optimize` + `status-go --json`), and interactive disk usage analysis (`analyze-go --json`), with one-click GitHub updates (`Scripts/update-mole.sh` / `Mole-Guncelle.command` / Settings → Update Mole).
2. **Library & Ecosystem Audit (`library_clean.md` Methodology)** — Five-group (`A`–`E`) `~/Library` and `/Library` orphan detection (including iOS/iPadOS `Wrapper/*.app` bundle resolution, dead `containermanagerd` project containers, bare-named `swift run` traces, dead `LaunchAgents`/`LaunchDaemons`, orphaned `pkgutil` receipts, safe copyable `sudo` one-liner generation ending with `echo TAMAM`, GitHub ignored build outputs with tracked-file protection, AI tool footprint auditing, browser site data / heavy app cache scanning, and Time Machine local snapshot thinning).
3. **Native Application Uninstaller & SmartDelete (`Uygulama Kaldırıcı`)** — Browse Applications, Widgets, and Plugins (PreferencePanes, QuickLook, Internet Plug-Ins, Screen Savers, Spotlight Importers, Audio Components), drag-and-drop any bundle to inspect every related file with icons, sizes, and checkboxes, guard against running or system-protected apps, and optionally watch `~/.Trash` (**SmartDelete**) to clean up leftover Library files when an app is trashed in Finder.

All agents operating in this repository must prioritize **data safety, reversibility (Dated Trash only), strict protection of system/shared/active resources, deterministic execution, process isolation, and native user experience**.

---

## 2. Non-Negotiable Constitutional Invariants

1. **Dated-Trash-Only Rule (`library_clean.md` Rule 1 — Never Permanent Delete):**
   - Cleanup and uninstall operations in `Curatare` **NEVER** permanently delete user or application files (`rm -rf` and `FileManager.removeItem` on user targets are strictly prohibited).
   - Every cleanup or uninstall round creates a timestamped batch directory inside `~/.Trash` (e.g. `~/.Trash/Curatare-2026-10-31-150000/user/...` and `system/...`) preserving the relative path structure from `~` or `/`, and records a reversible manifest (`TrashBatchManifest`) so the user can restore any batch with one click (**Restore / Geri Yükle**).
2. **Strict Do-Not-Touch Protection List (`library_clean.md` Rule 2):**
   - Never flag or move `/System/Library`, `com.apple.*`, `group.com.apple.*`, `systemgroup.*`, `org.cups.*`, or Apple system daemons (`AddressBook`, `CloudDocs`, `Knowledge`, `FileProvider`, `contactsd`).
   - Never flag shared third-party frameworks while any host app exists (`Sparkle`, `Firebase`, `Crashlytics`, `Kingfisher`, `Segment`, `Keystone`, `install4j` when any `com.install4j.*` app is installed, `Google` and `Microsoft` shared groups when Chrome/Drive/Office/Edge/Teams are installed).
   - Never flag shared developer caches (`Gradle` `modules-2` and active wrapper versions referenced in `gradle-wrapper.properties`, `NuGet`/`.nuget`, `.pub-cache`, `Homebrew`, `pip`, `ms-playwright*`, `go-build`, `swiftpm`, `.rustup`, `.konan`, `.hvigor`, `.android/avd`), active virtualization helpers (`com.vmware.*` when VMware Fusion is installed, `com.parallels.*` when Parallels is installed, Claude `vm_bundles`), active AI tool state (`~/.codex`, `~/.gemini`, `codex-primary-runtime`, `.antigravity-ide`, Chrome `OptGuideOnDeviceModel`, Photoshop `sensei_model_cache`, UPDF OCR models), or sibling family applications (`com.babadogantech.arhivar`, `net.babadogan.arhivar`, `com.babadogantech.copiator`, `com.babadogantech.descarcator`, `com.babadogantech.curatare`).
3. **Running-Process Guard (`pgrep` / `NSRunningApplication`):**
   - Before moving any application bundle, container, browser IndexedDB/cache, or daemon data to the dated Trash folder, `Curatare` must verify that the owning process is not currently running.
4. **Process Boundary & Kernel Sandbox (`sandbox-exec`):**
   - External helper invocations (`mole`, `analyze-go`, `status-go`, `git`, `pkgutil`, `tmutil`, `ollama`) run strictly through `CommandRunner` and `ChildProcessGuard` (never via `sh -c` string concatenation with user paths).
   - Sensitive credential directories (`~/.ssh`, `~/.gnupg`, `~/.aws`, `~/Library/Keychains`) are denied at both the scanner layer and the `SandboxProfile` layer.
5. **Complete Trilingual Localization (`tr`, `en`, `ro`):**
   - All user-facing strings must live in `LKey` (`Localization.swift`) with 1:1 parity across `Resources/tr.lproj`, `Resources/en.lproj`, and `Resources/ro.lproj`. Turkish (`tr`) is the default development language.
6. **Table & Test Hygiene:**
   - Never use `@Environment` inside row closures of a hierarchical `Table(items, children: \.children)` (crashes in SwiftUI's `OutlineListCoordinator`); pass `language` or formatting closures explicitly from the parent view.
   - All unit and app tests must use `TestDefaults.make()` backed by a temporary plist and temporary directory fixtures so `swift test` leaves zero files in `~/Library/Preferences` or `~/.Trash`.
7. **Language Rule for `.agents/`:**
   - Every file inside `.agents/` (`AGENTS.md`, `context/`, `rules/`, `skills/`) must be written exclusively in English.

---

## 3. Repository Map

| Path | Responsibility |
| :--- | :--- |
| `Package.swift` | SwiftPM manifest (`CuratareCore`, `Curatare`, `CuratareCoreTests`, `CuratareAppTests`). |
| `Sources/CuratareCore/` | Engine locator/updater, Mole bridge (`status-go`, `analyze-go`, `mole` CLI), `ProtectionRules`, `DatedTrash` (reversible `~/.Trash/Curatare-...` batches), `LibraryScanner` (Steps 1–6, Groups A–E, `sudo` one-liner generator), `ExtendedScanners` (GitHub build artifacts, AI footprint, Browser/App caches, Time Machine snapshots), `AppUninstaller`, `TrashWatcher` (SmartDelete), `SandboxProfile`, `CommandRunner`, `ChildProcessGuard`, `AppLog`, `AppUpdate`, `Localization`. |
| `Sources/Curatare/` | `@MainActor` SwiftUI app (`CuratareApp`, `AppModel`, `AppSettings`, `FinderService`, `ContentView`, `LibraryAuditView`, `UninstallerView`, `DevAICleanupView`, `BrowserCachesView`, `DiskAnalyzerView`, `SystemStatusView`, `TrashHistoryView`, `SettingsView`, `LogView`, `AboutView`). |
| `Vendor/mole/` | Bundled Mole scripts (`mole`, `bin/*.sh`, `lib/**`) and universal Mach-O helpers (`bin/analyze-go`, `bin/status-go`), populated and updated by `Scripts/update-mole.sh`. |
| `Resources/` | `AppIcon.icns` and `tr.lproj`, `en.lproj`, `ro.lproj` localization tables (`Localizable.strings`, `InfoPlist.strings`, `ServicesMenu.strings`). |
| `Scripts/` | `update-mole.sh`, `build_app.sh`, `package.sh`, `release.sh`, `set-version.sh`, `verify_bundle.sh`, `make_icon.swift`, `update_signing.swift`. |
| `Tests/` | `CuratareCoreTests` and `CuratareAppTests` Swift Testing suites. |
