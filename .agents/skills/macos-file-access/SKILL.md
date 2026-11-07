---
name: macos-file-access
description: >-
  Use this skill when implementing file system operations under macOS App Sandbox.
  Covers NSOpenPanel, NSSavePanel, Security-Scoped Bookmarks, and permission bracketing.
---

# Technology Skill: macOS Sandboxed File Access

## Objective
Safely request, access, and persist file system permissions across application launches under the macOS App Sandbox.

---

## Canonical Implementation Patterns

### 1. Requesting User Access via NSOpenPanel
```swift
import AppKit

@MainActor
public func selectDocumentFolder() throws -> URL {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = String(localized: "Grant Access")

    guard panel.runModal() == .OK, let selectedURL = panel.url else {
        throw AppError.permissionDenied("User cancelled folder selection.")
    }
    return selectedURL
}
```

### 2. Persisting Security-Scoped Bookmark
```swift
public func createSecurityBookmark(for url: URL) throws -> Data {
    try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
}
```

### 3. Accessing File via Bookmark with Safe Bracketing
```swift
public func accessBookmark(data: Data, perform: (URL) throws -> Void) throws {
    var isStale = false
    let resolvedURL = try URL(
        resolvingBookmarkData: data,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    )

    guard resolvedURL.startAccessingSecurityScopedResource() else {
        throw AppError.permissionDenied("Failed to access security-scoped resource.")
    }
    defer { resolvedURL.stopAccessingSecurityScopedResource() }

    try perform(resolvedURL)
}
```
