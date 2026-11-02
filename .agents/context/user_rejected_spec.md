# User-Rejected Specifications & Redlines — Curatare

> **Memory Category:** TencentDB L3 Persona & Redline Asset
> **Scope:** Permanently banned behaviors and anti-features.

---

## 1. Permanent Deletion (`rm -rf` / Direct Unlink) is Strictly Prohibited
- **Rule:** Never permanently delete user files, Library leftovers, application bundles, or build caches during cleanup. Every cleanup action must move items into a dated folder inside `~/.Trash/Curatare-YYYY-MM-DD-HHmmss/` so the user can inspect or restore them before emptying the Trash manually.

## 2. Touching Protected System, Shared Framework, VM, or Active AI State is Prohibited
- **Rule:** Never flag or move items on the `library_clean.md` Do-Not-Touch list (`com.apple.*`, shared frameworks like `Sparkle`/`Firebase`/`Kingfisher`, active Gradle/NuGet/pub/rustup/playwright/Homebrew toolchains, VMware/Parallels/Claude VM bundles, or active `~/.codex` / `~/.gemini` / `.antigravity-ide` state).

## 3. Silent Background Privilege Escalation is Prohibited
- **Rule:** Never prompt for or cache root passwords in the background. For `/Library` system orphans, system `LaunchDaemons`, and `pkgutil --forget`, generate a transparent, inspectable one-line `sudo` command ending with `echo TAMAM` that moves `/Library` items into the dated `~/.Trash` folder and restores user ownership (`chown -R $(id -un):staff`), allowing the user to review and run it in Terminal.

## 4. Explicit Mentions of Third-Party Proprietary Uninstallers are Strictly Prohibited
- **Rule:** Never mention third-party proprietary uninstaller names anywhere in the application interface, localization strings, user-facing notices, codebase comments, tests, or documentation. Refer to the capability strictly as native Application Uninstaller (`Uygulama Kaldırıcı`) & SmartDelete.

## 5. Explicit Mentions of Third-Party Proprietary Maintenance Utilities are Strictly Prohibited
- **Rule:** Never mention third-party proprietary maintenance utilities or benchmark tool names anywhere in the application interface, localization strings, user-facing notices, codebase comments, tests, transcripts, or documentation. Refer to such tools generically as "benchmark utility", "reference system maintenance tool", or "industry maintenance baseline".
