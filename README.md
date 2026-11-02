# Curatare

Curatare (Romanian *Curățare* = Cleaning) is a native, high-assurance macOS system cleaner, library orphan auditor, application and plugin uninstaller, developer & AI cache cleaner, interactive disk usage analyzer, and system maintenance studio. Designed for macOS 26 (Tahoe) and later, it is written in **Swift 6.2** with **SwiftUI (Liquid Glass)** as a universal binary (`arm64` + `x86_64`).

Curatare shares its architectural foundation, safety standards, and native design language with its sibling apps: **Arhivar**, **Copiator**, and **Descarcator**.

---

## Three Core Pillars

1. **Embedded Mole Engine (`tw93/mole`) & Self-Contained Maintenance:**
   - Bundles the complete **Mole** suite (`Contents/Resources/mole/mole`, shell plugins, libraries) along with native universal Mach-O helpers (`analyze-go` and `status-go`).
   - Updatable directly from GitHub (`tw93/Mole`) via **Settings › Mole Engine & Updates**, the menu bar extra, or the standalone `Mole-Guncelle.command` script.
2. **Library Leftovers Audit (5-Group `A`–`E` Methodology):**
   - **Dated-Trash-Only Rule (Never Permanent Delete):** No user files are ever removed permanently (`rm -rf` and `FileManager.removeItem` on user items are strictly prohibited). Items are safely relocated to timestamped folders under `~/.Trash/Curatare-YYYY-MM-DD-HHmmss/` preserving relative directory structure, backed by a `manifest.json` for one-click restoration.
   - **Strict Protection Invariant (`ProtectionRules`):** Absolute protection for Apple system components (`com.apple.*`, `group.com.apple.*`, `systemgroup.*`, `AddressBook`, `CloudDocs`, `Knowledge`), shared third-party frameworks (`Sparkle`, `Firebase`, `Crashlytics`, `Kingfisher`, `Segment`, `Keystone`, `install4j`), developer caches (`Gradle modules-2`, active `gradle-wrapper.properties` distributions, `NuGet`, `.pub-cache`, `Homebrew`, `ms-playwright*`, `swiftpm`, `.rustup`, `.konan`), active virtualization helpers (`com.vmware.*`, `com.parallels.*`, Claude `vm_bundles`), and active AI tool workspaces (`~/.codex`, `~/.gemini`, `.antigravity-ide`, `OptGuideOnDeviceModel`).
   - **5 Finding Groups (`A`–`E`):**
     - **Group A (Project & Test Traces):** `*Tests-<UUID>.plist`, `*Fuzz-<UUID>.plist`, and template identifier remnants.
     - **Group B (Dead Container Metadata):** `containermanagerd` metadata whose `application_bundle` path no longer exists on disk (preserving iOS `Wrapper/*.app` bundles and active git repositories).
     - **Group C (Bare CLI Remnants):** Leftover traces from `swift run` and bare binary executions without a bundle ID.
     - **Group D (Orphaned App Data):** Uninstalled app remnants across 11 key `~/Library` directories that do not match any installed app or 3-component root prefix.
     - **Group E (Services & System Orphans):** Broken `LaunchAgents`/`LaunchDaemons` whose target binary is missing, plus orphaned `/Library` system receipts with safe, copyable single-line `sudo` script generation ending with `echo TAMAM`.
3. **Application Uninstaller & SmartDelete (`TrashWatcher`):**
   - Browse Applications, Widgets, and Plugins (PreferencePanes, QuickLook, Internet Plug-Ins, Screen Savers, Spotlight Importers, Audio Components).
   - Drag-and-drop any bundle into the app window or Dock icon to inspect every associated container, cache, preference, and support file with live file sizes and granular checkboxes.
   - **SmartDelete:** Watches `~/.Trash` in the background to detect when an application is moved to the Trash in Finder, prompting to clean up leftover Library items.

---

## Key Features

