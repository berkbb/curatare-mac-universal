# Mistral AI Function Calling & Agents API Standard (`mistral_function_calling.md`)

> **Upstream Source:** <https://docs.mistral.ai/capabilities/function_calling/> (Agents API: <https://docs.mistral.ai/agents/introduction>)
> **Version / Date:** Undated documentation pages (footer "Mistral AI © 2026"), content as read on 2026-11-03
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption at the user's request. Applies the function-calling contract (the model proposes, the developer executes) to how coding agents treat tool calls and external tool contracts in this repository. `Curatare` makes no model calls.

---

## Upstream Summary

- Function calling has five steps: the developer defines tools, the user asks, the model generates function arguments, the developer executes the function, and the model answers from the result. The model may chain another tool call before answering.
- Each tool is a JSON object with `"type": "function"` and a `function` block holding `name`, `description`, and a JSON Schema `parameters` object with `properties` and `required`.
- The docs say "the function execution lies on the user/developer side"; the model does not run the function itself.
- `tool_choice` is `auto` (default), `any` (forces tool use), or `none`. `parallel_tool_calls` defaults to `true`; `false` forces single calls. Results go back as a `role: "tool"` message with the function `name`, `content`, and a `tool_call_id` matching the call's `id`.
- The Agents API adds built-in connector tools (code execution, web search, image generation, document library), persistent conversations, and handoffs that let agents call other agents.

## Core Requirements

1. **Proposals Are Not Executions:** `Curatare` has no model tool binding. For coding agents, a planned tool call is a proposal; deletions, moves into `~/.Trash`, and privileged commands stay with the user (Dated-Trash-only rule, transparent `sudo ... && echo TAMAM` one-liners).
2. **External Contracts Are Checked:** The Mole CLI flags and the `status-go --json` and `analyze-go --json` shapes that `MoleBridge` decodes are this repository's tool contracts. After `Scripts/update-mole.sh` brings a new Mole version, check them against `Vendor/mole` or a read-only run, never from memory.
3. **Every Result Traces to Its Call:** Each reported outcome names the command or test that produced it, the way `tool_call_id` ties a result to its call.
4. **Parallel Calls Only for Independent Work:** Run tool calls in parallel only when they are independent reads; dependent edits and checks run in order.
