# Domain Wiki — Curatare Knowledge Asset

> **Memory Category:** TencentDB LLM-Wiki Knowledge Asset
> **Scope:** Domain workflows, Mole engine contract, `library_clean.md` 5-group audit protocol, native uninstaller & SmartDelete, Dated-Trash reversibility, and security boundaries.

---

## 1. System Overview

**Curatare** (`com.babadogantech.curatare`) is a universal macOS system cleaner, library auditor, app/plugin uninstaller, developer/AI cache cleaner, disk analyzer, and system optimizer (`arm64` + `x86_64`, macOS 26+) split into two SwiftPM targets:
- **`CuratareCore`**: Mole engine discovery/updating (`EngineLocator`, `EngineUpdater`), `MoleBridge` (`status-go`, `analyze-go`, `mole` CLI), `ProtectionRules` (`library_clean.md` Do-Not-Touch invariants), `DatedTrash` (reversible dated batches in `~/.Trash/Curatare-YYYY-MM-DD-HHmmss`), `LibraryScanner` (Steps 1–6, Groups A–E, safe `sudo` command generator), `ExtendedScanners` (GitHub build artifacts, AI tools footprint, Browser/App heavy caches, Time Machine local snapshots), `DuplicateFinder` (identical files in `~/Downloads`: size buckets, then SHA-256; paths sharing an APFS clone ID (`ATTR_CMNEXT_CLONEID`) or an inode count as one copy), `AppUninstaller` (Applications, Widgets, Plugins, associated files discovery), `TrashWatcher` (SmartDelete `~/.Trash` monitor), `HomebrewScanner`, `SystemTweaks` (`SystemTweakManager`, typed `PreferenceStoreProtocol`), `SystemInfoCenter` (`SystemCenterCollector`, S.M.A.R.T.), `FileChecksum`, `FullDiskAccess`, `SandboxProfile`, `CommandRunner`, `ChildProcessGuard`, `AppLog`, `AppUpdate`, and `Localization`.
- **`Curatare`**: `@MainActor` SwiftUI Liquid Glass application (`AppModel`, `AppSettings`, `FinderService`, 9 studio sections (`StudioSection`: home, libraryAudit, uninstaller, homebrew, devAndAI, browserAndCaches, diskAnalyzer, systemStatus, trashHistory), menu bar monitor, log viewer, settings, and about sheets).

## 2. Three Integrated Pillars

### Pillar A: Mole Engine (`tw93/mole`)
- Bundled under `Contents/Resources/mole/` (`mole`, `bin/*.sh`, `lib/**`, universal `bin/analyze-go`, universal `bin/status-go`) with `Contents/MacOS/mole -> ../Resources/mole/mole`.
- Updated from `https://api.github.com/repos/tw93/Mole/releases/latest` via `Scripts/update-mole.sh` (`Mole-Guncelle.command` or in-app Settings/Menu), downloading source scripts and merging `binaries-darwin-arm64.tar.gz` + `binaries-darwin-amd64.tar.gz` via `lipo -create` (or compiling universal binaries with `go build` + `lipo`).
- JSON & CLI contracts:
  - `bin/status-go --json`: returns CPU, memory, swap, disks, disk I/O, network rates, uptime, top processes, and `health_score` (0–100).
  - `bin/analyze-go --json <path>`: returns hierarchical directory size breakdown (`entries`, `total_size`, `total_files`).
  - `mole clean --dry-run`: writes candidate clean items and reports estimated reclaimable space.
  - `mole uninstall --list`: returns JSON array of installed apps.
  - `mole purge --dry-run` / `mole installer --dry-run` / `mole optimize --dry-run` / `mole slim --dry-run`.
