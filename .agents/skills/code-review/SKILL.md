---
name: code-review
description: >-
  Use this skill when auditing, reviewing, or evaluating code changes or pull requests.
  Inspects correctness, architectural alignment, concurrency safety, security baselines,
  and anti-patterns against AAS standards.
---

# Workflow: Code Review

## Objective
Provide an objective, rigorous, and actionable code audit evaluating correctness, architectural boundaries, Swift 6 concurrency safety, and security invariants.

---

## Review Checklist

### 1. Architectural & Module Boundaries
- [ ] Does the change violate Dependency Inversion? (e.g., Domain importing SwiftUI/AppKit/Infra).
- [ ] Does a Feature module import another Feature module directly?
- [ ] Are dependencies injected at the Composition Root?

### 2. Concurrency & Memory Safety (Swift 6)
- [ ] Are UI-bound ViewModels correctly isolated with `@MainActor`?
- [ ] Do types crossing concurrency boundaries conform to `Sendable`?
- [ ] Is structured concurrency preferred over unconstrained `Task.detached`?
- [ ] Are closures properly evaluated for retain cycles without blanket/superfluous `[weak self]`?

### 3. SwiftUI & Component Hierarchy
- [ ] Does the view conform to the 4-level hierarchy (C0–C3)?
- [ ] Is high-frequency state (scrubbing, cursor, timers) isolated from low-frequency state?
- [ ] Are Views free of direct database/network I/O calls?

### 4. Security & Error Handling
- [ ] Are errors handled explicitly without blind `try?` or `!` force unwrap?
- [ ] Are secrets or sensitive data excluded from logs and storage?
- [ ] Are Sandbox file access APIs properly bracketed with security-scoped resources?

### 5. Verification & Tests
- [ ] Are new capabilities accompanied by deterministic unit tests?
- [ ] Is raw verification output attached to the submission?

---

## Output Format
Categorize findings by severity:
* **Blocker (Must Fix):** Security flaws, data loss risk, architecture boundary violations, concurrency data races.
* **Warning (Should Fix):** Missing test cases, oversized methods, redundant re-renders.
* **Suggestion (Nice to Have):** Naming improvements, minor micro-optimizations.
