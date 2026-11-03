# GitHub Spec Kit — Spec-Driven Development (SDD) Standard (`github_spec_kit.md`)

> **Memory Category:** Master Protocol Rule
> **Upstream Source:** <https://github.com/github/spec-kit> (README, `CHANGELOG.md`, and releases; CLI package `specify-cli`, installed with `uv tool install specify-cli`)
> **Version / Date:** Spec Kit 1.2.6 (2026-11-02)
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: added this header; the lifecycle now includes `clarify`, `checklist`, and `analyze`; recorded the bundled `github` extension (1.0.13), the deprecation of the core `taskstoissues` command (1.1.3; the global `CLAUDE.md` says 1.1.0, the CHANGELOG says 1.1.3), the bundled `bug` and `assess` extensions, bundles, and workflow gates. Earlier undated version: six-phase lifecycle mapped to `Curatare` modules.

---

## 1. Upstream Summary

- **Core SDD commands (README):** `/speckit-constitution`, `/speckit-specify`, `/speckit-plan`, `/speckit-tasks`, `/speckit-implement`, `/speckit-converge`.
- **Supporting commands (CHANGELOG):** `clarify` refines the spec before planning, and the spec quality checklist is re-validated after it (0.8.16); `checklist` runs after `plan` (0.11.8); `analyze` checks consistency (0.11.3).
- **Bundled extensions:** `bug` (0.9.5; `specify extension add bug`; `/speckit-bug-assess`, `/speckit-bug-fix`, `/speckit-bug-test`), `assess` (0.13.0; `specify extension add assess`; `/speckit-assess-intake`, `-research`, `-define`, `-shape`, `-decide`), and `github` for turning tasks into issues (1.0.13). The core `taskstoissues` command is deprecated since 1.1.3.
- **Bundles, presets, workflows:** bundles package extensions, presets, and workflows for a role (first-party `bugfix` and `assess` bundles since 1.0.9). Workflows (`workflow.yml`) automate prompts, commands, gates, and shell tasks. A gate step rejects with `abort`, `skip`, or `retry` (0.15.2), and an interrupted gate prompt does not approve the gate (1.1.2).

## 2. Lifecycle Protocol for `Curatare`

1. **Constitution:** Enforce `.agents/AGENTS.md` invariants (Dated-Trash-Only, Protection Rules, Running-Process Guard, Sandbox Isolation, Trilingual Parity).
2. **Specify & Clarify:** Map user requirements (`Mole` + `library_clean.md` + uninstaller + GitHub Mole updater) to concrete `CuratareCore` and `Curatare` modules, and settle open questions with the user before planning.
3. **Checklist:** Before planning, confirm the spec covers `tr`/`en`/`ro` keys, the protection list, Dated Trash, and the running-process guard.
4. **Plan, Tasks & Analyze:** Name real symbols from `.agents/context/code_graph_wiki.md`, order tasks test-first, and check spec, plan, and code agree before implementing.
5. **Implement & Converge:** Verify with `swift test`, `./Scripts/build_app.sh`, and `./Scripts/verify_bundle.sh`.
6. **Review Gates:** A gate between spec, plan, and implementation needs the user's explicit verdict; a skipped or interrupted gate counts as not approved.
7. **Issues:** Create GitHub issues from tasks only through the `github` extension, never the deprecated core `taskstoissues`, and only after the user approves (it publishes).
8. **Tooling:** This repository has no `.specify/` directory; agents follow the lifecycle by hand. Installing `specify-cli` or running `specify init` needs the user's approval.
