# Snapshot & Trash Batch Audit Skill

> **Memory Category:** TencentDB Procedural Memory (Skill Asset)
> **Trigger:** When auditing `TrashBatchManifest` backward compatibility or `ProtectionRules` regression coverage.

---

## 1. Procedure

1. Run `swift test --filter DatedTrashTests` to verify that dated trash manifests (`trash-batches.json`) round-trip cleanly and restore every file to its original path without overwriting newer existing files unless confirmed.
2. Run `swift test --filter ProtectionRulesTests` and `swift test --filter LibraryScannerTests` to verify that every protected prefix, shared framework, active dev toolchain, VM helper, and iOS Wrapper app in `library_clean.md` is never flagged as an orphan.
