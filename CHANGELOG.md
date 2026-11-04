# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Code layout (no behavior change):** `AppModel` (2,356 lines) is split into per-feature extension files, and the two largest view files into one file per screen, with System Status and the uninstaller further split by sub-tab and panel. The largest app source file is now about 1,100 lines.

## [1.1.0] - 2026-11-04

### Added
- **Portable protection rules** in Settings → Protection:
  - **Export** writes the custom whitelist and the Mole purge paths (`~/.config/mole/purge_paths`) to a versioned JSON file. Paths inside the home folder are written as `~/`, so they open correctly on a Mac with another user name.
  - **Import** shows a preview of what will be added and removed before anything changes. **Merge** (the default) only adds new entries; **Replace** also drops entries that are not in the file, and only for lists the file contains.
  - **Validation:** entries on the do-not-touch list (`com.apple.*`, credential folders, shared frameworks, active AI state, sibling apps) are rejected, and so are purge paths that are too broad or unsafe (the home folder, system folders, applications, Library, Trash, wildcards). Each rejected entry is listed with its reason in the user's language.
  - **Compatibility:** unknown fields from newer versions are ignored and missing fields get defaults. Import changes only Curatare's whitelist and the purge paths file, keeps the file's comment lines and symbolic link, and never moves or deletes any other file.
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
- **Remaining user-level tweaks from the reference system maintenance tool:**
  - **Toggles:** Finder windows and Get Info sections without animation; title bar document icon without the hover delay.
  - **Choices:** tooltip delay (macOS default, 100, 500 or 2000 ms) and whether the power button puts the Mac to sleep.
- **Duplicate Downloads** in Disk Analyzer: a new sub-tab finds files of 1 MB or more with identical content in `~/Downloads`.
  - **Read-only scan:** Files are grouped by size first, and only same-size files are read and confirmed with SHA-256. Hidden files, unfinished downloads, files still in iCloud and package contents are skipped.
  - **APFS clones and hard links:** Paths that share the same APFS clone ID (`getattrlist` `ATTR_CMNEXT_CLONEID`) or the same inode count as one copy, because trashing one of them frees no space.
  - **One action:** Selected extra copies move to the dated `~/.Trash/Curatare-YYYY-MM-DD-HHmmss` folder and can be restored from Trash History. At least one copy of each file always stays, and files that changed after the scan are left in place.
  - **Permission on demand:** The Downloads folder is read only when you open the sub-tab or press **Scan Now**, never at launch, so the macOS Downloads prompt appears only then.

### Changed
- **Screenshot save folder:**
  - A folder picker replaces the "Save Screenshots to Downloads" toggle. **Use Default** returns new screenshots to the Desktop, and so does **Reset All**.
  - A folder set by the old toggle is kept and shown.
- **Inline loading for read-only scans:** Library audit, uninstaller, Homebrew, developer & AI, language ecosystem, browser cache and disk analyzer scans now show a thin in-tab progress strip instead of dimming the whole content area; the full-screen overlay is reserved for cleanup, uninstall and maintenance operations. A scan keeps running when you switch tabs, and a tab opened while another scan runs loads as soon as it finishes.
- **System Status loads once:** The tab no longer re-runs `status-go`, `system_profiler` and `diskutil` on every visit; data is cached until **Refresh**. Live CPU, memory and disk metrics refresh every 15 seconds while the Live Status dashboard is visible. App launch now fetches only the light `status-go` metrics.

- **Permissions after the window appears:**
  - **Launch:** The app reads only its own settings before the window appears. Tweak preferences, Dated Trash batches, the SmartDelete watcher, the Mole engine and the update consent start once the window is on screen, so a macOS permission prompt or a slow read can no longer hold the window back.
  - **Full Disk Access banner:** When Full Disk Access is missing, a banner on every tab says what cannot work and opens the right System Settings pane. **Later** hides it for the session, and it updates by itself when you come back from System Settings. Accessibility access is not needed and is not asked for.
  - **Prompt-free check:** The access check no longer looks inside Mail's container, which could raise the "access data from other apps" prompt.

- **Bundled Mole engine 1.68.0:** The embedded engine scripts and the universal `analyze-go` / `status-go` helpers were updated from 1.67.0, with the release archive checked by SHA-256.

