# Retrieval-Augmented Generation Standard (`retrieval_augmented_generation.md`)

> **Upstream Source:** <https://arxiv.org/abs/2005.11401> — "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks", Patrick Lewis, Ethan Perez, Aleksandra Piktus, Fabio Petroni, Vladimir Karpukhin, Naman Goyal, Heinrich Küttler, Mike Lewis, Wen-tau Yih, Tim Rocktäschel, Sebastian Riedel, Douwe Kiela
> **Version / Date:** arXiv v4, 2021-04-12 (accepted at NeurIPS 2020; v1 2020-05-22)
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption. Treats the repository's memory assets and sources as the non-parametric memory that agents must retrieve from before answering or changing code.

---

## Upstream Summary

- Knowledge stored in model parameters is hard to access precisely; giving provenance for outputs and updating world knowledge are open problems for parametric-only models.
- RAG pairs parametric memory (a pre-trained seq2seq model) with non-parametric memory (a dense vector index of Wikipedia read through a pre-trained neural retriever). One formulation uses the same retrieved passages for the whole output; the other may use different passages per token.
- RAG models set the state of the art on three open-domain QA tasks and produced more specific, diverse, and factual text than a parametric-only seq2seq baseline.

## Core Requirements

1. **Retrieve From the Right Source:**
   - Code structure and impact → `graphify-out/graph.json` (`graphify query`, `explain`, `affected`) and `.agents/context/code_graph_wiki.md`.
   - Domain rules (`library_clean.md` method, protection list, Mole contracts) → `.agents/AGENTS.md` and `.agents/context/domain_wiki.md`.
   - Mole CLI behavior → `Vendor/mole/` sources and `Vendor/mole/SOURCE.txt`.
   - Past failures and rejected ideas → `.agents/context/reflexion_memory_log.md` and `.agents/context/user_rejected_spec.md`.
2. **Cite Provenance:** Claims about code or engine behavior in plans, reviews, and docs name the file (and line, when it matters) they came from.
3. **Source Beats Memory:** When a retrieved source and a memory asset disagree, the source wins and the stale asset is corrected in the same change.
4. **Check Freshness:** Compare the `Built at commit` line in `code_graph_wiki.md` with `git rev-parse HEAD` before relying on it; rebuild the graph when they differ after structural changes.
5. **Retrieval Stays Local:** Scan results and paths from the user's Mac are not sent to external tools or services for retrieval.
