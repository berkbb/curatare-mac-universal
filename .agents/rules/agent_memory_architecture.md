# TencentDB Agent Memory Architecture Standard (`agent_memory_architecture.md`)

> **Memory Category:** Master Protocol Rule
> **Upstream Source:** <https://github.com/TencentCloud/TencentDB-Agent-Memory> (MIT)
> **Version / Date:** v2.0.0 (the README gives no release date)
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: added this header and the upstream definitions; tier names now match upstream (`L0 Conversation`, `L1 Atom`, `L2 Scenario`, `L3 Core / Persona`). Earlier undated version: four assets and L0–L3 tiers mapped to `Curatare` files.
> **Scope:** Four Memory Assets (Chat Memory, Skill, LLM-Wiki, Code-Graph) and L0–L3 Memory Tiers.

---

## 1. Upstream Summary

- TencentDB Agent Memory is a team-level memory hub for AI agents that turns conversations, docs, and code into four reusable memory assets: **Chat Memory** (preferences, facts, decisions, interaction history), **Skill** (reusable expertise with versions, resource files, trigger boundaries, execution steps, and validation rules), **Wiki / LLM-Wiki** (docs, specs, and runbooks as structured, linked pages), and **CodeGraph / Code-Graph** (code symbols, files, call relationships, and impact paths).
- Chat Memory is layered: **L0 Conversation** (raw conversations with full context), **L1 Atom** (facts, preferences, constraints, and events extracted from them), **L2 Scenario** (knowledge blocks organized around projects or scenarios), **L3 Core / Persona** (long-term profiles, stable patterns, high-level cognition).
- `Curatare` uses the layout as a file convention only; it does not run the Memory Core, Proxy, Panel, or Hub services.

## 2. Four Memory Assets in `Curatare`

1. **Chat Memory:** Session context and user intent logs.
2. **Skill (`skills/`):** Executable validation, engine update, and bundle verification procedures (format: `agent_skills_specification.md`).
3. **LLM-Wiki (`context/domain_wiki.md`):** Domain rules (`library_clean.md`), Mole CLI contracts, and uninstaller workflows.
4. **Code-Graph (`context/code_graph_wiki.md`):** Symbols, module dependencies, and impact paths, regenerated from Graphify (`graphify_knowledge_graph.md`).

## 3. Four-Tier Hierarchy (L0–L3) in `Curatare`

The global `CLAUDE.md` extends the upstream conversation tiers to project state; this repository follows that mapping:

- **L0 Conversation / Execution Logs:** Execution traces and `AppLog` entries.
- **L1 Atom:** `AppSettings` keys, `ProtectionRules` patterns, and `EngineLocator` search paths.
- **L2 Scenario:** `AppModel` runtime states, scan results, and `TrashBatchManifest` records.
- **L3 Core / Persona:** `.agents/AGENTS.md` constitutional invariants and `user_rejected_spec.md`.
