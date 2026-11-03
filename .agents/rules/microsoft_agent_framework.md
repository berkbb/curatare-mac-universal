# Microsoft Agent Framework Multi-Agent Orchestration Standard (`microsoft_agent_framework.md`)

> **Upstream Source:** <https://github.com/microsoft/agent-framework> (official docs: <https://learn.microsoft.com/en-us/agent-framework/overview/>)
> **Version / Date:** GitHub releases `python-1.24.0` and `dotnet-1.27.0` (both 2026-10-30); Learn overview page `ms.date` 2026-10-23
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption at the user's request. Applies the framework's handoff and human-in-the-loop principles to coding agents and sessions working on this repository. `Curatare` itself ships no agent framework.

---

## Upstream Summary

- Microsoft Agent Framework is an open, multi-language framework for building production AI agents and multi-agent workflows. Python and .NET live in the main repository; the Go SDK lives in `microsoft/agent-framework-go` and the Learn docs mark it public preview.
- Workflows connect agents and functions through explicit execution paths, using graph-based patterns such as sequential, concurrent, handoff, and group collaboration. They support checkpointing, streaming, human-in-the-loop control, and time-travel, with OpenTelemetry tracing.
- The Learn docs advise a workflow when a process has well-defined steps or several agents must coordinate, and add: "If you can write a function to handle the task, do that instead of using an AI agent."
- The Learn docs call the framework the direct successor of Semantic Kernel and AutoGen, built by the same teams. The AutoGen README marks AutoGen archived and no longer maintained and sends new users here (the GitHub repository itself was not in archived state on 2026-11-03).
- The docs make builders responsible for reviewing data shared with third-party systems and for their own responsible AI mitigations.

## Core Requirements

1. **Functions Over Agents in the App:** `Curatare` ships no agents or workflows. Scanners, `ProtectionRules`, and `DatedTrashService` stay deterministic Swift code; adding an agent runtime needs an explicit user decision.
2. **Explicit Handoffs:** Work passed between sessions or subagents states the goal, the files touched, the latest `swift test` result, and what is not done or not verified. The receiver re-reads `.agents/AGENTS.md` and treats the sender's conclusions as unverified.
3. **One Writer per File:** Parallel agents get disjoint file scopes; two agents never edit the same file in one round.
4. **Human Approval at Side Effects:** Commits, pushes, `Scripts/release.sh`, Mole updates, and moves into `~/.Trash` pause for the user's approval; one approval does not cover the next action.
5. **Retired Names Stay History:** AutoGen is named only as history; new rules and docs reference Microsoft Agent Framework.
