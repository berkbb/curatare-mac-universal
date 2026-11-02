# Domain Wiki — Curatare Knowledge Asset

> **Memory Category:** TencentDB LLM-Wiki Knowledge Asset
> **Scope:** Domain workflows, Mole engine contract, `library_clean.md` 5-group audit protocol, native uninstaller & SmartDelete, Dated-Trash reversibility, and security boundaries.

---

## 1. System Overview

**Curatare** (`com.babadogantech.curatare`) is a universal macOS system cleaner, library auditor, app/plugin uninstaller, developer/AI cache cleaner, disk analyzer, and system optimizer (`arm64` + `x86_64`, macOS 26+) split into two SwiftPM targets:
- **`CuratareCore`**: Mole engine discovery/updating (`EngineLocator`, `EngineUpdater`), `MoleBridge` (`status-go`, `analyze-go`, `mole` CLI), `ProtectionRules` (`library_clean.md` Do-Not-Touch invariants), `DatedTrash` (reversible dated batches in `~/.Trash/Curatare-YYYY-MM-DD-HHmmss`), `LibraryScanner` (Steps 1–6, Groups A–E, safe `sudo` command generator), `ExtendedScanners` (GitHub build artifacts, AI tools footprint, Browser/App heavy caches, Time Machine local snapshots), `AppUninstaller` (Applications, Widgets, Plugins, associated files discovery), `TrashWatcher` (SmartDelete `~/.Trash` monitor), `SandboxProfile`, `CommandRunner`, `ChildProcessGuard`, `AppLog`, `AppUpdate`, and `Localization`.
- **`Curatare`**: `@MainActor` SwiftUI Liquid Glass application (`AppModel`, `AppSettings`, `FinderService`, 7 main studio tabs, menu bar monitor, log viewer, settings, and about sheets).

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
2. **Maintenance Tasks (`MaintenanceTasks.swift`):** 11 native maintenance routines:
   - APFS live filesystem verification (`fsck_apfs -n`)
   - Spotlight search metadata rebuild (`mdutil -E`)
   - Time Machine local snapshot thinning (`tmutil thinlocalsnapshots`)
   - Apple Mail Envelope Index rebuild
   - CUPS printer queue clearing (`cancel -a -`)
   - QuickLook cache reload (`qlmanage -r cache`)
   - DNS cache flush (`mDNSResponder -HUP`)
   - System and user font caches reset (`atsutil`)
   - IconServices icon cache flush
   - LaunchServices "Open With" database rebuild
   - System and diagnostic log cache purging
3. **Hidden Utilities & Checksum (`HiddenSystemToolsLauncher`, `ChecksumCalculator`):**
   - 1-click launchers for 7 hidden Apple utilities (Wireless Diagnostics, Directory Utility, ColorSync, Archive Utility, Keychain Access, Feedback Assistant, Screen Sharing).
   - Real-time streaming MD5, SHA-1, and SHA-256 hash calculator with auto-matching verification.
4. **Files & Caches:** 5-group orphan cleaning, 12 developer language ecosystem package caches (pip, cargo, npm, gradle, maven, swiftpm, pub, ccache, go-build, etc.), AI tool caches (Ollama, LM Studio, HuggingFace), browser site storage (Safari, Chrome, Arc, Brave, Edge, Firefox), and Xcode archives.
5. **Security Center (`SecurityStatusCard`):** Live status indicators for SIP, FileVault, Gatekeeper, XProtect & XProtect Remediator definitions, and Lockdown Mode.
6. **Disk Analyzer (`DiskAnalyzerView`):** Multi-level interactive disk tree powered by native universal `analyze-go`.
7. **macOS Tweaks (`SystemTweakManager`):** 20 curated macOS preferences (Finder hidden files, POSIX path in title, Dock spacer tiles, external USB `.DS_Store` prevention, Ctrl+Cmd window dragging, key repeat speed, TextEdit blank doc, screenshot destination and shadow toggles).
8. **System Center (`SystemInfoCenter`):** 5-panel system inspector (Hardware core topology, Memory with live Memory Pressure gauge & swap purge, APFS Volumes, OS/Identity Uptime, and Profile export).

### Constitutional Redlines on Feature Adoption
- **DoD 7-Pass Shredding / Permanent Erase:** Strictly rejected. Modern SSD/NVMe wear-leveling makes multi-pass rewriting ineffective and degrades flash longevity. All deletions must strictly route to reversible dated batches under `~/.Trash/Curatare-TARİH` (`DatedTrash`).
- **Legacy HFS+ / Pre-APFS Routines:** Obsolete defragmentation and NetInfo caches are omitted to maintain APFS system integrity.
- **Root/Kext Invasions:** Kernel extensions or intrusive root-level system volume modifications are prohibited under Apple Silicon Signed System Volume (SSV) security.
