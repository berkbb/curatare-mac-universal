# Engine Maintenance Skill — Mole GitHub Updater (`update-mole.sh`)

> **Memory Category:** TencentDB Procedural Memory (Skill Asset)
> **Trigger:** When checking or updating the bundled Mole engine (`tw93/mole`) from GitHub releases or seeding locally.

---

## 1. Check Latest Mole Release
```bash
./Scripts/update-mole.sh check
```

## 2. Update Bundled Mole Engine from GitHub Releases
```bash
./Scripts/update-mole.sh install --dest Vendor/mole
```
- Queries `https://api.github.com/repos/tw93/Mole/releases/latest`.
- Downloads the release tag source archive (`mole`, `bin/*.sh`, `lib/**`) and `binaries-darwin-arm64.tar.gz` + `binaries-darwin-amd64.tar.gz` (verifying `sha256` digests, or building universal binaries via `go build` + `lipo -create`), merges `analyze-go` and `status-go` into universal (`arm64` + `x86_64`) Mach-O binaries, and signs them ad-hoc.
