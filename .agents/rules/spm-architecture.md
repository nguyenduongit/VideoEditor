# Apple Platform Rule: SPM Modular Architecture

> **Identifier:** `platforms/apple/rules/spm-architecture.md`  
> **Status:** Platform Invariant  
> **Target:** Swift Package Manager, macOS 14.0+

---

## 1. Modular Layering & Dependency Inversion

```
┌────────────────────────────────────────────────────────────────────────┐
│                    App Layer (Composition Root)                        │
│       (@main DesktopApp, WindowGroup, MenuBar, Commands, DI Container) │
└───────────────┬────────────────────────────────────────┬───────────────┘
                │                                        │
                ▼                                        ▼
┌──────────────────────────────┐        ┌────────────────────────────────┐
│       Features Modules       │        │   UIComponents / DesignSystem  │
│ (FeatureEditor, FeatureList) │◄───────┤ (Tokens, Primitives, Controls) │
└───────────────┬──────────────┘        └────────────────────────────────┘
                │
                ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Domain Module (Pure Swift)                      │
│        (Entities, Use Cases, Value Types, Repository Protocols)        │
└────────────────────────────────┬───────────────────────────────────────┘
                                 ▲
                                 │ implements protocol
┌────────────────────────────────┴───────────────────────────────────────┐
│                     Infrastructure / Data Module                       │
│        (File System, SwiftData/GRDB, URLSession, SecurityBookmarks)    │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Rigid Boundary Invariants

1. **Domain is Pure Swift:**
   * Target `Domain` imports **only `Foundation`**.
   * **STRICT PROHIBITION:** Never import `SwiftUI`, `AppKit`, `CoreData`, `SwiftData`, or `GRDB` into `Domain`.
2. **Protocol in Domain, Implementation in Infrastructure:**
   * All external interaction contracts (storage, disk, network, keychain) are declared as protocols in `Domain`.
   * Target `Infrastructure` implements these protocols.
3. **Features Never Import Infrastructure Directly:**
   * Features consume abstract Domain protocols.
   * Concrete implementations are injected at the **App Layer (Composition Root)**.
4. **Features Never Import Other Features:**
   * Feature modules are peer targets and must never import each other.
   * Inter-feature navigation and workflows must flow through Domain events/commands or a Navigation Coordinator in the App layer.

---

## 3. Command Pattern for Mutations (Single Source of Truth)
* User modifications to domain state (Add/Edit/Delete, layout transforms, parameter changes) must be modeled as immutable `Command` types in `Domain`.
* The undo/redo history must be managed by a Domain-level `UndoStack`.
* macOS `Edit -> Undo / Redo` menu commands delegate to the active domain session's `undo()` / `redo()` methods. Do not maintain parallel state in `NSUndoManager`.
