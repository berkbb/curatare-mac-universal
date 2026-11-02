# Apple App Intents & Native macOS Integration Standard (`apple_app_intents_agent.md`)

> **Upstream Source:** <https://developer.apple.com/documentation/appintents> & <https://security.apple.com/documentation/private-cloud-compute>
> **Version / Date:** macOS 26 (Tahoe) / 2026
> **Last Reviewed:** 2026-10-31
> **Change Summary:** Standardized native macOS system integration (`NSServices` Finder integration, `NSWorkspace`, `NSRunningApplication`, and local on-device privacy).

---

## Core Requirements

1. **100% Local On-Device Execution:** All library audits, app uninstall inspections, SmartDelete (`TrashWatcher`) monitoring, and disk analysis (`analyze-go`, `status-go`) execute strictly on-device with zero telemetry or cloud uploads.
2. **Safe Finder Service (`NSServices`):** `FinderService` (`cleanUninstallService`) validates incoming `.app` bundle URLs through `OpenSafety` before inspecting related `~/Library` paths.
