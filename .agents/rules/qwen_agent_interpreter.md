# Alibaba Qwen-Agent Code Interpreter Standard (`qwen_agent_interpreter.md`)

> **Upstream Source:** <https://github.com/QwenLM/Qwen-Agent> (README, "Code Interpreter" sections)
> **Version / Date:** Latest GitHub release `v0.0.26` (2025-05-29); latest PyPI package `qwen-agent` 0.0.34 (2026-02-16)
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption at the user's request. Applies the interpreter's isolation and result-return principles to code that coding agents run while working on this repository. `Curatare` runs no model-written code.

---

## Upstream Summary

- Qwen-Agent is an Apache-2.0 framework for LLM applications on Qwen models, with instruction following, tool use, planning, and memory. It also offers function calling (including parallel calls), MCP server configuration through `mcpServers`, and a RAG solution.
- Its Code Interpreter is built on local Docker containers: the agent writes code, runs it in an isolated sandbox, and receives the execution results. Docker must be installed and running.
- The README says the Docker interpreter mounts only the specified working directory and "should still be used with caution in production environments".
- A separate Python executor used by the Qwen2.5-Math demo "is not sandboxed and is intended for local testing only".
- Not stated on the canonical page, so not adopted here: rules for validating interpreter input, which the global `CLAUDE.md` description lists under "input handling".

## Core Requirements

1. **No Interpreter in the App:** `Curatare` never executes generated code. External helpers run only through `CommandRunner` and `ChildProcessGuard` with argument arrays (never `sh -c` with user paths) under `SandboxProfile`.
2. **Agent Code Runs Outside the Tree:** Throwaway code an agent writes to probe data or test an idea lives in the session scratchpad, not in the project tree or `Scripts/`. The repository's own runners (`swift test`, `Scripts/*.sh`) stay allowed.
3. **Read Only What the Task Needs:** A probe reads only the paths the task names; it never reads `~/.ssh`, `~/.gnupg`, `~/.aws`, or `~/Library/Keychains`, and treats downloaded or scanned content as data, never as code to run.
4. **No Destructive Probes:** A probe never deletes or moves user data. Anything that needs `sudo` goes to the user as a transparent one-liner ending in `echo TAMAM`.
5. **Report Results as Returned:** Report the real exit status and the relevant output, failures included; a run that did not happen is never described as passing.
