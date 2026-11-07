---
name: swiftui-components
description: >-
  Use this skill when designing or implementing SwiftUI views for macOS.
  Enforces the 4-level component hierarchy (C0-C3), Observation framework state isolation,
  and anti-overengineering rules.
---

# Technology Skill: SwiftUI Component Architecture

## Objective
Build maintainable, high-performance macOS SwiftUI components following the 4-level hierarchy and clean state separation.

---

## 4-Level Implementation Guide

### Level 0: Design Tokens & Primitives (`UIComponents/Tokens/` or `Primitives/`)
* Define colors, typography, and AppKit representables.
* Example: Custom blur vibrancy modifier or NSViewRepresentable wrapper.

### Level 1: Generic Controls (`UIComponents/Controls/`)
* Pure reusable controls. Only accepts primitives or `@Binding`. Emits closures.
* No Domain imports permitted.
```swift
public struct ScrubberSlider: View {
    @Binding public var value: Double
    public let range: ClosedRange<Double>
    public let onScrubEnd: () -> Void

    public var body: some View { ... }
}
```

### Level 2: Domain Organisms (`Features/<Name>/Components/`)
* Business-aware composite components. Consumes Domain entities; emits action closures.
* No internal ViewModels, no direct async I/O.
```swift
public struct DocumentRowView: View {
    public let document: DocumentEntity
    public let onSelect: (DocumentEntity) -> Void
    public let onDelete: (DocumentEntity) -> Void

    public var body: some View { ... }
}
```

### Level 3: Screens & Windows (`Features/<Name>/Screens/`)
* Holds the `@State` ViewModel using Observation framework. Handles toolbars and shortcuts.
```swift
@MainActor
public struct DocumentEditorScreen: View {
    @State private var viewModel: DocumentEditorViewModel

    public var body: some View {
        NavigationSplitView { ... } detail: { ... }
            .toolbar { ... }
    }
}
```

---

## Anti-Patterns to Avoid
1. **Never put business logic or repository calls inside a View body or `.task` block directly.**
2. **Never mix high-frequency state (dragging, scrubber position) into the main ViewModel.** Isolate it in a C1/C2 child view.
3. **Never create single-use wrapper views without distinct styling or behavior.**
