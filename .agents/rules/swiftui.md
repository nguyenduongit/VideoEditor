# Apple Platform Rule: SwiftUI Component Architecture

> **Identifier:** `platforms/apple/rules/swiftui.md`  
> **Status:** Platform Invariant  
> **Target:** SwiftUI, macOS 14.0+ (Observation Framework)

---

## 1. The 4-Tier Component Hierarchy

UI components must be categorized into one of four distinct levels with strict boundary responsibilities:

```
[ C0: Tokens & Primitives ]  ──► Semantic colors, typography, AppKit wrappers (NSViewRepresentable)
              ▼
[ C1: Generic Controls ]     ──► Reusable across apps; receives primitives/bindings; zero Domain imports
              ▼
[ C2: Domain Organisms ]     ──► Bound to Domain entities/protocols; emits action closures; NO direct I/O
              ▼
[ C3: Screens & Windows ]    ──► Owns ViewModel (@Observable); window lifecycle; toolbars; shortcuts
```

### Level 0: Design Tokens & Primitives
* **Responsibility:** Visual foundation, semantic typography, colors, vibrancy modifiers, primitive AppKit bridges.
* **Location:** `UIComponents/Tokens/` or `UIComponents/Primitives/`.
* **Prohibitions:** Must never contain business logic or import Domain entities.

### Level 1: Generic Controls & Molecules
* **Responsibility:** Desktop controls (custom search field, scrubber slider, status badge, metric chip).
* **Location:** `UIComponents/Controls/`.
* **Rules:** Accepts primitive properties (`String`, `Double`, `Bool`) or `@Binding`. Emits events via closures (`onCommit`, `onTap`).
* **Prohibitions:** Must never import Domain; must never hold a Domain ViewModel.

### Level 2: Domain Organisms
* **Responsibility:** Composite UI blocks displaying business concepts (`ProjectRowView`, `InspectorPropertySection`, `LayerTableView`).
* **Location:** `Features/<FeatureName>/Components/`.
* **Rules:** Consumes Domain entities (value types) or display protocols. Communicates upwards via action closures (`onDelete: () -> Void`).
* **Prohibitions:** Must never instantiate ViewModels. Must never execute direct repository or service calls (no `Task { await repo.fetch() }`).

### Level 3: Screens, Windows & Sheets
* **Responsibility:** Window lifecycle (`WindowGroup`, `DocumentWindow`, `Sheet`), navigation, toolbars, keyboard shortcuts.
* **Location:** `Features/<FeatureName>/Screens/`.
* **Rules:** The sole layer permitted to instantiate and own ViewModels (`@State` with `@Observable`). Composes C0, C1, and C2 components.

---

## 2. Anti-Overengineering Directives

1. **Rule of Three:** Do not extract a view into Level 1 (Generic Control) unless it is reused in at least 2 distinct screens or forms part of the shared design system.
2. **Prohibit Single-Use Wrappers:** Never create a struct view purely to wrap built-in SwiftUI components without adding styling, interaction logic, or accessibility (e.g., do not write `CustomVStack` that merely wraps `VStack(spacing: 8)`).
3. **Maximum Nesting Depth:** Component trees must not exceed 4 levels of depth (`C3 Screen -> C2 Organism -> C1 Control -> C0 Primitive`).
4. **Isolate High-Frequency State:**
   * High-frequency updates (60/120Hz: slider dragging, scrubbing position, cursor tracking, VU meters) must be isolated into dedicated child views.
   * Never store high-frequency state in the same `@Observable` ViewModel that drives low-frequency lists or document metadata, preventing entire window re-renders.

---

## 3. Standardized View State
Screens with asynchronous loading must adopt the standard `ViewState<T>` enum:

```swift
public enum ViewState<T: Sendable>: Sendable {
    case idle
    case loading(message: String?)
    case success(T)
    case empty(title: String, description: String?, systemImage: String?)
    case failure(AppError)
}
```

---

## 4. 100% Offline Previews
SwiftUI Previews must always execute against mock ViewModels and in-memory mock data. Previews must render instantaneously without hitting disk or network.
