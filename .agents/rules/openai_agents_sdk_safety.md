# OpenAI Agents SDK Guardrails & Tool Safety Standard (`openai_agents_sdk_safety.md`)

> **Upstream Source:** <https://github.com/openai/openai-agents-python> (Successor of the retired Swarm)
> **Version / Date:** 2026 Stable
> **Last Reviewed:** 2026-10-31
> **Change Summary:** Applied input/output guardrails to tool invocations and external process execution (`CommandRunner`, `ProtectionRules`, `DatedTrashService`).

---

## Core Requirements

1. **Pre-Execution Tripwires:** Every destructive or state-changing tool call must pass `ProtectionRules.evaluate(...)` and running-process checks (`NSRunningApplication` / `pgrep`) before touching disk.
2. **Post-Execution Validation:** Verify that staged items exist at their destination inside `~/.Trash/Curatare-...` before recording completion in `TrashBatchManifest`.
