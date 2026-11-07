# AAS Core Rule: Governance & Precedence

> **Identifier:** `core/rules/00-governance.md`  
> **Status:** Mandatory Invariant  
> **Target:** All Languages, Platforms, and Workspaces

---

## 1. The Precedence Hierarchy

When conflicting instructions or conventions arise, the agent must resolve them using this strict hierarchy (from highest to lowest priority):

1. **Core Safety & Security Invariants** (Zero-override baseline: no data loss, no sandboxing bypass, no leaked secrets).
2. **Explicit User Prompt in Current Turn** (Direct user command overrides default platform conventions, but cannot bypass Core Safety).
3. **Global Core Governance & Autonomy Limits** (`core/rules/*`).
4. **Technology & Platform Standards** (`platforms/<platform>/rules/*`).
5. **Project Workspace Anchor & Approved ADRs** (`AGENTS.md`, `.aas/project.yaml`, `docs/adr/*.md`).
6. **Existing Repository Conventions** (Current code style in the workspace).
7. **Agent Default Inference / Habitual Assumptions** (Lowest priority: never assume when verification is possible).

---

## 2. Invariants vs. Overridable Rules

### A. Non-Negotiable Invariants (Cannot be overridden by any layer or ADR)
* **Integrity of Verification:** The agent must never fabricate or hallucinate command execution, test results, or compiler output.
* **Scope Discipline:** The agent must never perform unrequested structural refactorings or silent deletions of verified code/tests.
* **Credential Protection:** Secrets and credentials must never be written to Git, unencrypted configs, or plain logs.
* **Fail Fast & Loud:** Errors must never be silently swallowed or suppressed without explicit diagnostics.

### B. Overridable Architectural & Technical Conventions
* Supported OS / Platform versions (e.g., macOS 14 vs macOS 13 compatibility).
* State management paradigms (e.g., `@Observable` vs `ObservableObject`).
* Persistence engine choices (e.g., SwiftData vs GRDB vs CoreData).
* Internal package boundaries and third-party dependencies (when explicitly justified).

---

## 3. Architectural Decision Records (ADR) Policy
1. Any deviation from an established Platform Standard requires an approved ADR located at `docs/adr/NNN-title.md`.
2. The ADR must document: Context, Decision, Consequences, and Approved By.
3. **The agent is strictly prohibited from creating and approving its own ADRs.** Architectural exceptions must be confirmed by the human engineer.
