# Sentinel Test Skill — Test Execution & Bundle Validation

> **Memory Category:** TencentDB Procedural Memory (Skill Asset)
> **Trigger:** Before committing, packaging, or completing any code/resource change in `Curatare`.

---

## 1. Standard Execution Procedure

### Step 1: Ensure Bundled Mole Engine Is Present
```bash
./Scripts/update-mole.sh install --local-seed
```

### Step 2: Run the Full Swift Test Suite
```bash
swift test
```
- **Expected Result:** All `CuratareCoreTests` and `CuratareAppTests` suites pass with zero residual files in `~/Library/Preferences` or `~/.Trash`.

### Step 3: Build & Verify Universal App Bundle
```bash
./Scripts/build_app.sh && ./Scripts/verify_bundle.sh
```
- Verifies universal (`arm64` + `x86_64`) `Curatare`, universal `analyze-go` and `status-go`, bundled `Contents/Resources/mole/mole` + `Contents/MacOS/mole` symlink, `Scripts/update-mole.sh`, license files, trilingual `.lproj` string files, and `codesign --verify --deep --strict`.
