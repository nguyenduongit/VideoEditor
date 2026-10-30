import Foundation
import Observation
import Domain

@Observable
@MainActor
public final class StockLibraryViewModel {
    public static let categories: [String] = [
        "Tất cả",
        "Màu nền",
        "Video mẫu"
    ]

    public var selectedCategory: String = "Tất cả"
    public var searchQuery: String = ""
    public var isLoading: Bool = false
    public var items: [StockLibraryItem] = []

    public var onAddStockItem: ((StockLibraryItem) -> Void)?

    public init() {
        self.items = Self.defaultStockItems
        Task { [weak self] in
            await self?.loadOnlineStockItems()
        }
    }

    public var filteredItems: [StockLibraryItem] {
        var result = items
        if selectedCategory != "Tất cả" {
            result = result.filter { $0.category == selectedCategory }
        }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { item in
                item.title.lowercased().contains(query) ||
                item.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }
        return result
    }

    public func selectCategory(_ category: String) {
        selectedCategory = category
    }

    public func addItemToTimeline(_ item: StockLibraryItem) {
        onAddStockItem?(item)
    }

    public func loadOnlineStockItems() async {
        guard let url = URL(string: "https://cbtfcbkczilkwngrxwgt.supabase.co/rest/v1/stock_items?select=*") else { return }
        var request = URLRequest(url: url)
        let key = ProcessInfo.processInfo.environment["SUPABASE_PUBLISHABLE_KEY"] ?? "sb_publishable_slaMIVdTU6RIrJJi9nSqEw_lh2CSGXL"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
            struct RemoteStockRow: Decodable {
                let id: String
                let title: String
                let category: String
                let media_type: String
                let preview_url: String?
                let duration: Double?
                let tags: [String]?
                let is_pro: Bool?
            }
            let rows = try JSONDecoder().decode([RemoteStockRow].self, from: data)
            if !rows.isEmpty {
                self.items = rows.map { row in
                    StockLibraryItem(
                        id: row.id,
                        title: row.title,
                        category: row.category,
                        mediaType: row.media_type,
                        previewURL: row.preview_url,
                        duration: row.duration,
                        tags: row.tags ?? [],
                        isPro: row.is_pro ?? false
                    )
                }
            }
        } catch {
            // Giữ lại defaultStockItems nếu mất mạng hoặc lỗi giải mã
        }
    }

    public static let defaultStockItems: [StockLibraryItem] = [
        StockLibraryItem(
            id: "stock_black_screen",
            title: "Màn hình đen",
            category: "Màu nền",
            mediaType: "solid_color",
            duration: 5.0,
            tags: ["black", "matte", "background", "procedural", "infinite"]
        )
    ]
}
