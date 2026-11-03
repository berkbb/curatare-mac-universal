# Amazon Bedrock AgentCore Governance Standard (`aws_bedrock_agentcore.md`)

> **Upstream Source:** <https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/what-is-bedrock-agentcore.html>; Classic status: <https://docs.aws.amazon.com/bedrock/latest/userguide/agents-classic-maintenance-mode.html>
> **Version / Date:** AgentCore Developer Guide overview as published on 2026-11-03 (the page shows no version or date); Bedrock Agents Classic closed to new customers on 2026-07-30
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption at the user's request. Maps AgentCore's Policy, Observability, Evaluations, and Identity ideas onto how coding agents work here. `Curatare` uses no AWS service.

---

## Upstream Summary

- AgentCore is an agentic platform for building, deploying, and operating agents with any framework and foundation model; its services work together or independently. The overview lists Harness, Runtime, Memory, Gateway, Identity, Code Interpreter, Browser, Observability, Payments, Evaluations, Optimization, Policy, and Registry.
- Policy gives deterministic control: rules written in natural language or a Cedar-compatible policy language are enforced through Gateway, which intercepts every tool call before it runs.
- Runtime provides session isolation; Identity handles agent identity, access, and authentication with existing identity providers.
- Observability traces each step so intermediate outputs can be audited (OpenTelemetry-compatible). Evaluations measure task execution, edge-case handling, and output reliability before and after deployment.
- Amazon Bedrock Agents (launched November 2023) is now Bedrock Agents Classic, in maintenance mode: closed to new customers from 2026-07-30, existing agents keep working, no new features, no planned end-of-life. AWS recommends migrating to AgentCore.
- Not stated on the canonical page, so not adopted here: an AWS document called a "governance standard". The page describes a platform of services; the Classic status comes from the second page above.

## Core Requirements

1. **Policy Before Every Side Effect:** Each command that changes files or system state is checked against fixed rules before it runs: no `rm -rf` or `FileManager.removeItem` on user data (Dated Trash only), nothing on the Protection Rules list (`com.apple.*` and the rest), no silent `sudo`. A match blocks the command; it is not traded off against convenience.
2. **Trace What Ran:** The task report lists the commands run and their results; failures and corrections go into `reflexion_memory_log.md`. Inside the app, operations are logged through `AppLog` and every move is recorded in a `TrashBatchManifest`.
3. **Evaluate Before and After:** Changes are evaluated before they ship (`swift test`; `./Scripts/build_app.sh` and `./Scripts/verify_bundle.sh` for bundle changes), and outcomes are reported as they happened. Partial or failed results are never described as success, in an agent's report or in the app's UI text.
4. **Least-Privilege Identity:** Agents work as the user's normal account with the narrowest access the task needs. They never read or send `~/.ssh`, `~/.gnupg`, `~/.aws`, or `~/Library/Keychains`, and never store cloud credentials in the repository.
5. **No Cloud Agent in the App:** Adding AWS SDKs, AgentCore, or any hosted agent service to `Curatare` breaks the on-device rule in `apple_app_intents_agent.md` and needs an explicit user decision first.
