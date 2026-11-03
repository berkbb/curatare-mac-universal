# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Disk health (S.M.A.R.T.) status** in System Center → Hardware, read from the same `diskutil info disk0` call already used for the disk name: green when verified, red with a back-up warning when failing.
- **Screenshot format tweak** (PNG, JPG, HEIC, PDF) in System Tweaks → Screenshot; choosing PNG restores the macOS default, and **Reset All** returns it to PNG.
- **Eight more system tweaks:** Finder path bar from the home folder; Dock icon and size locks and stack grid highlight; screenshot floating thumbnail and mouse pointer; always-expanded Save dialogs; App Nap off. All are user-level, reversible and restored by **Reset All**.
- **Multi-value tweaks:**
  - **Dock:** window minimize effect (Genie, Scale and the hidden Suck), number of recent apps.
  - **Finder:** column auto-sizing, hiding Quick Look when Finder is in the background.
  - **System:** number of recent documents in File menus, number of recent places in Save dialogs.
  - A **macOS default** choice removes the key, so the tweak never assumes a default it cannot verify.
- **New toggles:**
  - **Screenshot file name prefix**, set from a text field.
  - Dock show and hide without animation.
  - Suggested and recent apps in the Dock.
  - Quick Look without animation.

### Changed
- **Inline loading for read-only scans:** Library audit, uninstaller, Homebrew, developer & AI, language ecosystem, browser cache and disk analyzer scans now show a thin in-tab progress strip instead of dimming the whole content area; the full-screen overlay is reserved for cleanup, uninstall and maintenance operations. A scan keeps running when you switch tabs, and a tab opened while another scan runs loads as soon as it finishes.
- **System Status loads once:** The tab no longer re-runs `status-go`, `system_profiler` and `diskutil` on every visit; data is cached until **Refresh**. Live CPU, memory and disk metrics refresh every 15 seconds while the Live Status dashboard is visible. App launch now fetches only the light `status-go` metrics.

- **Faster scans:** The language ecosystem scan is about 5× faster (11.6–13.5 s → 2.3–2.7 s) and the Homebrew package list about 2× faster (4.0 s → 1.8 s) thanks to a parallel folder size walk (`DiskSpace.sizes(of:)`); the Homebrew status scan runs its `brew` calls concurrently (brew's own ~7 s `cleanup --dry-run` remains the floor). The Dev & AI tab no longer runs the Homebrew status scan it never displayed (about 10 s → 4 s on a warm cache), and the uninstaller's Homebrew shortcut no longer waits for a scan to appear.

### Fixed
- **Global tweaks had no effect:** Tweaks in the global domain (show all extensions, Ctrl+⌘ window drag, key repeat, window animations) were written to a separate `NSGlobalDomain.plist` instead of the real global preferences, so the switch moved but macOS ignored it. They now write to the global domain.
- **Safari Develop menu tweak showed the wrong state:**
  - **Cause:** The `com.apple.Safari` domain resolves to Safari's protected container. Without Full Disk Access it reads as empty, so the switch showed off even when the menu was on.
  - **Fix:** The tweak now uses the `com.apple.Safari.SandboxBroker` `ShowDevelopMenu` key, which Safari's own setting writes.
- **Dock auto-hide delay** is now written as a number (`-float 0`) instead of the string `"0"`. Values written by earlier versions are still read as on.
- **Uninstaller leftover labels** (Caches, Preferences, Launch Agent and the rest) moved from code into each language's own `Localizable.strings`.
- **Uninstaller app list ~300× faster:** The list no longer walks every bundle to compute sizes it never displays (32 s → 0.1 s for 92 apps); the selected app is still sized during inspection.
- **System Status header:** The four-tab picker no longer overlaps the subtitle or hides behind the Refresh button; the safety banner wraps instead of truncating.
- **Homebrew tab** no longer shows "Homebrew is not installed" while its first scan is running.
- **System Center localization:** Core breakdown, built-in GPU label, APFS volume kinds, byte counts, uptime, last-refresh date, identity groups, profile kinds/formats and profile messages are now localized 1:1 in `tr`, `en` and `ro` (previously Turkish or English text leaked into other languages).
- **No more invented values:** System Center shows "—" when a value cannot be read instead of placeholder data (firmware version, uptime, `id` output, GPU core count, disk/memory type, volume names and usage).
- **Wrong toasts:** Saving a system profile no longer reports "Item permanently deleted", and copying a checksum shows "Copied: SHA-256" instead of a raw `%@`.

## [1.0.0] - 2026-10-31

### Added
- **Embedded Mole Engine (`tw93/mole`) & GitHub Updater (`Scripts/update-mole.sh`, `Mole-Guncelle.command`):** Integrated `mole` CLI scripts and universal (`arm64` + `x86_64`) `analyze-go` / `status-go` Mach-O helpers.
- **Library Leftovers Audit (5 Groups `A`–`E`):** Detection of iOS `Wrapper/*.app` containers, 3-component root prefix matching, dead `containermanagerd` project metadata resolution, broken `LaunchAgents`/`LaunchDaemons`, and safe copyable single-line `sudo` generator ending with `echo TAMAM`.
- **Dated Trash Service (`DatedTrashService`) & One-Click Restore:** Safe relocation to `~/.Trash/Curatare-YYYY-MM-DD-HHmmss/` without permanent deletion (`rm -rf` prohibited), supported by `manifest.json` for one-click batch restoration.
- **Application Uninstaller & SmartDelete (`TrashWatcher`):** Scans Applications, Widgets, and Plugins with drag-and-drop support, Finder Services integration, and real-time `~/.Trash` monitoring for dragged apps.
- **Extended Scanners (`ExtendedScanners`):** GitHub project build artifact detection with tracked git file protection, AI tool and Ollama model audit, browser `IndexedDB` and `File System` caches, and local Time Machine snapshot thinning.
- **Trilingual Localization (`tr`, `en`, `ro`):** Complete 1:1 localization parity across Turkish, English, and Romanian.
- **Process Isolation & Sandbox:** Child process execution protected by `sandbox-exec` kernel sandbox profiles and `ChildProcessGuard`.
