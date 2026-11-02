# Mathematical & Byte Accounting Rules — Curatare

> **Memory Category:** Declarative Domain Rule
> **Scope:** Byte arithmetic, directory size aggregation, human-readable unit parsing, and health score invariants.

---

## 1. Saturating `Int64` Byte Arithmetic (`DiskSpace.saturatingAdd`)

- All file sizes, directory totals, reclaimable space summaries, and disk capacity values are stored as non-negative `Int64` byte counts.
- Summing arbitrary file sizes across `~/Library` or `analyze-go` trees must use `DiskSpace.saturatingAdd(_:_:)` (`addingReportingOverflow`, clamping on overflow to `Int64.max` and clamping negative values to `0`) so malformed metadata can never trigger an integer overflow trap.

## 2. Human-Readable Size Parsing (`DiskSpace.parseHumanSize`)

- Mole CLI outputs (`mole uninstall --list` size strings such as `"477.5MB"`, `"2.11GB"`, `"156KB"`) and `ollama list` sizes are parsed into `Int64` bytes with decimal support (`B`, `K`/`KB`/`KiB`, `M`/`MB`/`MiB`, `G`/`GB`/`GiB`, `T`/`TB`/`TiB`).

## 3. Health Score & Metric Bounds

- `health_score` from `status-go --json` is clamped to `0...100`.
- CPU, memory, and disk usage percentages are clamped to `0.0...100.0`.