- **Studio Sections:**
  - **Library Leftovers:** 5-group audit (`A`–`E`) with group filtering, path search, and batch selection.
  - **Application Uninstaller:** Inspect and safely uninstall applications, widgets, and plugins.
  - **Dev & AI Cleanup:** Scan GitHub repository build artifacts (`build/`, `DerivedData/`, `.build/`, `target/`, `dist/`, `.next/`, `node_modules/`) with tracked git file protection, Ollama models, and AI developer CLI footprints.
  - **Heavy Caches & Time Machine:** Inspect browser site data (`IndexedDB`, `File System`), messaging cache blocks, and thin local Time Machine snapshots.
  - **Disk Space Analyzer:** Interactive sunburst and hierarchical disk visualization powered by `analyze-go`.
  - **System Status & Maintenance:** Real-time CPU, RAM, battery, temperature, network, and disk health metrics powered by `status-go`, with one-click safe system optimization tasks.
  - **Trash History & Restore:** View all past Curatare cleanup batches, inspect manifests, and restore any batch back to its original location with a single click.
- **Process Isolation & Safety:** External CLI helpers run in a dedicated `sandbox-exec` kernel sandbox profile denying access to credentials (`~/.ssh`, `~/.aws`, `~/.gnupg`, `~/Library/Keychains`).
- **Running-Process Guard:** Prevents moving data belonging to currently running applications.
- **Trilingual Localization:** 100% native Turkish (default), English, and Romanian catalogs across all interfaces, notifications, and menus.
- **Console-Style Log Window:** Real-time log console (⌥⌘L) mirroring events to Apple Unified Logging (`os_log`).

---

## Installation

**Requires:** macOS 26 (Tahoe) or later. Universal binary for Apple Silicon (`arm64`) and Intel (`x86_64`).

1. Download the latest `Curatare-<version>.dmg` from the [Releases](https://github.com/berkbb/curatare-mac-universal/releases) page.
2. (Optional) Verify the SHA-256 checksum:
   ```bash
   shasum -a 256 -c SHA256SUMS.txt
   ```
3. Open `Curatare-<version>.dmg` and drag **Curatare** to your **Applications** folder.
4. **First Launch:** Curatare is ad-hoc signed. On first launch, macOS Gatekeeper may show a notice:
   - Click **Done**.
   - Navigate to **System Settings › Privacy & Security**, scroll down, and click **Open Anyway** next to the Curatare prompt.
   - Alternatively, remove the quarantine attribute in Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/Curatare.app
     ```
5. Finder Service Integration: Right-click any `.app` in Finder and select **Quick Actions › Clean Uninstall with Curatare** (or enable it in System Settings › Keyboard › Keyboard Shortcuts › Services › Files and Folders).

---

## Development

Double-click in Finder:

- **`Paketle.command`**: Runs tests, compiles the universal `build/Curatare.app`, and packages `dist/Curatare-<version>.dmg` along with `SHA256SUMS.txt`.
- **`Mole-Guncelle.command`**: Updates `Vendor/mole` and `build/Curatare.app` to the latest Mole release from GitHub.
- **`Yayimla.command`**: Validates the repository state, shows a dry-run preview, asks for confirmation, and creates a tagged release on GitHub Releases.

Command-line workflows:

```bash
# Update embedded Mole engine from GitHub
./Scripts/update-mole.sh install

# Run the test suite
swift test

# Build universal Curatare.app and verify bundle integrity
./Scripts/build_app.sh
./Scripts/verify_bundle.sh build/Curatare.app

# Create distribution DMG package under dist/
./Scripts/package.sh
```

---

## License & Third-Party Notices

Curatare is licensed under the **GNU General Public License v3.0 or later** ([GPL-3.0-or-later](LICENSE)).

- **Mole:** © Tw93 and contributors, licensed under the GNU General Public License v3.0 ([github.com/tw93/mole](https://github.com/tw93/mole)).
- **Arhivar & Copiator (derived components):** © Babadogan Tech and Edu, licensed under the MIT and GPL-3.0-or-later licenses.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for full license texts and attributions.
