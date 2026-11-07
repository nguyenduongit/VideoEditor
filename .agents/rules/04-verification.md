# AAS Core Rule: Verification & Proof-First Engineering

> **Identifier:** `core/rules/04-verification.md`  
> **Status:** Mandatory Invariant  
> **Target:** All Languages, Platforms, and Workspaces

---

## 1. Zero Fake Proof (Absolute Empirical Truth)

The agent must never claim that code compiles, passes tests, or conforms to lint rules based on presumption or reasoning alone.

* **Prohibited:** Subjective assertions like *"Everything built cleanly and tests passed."* without attached command output.
* **Mandated:** Verbatim raw execution output showing exit codes, executed test suites, and duration.
* **Blocked Verification Protocol:** If verification cannot be run automatically (e.g., missing CLI tools, missing simulator, sandboxed network block), the agent must:
  1. Clearly explain why verification was blocked.
  2. Provide the exact shell command for the user to execute manually.

---

## 2. Risk-Based Verification Matrix

The required verification intensity scales directly with the risk profile of the task:

| Risk Tier | Trigger Conditions | Required Verification Pipeline | Quality Gate (Exit Criteria) |
|---|---|---|---|
| **Low Risk** | Local bugfix, UI copy adjustment, private helper ($\le 2$ files, same target). | 1. Local target compile: `swift build --target <Target>`<br>2. Local unit tests: `swift test --filter <TargetTests>` | • Target compiles with 0 errors.<br>• Target unit tests pass 100%. |
| **Medium Risk** | New feature, refactored ViewModel/Organism, 3–5 files touched. | 1. Workspace build: `swift build`<br>2. Relevant test suites: `swift test --filter <FeatureTests>`<br>3. Changed-file linter: `swiftlint lint --path <Files>`<br>4. Strict Concurrency audit | • Zero new warnings under `-strict-concurrency=complete`.<br>• Zero new linter violations.<br>• Offline UI Previews render cleanly. |
| **High Risk** | Architectural changes, Domain protocol diffs, Data schema migration, Sandbox/Entitlements. | 1. Full workspace test suite: `swift test`<br>2. Architecture check script: `Scripts/check_imports.sh`<br>3. Desktop App scheme build: `xcodebuild -scheme <App> build`<br>4. Memory / Undo Stack leak checks | • 100% of full test suite passes.<br>• No illegal cross-module imports.<br>• App target builds with correct entitlements. |

---

## 3. Scope of Test Execution
* When running scoped tests (e.g., `swift test --filter`), the agent must explicitly state which tests were executed and which were skipped due to scope optimization.
* It is strictly prohibited to declare "All tests in the project passed" when only a filtered subset was executed.
