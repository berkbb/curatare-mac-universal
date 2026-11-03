# OpenInference Specification Standard (`openinference_specification.md`)

> **Upstream Source:** <https://github.com/Arize-AI/openinference> (specification: <https://arize-ai.github.io/openinference/spec/>)
> **Version / Date:** The specification shows no version number; `openinference-semantic-conventions` 0.1.43 (PyPI, 2026-10-29) is the latest Python conventions package
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption at the user's request. Uses OpenInference's span kinds as a checklist for honest reporting by coding agents. `Curatare` has no LLM and emits no traces.

---

## Upstream Summary

- OpenInference is "a set of conventions and plugins that is complementary to OpenTelemetry to enable tracing of AI applications." The specification is transport- and file-format-agnostic and works with Arize Phoenix, Arize AX, or any OpenTelemetry-compatible collector.
- Each span carries `openinference.span.kind`, one of 11 kinds: LLM, AGENT, CHAIN, TOOL, RETRIEVER, RERANKER, EMBEDDING, GUARDRAIL, EVALUATOR, PROMPT, and DECISION. Attribute names use dot-separated namespaces such as `llm.input_messages`.
- Prompts and completions "must be maskable before export". `OPENINFERENCE_HIDE_*` environment variables (for example `OPENINFERENCE_HIDE_INPUTS`, `OPENINFERENCE_HIDE_OUTPUTS`, `OPENINFERENCE_HIDE_LLM_TOOLS`) default to `False`, and code-level `TraceConfig` overrides them.
- Semantic-convention packages exist for Python, JavaScript, Java, and Go.

## Core Requirements

1. **Report Every Span Kind Honestly:** Each TOOL step (a command run) is reported with its real outcome; a GUARDRAIL that blocked an action (`ProtectionRules`, a denied permission) is reported as blocked, not left out; an EVALUATOR result (`swift test`) is quoted, not paraphrased into a pass.
2. **Never Quiet the Log:** Do not downgrade `AppLog` `.error` or `.warning` entries to `.info`, or drop them, to make a run look clean; `LogView` must show what happened.
3. **Mask by Default:** A log line an agent adds to `AppLog` never contains credentials, file contents, or data from `~/.ssh`, `~/.gnupg`, `~/.aws`, or `~/Library/Keychains`; test fixtures use dummy data.
4. **No Exporter in the App:** `AppLog` writes to `~/Library/Logs/Curatare/` and the unified log subsystem `com.babadogantech.curatare`. Adding OpenInference, OpenTelemetry, or any trace exporter breaks the on-device rule in `apple_app_intents_agent.md` and needs an explicit user decision.
5. **Agent-Side Tracing Stays Masked:** If the user approves tracing for agent tooling outside the app, it uses a local collector with `OPENINFERENCE_HIDE_INPUTS` and `OPENINFERENCE_HIDE_OUTPUTS` set to true.
