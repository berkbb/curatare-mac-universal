# Roadmap & SOTA Checklist — Curatare

> **Memory Category:** TencentDB Knowledge Asset
> **Scope:** Delivered v1.0 capabilities and planned future milestones.

---

## 1. Delivered in v1.0

- [x] **Universal macOS 26 Liquid Glass App (`arm64` + `x86_64`)** with Swift 6.2 strict concurrency.
- [x] **Bundled Mole Engine (`Vendor/mole/`) & GitHub Updater (`Scripts/update-mole.sh`, `Mole-Guncelle.command`)** with universal (`arm64` + `x86_64`) `analyze-go` and `status-go` binaries.
- [x] **`library_clean.md` 5-Group Library Audit (`A`–`E`)**:
  - [x] Step 1: Deep installed bundle ID index (including iOS `Wrapper/*.app`, PreferencePanes, QuickLook, LaunchServices, Caskroom, LaunchAgents/Daemons).
  - [x] Step 2 (Group D): 11-folder `~/Library` reverse-DNS orphan detection with 3-component root matching.
  - [x] Step 3 (Group B): Dead `containermanagerd` project container detection.
  - [x] Step 4 (Group C) & Group A: Bare-named `swift run` traces and test/template plists.
  - [x] Steps 5 & 6 (Group E): Dead `LaunchAgents`/`LaunchDaemons`, `/Library` system orphans, orphaned `pkgutil` receipts, and safe copyable `sudo` one-liner ending in `echo TAMAM`.
- [x] **Dated-Trash-Only Cleanup (`DatedTrashService`)** with manifest persistence and 1-click **Restore (`Geri Yükle`)**.
- [x] **Strict Protection Rules (`ProtectionRules`)** & `pgrep` running-process checks.
- [x] **Application Uninstaller (`AppUninstaller` & `TrashWatcher` SmartDelete)** across Applications, Widgets, and Plugins + drag-and-drop + Finder Service.
- [x] **Extended Scanners**: GitHub ignored build outputs (with tracked-file check), AI tool footprint & Ollama models, Browser IndexedDB / heavy app caches, `.dmg`/`.pkg` installer finder, universal binary slimmer, and Time Machine local snapshot inspector/thinner.
- [x] **Interactive Disk Analyzer (`analyze-go`) & Live System Status Monitor (`status-go` + `MenuBarExtra`)**.
- [x] **Complete Trilingual Localization (`tr`, `en`, `ro`)**, Ed25519 DMG signing, and comprehensive Swift Testing suites.

## 2. Future Milestones (Post-v1.0)

_No open milestones. Add new items only after a codebase audit and a check against `user_rejected_spec.md`._

**Direction (user decision, 04.11.2026):** Curatare already covers enough ground. Prefer deepening, simplifying and hardening existing features over adding new tabs or feature areas.
