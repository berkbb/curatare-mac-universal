# Graphify Labs Codebase Knowledge Graph Standard (`graphify_knowledge_graph.md`)

> **Upstream Source:** <https://github.com/Graphify-Labs/graphify> (PyPI: `graphifyy`)
> **Version / Date:** graphifyy 0.9.101 (installed with `uv tool install graphifyy`)
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: `.graphifyrc` rewritten in the `key=value` format that graphifyy actually parses (the earlier JSON file stopped every run); privacy moved to environment variables; `.graphifyignore` now excludes all of `Vendor/`; `graphify-out/` added to `.gitignore`; first code-only build regenerated `code_graph_wiki.md`; documented the privacy boundary (only code parsing is local), refresh after refactors, and the agent integration commands (project-scoped skill, per-platform installs, git hooks, `/graphify .`). 2026-10-31: standardized local tree-sitter AST extraction, `EXTRACTED` / `INFERRED` edge provenance, Leiden community detection, and synchronization with `.agents/context/code_graph_wiki.md`.

---

## 1. Core Principles

1. **Graph-First Code Navigation:** Agents turn the repository's code (Swift, shell, and Python via local tree-sitter AST) into a queryable knowledge graph with `EXTRACTED` and `INFERRED` edge provenance and Leiden community detection.
2. **Query Before Grep:** Query the knowledge graph (`graphify query`, `graphify path`, `graphify explain`, `graphify affected`) before broad search-style tool calls when `graphify-out/graph.json` is present.
3. **Artifact Sync:** Outputs live in `graphify-out/` (`graph.json`, `graph.html`, `GRAPH_REPORT.md`) and feed the Code-Graph Memory Asset (`.agents/context/code_graph_wiki.md`). `graphify-out/` is git-ignored and regenerable; never commit it.
4. **Privacy Boundary:** Only code parsing is local (tree-sitter, no LLM). A full build (`/graphify .` in an agent, or `graphify extract` without `--code-only`) sends docs, PDFs, and images to the host assistant's model or to the backend set by `GRAPHIFY_BACKEND`; use `GRAPHIFY_BACKEND=ollama` when that pass must stay local. This repository builds code-only and offline. Privacy is set through the environment, not `.graphifyrc`, which only accepts `viz_node_limit` and `language.<ext>=<language>`:
   ```bash
   GRAPHIFY_NO_TIPS=1 GRAPHIFY_QUERY_LOG_DISABLE=1 GRAPHIFY_BACKEND=off graphify extract . --code-only
   GRAPHIFY_BACKEND=off graphify cluster-only . --no-label
   ```
   `GRAPHIFY_BACKEND=off` stops graphify from auto-selecting an LLM backend from ambient API keys; `--no-label` keeps community naming local. Never enable the hosted Graphify platform unless the user asks for it.
5. **Ignore List Before the First Build:** `.graphifyignore` excludes build outputs, `graphify-out/`, `.claude/` worktrees, all of `Vendor/` (third-party Mole engine), and credential, member, or customer data patterns (`.secrets/`, `.env*`, keys, certificates, `*.csv`, `*.sql` dumps, `*.xlsx`).
6. **Refresh After Structural Changes:** After a refactor that adds, moves, or deletes types, run `graphify update .` (code only, no LLM; add `--force` when code was deleted), then `cluster-only` as above, and regenerate `code_graph_wiki.md`.

## 2. Agent Integration (not installed in this repository)

These commands write skill files, `CLAUDE.md` / `AGENTS.md` sections, or git hooks, so each one runs only after the user approves it:

- **Skill:** `graphify install --project` registers the skill for this project only; a global `graphify install` only when the user asks for it.
- **Per platform:** `graphify claude install` (`CLAUDE.md` section and `PreToolUse` hook), `graphify gemini install` (`GEMINI.md` section and `BeforeTool` hook), `graphify codex install` (`AGENTS.md` section), `graphify cursor install` (`.cursor/rules/graphify.mdc`).
- **Git hooks:** `graphify hook install` adds post-commit, post-checkout, post-merge, and post-rewrite hooks that keep the graph current.
- **Build from an agent:** `/graphify .` once the skill is installed (runs the semantic pass through the host model, see principle 4).
