# Domain Rules Index & Governance Structure Standard (`about_rules.md`)

> **Scope:** Index of project-relevant domain rules and core standards in `.agents/rules/` for `Curatare` (Zero Static Bloat policy: only standards directly applicable to this native macOS cleaner/uninstaller are kept).
> **Last Reviewed:** 2026-10-31

---

## 1. Active Rule Files in `.agents/rules/`

| Rule File | Upstream / Standard | Relevance to `Curatare` |
| :--- | :--- | :--- |
| `about_rules.md` | Governance Index & Standard Maintenance Rules (1–8) | Tracks versioning, review dates, and scope boundaries. |
| `agent_memory_architecture.md` | TencentDB-Agent-Memory (`TencentCloud/TencentDB-Agent-Memory`) | 4 Memory Assets (`Chat Memory`, `Skill`, `LLM-Wiki`, `Code-Graph`) & L0–L3 tiers. |
| `github_spec_kit.md` | GitHub Spec Kit (`github/spec-kit`, SDD v1.2.x) | Spec-Driven Development lifecycle and verification gates. |
| `graphify_knowledge_graph.md` | Graphify Labs (`Graphify-Labs/graphify`, `graphifyy`) | Local AST knowledge graph (`.graphifyrc`, `.graphifyignore`, `code_graph_wiki.md`). |
| `constitutional_principles.md` | Anthropic Claude Constitution (January 2026 revision) | Reasoning-based alignment: Dated-Trash-only reversibility (`rm -rf` ban) and user autonomy. |
| `openai_agents_sdk_safety.md` | OpenAI Agents SDK Guardrails & Tool Safety | Pre-execution tripwires (`ProtectionRules`, `NSRunningApplication`/`pgrep` running-process guard) and post-staging manifest checks. |
| `meta_purple_llama_safety.md` | Meta Purple Llama Agentic Safety | Credential firewall (`~/.ssh`, `~/.gnupg`, `~/.aws`, `~/Library/Keychains`), `SandboxProfile`, and symlink escape prevention. |
| `owasp_agentic_security.md` | OWASP Top 10 for Agentic Applications (ASI 2026) | Zero shell injection (`CommandRunner`), explicit `sudo` one-liner escaping, and supply-chain verification (`update-mole.sh`). |
| `apple_app_intents_agent.md` | Apple App Intents & Native macOS Security | 100% on-device execution and safe Finder `NSServices` (`FinderService`) integration. |
| `math_rules.md` | Mathematical & Storage Unit Invariants | Base-10 (`ByteCountFormatter` `.file`) byte arithmetic and deterministic disk space calculations. |
| `ui_rules.md` | macOS 26 Liquid Glass & Trilingual (`tr`/`en`/`ro`) UI Rules | 1:1 localization parity (`LKey`), anti-hardcoding, and hierarchical `Table` `@Environment` safety. |

---

## 2. Standard Maintenance Rules

1. **Versioning:** Every standard file records its upstream source, version/publication date, last review date (`2026-10-31`), and change summary.
2. **Zero Static Bloat:** Unrelated standards (e.g. cloud commerce protocols `ACP`/`AP2`/`UCP`, Python multi-agent chat frameworks, or sovereign country laws) are excluded from `.agents/rules/`.
3. **Conflict Resolution:** When rules conflict, safety (`ProtectionRules` and `DatedTrashService`), human oversight, and `.agents/AGENTS.md` take precedence.
