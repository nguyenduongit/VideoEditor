import Foundation

/// Bảng giá trị mặc định của thuộc tính theo loại clip, tính MỘT LẦN từ descriptor built-in.
/// Là hằng số dữ liệu bất biến (không phải singleton có trạng thái — R3.3), dùng cho init của model
/// để không phải phụ thuộc vào registry được inject.
public enum BuiltInClipPropertyDefaults {
    private static let table: [ClipKind: [String: PropertyValue]] = {
        let registry = ClipPropertyRegistry()
        var result: [ClipKind: [String: PropertyValue]] = [:]
        for kind in ClipKind.allCases {
            result[kind] = registry.defaultProperties(for: kind)
        }
        return result
    }()

    public static func properties(for kind: ClipKind) -> [String: PropertyValue] {
        table[kind] ?? [:]
    }
}
