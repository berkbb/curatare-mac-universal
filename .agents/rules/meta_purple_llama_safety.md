# Meta Purple Llama Agentic Safety Standard (`meta_purple_llama_safety.md`)

> **Upstream Source:** <https://github.com/meta-llama/PurpleLlama> (Llama Guard 4, LlamaFirewall, Prompt Guard 2, CyberSecEval 4)
> **Version / Date:** 2026 Stable
> **Last Reviewed:** 2026-10-31
> **Change Summary:** Enforced filesystem boundary protection, symlink traversal defenses, and credential directory blocking (`~/.ssh`, `~/.gnupg`, `~/.aws`, `~/Library/Keychains`).

---

## Core Requirements

1. **Credential & Keychain Firewall:** `ProtectionRules` and `SandboxProfile` unconditionally deny read/write/move operations on `~/.ssh`, `~/.gnupg`, `~/.aws`, and `~/Library/Keychains`.
2. **Symlink Escape Prevention:** `OpenSafety` and `LibraryScanner` do not follow symlinks outside their designated scan roots (`skipsPackageDescendants` / non-following enumerators).
