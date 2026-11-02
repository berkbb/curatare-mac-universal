# Graphify Labs Codebase Knowledge Graph Standard (`graphify_knowledge_graph.md`)

> **Upstream Source:** <https://github.com/Graphify-Labs/graphify> (PyPI: `graphifyy`)
> **Last Reviewed:** 2026-10-31
> **Change Summary:** Standardized local tree-sitter AST extraction, `EXTRACTED` / `INFERRED` edge provenance, Leiden community detection, `.graphifyrc` / `.graphifyignore` configuration, and synchronization with `.agents/context/code_graph_wiki.md`.

---

## 1. Core Principles

1. **Graph-First Code Navigation:** Agents turn the repository (Swift code via local tree-sitter AST, shell scripts, and Markdown docs) into a queryable knowledge graph with `EXTRACTED` and `INFERRED` edge provenance and Leiden community detection.
2. **Query Before Grep:** Query the knowledge graph (`graphify query`, `graphify path`, `graphify explain`) before broad search-style tool calls when `graphify-out/graph.json` is present.
3. **Artifact Sync:** Outputs live in `graphify-out/` (`graph.json`, `graph.html`, `GRAPH_REPORT.md`) and feed the Code-Graph Memory Asset (`.agents/context/code_graph_wiki.md`).
4. **Local-Only Privacy:** Code parsing stays 100% local (tree-sitter, no external LLM calls); `.graphifyrc` sets `"cloud": false`, `"no_tips": true`, and `"query_log_disable": true`. `.graphifyignore` excludes build outputs, binaries, and credentials.
