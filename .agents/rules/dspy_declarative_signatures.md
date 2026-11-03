# Stanford DSPy 3.x Declarative Signature Standard (`dspy_declarative_signatures.md`)

> **Upstream Source:** <https://github.com/stanfordnlp/dspy> (official docs: <https://dspy.ai/>; `dspy/signatures/signature.py`)
> **Version / Date:** GitHub release `3.4.1` (2026-10-12); the dspy.ai banner names DSPy 3.4.1
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption at the user's request. Applies declared inputs and outputs and metric-driven tuning to how coding agents change `CuratareCore` on this repository. `Curatare` ships no DSPy modules and makes no model calls.

---

## Upstream Summary

- DSPy (Declarative Self-improving Python) describes itself as "the framework for programming—rather than prompting—language models", used to build modular AI systems and optimize their prompts and weights.
- A **signature** defines a task as typed inputs and outputs: an inline string such as `"question -> answer"` or a `dspy.Signature` subclass with `InputField` and `OutputField`. Without instructions, the default reads "Given the fields …, produce the fields …".
- **Modules** such as `dspy.Predict`, `dspy.ChainOfThought`, and `dspy.ReAct` control how a signature runs. **Optimizers** such as `dspy.GEPA` take examples and a scoring metric and tune prompts until quality converges.
- The 3.4.1 notes make GEPA's structured `InstructionProposer` the default and repeat the 3.4.0 notice that legacy custom-LM interfaces will be removed in 3.5.

## Core Requirements

1. **No DSPy in the App:** `Curatare` has no LLM calls; this standard applies only to how coding agents shape code here.
2. **Declare Inputs and Outputs First:** Before changing a scanner or helper in `CuratareCore`, state what it takes and returns (types, units such as bytes, the `ProtectionRules` verdict) and keep the Swift signature typed rather than passing untyped strings.
3. **Metric Before Tuning:** Heuristic or performance changes (orphan matching, scan speed) start from a fixture and a measurable check in a Swift Testing suite, and report numbers before and after.
4. **Names Carry the Contract:** Function and `LKey` names describe what they hold; a renamed key changes all three tables (`tr`, `en`, `ro`) in the same change.
