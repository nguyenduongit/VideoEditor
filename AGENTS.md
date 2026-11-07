# Project Agent Constitution (Project Anchor)

> **Standard:** Antigravity Agent Standard (AAS)  
> **Status:** Active Project Governance Anchor

---

## 1. Project Configuration
```yaml
Project Name: [Project Name]
Platform: macOS (14.0+)
Language: Swift 6 (Complete Strict Concurrency)
Standards:
  AAS Core: 1.0.0
  Platform Pack: apple/1.0.0
Selected Blueprint: platforms/apple/blueprints/macos-app
State Model: Observation Framework (@Observable)
Third-Party Dependencies: None (100% Apple SDK)
Active ADRs: []
```

---

## 2. Non-Negotiable Invariants
1. **Never alter architecture or package boundaries** without Level 2/3 approval.
2. **Never add third-party dependencies** without explicit approval.
3. **Never delete verified code, tests, or validation logic**.
4. **Never swallow errors** (`try?` without logging or `!` force unwrap).
5. **Never fabricate verification results**; always provide verbatim terminal output.

---

## 3. Autonomy Gateways (Balanced Mode)
* **Level 1 (Fast Path):** Local changes ($\le 2$ files in 1 target, no interface breaks) $\rightarrow$ Execute immediately.
* **Level 2 (Plan Gate):** Multi-file ($\ge 3$ files), cross-module changes, or new features $\rightarrow$ Present plan and await approval.
* **Level 3 (Hard Barrier):** Dependencies, SPM target creation, Entitlements, file deletions $\rightarrow$ Explicit human command required.

---

## 4. Verification Protocols
Execute verification according to task risk tier:
* **SPM Packages:** `swift build` and `swift test --filter <Tests>`
* **App Target:** `xcodebuild -scheme <AppScheme> -destination 'platform=macOS' build`
* **Architecture Validation:** `bash Scripts/check_imports.sh`

---

## 5. Navigation Directory
* Core Rules: `.agents/rules/`
* Technical Skills: `.agents/skills/`
* Architecture Docs: `docs/architecture/`
* ADR Records: `docs/adr/`
