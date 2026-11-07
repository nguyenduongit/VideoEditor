---
name: refactoring
description: >-
  Use this skill when improving internal code structure, maintainability, or readability
  without altering external runtime behavior. Enforces invariant preservation, test coverage
  validation, and blast-radius control.
---

# Workflow: Refactoring

## Objective
Improve code cleanliness, reduce duplication, or break down oversized files/methods while guaranteeing that external behavior and interface contracts remain completely unchanged.

---

## Workflow Steps

### Step 1: Establish Behavioral Invariants
1. Verify that the target code currently passes all existing tests.
2. If tests are absent or inadequate, write characterization tests first to lock in existing behavior before refactoring.

### Step 2: Determine Scope & Autonomy Gate
* Internal refactor of a private helper or subview inside 1 file: **Level 1 (Fast Path)**.
* Multi-file refactor, splitting a large target, or moving files between modules: **Level 2 (Plan Gate)** $\rightarrow$ requires user approval of target file paths.

### Step 3: Apply Incremental Transformations
1. Perform one refactoring step at a time (e.g., Extract Method $\rightarrow$ Verify $\rightarrow$ Extract Subview $\rightarrow$ Verify).
2. Never mix refactoring with adding new features or changing business logic.
3. Obey the Rule of Three: Do not create single-use wrappers or over-abstracted generic abstractions.

### Step 4: Verify Behavioral Equivalence
1. Run target and workspace tests after each transform step.
2. Ensure no compiler warnings are introduced under strict concurrency.
3. Check file and function line count metrics.

### Step 5: Report
Produce the completion report showing before-and-after line metrics and full test passing output.
