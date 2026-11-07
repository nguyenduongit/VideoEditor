---
name: spec-driven-development
description: >-
  Use this skill when executing complex feature development or major architectural capabilities
  using Spec-Driven Development (SDD). Orchestrates the complete lifecycle:
  User Scenarios (Spec) -> Technical Architecture (Plan) -> Granular Task Breakdown (Tasks) -> Verified Implementation.
---

# Workflow: Spec-Driven Development (SDD)

## Objective
Eliminate "vibe-coding" and guesswork by establishing an explicit chain of custody:
**Product Spec $\rightarrow$ Technical Plan $\rightarrow$ Bite-Sized Tasks $\rightarrow$ Verified Code**.

Inspired by the GitHub Spec-Kit methodology, integrated natively with AAS Quality Gates and Platform Rules.

---

## The 4-Phase Lifecycle

```
[ 1. SPECIFY ]        [ 2. PLAN ]            [ 3. BREAK DOWN ]       [ 4. EXECUTE & VERIFY ]
User Stories (P1-P3) ──► Architecture Plan ──► Task Checklist (Tasks) ──► AAS Quality Gates
Acceptance Criteria     Interface Contracts    Parallel Flags [P]         Raw Test Proof
```

---

## Execution Steps

### Phase 1: Specify (`specs/<feature-name>/spec.md`)
1. Create or read `specs/<feature-name>/spec.md` using `templates/spec-kit/spec.template.md`.
2. Structure user stories by priority:
   * **P1 (Core MVP):** Minimal independently testable slice delivering immediate value.
   * **P2 (Secondary):** Next logical value increment.
   * **P3 (Edge/Polish):** Enhancements.
3. Define strict acceptance criteria using **Given-When-Then** format.
4. Define non-functional constraints and measurable success criteria.

### Phase 2: Plan (`specs/<feature-name>/plan.md`)
1. Translate functional requirements into a concrete technical architecture plan using `templates/spec-kit/plan.template.md`.
2. Map out all file targets across architectural layers (Contracts/Domain, Infra, UI C0-C3).
3. Draft interface signatures, protocols, and DTOs before coding.
4. **Plan Gate Checkpoint:** Present the plan to the human engineer for Level 2 approval before generating tasks.

### Phase 3: Task Breakdown (`specs/<feature-name>/tasks.md`)
1. Generate an actionable checklist in `specs/<feature-name>/tasks.md` using `templates/spec-kit/tasks.template.md`.
2. Structure tasks into phases:
   * **Phase 1: Foundational setup** (blocks all stories).
   * **Phase 2: User Story 1 (P1 MVP)** with an independent validation checkpoint.
   * **Phase 3: User Story 2 (P2)** with integration verification.
   * **Phase 4: Quality Gate verification & Polish**.
3. Mark independent tasks with `[P]` (parallelizable).

### Phase 4: Execute & Converge
1. Execute tasks in strict dependency order:
   * Author failing test $\rightarrow$ Implement service $\rightarrow$ Compose UI $\rightarrow$ Verify.
2. Check off tasks in `tasks.md` as they complete (`- [x]`).
3. Stop at checkpoints to validate each User Story independently.
4. Run AAS Quality Gates:
   * Swift: `swift test` and `Scripts/check_imports.sh`.
   * Web: `npm run type-check && npm test`.
5. Output final report following `core/rules/06-reporting.md` with verbatim raw terminal output.
