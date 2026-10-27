import SwiftUI
import CoreText
import AppKit

/// Phân loại danh mục phong cách phông chữ trong hệ thống biên tập video.
public enum FontCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "Tất cả"
    case calligraphy = "Thư pháp"
    case handwriting = "Viết tay"
    case headline = "Tiêu đề"
    case comic = "Hoạt hình"
    case vintage = "Cổ điển"
    case subtitle = "Phụ đề"

    public var id: String { rawValue }
}

/// Đại diện cho một phông chữ có thể chọn trong ứng dụng.
public struct CustomFontItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: String           // PostScript name (dùng để gán cho NSFont)
    public let displayName: String  // Tên hiển thị người dùng (vd: UVN Bạch Đằng)
    public let isCustom: Bool       // Font nạp ngoài hay font hệ thống
    public let category: FontCategory // Phân loại danh mục font

    public init(id: String, displayName: String, isCustom: Bool = false, category: FontCategory = .headline) {
        self.id = id
        self.displayName = displayName
        self.isCustom = isCustom
        self.category = category
    }
}

/// Dịch vụ quản lý, nạp động các file font và danh sách font yêu thích.
/// Hỗ trợ quét Sources/Font, Bundle Resources và ~/Library/Application Support/VideoEditor/Fonts.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
@MainActor
@Observable
public final class CustomFontManager {
    public private(set) var fonts: [CustomFontItem] = []
    public private(set) var favoriteFontIDs: Set<String> = []
    public private(set) var isLoaded: Bool = false

    private let favoritesKey = "VideoEditor_FavoriteFonts"

    public init() {
        loadFavorites()
        loadFonts()
    }

    public func toggleFavorite(fontID: String) {
        if favoriteFontIDs.contains(fontID) {
            favoriteFontIDs.remove(fontID)
        } else {
            favoriteFontIDs.insert(fontID)
        }
        UserDefaults.standard.set(Array(favoriteFontIDs), forKey: favoritesKey)
    }

    public func isFavorite(fontID: String) -> Bool {
        favoriteFontIDs.contains(fontID)
    }

    public func displayName(for fontID: String) -> String {
        fonts.first(where: { $0.id == fontID })?.displayName ?? fontID
    }

    /// Trả về 2 danh sách: [Yêu thích] và [Các font còn lại], có hỗ trợ lọc theo từ khóa tìm kiếm và danh mục.
    public func sortedFonts(
        matching query: String = "",
        category: FontCategory = .all
    ) -> (favorites: [CustomFontItem], others: [CustomFontItem]) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = fonts.filter { item in
            let matchesCategory = (category == .all) || (item.category == category)
            guard matchesCategory else { return false }
            return cleanQuery.isEmpty
                || item.displayName.lowercased().contains(cleanQuery)
                || item.id.lowercased().contains(cleanQuery)
        }

        var favs: [CustomFontItem] = []
        var others: [CustomFontItem] = []

        for item in filtered {
            if favoriteFontIDs.contains(item.id) {
                favs.append(item)
            } else {
                others.append(item)
            }
        }

        favs.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        others.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        return (favs, others)
    }

    // MARK: - Internal Font Loading

    private func loadFavorites() {
        if let saved = UserDefaults.standard.stringArray(forKey: favoritesKey) {
            favoriteFontIDs = Set(saved)
        }
    }

    public func loadFonts() {
        var allItems: [CustomFontItem] = []
        var registeredURLs: [URL] = []

        for dir in discoverFontDirectories() {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            if let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                let fontFiles = urls.filter { ["ttf", "otf"].contains($0.pathExtension.lowercased()) }
                registeredURLs.append(contentsOf: fontFiles)
            }
        }

        if !registeredURLs.isEmpty {
            CTFontManagerRegisterFontURLs(registeredURLs as CFArray, .process, false, nil)
            for url in registeredURLs {
                if let item = extractFontItem(from: url) {
                    if !allItems.contains(where: { $0.id == item.id }) {
                        allItems.append(item)
                    }
                }
            }
        }

        allItems.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        self.fonts = allItems
        self.isLoaded = true
    }

    private func discoverFontDirectories() -> [URL] {
        var dirs: [URL] = []

        // 1. Thư mục Sources/Font trong dự án (Dev)
        let cwd = FileManager.default.currentDirectoryPath
        let projectFontDir = URL(fileURLWithPath: cwd).appendingPathComponent("Sources/Font")
        dirs.append(projectFontDir)

        // 2. Thư mục Resources/Font trong App Bundle (.app)
        if let bundleResources = Bundle.main.resourceURL {
            dirs.append(bundleResources.appendingPathComponent("Font"))
        }

        // 3. Thư mục mở rộng của người dùng trong Application Support
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let userFontsDir = appSupport.appendingPathComponent("VideoEditor/Fonts")
            try? FileManager.default.createDirectory(at: userFontsDir, withIntermediateDirectories: true)
            dirs.append(userFontsDir)
        }

        return dirs
    }

    private func extractFontItem(from url: URL) -> CustomFontItem? {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let desc = descriptors.first else {
            return nil
        }
        let font = CTFontCreateWithFontDescriptor(desc, 12.0, nil)
        let postScript = (CTFontCopyPostScriptName(font) as String)
        let display = (CTFontCopyDisplayName(font) as String)
        let category = Self.resolveCategory(for: postScript, displayName: display)
        return CustomFontItem(id: postScript, displayName: display, isCustom: true, category: category)
    }

    /// Tự động phân loại danh mục nghệ thuật dựa trên tên PostScript và tên hiển thị của font.
    public static func resolveCategory(for itemID: String, displayName: String) -> FontCategory {
        let name = (itemID + " " + displayName).lowercased()

        // 1. Thư pháp & Bút lông
        if name.contains("thuphap") || name.contains("thu phap") || name.contains("ong do")
            || name.contains("ong-do") || name.contains("shodo") || name.contains("brush") {
            return .calligraphy
        }

        // 2. Viết tay & Uốn lượn (Script, Cursive)
        if name.contains("script") || name.contains("cursive") || name.contains("smooch")
            || name.contains("rukola") || name.contains("bucthu") || name.contains("buc thu")
            || name.contains("benxuan") || name.contains("ben xuan") {
            return .handwriting
        }

        // 3. Hoạt hình & Vui nhộn (Comic, Pop, Cute)
        if name.contains("nabila") || name.contains("pony") || name.contains("koni")
            || name.contains("soupofjustice") || name.contains("soup of justice")
            || name.contains("banhmi") || name.contains("banh mi")
            || name.contains("mangcau") || name.contains("mang cau") {
            return .comic
        }

        // 4. Phụ đề & Tối giản (Subtitle, Monospace)
        if name.contains("tahoma") || name.contains("courier") {
            return .subtitle
        }

        // 5. Cổ điển & Điện ảnh (Vintage, Retro, Phim, Serif)
        if name.contains("sacredbridge") || name.contains("sacred bridge") || name.contains("phuong khau")
            || name.contains("hottroof") || name.contains("mijas") || name.contains("cadena")
            || name.contains("arid") || name.contains("buidoi") || name.contains("bui doi")
            || name.contains("phuongtay") || name.contains("phuong tay") || name.contains("thangvu")
            || name.contains("thang vu") || name.contains("kechuyen") || name.contains("ke chuyen")
            || name.contains("uvnvan") || (name.contains("van") && !name.contains("baisau")) {
            return .vintage
        }

        // 6. Tiêu đề Đậm & Hiện đại
        return .headline
    }
}
