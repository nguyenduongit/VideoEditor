# Apple Platform Rule: Quality Gates & Testing Standards

> **Identifier:** `platforms/apple/rules/testing.md`  
> **Status:** Platform Invariant  
> **Target:** Swift 6.0+, macOS 14.0+

---

## 1. Tool Selection: `swift` CLI vs. `xcodebuild`

The agent must select the correct verification tool based on the target type:

| Target Type | Primary Command | Justification |
|---|---|---|
| **SPM Library Packages** (`Domain`, `Infrastructure`, `UIComponents`, `Features`) | `swift build`<br>`swift test` | Fast, deterministic, headless execution for pure Swift and component packages. |
| **macOS App Target** (App lifecycle, Entitlements, Sandbox, Assets) | `xcodebuild -scheme <AppScheme> -destination 'platform=macOS' build` | Validates code signing, App Sandbox entitlements, Info.plist, and resource compilation. |
| **UI Integration Tests** (XCUITest) | `xcodebuild -scheme <AppScheme> -destination 'platform=macOS' test` | Required for end-to-end window, menu bar, and native dialog testing. |

---

## 2. Mandatory Quality Gates (Definition of Done)

A task is officially complete only when all criteria below are satisfied:

1. **Zero Compilation Errors & Warnings:**
   * SPM targets compile cleanly under `-strict-concurrency=complete`.
2. **Deterministic Test Execution:**
   * All relevant unit tests pass with 0 failures (`swift test`).
3. **Architecture Boundary Validation:**
   * No forbidden imports detected by `Scripts/check_imports.sh`.
4. **Linting Compliance:**
   * SwiftLint executes without errors on touched files (`swiftlint lint --path <files>`).
   * No `force_cast`, `force_try`, or `force_unwrapping` introduced.
5. **Report with Raw Proof:**
   * The final report includes the exact verbatim terminal output and exit code `0`.

---

## 3. Handling Pre-existing Violations
If the codebase already contains files exceeding size limits (e.g., > 300 lines) or using deprecated APIs outside the requested scope:
* **DO NOT** refactor them automatically.
* Document them under `3. PENDING VIOLATIONS & UNRELATED DEBT` in the final report.
