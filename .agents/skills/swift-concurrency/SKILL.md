---
name: swift-concurrency
description: >-
  Use this skill when designing asynchronous systems, solving Swift 6 concurrency warnings,
  managing actor isolation, or auditing Sendable conformance on macOS.
---

# Technology Skill: Swift 6 Concurrency & Actor Isolation

## Objective
Implement thread-safe, race-free asynchronous workflows under Swift 6 Complete Concurrency without dropping frames on the Main Thread.

---

## Technical Patterns

### 1. ViewModels with Observation & `@MainActor`
Always annotate presentation models with `@MainActor`:
```swift
import Observation

@Observable
@MainActor
public final class ProjectViewModel {
    public private(set) var state: ViewState<ProjectDetails> = .idle
    private let repository: ProjectRepositoryProtocol

    public init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    public func loadData() async {
        state = .loading(message: "Loading project...")
        do {
            let details = try await repository.fetchDetails()
            state = .success(details)
        } catch let error as AppError {
            state = .failure(error)
        } catch {
            state = .failure(.stateCorruption(details: error.localizedDescription))
        }
    }
}
```

### 2. Offloading Heavy Work: Structured Concurrency vs Actor
* **Dedicated Actor for Persistent Background State:**
  ```swift
  public actor ImageCacheManager {
      private var cache: [URL: Data] = [:]
      public func get(url: URL) -> Data? { cache[url] }
      public func store(_ data: Data, for url: URL) { cache[url] = data }
  }
  ```
* **Structured Concurrency for Parallel Operations:**
  ```swift
  func loadAllAssets(urls: [URL]) async throws -> [Asset] {
      try await withThrowingTaskGroup(of: Asset.self) { group in
          for url in urls {
              group.addTask { try await self.fetchAsset(url) }
          }
          var results: [Asset] = []
          for try await asset in group {
              results.append(asset)
          }
          return results
      }
  }
  ```

### 3. Resolving Sendable Warnings
* Ensure entities passed into tasks are value types (`struct`).
* For closures crossing actor boundaries, mark `@Sendable`.
* Avoid `Task.detached` unless explicitly justified in technical comments.
