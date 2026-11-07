# Mistral AI Function Calling, Agents SDK & Managed Agents Standard (`mistral_function_calling.md`)

> **Upstream Source:** <https://docs.mistral.ai/capabilities/function_calling/> (Agents SDK `mistralai-agents` and Managed Agents, public preview: <https://docs.mistral.ai/studio/agents/overview>; migration guide: <https://docs.mistral.ai/studio/agents/getting-started/from-agents-api>; the former Agents and Conversations API (`client.beta.agents`) is deprecated: <https://docs.mistral.ai/studio/agents/deprecated/overview>)
> **Version / Date:** Undated documentation pages (footer "Mistral AI © 2026"), content as read on 2026-11-06; Managed Agents and the Agents SDK are marked public preview
> **Last Reviewed:** 2026-11-07
> **Change Summary:** 2026-11-07: brought in line with Descarcator's 2026-11-06 source check (no new fetch): the function calling page is unchanged (five steps, tool format, `tool_choice`, `parallel_tool_calls`, `role: "tool"` results), but the agents documentation now describes the Agents SDK (`mistralai-agents`) and Managed Agents in public preview, the migration guide says the Agents SDK replaces the Agents and Conversations API, and the former Agents API overview sits in a deprecated section; the title, the upstream sources and the Agents API bullet were rewritten to match; the Core Requirements are unchanged. 2026-11-03: initial adoption at the user's request. Applies the function-calling contract (the model proposes, the developer executes) to how coding agents treat tool calls and external tool contracts in this repository. `Curatare` makes no model calls.

---

## Upstream Summary

- Function calling has five steps: the developer defines tools, the user asks, the model generates function arguments, the developer executes the function, and the model answers from the result. The model may chain another tool call before answering.
- Each tool is a JSON object with `"type": "function"` and a `function` block holding `name`, `description`, and a JSON Schema `parameters` object with `properties` and `required`.
- The docs say "the function execution lies on the user/developer side"; the model does not run the function itself.
- `tool_choice` is `auto` (default), `any` (forces tool use), or `none`. `parallel_tool_calls` defaults to `true`; `false` forces single calls. Results go back as a `role: "tool"` message with the function `name`, `content`, and a `tool_call_id` matching the call's `id`.
- Managed Agents and the Agents SDK (`mistralai-agents`, public preview, so the API and limits may change) run an agent on its own for long periods in a stateful session that keeps every message, tool call, and result; after a crash, a turn continues from its last finished model or tool call.
- The migration guide says the Agents SDK replaces the Agents and Conversations API (`client.beta.agents`, `client.beta.conversations`): an agent becomes an `agents.Agent` object in the caller's process, conversations become sessions, handoffs become subagents (`agents.Subagent`), connectors are added by name, code execution uses `agents.MistralSandbox()`, and tool approval is set with `permission_mode` or `permission_policy`.
- The earlier Agents API overview (built-in code execution, web search, image generation, and document library tools, persistent conversations, and handoffs between agents) is kept in a deprecated section for existing integrations; no removal date is given.

## Core Requirements

1. **Proposals Are Not Executions:** `Curatare` has no model tool binding. For coding agents, a planned tool call is a proposal; deletions, moves into `~/.Trash`, and privileged commands stay with the user (Dated-Trash-only rule, transparent `sudo ... && echo TAMAM` one-liners).
2. **External Contracts Are Checked:** The Mole CLI flags and the `status-go --json` and `analyze-go --json` shapes that `MoleBridge` decodes are this repository's tool contracts. After `Scripts/update-mole.sh` brings a new Mole version, check them against `Vendor/mole` or a read-only run, never from memory.
3. **Every Result Traces to Its Call:** Each reported outcome names the command or test that produced it, the way `tool_call_id` ties a result to its call.
4. **Parallel Calls Only for Independent Work:** Run tool calls in parallel only when they are independent reads; dependent edits and checks run in order.
