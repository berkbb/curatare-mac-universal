# Agent-to-User Interface Protocol Standard (`agent_to_user_interface_protocol.md`)

> **Upstream Source:** <https://a2ui.org> (repository: `a2ui-project/a2ui`)
> **Version / Date:** v0.9.1 current production release; v1.0 release candidate (previously designated v0.10 in draft); v0.9 previous stable; v0.8 legacy
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption at the user's request. Applies A2UI's declarative, catalog-only principle to SwiftUI that coding agents write for this repository. `Curatare` has no A2UI renderer and shows no agent-generated UI at runtime.

---

## Upstream Summary

- A2UI ("Agent to User Interface") lets agents send declarative component descriptions, structure plus data, instead of "text-only responses or risky code execution"; clients render them with their own native widgets "across web, mobile, and desktop."
- Agents "can only use pre-approved components from your catalog", which the site presents as its "Secure by Design" defense against UI injection.
- Named renderers include Angular, Flutter, Lit, and Markdown; transports such as A2A carry A2UI messages. SwiftUI is not named.
- The site says A2UI is "Apache 2.0 licensed, created by Google" with contributions from CopilotKit and the open-source community; the repository lives under `a2ui-project`.

## Core Requirements

1. **Generated UI Is Reviewed Code:** SwiftUI an agent writes is executable code, not declarative data, so it gets the full review: build, `swift test`, and a check in the running app before it is reported as finished.
2. **Reuse the Catalog:** New views compose existing components and patterns from `Sources/Curatare/` and follow `ui_rules.md`. A new reusable component is a deliberate addition named in the report.
3. **Destructive Controls Keep Their Guards:** A generated control that moves files goes through `ProtectionRules`, the running-process guard, a confirmation, and Dated Trash. Generated UI never offers permanent delete or a silent privilege prompt.
4. **Every Label Is Localized:** Generated UI adds its strings as `LKey` entries with 1:1 parity in `tr`, `en`, and `ro`; no hardcoded text.
5. **No Runtime Agent UI:** Adding an A2UI renderer or any agent-driven interface to the app needs an explicit user decision first.
