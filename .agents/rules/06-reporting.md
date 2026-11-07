# AAS Core Rule: Agent Completion Reporting

> **Identifier:** `core/rules/06-reporting.md`  
> **Status:** Mandatory Invariant  
> **Target:** All Languages, Platforms, and Workspaces

---

## 1. Reporting Requirements

Upon completing any task, the agent must output a structured completion report formatted according to the template below.

The report serves as a formal contract of work delivered, providing complete transparency into changes, verification evidence, and pending debt.

---

## 2. Standard Report Specification

```markdown
### 1. SUMMARY OF CHANGES
- [x] Objective: [Concise description of the task completed]
- [x] Modified / Created Files:
  - `Path/To/File1.swift` (Layer / Role)
  - `Path/To/File2.swift` (Layer / Role)
- [x] Code Metrics: Largest file: N lines, longest function: N lines.

### 2. VERIFICATION EVIDENCE (RAW TERMINAL OUTPUT)
Command Executed: `[Exact shell command, e.g. swift test --filter ModuleTests]`
Exit Code: `0`
Verbatim Output:
```text
[Paste raw command output from terminal here]
```

### 3. PENDING VIOLATIONS & UNRELATED DEBT
- [Observed but left untouched due to scope bounds]: [e.g., File LegacyManager.swift exceeds 300 lines and contains force unwraps]

### 4. RISKS & USER DECISIONS REQUIRED
- [Action required from human engineer, e.g., Grant entitlement in Xcode, review migration script]
```
