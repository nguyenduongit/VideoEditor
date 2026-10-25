import Foundation

/// Bộ nạp và đồng bộ các file kịch bản JSON mẫu chỉnh màu (Adjustment Template Scripts) từ Local Disk, Bundle và Supabase Cache.
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public final class AdjustmentTemplateLoader: @unchecked Sendable {
    public static let shared = AdjustmentTemplateLoader()

    private let lock = NSLock()
    private var cachedTemplates: [AdjustmentPreset]?

    public init() {}

    /// Nạp toàn bộ danh sách AdjustmentPreset từ các thư mục `.json` (có cache trong bộ nhớ, gọi `reload()` khi cập nhật từ Supabase).
    public func loadAllTemplates(forceReload: Bool = false) -> [AdjustmentPreset] {
        lock.lock()
        if !forceReload, let cached = cachedTemplates, !cached.isEmpty {
            lock.unlock()
            return cached
        }
        lock.unlock()

        var byID: [String: AdjustmentPreset] = [:]
        var orderedIDs: [String] = []

        for dir in discoverTemplateDirectories() {
            let loaded = loadTemplatesFromDirectory(dir)
            for item in loaded {
                if byID[item.id] == nil {
                    orderedIDs.append(item.id)
                }
                byID[item.id] = item
            }
        }

        let result = orderedIDs.compactMap { byID[$0] }
        let finalTemplates = result.isEmpty ? Self.fallbackBuiltInTemplates : result

        lock.lock()
        cachedTemplates = finalTemplates
        lock.unlock()
        return finalTemplates
    }

    /// Xóa bộ nhớ đệm và nạp lại từ đĩa (gọi sau khi đồng bộ kịch bản JSON mới từ Supabase)
    @discardableResult
    public func reload() -> [AdjustmentPreset] {
        loadAllTemplates(forceReload: true)
    }

    /// Đọc toàn bộ các file `*.json` trong một thư mục chỉ định
    public func loadTemplatesFromDirectory(_ directoryURL: URL) -> [AdjustmentPreset] {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return [] }
        // Giải thích try?: Bỏ qua an toàn nếu thư mục chưa tồn tại hoặc không có quyền đọc
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let jsonFiles = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        var presets: [AdjustmentPreset] = []
        for fileURL in jsonFiles {
            // Giải thích try?: Bỏ qua file JSON bị lỗi định dạng mà không làm gián đoạn các file khác (R5.6)
            if let data = try? Data(contentsOf: fileURL),
               let preset = try? JSONDecoder().decode(AdjustmentPreset.self, from: data) {
                presets.append(preset)
            }
        }
        return presets
    }

    /// Giải mã danh sách JSON trả về từ bảng `adjustment_templates` trên Supabase và lưu xuống bộ nhớ đệm cục bộ
    public func mergeSupabaseTemplateScripts(_ jsonPayloads: [String], persistToCache: Bool = true) -> [AdjustmentPreset] {
        var decodedPresets: [AdjustmentPreset] = []
        for payload in jsonPayloads {
            guard let preset = AdjustmentPreset.decode(from: payload) else { continue }
            decodedPresets.append(preset)
            if persistToCache {
                _ = saveTemplateToUserCache(preset)
            }
        }
        var current = loadAllTemplates(forceReload: true)
        if !persistToCache {
            for preset in decodedPresets {
                if let idx = current.firstIndex(where: { $0.id == preset.id }) {
                    current[idx] = preset
                } else {
                    current.append(preset)
                }
            }
            lock.lock()
            cachedTemplates = current
            lock.unlock()
        }
        return current
    }

    /// Lưu 1 mẫu `AdjustmentPreset` thành file `<id>.json` trong thư mục cache Application Support
    public func saveTemplateToUserCache(_ preset: AdjustmentPreset) -> URL? {
        guard let cacheDir = userCacheDirectory(),
              let json = preset.encodeToJSON(prettyPrinted: true),
              let data = json.data(using: .utf8) else { return nil }
        let safeID = preset.id.replacingOccurrences(of: "/", with: "_")
        let fileURL = cacheDir.appendingPathComponent("\(safeID).json")
        // Giải thích try?: Trả về nil nếu ổ đĩa đầy hoặc không ghi được file cache
        guard (try? data.write(to: fileURL, options: .atomic)) != nil else { return nil }
        return fileURL
    }

    /// Khám phá các thư mục chứa file JSON kịch bản mẫu chỉnh màu theo thứ tự ưu tiên
    public func discoverTemplateDirectories() -> [URL] {
        var dirs: [URL] = []

        // 1. Thư mục Sources/AdjustmentTemplates định vị qua #filePath (luôn chính xác khi chạy dev & test)
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let repoTemplatesDir = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AdjustmentTemplates")
        dirs.append(repoTemplatesDir)

        // 2. Thư mục Sources/AdjustmentTemplates tính từ working directory hiện tại
        let cwdDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/AdjustmentTemplates")
        if cwdDir.path != repoTemplatesDir.path {
            dirs.append(cwdDir)
        }

        // 3. Thư mục Resources/AdjustmentTemplates trong gói ứng dụng (.app Bundle)
        if let bundleResources = Bundle.main.resourceURL {
            dirs.append(bundleResources.appendingPathComponent("AdjustmentTemplates"))
        }

        // 4. Thư mục đồng bộ từ Supabase trong Application Support
        if let cacheDir = userCacheDirectory() {
            dirs.append(cacheDir)
        }

        return dirs
    }

    private func userCacheDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("VideoEditor/AdjustmentTemplates")
        // Giải thích try?: Bỏ qua nếu thư mục đã tồn tại
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static let fallbackBuiltInTemplates: [AdjustmentPreset] = [
        AdjustmentPreset(
            id: "cinematic",
            name: "Điện ảnh",
            description: "Tông Teal & Orange tương phản chuẩn Hollywood",
            category: .cinematic,
            previewBadge: "HOLLYWOOD",
            previewColorsHex: ["#1A8099", "#D97326"],
            config: {
                var hsl = HSLAdjustments()
                hsl.orange = HSLChannel(hue: -15, saturation: 20, luminance: 10)
                hsl.blue = HSLChannel(hue: -10, saturation: 35, luminance: -10)
                hsl.cyan = HSLChannel(hue: 5, saturation: 25, luminance: -5)
                return AdjustmentConfiguration(
                    basic: BasicGradingParameters(
                        temp: 15, tint: 5, saturation: 5,
                        exposure: 2, contrast: 18, highlight: -20, shadow: 15,
                        white: 5, black: -5, brilliance: 12
                    ),
                    hsl: hsl
                )
            }()
        )
    ]
}
