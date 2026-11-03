# LangChain/LangGraph 1.x Cyclic State Machine Standard (`langgraph_state_machine.md`)

> **Upstream Source:** <https://github.com/langchain-ai/langgraph> (official docs: <https://docs.langchain.com/oss/python/langgraph/graph-api>, <https://docs.langchain.com/oss/python/langgraph/persistence>)
> **Version / Date:** GitHub release `langgraph==1.2.19` (2026-10-30)
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption at the user's request. Applies explicit state, bounded loops, and resumable checkpoints to how coding agents work on this repository and to the app's own documented state graph. `Curatare` ships no LangGraph runtime.

---

## Upstream Summary

- LangGraph is an MIT-licensed "low-level orchestration framework and runtime for building, managing, and deploying long-running, stateful agents". It can be used without LangChain.
- A graph has a shared **State** (a `TypedDict`, Pydantic model, or dataclass schema, with one reducer per key), **nodes** that do the work, and normal or conditional **edges** that pick the next node. Graphs can loop, run in super-steps, and must be compiled before use.
- The recursion limit caps super-steps per run (default 10,007 since 1.1.4); hitting it raises `GraphRecursionError`.
- Checkpointers persist a thread's graph state as checkpoints, which the docs tie to human-in-the-loop workflows, time travel, and fault tolerance. Durable execution lets agents resume from where they left off after failures.

## Core Requirements

1. **The App's State Graph Is Explicit:** The scan, review, process-check, Dated Trash, and restore flow is documented in `.agents/context/symbolic_memory_graph.md`. A change that adds or removes a transition updates that graph in the same change.
2. **Agent State Is Written Down:** An agent keeps its plan, the files it touched, and the last test result as explicit state (task list or handoff note), so another session can resume without guessing.
3. **Loops Are Bounded:** The edit–test cycle stops after three consecutive failures on the same issue; the agent reverts unstable edits and asks the user (3-Strike Rule).
4. **Interrupt Before Side Effects:** Like a human-in-the-loop interrupt, the loop pauses for user approval before commits, pushes, releases, or any move into `~/.Trash`.
5. **Know the Restore Point:** Before a multi-file change, check `git status` so the prior state is known; commit only when the user asks.
