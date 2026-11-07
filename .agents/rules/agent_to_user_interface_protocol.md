# Agent-to-User Interface Protocol Standard (`agent_to_user_interface_protocol.md`)

> **Upstream Source:** <https://a2ui.org> (v1.0 specification: <https://a2ui.org/specification/v1.0-a2ui/>; repository: `a2ui-project/a2ui`)
> **Version / Date:** v1.0 current since 2026-11-06 (a2ui.org labels v1.0 "Current"; previously designated v0.10; the page is a living document, created 2025-11-20, last updated 2026-06-08); v0.9.1 (status Closed) and v0.9 previous; v0.8 deprecated
> **Last Reviewed:** 2026-11-07
> **Change Summary:** 2026-11-07: version record brought in line with Descarcator's 2026-11-06 source check (no new fetch): a2ui.org now labels v1.0 "Current" (marked so upstream on 2026-11-06), v0.9.1 and v0.9 "Previous" and v0.8 "Deprecated", replacing the "v0.9.1 current, v1.0 release candidate" record; the v1.0 specification link, the v1.0 changes and the renderer status were added; the Core Requirements are unchanged. 2026-11-03: initial adoption at the user's request. Applies A2UI's declarative, catalog-only principle to SwiftUI that coding agents write for this repository. `Curatare` has no A2UI renderer and shows no agent-generated UI at runtime.

---

## Upstream Summary

- A2UI ("Agent to User Interface") lets agents send declarative component descriptions, structure plus data, instead of "text-only responses or risky code execution"; clients render them with their own native widgets "across web, mobile, and desktop."
- Agents "can only use pre-approved components from your catalog", which the site presents as its "Secure by Design" defense against UI injection.
- v1.0 differs from v0.9 and v0.9.1 by bidirectional function calls checked against the catalog, single-message UI setup (components and data in `createSurface`), no hardcoded theme properties (a v1.0 `createSurface` that carries `theme` is invalid), catalog schema changes, and stricter identifier rules (Unicode UAX #31, a reserved `@` namespace).
- The site names Angular, Flutter, Lit, and Markdown renderers (and React in its overview); transports such as A2A carry A2UI messages. The site does not name SwiftUI; the repository README lists a SwiftUI renderer and basic catalog views as "Not published yet".
- The site says A2UI is "Apache 2.0 licensed, created by Google" with contributions from CopilotKit and the open-source community; the repository lives under `a2ui-project`.

## Core Requirements

1. **Generated UI Is Reviewed Code:** SwiftUI an agent writes is executable code, not declarative data, so it gets the full review: build, `swift test`, and a check in the running app before it is reported as finished.
2. **Reuse the Catalog:** New views compose existing components and patterns from `Sources/Curatare/` and follow `ui_rules.md`. A new reusable component is a deliberate addition named in the report.
3. **Destructive Controls Keep Their Guards:** A generated control that moves files goes through `ProtectionRules`, the running-process guard, a confirmation, and Dated Trash. Generated UI never offers permanent delete or a silent privilege prompt.
4. **Every Label Is Localized:** Generated UI adds its strings as `LKey` entries with 1:1 parity in `tr`, `en`, and `ro`; no hardcoded text.
5. **No Runtime Agent UI:** Adding an A2UI renderer or any agent-driven interface to the app needs an explicit user decision first.
