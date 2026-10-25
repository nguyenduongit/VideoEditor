import SwiftUI
import CoreText
import AppKit

/// Đại diện cho một phông chữ có thể chọn trong ứng dụng.
public struct CustomFontItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: String           // PostScript name (dùng để gán cho NSFont)
    public let displayName: String  // Tên hiển thị người dùng (vd: UVN Bạch Đằng)
    public let isCustom: Bool       // Font nạp ngoài hay font hệ thống

    public init(id: String, displayName: String, isCustom: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.isCustom = isCustom
    }
}

/// Dịch vụ quản lý, nạp động các file font và danh sách font yêu thích.
/// Hỗ trợ quét Sources/Font, Bundle Resources và ~/Library/Application Support/VideoEditor/Fonts.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
@MainActor
@Observable
public final class CustomFontManager {
    public static let shared = CustomFontManager()

    public private(set) var fonts: [CustomFontItem] = []
    public private(set) var favoriteFontIDs: Set<String> = []
    public private(set) var isLoaded: Bool = false

    private let favoritesKey = "VideoEditor_FavoriteFonts"

    private let defaultSystemFonts: [CustomFontItem] = [
        CustomFontItem(id: "System", displayName: "System"),
        CustomFontItem(id: "Helvetica", displayName: "Helvetica"),
        CustomFontItem(id: "Arial", displayName: "Arial"),
        CustomFontItem(id: "Impact", displayName: "Impact"),
        CustomFontItem(id: "Times New Roman", displayName: "Times New Roman"),
        CustomFontItem(id: "Courier New", displayName: "Courier New"),
        CustomFontItem(id: "Georgia", displayName: "Georgia"),
        CustomFontItem(id: "Trebuchet MS", displayName: "Trebuchet MS"),
        CustomFontItem(id: "Avenir Next", displayName: "Avenir Next"),
        CustomFontItem(id: "Futura", displayName: "Futura")
    ]

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

    /// Trả về 2 danh sách: [Yêu thích] và [Các font còn lại], có hỗ trợ lọc theo từ khóa tìm kiếm.
    public func sortedFonts(matching query: String = "") -> (favorites: [CustomFontItem], others: [CustomFontItem]) {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = fonts.filter {
            cleanQuery.isEmpty || $0.displayName.lowercased().contains(cleanQuery) || $0.id.lowercased().contains(cleanQuery)
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
        var allItems = defaultSystemFonts
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
        return CustomFontItem(id: postScript, displayName: display, isCustom: true)
    }
}
