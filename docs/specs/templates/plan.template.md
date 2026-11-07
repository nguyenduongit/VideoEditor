# Technical Implementation Plan: [FEATURE NAME]

**Spec Reference**: `specs/[feature-id]/spec.md`  
**Blueprint**: [e.g., platforms/apple/blueprints/macos-app OR platforms/web/blueprints/nextjs-supabase]  
**Status**: Plan Gate Draft | Approved  

---

## 1. Architecture Alignment & Target Modules

### Affected Modules & File Targets
| Module / Layer | Files to Create / Modify | Responsibility |
|---|---|---|
| **Contracts / Domain** | `[Path to file]` | Entities, DTOs, Repository Protocols |
| **Infrastructure / Edge** | `[Path to file]` | Concrete storage, DB migrations, API routes |
| **UI Components (C0-C2)** | `[Path to file]` | Presentational components, Organisms |
| **Screens / Routes (C3)** | `[Path to file]` | Orchestration, ViewModel / TanStack Query |

---

## 2. Interface Contracts & Boundary Changes

### New / Modified Types & Protocols
```text
[Provide draft type signatures, Zod schemas, or Swift protocol definitions]
```

### Dependency Inversion Check
- [ ] Domain / Contracts does NOT import UI or Infrastructure.
- [ ] Peer feature targets do not import each other directly.
- [ ] Dependencies injected at Composition Root.

---

## 3. Concurrency, State & Security Plan
* **State Strategy**: [Swift @Observable ViewModel OR Web URL-First + TanStack Query]
* **Concurrency / Isolation**: [Swift @MainActor & dedicated background actor OR Serverless Edge runtime]
* **Security & Auth**: [macOS Sandbox & Security Bookmarks OR Supabase Postgres RLS policies]

---

## 4. Verification & Testing Strategy
* **Unit Tests**: `[List of test suites to author]`
* **Contract Tests**: `[Boundary schema validation tests]`
* **CLI Command**: `[e.g., swift test --filter ... OR npm run type-check && npm test]`
* **Quality Gate Threshold**: Zero compilation errors, 0 warnings, verbatim terminal output.
