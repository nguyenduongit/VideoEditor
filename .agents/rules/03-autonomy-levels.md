# AAS Core Rule: Autonomy Levels (Balanced Mode)

> **Identifier:** `core/rules/03-autonomy-levels.md`  
> **Status:** Mandatory Invariant  
> **Target:** All Languages, Platforms, and Workspaces

---

## 1. Balanced Autonomy Philosophy

To maintain maximum engineering velocity without risking codebase stability or architectural drift, AAS implements **Balanced Autonomy** via a 3-tier gateway based on **blast radius and risk**.

---

## 2. The 3 Autonomy Gateways

```
┌────────────────────────────────────────────────────────────────────────┐
│ LEVEL 1: FAST PATH (Local Autonomy)                                    │
│ • Scope: Local bugfix, private helper, unit test additions.            │
│ • Impact: <= 2 files within 1 target; no public API/protocol changes.   │
│ • Action: Agent executes immediately (Inspect -> Code -> Verify).      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Crosses blast-radius threshold
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ LEVEL 2: PLAN GATE (Approval Required Before Coding)                   │
│ • Scope: New feature, multi-file refactoring, changing public contracts│
│ • Impact: >= 3 files, cross-module boundaries, data schema migration.  │
│ • Action: Agent stops at Plan stage, presents summary, awaits OK.      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Touches critical infrastructure
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ LEVEL 3: HARD BARRIER (Explicit Human Command Required)                │
│ • Scope: Dependencies, SPM target creation, Entitlements, deletions.  │
│ • Impact: High-risk security, build manifest, external environment.    │
│ • Action: Prohibited from autonomous execution; requires human command.│
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Criteria

### Level 1 — Fast Path (Autonomous Execution)
* Criteria:
  * Modifies $\le 2$ files in the same target or module.
  * Preserves existing `public` / `internal` interface contracts.
  * Fixes a compiler error or warning caused directly by the current task.
  * Adds new unit test cases covering the task.
* Agent Protocol: Proceed directly from Inspect to Code, execute verification, and output the report.

### Level 2 — Plan Gate (Approval Checkpoint)
* Criteria:
  * Adds a new Feature, Screen, or Component.
  * Modifies $\ge 3$ files across the repository.
  * Modifies a Domain Entity, Repository Protocol, or public API contract.
  * Involves Concurrency actor isolation changes or state synchronization refactoring.
* Agent Protocol: Formulate a 3–5 bullet point plan (Affected Files, Contract Diffs, Test Strategy) and stop. Await explicit user approval before writing code.

### Level 3 — Hard Barrier (Strictly Prohibited Without Direct Command)
* Criteria:
  * Adding, removing, or upgrading third-party dependencies in `Package.swift`.
  * Deleting files, targets, or existing test suites.
  * Modifying App Sandbox, Entitlements, or Hardened Runtime configuration.
  * Git history rewrites (`git reset --hard`, `git push --force`).
  * Creating or approving architectural exceptions (ADRs).
* Agent Protocol: Report technical necessity, present the proposed changes, and halt immediately until the user issues an explicit command to proceed.
