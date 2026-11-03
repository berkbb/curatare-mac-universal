# AutoGPT Platform Continuous Autonomous Goal Loop Standard (`autogpt_autonomous_loop.md`)

> **Upstream Source:** <https://github.com/Significant-Gravitas/AutoGPT> (README and `classic/README.md`)
> **Version / Date:** GitHub release `autogpt-platform-beta-v0.10.0` (2026-10-27)
> **Last Reviewed:** 2026-11-03
> **Change Summary:** 2026-11-03: initial adoption at the user's request. Applies the platform's review-before-send and scoped-access principles to the plan–act–check cycle of coding agents on this repository. `Curatare` runs no autonomous agent loop.

---

## Upstream Summary

- The README presents AutoGPT as a team of AI "Experts" coordinated by an agent named Otto. Each Expert's role is shaped by instructions, context, skills, and connected apps; the Platform runs hosted (paid) or self-hosted with Docker.
- Users choose which accounts each Expert can access, set spending controls, and follow progress in each Expert's activity. The demo run prepares work "for review without sending or publishing it".
- The described cycle is choose an Expert, brief it, then review and refine; users can "Activate routines for jobs that keep coming back". A visual builder connects blocks and branch logic, and an API and MCP server run workflows from code.
- `autogpt_platform/` is under Polyform Shield; `classic/` and the rest are MIT. AutoGPT Classic is described as "an experimental project to demonstrate autonomous GPT-4 operation".
- Platform release tags carry the `beta` label (for example `autogpt-platform-beta-v0.10.0`).
- Not stated on the canonical page, so not adopted here: "continuous" operation or a plan, execute, evaluate, replan goal loop as a Platform feature.

## Core Requirements

1. **No Goal Loop in the App:** `Curatare` runs no agent loop. Its one background watcher, SmartDelete (`TrashWatcher`, a Settings toggle that is on by default), only reports leftovers of apps the user trashed in Finder; moving them waits for the user's click.
2. **Bounded Plan–Act–Check Cycle:** Coding agents plan, edit, run `swift test`, and replan on failure, stopping after three consecutive failures on the same issue (3-Strike Rule).
3. **Prepare for Review, Do Not Send:** Agents prepare commits, release notes, and Mole updates for review; nothing is committed, pushed, published, or released without the user's approval.
4. **Scoped Access and Spend:** Agents use only the access the task needs and add no paid cloud API, network service, or new account.
5. **Honest Completion:** A task is reported done only after its tests ran and passed; anything unverified is named as such.
