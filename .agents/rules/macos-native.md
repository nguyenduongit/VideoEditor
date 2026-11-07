# Apple Platform Rule: macOS Desktop Native Integration

> **Identifier:** `platforms/apple/rules/macos-native.md`  
> **Status:** Platform Invariant  
> **Target:** macOS 14.0+ (Sonoma, Sequoia)

---

## 1. Window Management & Menu Commands
* **Explicit Window Identifiers:** Every window (`WindowGroup`, `Settings`, `Window`) must declare a stable identifier string.
* **State Restoration:** Restore window sizes and positions via `@SceneStorage` or NSWindow autosave name.
* **Centralized Menu Commands:** Consolidate keyboard shortcuts and menu bar commands in a dedicated `Commands` module.
* **Respect Standard OS Shortcuts:** Never hijack standard macOS shortcuts:
  * `Cmd+Q` (Quit), `Cmd+W` (Close Window), `Cmd+M` (Minimize), `Cmd+H` (Hide), `Cmd+,` (Preferences/Settings).

---

## 2. App Sandbox & Security-Scoped Bookmarks
* **User-Selected File Access:** Any file access outside the application sandbox container must originate from `NSOpenPanel` or `NSSavePanel`.
* **Security-Scoped Bookmarks:** When a user grants access to a file or folder, persist its bookmark with the security-scoped option:
  ```swift
  let bookmarkData = try url.bookmarkData(
      options: .withSecurityScope,
      includingResourceValuesForKeys: nil,
      relativeTo: nil
  )
  ```
* **Mandatory Bracketing Pattern:** When accessing a resolved bookmark URL:
  ```swift
  guard url.startAccessingSecurityScopedResource() else {
      throw AppError.permissionDenied("Security-scoped access failed for: \(url.path)")
  }
  defer { url.stopAccessingSecurityScopedResource() }
  // Perform file I/O safely
  ```

---

## 3. macOS Keychain & Diagnostic Privacy
* **Keychain Services:** Passwords, API tokens, and cryptographic keys must be stored in the macOS Keychain (`kSecClassGenericPassword`), never in `UserDefaults` or disk files.
* **Diagnostic Logging (`OSLog`):** Use unified logging via `Logger(subsystem:category:)`. Ensure privacy flags are appropriately set so sensitive strings are masked (`<private>`).
