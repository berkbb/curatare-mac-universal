# UI & Localization Rules — Curatare

> **Memory Category:** Declarative Domain Rule
> **Scope:** SwiftUI views, localization (`tr`, `en`, `ro`), Liquid Glass styling, and accessibility.

---

## 1. Trilingual Localization (`tr`, `en`, `ro`)

- Every user-visible string must be defined as a case of `LKey` in `Sources/CuratareCore/Localization.swift` and present with 1:1 key parity in:
  - `Resources/tr.lproj/Localizable.strings`
  - `Resources/en.lproj/Localizable.strings`
  - `Resources/ro.lproj/Localizable.strings`
  - plus `InfoPlist.strings` and `ServicesMenu.strings` in all three `.lproj` directories.
- Format specifiers (`%@`, `%lld`, `%.1f`) must match in count and order across all three languages (`LocalizationTests` enforces this).
- **Dedicated File per Language:** Each language has its own `Resources/<lang>.lproj/` tables. Never merge languages into one shared file; every table mirrors the full key set, and a non-English table never holds English fallback text or a placeholder.
- A new key, button, dialog, menu item, or message lands in all three languages in the same change.

## 2. Language Switch & System-Level Text

- In-app language changes update SwiftUI views and custom windows at once. The macOS menu bar (`NSApp.mainMenu`), system panels (`NSOpenPanel` / `NSSavePanel`), and system alerts only reload with the Cocoa bundles.
- So a language change writes `AppleLanguages` in `UserDefaults` (`AppSettings.applyLanguageToDefaults`, removed for `system`), shows the `restartWarningTitle` / `restartWarningMessage` alert, and keeps the `restartMenuBarNotice` footer in Settings.

## 3. Hierarchical `Table` Environment Rule

- Never access `@Environment` inside a `TableColumn` row closure of a hierarchical `Table(items, children: \.children)` (triggers a crash in SwiftUI's `OutlineListCoordinator`). Always capture `language` or helpers in the enclosing view body.

## 4. Safety Confirmation & Transparency

- Every cleanup tab clearly displays that selected items are moved to a dated folder in `~/.Trash/Curatare-YYYY-MM-DD-HHmmss/` (never permanently deleted) and can be restored from the **Trash Batches & History (`Çöp Turları ve Geçmiş`)** tab.
