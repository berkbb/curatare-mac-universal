# TencentDB Agent Memory Architecture Standard

> **Memory Category:** Master Protocol Rule
> **Scope:** Four Memory Assets (Chat Memory, Skill, LLM-Wiki, Code-Graph) and L0–L3 Memory Tiers.

---

## 1. Four Memory Assets

1. **Chat Memory:** Session context and user intent logs.
2. **Skill (`skills/`):** Executable validation, engine update, and bundle verification procedures.
3. **LLM-Wiki (`context/domain_wiki.md`):** Domain rules (`library_clean.md`), Mole CLI contracts, and uninstaller workflows.
4. **Code-Graph (`context/code_graph_wiki.md`):** Symbol hierarchy and module dependencies.

## 2. Four-Tier Hierarchy (L0–L3)

- **L0:** Execution traces and `AppLog` entries.
- **L1:** `AppSettings` keys, `ProtectionRules` patterns, and `EngineLocator` search paths.
- **L2:** `AppModel` runtime states, scan results, and `TrashBatchManifest` records.
- **L3:** `.agents/AGENTS.md` constitutional invariants and `user_rejected_spec.md`.
