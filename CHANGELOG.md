# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-31

### Added
- **Embedded Mole Engine (`tw93/mole`) & GitHub Updater (`Scripts/update-mole.sh`, `Mole-Guncelle.command`):** Integrated `mole` CLI scripts and universal (`arm64` + `x86_64`) `analyze-go` / `status-go` Mach-O helpers.
- **Library Leftovers Audit (5 Groups `A`–`E`):** Detection of iOS `Wrapper/*.app` containers, 3-component root prefix matching, dead `containermanagerd` project metadata resolution, broken `LaunchAgents`/`LaunchDaemons`, and safe copyable single-line `sudo` generator ending with `echo TAMAM`.
- **Dated Trash Service (`DatedTrashService`) & One-Click Restore:** Safe relocation to `~/.Trash/Curatare-YYYY-MM-DD-HHmmss/` without permanent deletion (`rm -rf` prohibited), supported by `manifest.json` for one-click batch restoration.
- **Application Uninstaller & SmartDelete (`TrashWatcher`):** Scans Applications, Widgets, and Plugins with drag-and-drop support, Finder Services integration, and real-time `~/.Trash` monitoring for dragged apps.
- **Extended Scanners (`ExtendedScanners`):** GitHub project build artifact detection with tracked git file protection, AI tool and Ollama model audit, browser `IndexedDB` and `File System` caches, and local Time Machine snapshot thinning.
- **Trilingual Localization (`tr`, `en`, `ro`):** Complete 1:1 localization parity across Turkish, English, and Romanian.
- **Process Isolation & Sandbox:** Child process execution protected by `sandbox-exec` kernel sandbox profiles and `ChildProcessGuard`.
