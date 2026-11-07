---
name: bug-fixing
description: >-
  Use this skill when investigating, diagnosing, reproducing, and fixing defects or bugs.
  Guides the agent through root cause isolation, regression test creation, minimal fix
  implementation, and empirical verification.
---

# Workflow: Bug Fixing

## Objective
Isolate the root cause of an issue, reproduce it deterministically, apply the minimal necessary fix without introducing regressions or touching out-of-scope code, and verify with tests.

---

## Workflow Steps

### Step 1: Reproduce & Isolate Root Cause
1. Inspect the reported symptom, stack trace, or error log.
2. Locate the suspect module and file. Read the implementation carefully.
3. Formulate a hypothesis and verify it by locating the exact line or state transition responsible.
4. **Do not guess or apply shotgun fixes** (e.g., adding arbitrary optionals or force unwrapping).

### Step 2: Write a Failing Regression Test
1. Before modifying production code, write a unit test reproducing the exact failure scenario whenever feasible.
2. Run the test and confirm it fails for the expected reason:
   ```bash
   swift test --filter <BugRegressionTestCase>
   ```

### Step 3: Determine Autonomy Level
* If the fix is confined to $\le 2$ files in the same target without changing public interfaces: **Level 1 (Fast Path)** $\rightarrow$ proceed immediately.
* If the fix requires modifying cross-module protocols or data migration: **Level 2 (Plan Gate)** $\rightarrow$ present plan to the user.

### Step 4: Apply Surgical Fix
1. Apply the minimal necessary code change to address the root cause.
2. Avoid refactoring unrelated methods in the same file.
3. Keep the Git diff tight and readable.

### Step 5: Verify
1. Run the failing regression test again: confirm it now passes.
2. Run all adjacent tests in the target: confirm zero regressions.
3. Capture verbatim terminal output.

### Step 6: Report
Output the standard completion report including root cause explanation, modified files, and test output.
