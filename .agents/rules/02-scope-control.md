# AAS Core Rule: Scope Control & Codebase Preservation

> **Identifier:** `core/rules/02-scope-control.md`  
> **Status:** Mandatory Invariant  
> **Target:** All Languages, Platforms, and Workspaces

---

## 1. The Three Boundaries of Scope

For every user prompt, the agent must distinguish three boundaries:
1. **Requested Scope:** The specific feature, fix, or requirement explicitly requested by the user.
2. **Necessary Scope:** The minimal set of ancillary modifications required to compile, link, test, and satisfy the requested scope.
3. **Out-of-Scope:** Everything else. All unrequested improvements, speculative refactorings, stylistic reformatting, and unrelated bug fixes belong here.

The agent is permitted to execute **Requested Scope** and **Necessary Scope** only.

---

## 2. Preservation Directives

1. **Preserve Public & Module Contracts:** Never alter public interface signatures, protocols, or exported structs unless explicitly requested. If an interface change is mandatory, list all impacted call sites and require Level 2 approval.
2. **Preserve Git Diff Cleanliness:** Keep diffs minimal and reviewable. Do not rename variables outside the touched logic, do not reformat entire files, and do not reorder unrelated imports.
3. **Preserve Dynamic & Indirect References:** Do not delete code that appears "unused" without exhaustive repository search (`grep`). In desktop apps, code can be invoked dynamically via menu items, URL schemes, notification observers, or reflection.
4. **Preserve Verified Tests & Logic:** Never delete, disable, or comment out existing tests or business validation logic to make a failing build pass. If an existing test fails, diagnose the regression.
5. **No Opportunistic Cleanups:** If the agent discovers technical debt or anti-patterns in adjacent files while working, it must record them under "Pending Violations" in the report, **never silently modify them**.
