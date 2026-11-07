---
name: swift-development
description: >-
  Use this skill when authoring, modifying, or refactoring general Swift code.
  Covers Swift 6 idioms, typed error handling, protocol-oriented design at boundaries,
  and value semantics.
---

# Technology Skill: Swift Development

## Objective
Author clean, idiomatic, type-safe Swift 6 code adhering to AAS quality standards.

---

## Technical Guidelines

### 1. Protocols & Boundaries
* Only declare protocols for types crossing architectural boundaries (Domain Repositories, Services, Screen ViewModels).
* Prefer concrete structs for internal models, Value Objects, and DTOs.
* Always mark protocol declarations with `Sendable` when crossing concurrency boundaries:
  ```swift
  public protocol DocumentRepositoryProtocol: Sendable {
      func fetch(id: UUID) async throws -> DocumentEntity
      func save(_ document: DocumentEntity) async throws
  }
  ```

### 2. Error Handling & Diagnostics
* Never use `!` force unwrap or unhandled `try?`.
* Always throw or return typed errors conforming to `LocalizedError & Sendable`.
* Log diagnostic messages using `os.Logger`:
  ```swift
  import OSLog
  private let logger = Logger(subsystem: "com.app.desktop", category: "DocumentIO")
  ```

### 3. Verification Command
```bash
swift build --target <TargetName>
swift test --filter <TargetName>Tests
```
