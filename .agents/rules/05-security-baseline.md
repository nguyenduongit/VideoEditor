# AAS Core Rule: Security & Desktop Safety Baseline

> **Identifier:** `core/rules/05-security-baseline.md`  
> **Status:** Mandatory Invariant  
> **Target:** All Languages, Platforms, and Workspaces

---

## 1. Zero-Trust Credential Management
* **Never Commit Secrets:** API keys, passwords, certificates, auth tokens, and private keys must never be committed to Git, hardcoded in source files, or stored in plain-text configuration files (e.g., `UserDefaults`, JSON, plist).
* **Sanitize Logs:** Diagnostic log messages (`OSLog`, `print`, `NSLog`) must never contain user credentials, authorization tokens, decryption keys, or Personally Identifiable Information (PII).
* **Platform Keychain:** On macOS, credentials and sensitive tokens must be stored exclusively via macOS Keychain Services API.

---

## 2. Desktop Environment & App Sandbox
* **Respect Sandbox Boundaries:** Applications operating under App Sandbox must never attempt to bypass file access restrictions. All file access outside container directories must be user-initiated via `NSOpenPanel` / `NSSavePanel` and retained using Security-Scoped Bookmarks.
* **No Test-Driven Sandbox Disabling:** Never disable App Sandbox or remove hardened runtime entitlements simply to make a test pass or bypass an I/O error.
* **Privileged Operations:** Never execute commands that modify system directories, install global daemons, or execute unsanctioned network requests.

---

## 3. Defense Against Unsanctioned Workarounds
If an operation is blocked by permissions or security controls, the agent is blocked. Report the exact error and await human instructions; never write code to intercept, bypass, or spoof permission checks.
