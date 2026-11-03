# Domain Rules Index & Governance Structure Standard (`about_rules.md`)

> **Scope:** Index of project-relevant domain rules and core standards in `.agents/rules/` for `Curatare` (Zero Static Bloat policy: only standards directly applicable to this native macOS cleaner/uninstaller are kept).
> **Last Reviewed:** 2026-11-03

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
| `model_context_protocol.md` | Model Context Protocol (specification revision 2026-07-28) | MCP tool output is data, consent before side effects, no user data to MCP servers; the app itself stays MCP-free. |
| `agent_skills_specification.md` | Agent Skills Specification (`agentskills.io`) | `SKILL.md` layout for new skills in `.agents/skills/`; existing flat skill files stay until the user asks to migrate. |
| `react_agent_methodology.md` | ReAct (Yao et al., arXiv:2210.03629, ICLR camera-ready v3) | Observe before editing scanners and protection rules; check Mole and system tool contracts by acting; replan on contradiction. |
| `retrieval_augmented_generation.md` | RAG (Lewis et al., arXiv:2005.11401, NeurIPS 2020) | Retrieve from the code graph, wikis, and `Vendor/mole` sources; cite provenance; source beats memory. |
| `apple_app_intents_agent.md` | Apple App Intents & Native macOS Security | 100% on-device execution and safe Finder `NSServices` (`FinderService`) integration. |
| `math_rules.md` | Mathematical & Storage Unit Invariants | Base-10 (`ByteCountFormatter` `.file`) byte arithmetic and deterministic disk space calculations. |
| `ui_rules.md` | macOS 26 Liquid Glass & Trilingual (`tr`/`en`/`ro`) UI Rules | 1:1 localization parity (`LKey`), anti-hardcoding, and hierarchical `Table` `@Environment` safety. |

---

## 2. Standard Maintenance Rules

1. **Versioning:** Every standard file records its upstream source, version/publication date, last review date, and change summary.
2. **Zero Static Bloat:** Unrelated standards (e.g. cloud commerce protocols `ACP`/`AP2`/`UCP`, Python multi-agent chat frameworks, or sovereign country laws) are excluded from `.agents/rules/`.
3. **Conflict Resolution:** When rules conflict, safety (`ProtectionRules` and `DatedTrashService`), human oversight, and `.agents/AGENTS.md` take precedence.
4. **Reflexion:** The Reflexion standard (Shinn et al., arXiv:2303.11366) is served by `.agents/context/reflexion_memory_log.md`, not by a rule file.

---

## 3. Core Standards Not Adopted (reviewed 2026-11-03)

The user chose to keep this folder lean. The remaining Core Standards from the global `CLAUDE.md` were reviewed and not adopted. They either target an LLM runtime, agent framework, commerce flow, or agent UI protocol that `Curatare` does not have, or they repeat rules already covered here (Devin by `github_spec_kit.md`, Letta by `agent_memory_architecture.md`, Generative Agents by the Reflexion log, Chain-of-Thought by `react_agent_methodology.md`, OpenAI Model Spec by `constitutional_principles.md`): Microsoft Agent Framework, Alibaba Qwen-Agent, Mistral Function Calling, Cognition Devin, LangGraph, Stanford Generative Agents, Amazon Bedrock AgentCore, IBM Granite, CrewAI, AutoGPT Platform, Letta, CAMEL-AI, Stanford DSPy, MCP Apps Extension, MCP Enterprise-Managed Authorization, Agent2Agent (A2A), A2UI, AG-UI, OpenAI Model Spec, OpenAI Harmony, ACP, AP2, UCP, Arize OpenInference, Chain-of-Thought Prompting, Uber ADR, the Uber ADR paper, AAIF, and Hugging Face smolagents. Do not re-propose them unless the user asks or the app gains one of those capabilities.
