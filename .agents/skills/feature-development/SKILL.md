---
name: feature-development
description: >-
  Use this skill when implementing a new feature or expanding existing functionality.
  Guides the agent through requirements analysis, Plan Gate approval, surgical coding,
  risk-based verification, and completion reporting.
---

# Workflow: Feature Development

## Objective
Implement new application capabilities with strict scope control, maintainable architecture, and verifiable behavior without regressing existing features.

---

## Workflow Steps

### Step 1: Inspect & Understand
1. Read the project anchor (`AGENTS.md`) and manifest (`.aas/project.yaml`).
2. Identify the active architectural blueprint (e.g., Modular SPM, Clean Architecture).
3. Search for existing reusable components in `UIComponents/` or shared utilities.
4. Determine which Domain entities and protocols will be touched or introduced.

### Step 2: Analyze & Scope
1. Translate acceptance criteria into concrete code artifacts.
2. Verify that the requested feature does not duplicate existing modules.
3. Determine autonomy level:
   * Features typically require **Level 2 (Plan Gate)** because they touch multiple files or cross module boundaries.

### Step 3: Plan Gate (Checkpoint)
1. Formulate a 3–5 bullet point plan:
   * Target files to create/modify.
   * New Domain protocols and ViewModel contracts.
   * Testing strategy (unit tests + mock data).
2. **STOP AND WAIT FOR USER APPROVAL** before writing code.

### Step 4: Implement (Surgical Execution)
1. Load relevant technology skills (e.g., `swiftui-components`, `swift-concurrency`, `macos-file-access`).
2. Write Domain contracts and entities first.
3. Implement business logic and state transformations.
4. Compose UI using the 4-level component hierarchy (C0–C3).
5. Wire dependencies at the Composition Root (App layer).

### Step 5: Verify (Risk-Based Verification)
1. Run target build: verify zero compiler errors or warnings.
2. Run unit tests covering the new feature: verify 100% pass rate.
3. Run linter and strict concurrency checks.
4. Capture raw terminal output.

### Step 6: Report
Produce the completion report following `core/rules/06-reporting.md`.
