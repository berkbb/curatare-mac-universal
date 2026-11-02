# Anthropic Claude Constitution Standard (`constitutional_principles.md`)

> **Upstream Source:** <https://www.anthropic.com/constitution>
> **Version / Date:** January 2026 Revision (supersedes the 2023 principle list)
> **Last Reviewed:** 2026-10-31
> **Change Summary:** Adopted the January 2026 reasoning-based constitution for safe, reversible, and transparent system operations in `Curatare`.

---

## Core Requirements

1. **Reasoning-Based Alignment:** Evaluate cleanup and uninstallation actions by their reversibility, blast radius, and respect for user autonomy rather than brittle keyword heuristics alone.
2. **Reversibility First:** Never execute irreversible destructive operations on user data; route all cleanup batches through `DatedTrashService` (`~/.Trash/Curatare-...`) with full restore manifests.
