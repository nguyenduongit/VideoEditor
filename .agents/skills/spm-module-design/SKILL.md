---
name: spm-module-design
description: >-
  Use this skill when creating, structuring, or managing Swift Package Manager modules.
  Enforces Dependency Inversion, clean target boundaries, and Package.swift settings.
---

# Technology Skill: SPM Module Design

## Objective
Structure local Swift packages to achieve strict dependency inversion, isolated compilation units, and clear module boundaries.

---

## Canonical Multi-Target Package Structure

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Infrastructure", targets: ["Infrastructure"]),
        .library(name: "UIComponents", targets: ["UIComponents"]),
        .library(name: "FeatureEditor", targets: ["FeatureEditor"]),
    ],
    targets: [
        // 1. Pure Swift Domain (Zero UI, Zero Infra)
        .target(name: "Domain", dependencies: []),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),

        // 2. Infrastructure (Implements Domain protocols)
        .target(name: "Infrastructure", dependencies: ["Domain"]),
        .testTarget(name: "InfrastructureTests", dependencies: ["Infrastructure"]),

        // 3. UI Components (Design System: C0 & C1)
        .target(name: "UIComponents", dependencies: []),

        // 4. Feature Target (C2 Organisms & C3 Screens)
        .target(name: "FeatureEditor", dependencies: ["Domain", "UIComponents"]),
        .testTarget(name: "FeatureEditorTests", dependencies: ["FeatureEditor"]),
    ]
)
```

---

## Key Invariants
1. `Domain` must NEVER import `SwiftUI`, `AppKit`, `Infrastructure`, or persistence frameworks.
2. `FeatureEditor` must NEVER import `Infrastructure` directly.
3. Feature targets must NEVER import other feature targets. Inter-feature coordination occurs via the App layer.
