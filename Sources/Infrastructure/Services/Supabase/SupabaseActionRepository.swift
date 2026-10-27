import Foundation
import Domain
import Supabase
import os

/// Hiện thực kho lưu trữ Custom Actions thuần Online qua Supabase Database và RAM cache.
/// Tuyệt đối không ghi file đĩa cục bộ theo yêu cầu hệ thống chỉ lưu trữ Online.
/// Tuân thủ AGENTS.md R2.1 (Infrastructure hiện thực hóa Domain Protocol) và R3.1 (File <= 300 dòng).
public final class SupabaseActionRepository: ActionRepositoryProtocol, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.videoeditor", category: "SupabaseActionRepository")
    private let client: SupabaseClient?
    private let tableName = "custom_actions"

    private var inMemoryActions: [CustomAction] = CustomAction.defaultActions
    private let lock = NSLock()

    public init(client: SupabaseClient? = SupabaseConfig.makeClient()) {
        self.client = client
        self.inMemoryActions = CustomAction.defaultActions
    }

    public func fetchActions() async throws -> [CustomAction] {
        guard let client else {
            return getCachedActions()
        }

        // Tải danh sách trực tiếp từ Supabase
        do {
            let rows: [CustomActionRow] = try await client
                .from(tableName)
                .select()
                .execute()
                .value

            let fetched = rows.map { $0.toAction() }
                .filter { !$0.isSystem && !$0.id.hasPrefix("default_action_") }

            var merged = CustomAction.defaultActions
            for action in fetched {
                if !merged.contains(where: { $0.id == action.id }) {
                    merged.append(action)
                }
            }

            lock.withLock {
                inMemoryActions = merged
            }

            return merged
        } catch {
            // Mạng lỗi hoặc bảng chưa sẵn sàng: Sử dụng RAM hiện có
            return getCachedActions()
        }
    }

    public func saveAction(_ action: CustomAction) async throws {
        // 1. Cập nhật RAM cache tức thì
        lock.withLock {
            if let idx = inMemoryActions.firstIndex(where: { $0.id == action.id }) {
                inMemoryActions[idx] = action
            } else {
                inMemoryActions.append(action)
            }
        }

        // 2. Lưu trực tiếp lên Supabase Online
        guard let client else {
            NotificationCenter.default.post(name: .actionStoreDidUpdate, object: nil)
            return
        }

        let row = CustomActionRow(from: action)
        do {
            try await client
                .from(tableName)
                .upsert(row)
                .execute()
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain && (ns.code == NSURLErrorNetworkConnectionLost || ns.code == NSURLErrorTimedOut) {
                try await Task.sleep(nanoseconds: 300_000_000)
                do {
                    try await client
                        .from(tableName)
                        .upsert(row)
                        .execute()
                } catch {
                    Self.logger.error("Failed to retry saving action to Supabase: \(error.localizedDescription)")
                    throw error
                }
            } else {
                Self.logger.error("Failed to save action to Supabase: \(error.localizedDescription)")
                throw error
            }
        }

        NotificationCenter.default.post(name: .actionStoreDidUpdate, object: nil)
    }

    public func deleteAction(id: String) async throws {
        // 1. Xóa khỏi RAM cache
        lock.withLock {
            inMemoryActions.removeAll { $0.id == id }
        }

        // 2. Xóa trực tiếp trên Supabase Online
        guard let client else {
            NotificationCenter.default.post(name: .actionStoreDidUpdate, object: nil)
            return
        }

        do {
            try await client
                .from(tableName)
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            // Ghi nhận lỗi nhưng không chặn luồng
        }

        NotificationCenter.default.post(name: .actionStoreDidUpdate, object: nil)
    }

    private func getCachedActions() -> [CustomAction] {
        lock.withLock {
            inMemoryActions
        }
    }
}

// MARK: - Supabase DTO Row

private struct CustomActionRow: Codable, Sendable {
    let id: String
    let name: String
    let icon: String?
    let task_ids: [String]
    let title_text: String?
    let title_preset_id: String?
    let created_at: String?
    let is_system: Bool?

    init(from action: CustomAction) {
        self.id = action.id
        self.name = action.name
        self.icon = action.icon
        self.task_ids = action.taskIDs
        self.title_text = action.titleText
        self.title_preset_id = action.titlePresetID
        self.created_at = ISO8601DateFormatter().string(from: action.createdAt)
        self.is_system = action.isSystem
    }

    func toAction() -> CustomAction {
        let date = created_at.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        return CustomAction(
            id: id,
            name: name,
            icon: icon ?? "play.fill",
            taskIDs: task_ids,
            titleText: title_text,
            titlePresetID: title_preset_id,
            createdAt: date,
            isSystem: is_system ?? false
        )
    }
}
