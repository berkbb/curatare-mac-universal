# Developer Guide (DEVELOPMENT.md)

## Architecture

- **`CuratareCore`**: UI-independent core framework:
  - `EngineLocator` & `EngineUpdater`: Locates and updates the embedded Mole CLI suite.
  - `MoleBridge`: Interfacing with `mole`, `analyze-go`, and `status-go`.
  - `ProtectionRules`: Inviolable safety whitelist for system files, frameworks, developer caches, and virtualization.
  - `DatedTrashService`: Non-destructive dated trash management (`~/.Trash/Curatare-...`) and batch restoration.
  - `LibraryScanner`: 5-group audit (`A`–`E`) for `~/Library` and `/Library` leftovers, iOS containers, and broken launch jobs.
  - `ExtendedScanners`: GitHub build artifacts, AI tool footprints, browser site data, and Time Machine snapshot management.
  - `AppUninstaller`: Inspection and uninstallation of applications, widgets, and plugins with dependency mapping.
  - `TrashWatcher`: Real-time monitoring of `~/.Trash` for SmartDelete capabilities.
  - `SandboxProfile`: Generates restrictive `sandbox-exec` profiles protecting user credentials and keychains.
  - `CommandRunner` & `ChildProcessGuard`: Safe process spawning and timeout enforcement.
  - `AppLog`: Real-time log capture with os_log mirroring.
  - `AppUpdate`: GitHub release checker and Ed25519 signature verification.
  - `Localization`: Type-safe localization engine for `tr`, `en`, and `ro`.
- **`Curatare`**: `@MainActor` SwiftUI Liquid Glass client:
  - `AppModel`: Central observable application state coordinating background scans and user actions.
  - `AppSettings`: Persistent user configuration.
  - `FinderService`: NSServices provider for Finder context menus.
  - 7 Dedicated Studio Views: Library Leftovers, Application Uninstaller, Dev & AI Cleanup, Heavy Caches & Time Machine, Disk Space Analyzer, System Status & Optimization, Trash History & Restore.
  - Auxiliaries: Menu Bar Extra, Settings, Log Console, About, and SmartDelete Banner.

---

## Development Scripts

| Script | Description |
| :--- | :--- |
| `./Scripts/update-mole.sh check` | Queries GitHub (`tw93/Mole`) for the latest Mole release. |
| `./Scripts/update-mole.sh install` | Downloads and installs the latest Mole scripts and universal `analyze-go` / `status-go` binaries into `Vendor/mole`. Download addresses are accepted only under the `tw93/Mole` prefixes; when a `github.com` download fails, the same file is fetched from the GitHub API (`…/tarball/<tag>` for the sources, `…/releases/assets/<id>` with `Accept: application/octet-stream` for the binaries) and verified the same way. |
| `swift test` | Executes the complete Swift Testing suite using temporary sandboxed fixtures. |
| `./Scripts/build_app.sh` | Compiles the universal (`arm64` + `x86_64`) `build/Curatare.app` bundle and embeds the Mole suite. |
| `./Scripts/verify_bundle.sh` | Verifies bundle structure, universal binary architectures, localization catalogs, licenses, and ad-hoc code signature. |
| `./Scripts/package.sh` | Runs tests, builds the application, validates the bundle, and packages `dist/Curatare-<version>.dmg` with `SHA256SUMS.txt`. |
| `./Scripts/release.sh` | Validates git branch cleanliness, previews release notes (dry run), tags git, and uploads assets via `gh release`. |

---

## Coding & Safety Standards

1. **Non-Destructive Operations:** Never call `rm -rf` or `FileManager.removeItem` on user files. Always move files to dated trash batches via `DatedTrashService`.
2. **Process Safety:** Never spawn subshells with string interpolation (`sh -c`). Always use `CommandRunner` with explicit arguments array.
3. **Localization Integrity:** All user-facing strings must have matching keys in `Localization.swift` and across `tr.lproj`, `en.lproj`, and `ro.lproj`.
4. **Test Hygiene:** Unit tests must use `TestDefaults.make()` and temporary directories to ensure zero pollution in `~/Library` or `~/.Trash`.
