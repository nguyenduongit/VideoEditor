# Apple Platform Rule: Swift 6 Concurrency & Memory Safety

> **Identifier:** `platforms/apple/rules/swift-concurrency.md`  
> **Status:** Platform Invariant  
> **Target:** Swift 6.0 (Complete Strict Concurrency), macOS 14.0+

---

## 1. Concurrency Model & Actor Isolation
* **MainActor for UI & Presentation:** All ViewModels, screen coordinators, and UI event handlers must be isolated to `@MainActor`.
* **Dedicated Actors for Mutable Background State:** Encapsulate shared mutable state (e.g., caches, download managers, session trackers) inside independent `actor` types.
* **Sendable Enforcement:** All types crossing concurrency boundaries (Actors, Tasks, Threads) must conform to `Sendable`. Prefer value types (`struct`, `enum`) to achieve automatic sendability.

---

## 2. Structured Concurrency vs. Detached Tasks
* **Structured Concurrency as Default:** Always prefer structured concurrency primitives (`async let`, `withTaskGroup`, `withThrowingTaskGroup`) where tasks inherit priority, task-local values, and cancellation hierarchy.
* **Strict Constraints on `Task.detached`:**
  * Prohibited as a generic "run heavy work in background" hammer.
  * `Task.detached` breaks task-local context, ignores priority inheritance, and bypasses cancellation trees.
  * Only permit `Task.detached` when work explicitly requires complete detachment from the current actor context and execution lifecycle. Document the technical rationale.

---

## 3. Retain Cycles & Contextual `[weak self]`
* **Contextual Evaluation:** Do NOT mechanically enforce `[weak self]` on every asynchronous closure.
* **When `[weak self]` is Required:**
  * Escaping closures stored on long-lived reference types.
  * Long-running asynchronous streams or notification observers held by the object itself.
* **When `[weak self]` is Redundant or Harmful:**
  * Non-escaping closures (e.g., synchronous collection operations).
  * SwiftUI Value Types (`struct View`).
  * Actor methods where `self` is safe and actor isolation handles lifetime.
  * Tasks that represent atomic operations (e.g., saving user document to disk) where the operation must complete even if the presenting view dismisses.

---

## 4. Cancellation & Frame Budget
* **Responsive Main Thread:** Never perform heavy I/O, large JSON decoding, cryptography, or media processing on `@MainActor`. Drop frame rate below 60/120fps is an architectural defect.
* **Cooperative Cancellation:** In long-running loops or chunked processing, check `Task.isCancelled` or invoke `try Task.checkCancellation()`.