- User configuration read by Curatare: `~/.config/mole/whitelist` (merged into `ProtectionRules.userWhitelistPatterns`) and `~/.config/mole/purge_paths` (project folders `mole purge` scans; one path per line, `~` allowed, `#` comments; empty means Mole's defaults).
- **Portable rules (`PortableRules.swift`):** Settings → Protection exports `AppSettings.customWhitelistPaths` and the purge paths as JSON (`format` = `com.babadogantech.curatare.rules`, `version`, `exportedAt`, `whitelist`, `purgePaths`; home paths as `~/`). Import decodes leniently (unknown keys ignored, missing keys defaulted, non-text entries counted), validates every entry against the built-in do-not-touch list with user whitelist and allow flags switched off, rejects unsafe purge roots, previews a `PortableRulesImportPlan` (`merge` default, `replace` only for sections present in the file), and writes only the whitelist setting and `purge_paths` (`MolePurgePathsFile` keeps comment lines and follows a symlink).

### Pillar B: `library_clean.md` Methodology (Steps 1–6 & Extended Scanners)
1. **Rule 1 — Dated Trash Only:** Never run `rm -rf` on user targets. Move items to `~/.Trash/Curatare-YYYY-MM-DD-HHmmss/user/<relative-path>` (or `system/<relative-path>`), recording a manifest for one-click restoration.
2. **Rule 2 — Strict Protection List:** System (`com.apple.*`, `group.com.apple.*`, `systemgroup.*`, `org.cups.*`, `/System/Library`), shared frameworks (`Sparkle`, `Firebase`, `Crashlytics`, `Kingfisher`, `Segment`, `Keystone`, `install4j` when any `com.install4j.*` app exists), shared dev caches (`Gradle` `modules-2` & active wrapper versions, `NuGet`, `.pub-cache`, `Homebrew`, `pip`, `ms-playwright*`, `go-build`, `swiftpm`, `.rustup`, `.konan`), virtualization (`com.vmware.*` when Fusion exists, `com.parallels.*` when Parallels exists, Claude `vm_bundles`), and active AI state (`~/.codex`, `~/.gemini`, `.antigravity-ide`, `OptGuideOnDeviceModel`, `sensei_model_cache`).
3. **Rule 3 — Five Audit Groups (`A`–`E`):**
   - **Group A:** Project leftovers (`*Tests-<UUID>.plist`, `*Fuzz-<UUID>.plist`, `com.companyname.*`, `com.example.*`, retired bundle IDs).
   - **Group B:** Deleted project containers (`~/Library/Containers/*/.com.apple.containermanagerd.metadata.plist` whose `application_bundle` points to a missing path under `/Users`, `/Volumes`, or `/private/tmp`, excluding UUID iOS Wrapper containers and projects still present in `~/Documents/GitHub`).
   - **Group C:** Bare-named dev traces in `Preferences`, `Caches`, `HTTPStorages`, `WebKit`, `Application Support`, `Logs` from `swift run` or uninstalled bare binaries.
   - **Group D:** Uninstalled app leftovers across the 11 `~/Library` directories (`Preferences`, `Containers`, `Group Containers`, `Application Support`, `Caches`, `Saved Application State`, `HTTPStorages`, `WebKit`, `Application Scripts`, `Logs`, `LaunchAgents`) not matching any installed app (including iOS `Wrapper/*.app`), plugin, helper, or 3-component root prefix.
   - **Group E:** Dead `LaunchAgents`/`LaunchDaemons` (`Program` or `ProgramArguments[0]` missing on disk), `/Library` system orphans, and orphaned `pkgutil --pkgs` receipts, plus a copyable one-line `sudo` command ending with `echo TAMAM`.
4. **Extended Scanners:**
   - **GitHub Build Artifacts:** `git -C <repo> ls-files --others --ignored --exclude-standard --directory` for `build`, `.build`, `app/build`, `.gradle`, `.kotlin`, `.cxx`, `.deriveddata`, `dist` — skipping repos with tracked files inside build dirs or active compiler processes.
   - **AI Tools Footprint:** Orphaned `codex-runtime-install-*`, legacy `~/.antigravity` when `.antigravity-ide` is active, `CachedExtensionVSIXs`, `Claude-3p`, desktop `Application Support/Codex` when `Codex.app` is absent, and Ollama models via `ollama list`.
   - **Browser Site Data & Heavy App Caches:** Browser `IndexedDB` / `File System` blobs, Safari `Cookies.binarycookies_tmp_*.dat`, old Photoshop `PHSP/<ver>`, old `EdgeUpdater` versions, unused Gradle wrapper versions vs `gradle-wrapper.properties`, `~/.dartServer/.analysis-driver`, and Office lock files (`~$*`, `.~lock*`).
   - **Time Machine Local Snapshots:** `tmutil listlocalsnapshots /` and `tmutil thinlocalsnapshots / 30000000000 4`.

### Pillar C: Application Uninstaller & SmartDelete (`AppUninstaller` & `TrashWatcher`)
- Tabs for **Applications**, **Widgets**, and **Plugins** (PreferencePanes, QuickLook, Internet Plug-Ins, Screen Savers, Spotlight Importers, Audio Components).
- Drag-and-drop any `.app` or plugin onto the window, Dock icon, or Finder Service to inspect all associated `~/Library` and `/Library` files with Finder icons, sizes, and checkboxes.
- **SmartDelete (`TrashWatcher`):** Watches `~/.Trash` for newly trashed `.app` bundles and prompts to move their orphaned `~/Library` leftovers to the dated Trash batch.

---

## 3. Comprehensive System Maintenance & Control Center (Feature Parity)

Curatare achieves 100% feature coverage across all 8 core functional areas of industry-standard macOS maintenance utilities:

1. **Welcome / Quick Actions:** Mole-powered 100-point system health score, instant quick clean, deep clean, and maintenance task shortcuts.
2. **Maintenance Tasks (`MoleOptimizationTask`, `MoleBridge.runOptimizationTasks` in `MoleBridge.swift`):**
   - **Outcome reporting:** There are 12 routines. Each returns a `MoleOptimizationOutcome` with status `done`, `failed` or `needsAdmin(command:)`.
     - The completion toast counts only `done` outcomes and is skipped when nothing completed.
     - Failures and administrator commands share one alert with a **Copy Command** button.
     - Curatare never elevates itself.
   - **Default selection:** Only QuickLook is selected.
   - **The routines:**
     - QuickLook cache reload (`qlmanage -r cache`).
     - Saved window states not written for 30 days move to the Dated Trash (`MoleBridge.staleSavedStates`). Protected (`com.apple.*`) and running apps are skipped.
     - DNS cache flush. The cache lives in root-owned `mDNSResponder`, so the task hands over `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo TAMAM` (`needsAdmin`).
     - Icon redraw: restarts Dock and Finder.
       - A process counts as restarted only after its old PID has exited.
       - The user's `iconservicesagent` ignores SIGTERM, so it is not touched.
       - The root-owned `/Library/Caches/com.apple.iconservices.store` is not touched either.
     - User font cache (`atsutil databases -removeUser`).
     - LaunchServices "Open With" rebuild (`lsregister -kill -r`).
     - Spotlight rebuild (`mdutil -E /`).
     - User diagnostic reports (`~/Library/Logs/DiagnosticReports`) move to the Dated Trash.
     - Time Machine local snapshot thinning (`tmutil thinlocalsnapshots`).
     - Apple Mail Envelope Index moves to the Dated Trash. The task is reported as failed while Mail runs.
     - CUPS queue clearing (`cancel -a -`).
     - APFS verification (`diskutil verifyVolume /`). It is `done` only when the output says "appears to be OK"; it runs without root in about 10 seconds.
3. **Hidden Utilities & Checksum (`HiddenSystemUtility` in `MoleBridge.swift`, `FileChecksumCalculator` in `FileChecksum.swift`):**
   - 1-click launchers for 7 hidden Apple utilities (Wireless Diagnostics, Directory Utility, ColorSync, Archive Utility, Keychain Access, Feedback Assistant, Screen Sharing).
   - MD5, SHA-1, and SHA-256 hash calculator (`computeHashes(for:)`) with auto-matching verification (`verify(expected:)`).
4. **Files & Caches:** 5-group orphan cleaning, 12 developer language ecosystem package caches (pip, cargo, npm, gradle, maven, swiftpm, pub, ccache, go-build, etc.), AI tool caches (Ollama, LM Studio, HuggingFace), browser site storage (Safari, Chrome, Arc, Brave, Edge, Firefox), and Xcode archives.
5. **Security Center (`SystemSecurityStatus`, `MoleBridge.fetchSecurityStatus`):** Live status indicators for SIP, FileVault, Gatekeeper, XProtect & XProtect Remediator definitions, and Lockdown Mode.
6. **Disk Analyzer (`DiskAnalyzerView`):** Multi-level interactive disk tree powered by native universal `analyze-go`.
7. **macOS Tweaks (`SystemTweakManager` in `SystemTweaks.swift`; user-level preferences only):**
   - **30 boolean `SystemTweakItem`s** across the Finder, Dock, Screenshot, Disk & Network and System categories.
     - Items with an `enabledValue` write a typed value when on and remove the key when off: `autohide-delay` 0, `autohide-time-modifier` 0, `QLPanelAnimationDuration` 0, `NSToolbarTitleViewRolloverDelay` 0, `AnimateWindowZoom` false, `AnimateInfoPanes` false.
   - **8 multi-value `SystemChoiceTweak`s:** minimize effect (Genie, Scale, Suck), Dock recent-app count, column auto-sizing, Quick Look hide on deactivate, recent documents limit, recent places limit, tooltip delay, power button sleep.
     - The "macOS default" option removes the key, so no default has to be guessed.
   - **Screenshot cards:** format (PNG, JPG, HEIC, PDF; `ScreenshotFormat`), sanitized file-name prefix (`ScreenshotNamePrefix`; no `/` or `:`, at most 60 characters) and save folder picker (`ScreenshotLocation`).
   - **Safari Develop menu** is a read-only status card (`SafariDevelopMenu`: `com.apple.Safari.SandboxBroker` `ShowDevelopMenu`) with an **Open Safari** button.
   - **Reset All** restores every toggle and choice plus the screenshot format, name and folder. It never touches Safari.
   - **Dock spacers:** tiles can be added and removed by editing `com.apple.dock` `persistent-apps` / `persistent-others` through CFPreferences; no System Events automation and no `python3`, so no permission prompt or developer tools installer appears.
   - **Preference store:** All reads and writes go through `PreferenceStoreProtocol`: `SystemPreferenceStore` on CFPreferences, `MockPreferenceStore` in tests.
     - `PreferenceValue` (bool, int, double, string) matches values that `defaults` wrote with another type. For example, a legacy `-string 0` still reads as `0`.
     - `NSGlobalDomain` must map to `kCFPreferencesAnyApplication`. Passed through as an app ID, it silently writes a stray `~/Library/Preferences/NSGlobalDomain.plist`.
8. **System Center (`SystemCenterCollector` in `SystemInfoCenter.swift`):** A 5-tab system inspector (`SystemCenterTab`):
   - Hardware: core topology, plus the startup disk S.M.A.R.T. status (`DiskSmartStatus`) from `diskutil info disk0`.
   - Memory: live Memory Pressure gauge and swap purge.
   - APFS Volumes.
   - OS and Identity, with uptime.
   - Profile export.

### Constitutional Redlines on Feature Adoption
- **DoD 7-Pass Shredding / Permanent Erase:** Strictly rejected. Modern SSD/NVMe wear-leveling makes multi-pass rewriting ineffective and degrades flash longevity. All deletions must strictly route to reversible dated batches under `~/.Trash/Curatare-TARİH` (`DatedTrash`).
- **Legacy HFS+ / Pre-APFS Routines:** Obsolete defragmentation and NetInfo caches are omitted to maintain APFS system integrity.
- **Root/Kext Invasions:** Kernel extensions or intrusive root-level system volume modifications are prohibited under Apple Silicon Signed System Volume (SSV) security.
- **No Fake Success:** A maintenance task that cannot do its work must report `failed` or `needsAdmin`, never `done`. A sent signal or a zero exit code is not proof: compare PIDs or parse the tool's own verdict.
- **Sandboxed Apps' Preferences Are Read-Only:**
  - **Removed for the same reason:** The Apple Music half-stars and TextEdit blank-document toggles were removed on 2026-11-03. Reading `com.apple.Music` at launch opened a Media & Apple Music permission prompt that froze the app's main thread, and both domains live in protected containers.
  - **Rule:** Curatare does not write another sandboxed app's preferences unless a live test proves the change works both ways.
  - **Why:** The `com.apple.Safari` domain resolves to Safari's protected container. Safari applies an outside "off" through `SandboxBroker` but ignores an outside "on" (live test, 2026-11-03).
- **Security-Weakening Toggles:** Curatare offers no Gatekeeper, firewall, XProtect or disk-image verification switches. It offers no Recent Items or Help cache cleanup either, because those live under the `com.apple.*` do-not-touch list.
