---
name: technical-planning
description: >-
  Use this skill when preparing plans for complex tasks, architectural changes,
  or multi-file features. Produces structured plans required by Level 2 Plan Gate.
---

# Workflow: Technical Planning

## Objective
Analyze requirements, assess system impact, design interfaces, and present a structured, actionable implementation plan for human review prior to coding.

---

## Workflow Steps

### Step 1: Requirements Deconstruction
1. Deconstruct the user prompt into functional requirements and non-functional constraints.
2. Identify cross-cutting concerns (concurrency, persistence, security, undo/redo).

### Step 2: Impact Analysis & Blast Radius
1. Map out all affected modules, targets, and files.
2. Check if the task requires modifications to:
   * Public interface contracts (`protocol`, function signatures).
   * Data schemas or persistence models.
   * `Package.swift` target dependencies.
3. Classify task autonomy: If $\ge 3$ files or module boundary touched, classify as **Level 2 (Plan Gate)**.

### Step 3: Interface & Architecture Design
1. Draft new Domain entities, command types, and repository protocols.
2. Define the ViewModel state contract (`ViewState<T>`).
3. Identify existing C0/C1 components to reuse.

### Step 4: Verification Strategy
1. Specify which unit tests will be authored.
2. Specify exact build and test commands to run during verification.

### Step 5: Output Plan Gate Format
Present the plan cleanly in 3–5 bullet points to the user:
```markdown
### Proposed Plan
1. **Scope & Files Touched:** [List of files]
2. **Interface Contracts:** [New/modified protocols and DTOs]
3. **UI Hierarchy:** [C0-C3 component breakdown]
4. **Verification Strategy:** [Commands and test cases to run]
5. **Approval Request:** Awaiting confirmation to proceed to Step 3 (Code).
```
