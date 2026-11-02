# OWASP Top 10 for Agentic Applications Standard (`owasp_agentic_security.md`)

> **Upstream Source:** <https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/> (ASI 2026 Edition, published 2025-12-09)
> **Version / Date:** ASI 2026
> **Last Reviewed:** 2026-10-31
> **Change Summary:** Applied ASI02 (Tool Misuse), ASI03 (Identity & Privilege Abuse), ASI04 (Supply Chain), and ASI05 (Unexpected Code Execution) safeguards to `Curatare` process execution, Mole updater, and `sudo` command generation.

---

## Core Requirements

1. **ASI02 & ASI05 — Zero Shell Injection:** `CommandRunner` executes binaries directly with explicit `[String]` argument arrays; `LibraryScanner.generateSudoOneLiner` shell-escapes every single path with single-quote escaping (`'\''`).
2. **ASI03 — Least Privilege & Explicit Elevation:** `Curatare` runs as a standard user process with `SandboxProfile` (`sandbox-exec`) available for helper binaries and never silently escalates privileges.
3. **ASI04 — Supply Chain Verification:** `Scripts/update-mole.sh` fetches `tw93/mole` release assets over HTTPS from official GitHub releases and verifies universal Mach-O architectures (`lipo -archs`) and code signatures (`codesign --verify --deep --strict`).
