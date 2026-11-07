# Apple Platform Rule: Swift Language Standards

> **Identifier:** `platforms/apple/rules/swift-language.md`  
> **Status:** Platform Invariant  
> **Target:** Swift 6.0+, macOS 14.0+

---

## 1. Type Safety & Value Semantics
* **Value Types First:** Model Domain Entities, DTOs, Commands, and State using immutable `struct` or `enum`. Use `final class` or `actor` strictly when reference semantics, state mutation sharing, or actor isolation is required.
* **No Magic Strings or Floating Numbers:** Centralize layout constants, identifiers, and configuration metrics into typed namespaces (e.g., `enum Metric`, `enum AppConstant`).
* **Localization:** UI strings must use `String(localized: ...)` or String Catalogs (`.xcstrings`).

---

## 2. Protocol Usage: Boundaries & Dependency Inversion
* **Protocol at Architectural Boundaries:** Define protocols for interfaces crossing architectural layers:
  * Domain Repositories (`ProjectRepositoryProtocol`).
  * External Services (Network, Keychain, File I/O).
  * ViewModel contracts for complex screens (`ProjectEditorViewModelProtocol`).
* **Anti-Overengineering Rule (No Protocol Proliferation):**
  * Do NOT create protocols for internal structs, Value Objects, DTOs, stateless helpers, or single-use concrete components that have no mock or substitution requirements.
  * Avoid synthetic `Protocol + Impl` pairs when no test or architectural boundary justifies them.

---

## 3. Explicit Error Handling (Fail Fast & Loud)
* **No Swallowing Errors:**
  * **Prohibit Force Unwrap (`!`):** Strictly forbidden in production code (exemptions: `@IBOutlet` in legacy code or test assertions).
  * **Prohibit Blind `try?`:** Never use `try?` to silently swallow errors without logging or diagnostics.
* **Standardized Typed Errors:** Model subsystem errors via localized enums conforming to `LocalizedError & Sendable`:
  ```swift
  public enum AppError: LocalizedError, Sendable {
      case fileNotFound(URL)
      case permissionDenied(String)
      case encodingFailed(reason: String)
      case stateCorruption(details: String)

      public var errorDescription: String? { ... }
      public var recoverySuggestion: String? { ... }
  }
  ```

---

## 4. Complexity & Size Thresholds (Warning vs. Exception)
* **File & Function Thresholds:**
  * File size: Warn at **200 lines**, Review at **300 lines**.
  * Method size: Warn at **40 lines**, Review at **50 lines**.
  * View body: Warn at **30 lines**, Review at **40 lines**.
* **Technical Exceptions:** Code exceeding thresholds is permissible if readability and cohesion are maintained (e.g., exhaustive pattern matching enums, declarative SwiftUI layout bodies). Document the justification in code comments rather than artificially fragmenting clean logic into micro-helpers.
