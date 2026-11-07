# Actionable Task Breakdown: [FEATURE NAME]

**Spec**: `specs/[feature-id]/spec.md`  
**Plan**: `specs/[feature-id]/plan.md`  

---

## Phase 1: Setup & Foundations (Blocks All Stories)
*Purpose: Data types, contracts, schema migrations, and repository protocols.*

- [ ] T001 [P] Author shared data contracts / entities in `[Path/To/Contract]`
- [ ] T002 [P] Author repository protocol / service interface in `[Path/To/Protocol]`
- [ ] T003 Execute schema migration / database setup in `[Path/To/Migration]`

**Checkpoint 1**: Foundational interfaces compile cleanly with zero errors.

---

## Phase 2: User Story 1 - [Core Flow] (Priority: P1) - MVP
*Goal: Deliver independent, functional MVP for User Story 1.*

- [ ] T004 [P] [US1] Author failing unit test for core logic in `[Path/To/Test]`
- [ ] T005 [US1] Implement concrete service / repository in `[Path/To/Implementation]`
- [ ] T006 [P] [US1] Author Level 1/2 UI components in `[Path/To/Component]`
- [ ] T007 [US1] Wire Level 3 Screen / Route container in `[Path/To/Screen]`
- [ ] T008 [US1] Execute verification and confirm unit tests pass

**Checkpoint 2 (MVP Ready)**: User Story 1 works independently and can be verified.

---

## Phase 3: User Story 2 - [Secondary Flow] (Priority: P2)
*Goal: Deliver secondary capability without breaking User Story 1.*

- [ ] T009 [P] [US2] Author unit tests for secondary scenario in `[Path/To/Test]`
- [ ] T010 [US2] Implement secondary business logic in `[Path/To/Implementation]`
- [ ] T011 [US2] Integrate secondary UI components in `[Path/To/Component]`

**Checkpoint 3**: Both User Stories 1 and 2 operate cleanly together.

---

## Phase 4: Polish, Security & Quality Gate Verification
*Purpose: Cross-cutting checks, linting, security invariants, and final proof.*

- [ ] T012 Run architecture import validation script
- [ ] T013 Verify file and method line limit thresholds (warn 200, review 300)
- [ ] T014 Run full test suite and capture verbatim raw terminal output
- [ ] T015 Generate completion report conforming to `core/rules/06-reporting.md`