- **Faster scans:** The language ecosystem scan is about 5× faster (11.6–13.5 s → 2.3–2.7 s) and the Homebrew package list about 2× faster (4.0 s → 1.8 s) thanks to a parallel folder size walk (`DiskSpace.sizes(of:)`); the Homebrew status scan runs its `brew` calls concurrently (brew's own ~7 s `cleanup --dry-run` remains the floor). The Dev & AI tab no longer runs the Homebrew status scan it never displayed (about 10 s → 4 s on a warm cache), and the uninstaller's Homebrew shortcut no longer waits for a scan to appear.

### Fixed
- **No more launch freeze from an Apple Music permission prompt:**
  - **Cause:** The Apple Music half-stars toggle read `com.apple.Music` at launch, so macOS asked for Media & Apple Music access and the app waited without showing a window.
  - **Removed:** That toggle and the TextEdit blank-document toggle. Both apps keep their preferences in protected containers, and these toggles could not reliably read or change them.
- **Dock spacers without prompts:**
  - **Remove Spacers** asked for permission to control System Events and ran `python3`, which on a Mac without the command line developer tools opened the tools installer.
  - Adding and removing spacers now edits the Dock preferences directly, so no permission prompt or installer appears.
  - Spacers are removed from both sides of the Dock and other tiles are kept.
  - When there is nothing to remove, or the Dock preferences cannot be read, a message says so and nothing is written.
- **Small localization fixes:**
  - An unknown Mole version now shows a translated "unknown" instead of a hardcoded version number.
  - Trailing "…" was removed from interface texts.
  - Trash batches saved before this release show their titles in the user's language.
  - iOS backup names are no longer cut to 12 characters.
- **Every user-facing text comes from `Localizable.strings`:** Text that was hardcoded in Turkish or English now comes from each language's table:
  - 128 scan explanations, protection reasons and audit findings produced by the core.
  - Trash batch titles.
  - Cache scan names.
  - The trash and Homebrew counters.
  - The menu bar metric labels.

  Supporting changes:
  - The scanners, protection rules, uninstaller and maintenance tasks take the user's language (`localized(to:)`).
  - A duplicate `settingsEngine` key was removed.
  - Three untranslated values were translated.
  - All three tables hold 911 keys in identical order.
  - Batches created before this change keep their stored titles.
- **No truncated or cramped text in the interface:** Checked screen by screen in `tr`, `en` and `ro`.
  - **Window size:** The main window's minimum size is now 1180×700 (default 1280×800). Below that, the uninstaller's list and detail panes overflowed the window.
  - **Scrolling instead of squeezing:** The welcome screen and the Library audit intro scroll instead of squeezing their text.
  - **Wrapping text:** Shortcut cards, descriptions, app names, file paths, log lines and trash batch titles wrap instead of ending in "…".
  - **Buttons and badges keep their full width:** Tweak category picker, update banner, trash batch buttons and file kind badges. The uninstaller's action bar splits into two rows when it does not fit.
  - **Localized labels:** The trash batch stats, the trash file filter and the Homebrew "Caveats" heading were hardcoded in Turkish or English; they now come from each language's `Localizable.strings`.
- **Global tweaks had no effect:** Tweaks in the global domain (show all extensions, Ctrl+⌘ window drag, key repeat, window animations) were written to a separate `NSGlobalDomain.plist` instead of the real global preferences, so the switch moved but macOS ignored it. They now write to the global domain.
- **Safari Develop menu is now a read-only status card:**
  - **Problem 1, wrong state:** The `com.apple.Safari` domain resolves to Safari's protected container. Without Full Disk Access it reads as empty, so the switch showed off even when the menu was on.
  - **Problem 2, Safari ignores an outside "on":** Turning the setting off from outside hides the menu at Safari's next launch. Turning it back on does not bring the menu back. This was tested live.
  - **Now:**
    - The card shows the state that Safari's own setting writes (`com.apple.Safari.SandboxBroker` `ShowDevelopMenu`). It refreshes when the window becomes active again.
    - An **Open Safari** button opens Safari; the card names the setting in Safari › Settings › Advanced.
    - **Reset All** no longer touches it.
- **Maintenance tasks report their real outcome:**
  - The completion toast counts only completed tasks, and it is skipped when no task was completed.
  - Failed tasks, and steps that need administrator rights, appear together in one alert.
  - **DNS flush:**
    - **Before:** It only ran `dscacheutil -flushcache` as the user and reported success.
    - **Now:** It hands over a transparent one-line command, `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo TAMAM`, with a **Copy Command** button. The task is no longer selected by default.
  - **Icon services:**
    - **Before:** The task did nothing but log "marked for refresh".
    - **Now:** It restarts Dock and Finder to redraw icons. A process counts as restarted only after its old copy has actually exited.
    - **Left alone:** The user's `iconservicesagent` ignores the termination signal, so it is not touched. The root-owned system icon cache is not touched either.
  - **APFS verification:** It succeeds only when `diskutil verifyVolume /` reports the volume as OK. A failure, or a check that could not run, is now reported instead of "verified".
  - **Apple Mail envelope index reset:** When Mail is running or the reset fails, it is reported as not completed.
  - **Saved window states:**
    - **Before:** The task did nothing but log "verified".
    - **Now:** It moves saved states not written for 30 days to the Dated Trash. Apple apps on the do-not-touch list and open apps are skipped. The task is no longer selected by default.
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
