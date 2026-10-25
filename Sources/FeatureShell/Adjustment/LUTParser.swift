import Foundation
import Domain

/// Bộ phân tích cú pháp tệp 3D LUT chuẩn `.cube` (Adobe / DaVinci Resolve).
/// Chuyển đổi dữ liệu bảng tra màu 3D thành khối bộ nhớ RGBA Float cho bộ lọc `CIColorCube`.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) của AGENTS.md.
public enum LUTParser {
    private static let cache = LRUCache<Int, ParsedCube>(capacity: 16)

    public struct ParsedCube: Sendable {
        public let dimension: Int
        public let cubeData: Data
    }

    /// Phân tích nội dung chuỗi văn bản của tệp `.cube` thành `ParsedCube` (có bộ nhớ đệm LRU).
    public static func parse(cubeString: String) -> ParsedCube? {
        guard !cubeString.isEmpty else { return nil }
        let cacheKey = cubeString.hashValue
        if let cached = cache.get(cacheKey) {
            return cached
        }
        var dimension: Int?
        var rgbValues: [Float] = []

        let lines = cubeString.components(separatedBy: .newlines)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("TITLE") {
                continue
            }

            if line.hasPrefix("LUT_3D_SIZE") {
                let parts = line.split(separator: " ").map { String($0) }
                if parts.count >= 2, let dim = Int(parts[1]), dim >= 2 && dim <= 65 {
                    dimension = dim
                }
                continue
            }

            if line.hasPrefix("DOMAIN_MIN") || line.hasPrefix("DOMAIN_MAX") || line.hasPrefix("LUT_1D_SIZE") {
                continue
            }

            let components = line.split(whereSeparator: { $0.isWhitespace }).compactMap { Float($0) }
            if components.count >= 3 {
                rgbValues.append(components[0])
                rgbValues.append(components[1])
                rgbValues.append(components[2])
                rgbValues.append(1.0) // Kênh Alpha luôn là 1.0 cho CIColorCube
            }
        }

        guard let dim = dimension else { return nil }
        let expectedTotalFloats = dim * dim * dim * 4
        guard rgbValues.count == expectedTotalFloats else { return nil }

        let data = rgbValues.withUnsafeBufferPointer { Data(buffer: $0) }
        let parsed = ParsedCube(dimension: dim, cubeData: data)
        cache.set(parsed, for: cacheKey)
        return parsed
    }

    /// Đọc và phân tích tệp `.cube` từ đường dẫn URL cục bộ.
    public static func parse(fileURL: URL) -> ParsedCube? {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        return parse(cubeString: content)
    }
}
