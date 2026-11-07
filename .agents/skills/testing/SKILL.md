---
name: testing
description: >-
  Use this skill when designing, writing, or executing automated tests.
  Covers unit testing, mock generation, protocol verification, test execution,
  and risk-based test pipeline orchestration.
---

# Workflow: Testing & Verification

## Objective
Author deterministic, fast, and maintainable unit and integration tests that verify business logic, state transitions, and boundary contracts without flaky external dependencies.

---

## Workflow Steps

### Step 1: Identify Test Target & Scope
1. Determine the module under test (`DomainTests`, `InfrastructureTests`, `FeatureTests`).
2. Identify dependencies to mock:
   * Isolate Domain logic using in-memory mock repositories conforming to Domain protocols.
   * Never make real disk I/O or network requests in unit tests.

### Step 2: Author Focused Test Cases
1. Use Arrange-Act-Assert (AAA) or Given-When-Then structure.
2. Test both happy path and failure scenarios:
   * Verify explicit error propagation (e.g., `XCTAssertThrowsError`).
   * Test boundary conditions (empty states, edge values, cancelled tasks).
3. Ensure mocks are lightweight value types or Sendable actors.

### Step 3: Execute Tests
Execute tests using the appropriate CLI command:

```bash
# Filtered execution (Fast Path / Low Risk)
swift test --filter <TestCaseName>

# Full package execution (Medium / High Risk)
swift test

# Desktop App target scheme (via xcodebuild when applicable)
xcodebuild -scheme <AppScheme> test -destination 'platform=macOS'
```

### Step 4: Validate Concurrency & Clean Execution
1. Confirm zero test failures.
2. Confirm no concurrency race warnings under Swift 6 mode.
3. Record exact execution time and test counts for reporting.
