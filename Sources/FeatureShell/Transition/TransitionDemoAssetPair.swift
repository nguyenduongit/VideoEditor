import AppKit
import CoreImage
import Domain
import SwiftUI

/// Thông số màu RGB dự phòng thuần kiểu giá trị Sendable.
public struct TransitionDemoColorRGB: Sendable {
    public let r: Double
    public let g: Double
    public let b: Double

    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public var ciColor: CIColor {
        CIColor(red: r, green: g, blue: b)
    }

    public var swiftUIColor: Color {
        Color(red: r, green: g, blue: b)
    }
}

/// Cấu hình mô tả cặp ảnh mẫu demo chuyển cảnh cho một danh mục.
/// Giúp dễ dàng mở rộng, bổ sung hoặc thay đổi ảnh demo khi người dùng cung cấp thêm sau này.
/// Tuân thủ AGENTS.md (Sendable, File <= 300 dòng, Hàm <= 50 dòng).
public struct TransitionDemoPairDescriptor: Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let squareNameA: String
    public let originalNameA: String
    public let squareNameB: String
    public let originalNameB: String
    public let verticalFocusA: CGFloat
    public let verticalFocusB: CGFloat
    public let fallbackColorA: TransitionDemoColorRGB
    public let fallbackColorB: TransitionDemoColorRGB

    public init(
        id: String,
        displayName: String,
        squareNameA: String,
        originalNameA: String,
        squareNameB: String,
        originalNameB: String,
        verticalFocusA: CGFloat = 0.5,
        verticalFocusB: CGFloat = 0.5,
        fallbackColorA: TransitionDemoColorRGB = TransitionDemoColorRGB(0.2, 0.5, 0.8),
        fallbackColorB: TransitionDemoColorRGB = TransitionDemoColorRGB(0.8, 0.5, 0.2)
    ) {
        self.id = id
        self.displayName = displayName
        self.squareNameA = squareNameA
        self.originalNameA = originalNameA
        self.squareNameB = squareNameB
        self.originalNameB = originalNameB
        self.verticalFocusA = verticalFocusA
        self.verticalFocusB = verticalFocusB
        self.fallbackColorA = fallbackColorA
        self.fallbackColorB = fallbackColorB
    }
}

/// Dữ liệu bộ nhớ RAM đã nạp và pre-scale sẵn sàng cho GPU của một cặp ảnh demo chuyển cảnh.
public struct TransitionDemoAssetPair: @unchecked Sendable {
    public let id: String
    public let displayName: String
    public let imageA: Image
    public let imageB: Image
    public let nsImageA: NSImage?
    public let nsImageB: NSImage?
    public let ciImageA: CIImage
    public let ciImageB: CIImage

    public init(
        id: String,
        displayName: String,
        imageA: Image,
        imageB: Image,
        nsImageA: NSImage?,
        nsImageB: NSImage?,
        ciImageA: CIImage,
        ciImageB: CIImage
    ) {
        self.id = id
        self.displayName = displayName
        self.imageA = imageA
        self.imageB = imageB
        self.nsImageA = nsImageA
        self.nsImageB = nsImageB
        self.ciImageA = ciImageA
        self.ciImageB = ciImageB
    }
}

/// Danh mục định tuyến cặp ảnh demo theo TransitionCategory.
/// Được thiết kế tập trung để khi người dùng bổ sung ảnh mới trong tương lai,
/// chỉ cần thêm Descriptor và cập nhật một dòng định tuyến tại đây.
public enum TransitionDemoAssetCatalog {
    public static let naturePairID = "nature"
    public static let cityPairID = "city"
    public static let coastalPairID = "coastal"

    /// Danh sách cấu hình 3 cặp ảnh hiện có.
    public static let builtInDescriptors: [TransitionDemoPairDescriptor] = [
        TransitionDemoPairDescriptor(
            id: naturePairID,
            displayName: "Nature (Sea & Mountain)",
            squareNameA: "scene_a_sea_square",
            originalNameA: "scene_a_sea",
            squareNameB: "scene_b_mountain_square",
            originalNameB: "scene_b_mountain",
            verticalFocusA: 0.5,
            verticalFocusB: 0.55,
            fallbackColorA: TransitionDemoColorRGB(0.15, 0.45, 0.85),
            fallbackColorB: TransitionDemoColorRGB(0.35, 0.65, 0.25)
        ),
        TransitionDemoPairDescriptor(
            id: cityPairID,
            displayName: "City (Saigon Bitexco & Landmark)",
            squareNameA: "city_a_saigon_square",
            originalNameA: "city_a_saigon",
            squareNameB: "city_b_landmark_square",
            originalNameB: "city_b_landmark",
            verticalFocusA: 0.5,
            verticalFocusB: 0.5,
            fallbackColorA: TransitionDemoColorRGB(0.2, 0.35, 0.55),
            fallbackColorB: TransitionDemoColorRGB(0.55, 0.45, 0.3)
        ),
        TransitionDemoPairDescriptor(
            id: coastalPairID,
            displayName: "Coastal (Sunset Arch & Sea Stack)",
            squareNameA: "coastal_a_sunset_square",
            originalNameA: "coastal_a_sunset",
            squareNameB: "coastal_b_seastack_square",
            originalNameB: "coastal_b_seastack",
            verticalFocusA: 0.5,
            verticalFocusB: 0.6,
            fallbackColorA: TransitionDemoColorRGB(0.85, 0.45, 0.2),
            fallbackColorB: TransitionDemoColorRGB(0.3, 0.6, 0.7)
        )
    ]

    /// Phân chia ảnh demo theo từng danh mục chuyển cảnh:
    /// - Basic, Zoom, Blur: Cặp Thiên nhiên (Biển Đảo & Núi Hoa)
    /// - Slide & Wipe, Camera & Motion, Glitch: Cặp Đô thị (Sài Gòn Bitexco & Cao ốc Landmark)
    /// - Light Effects, 3D & Mask: Cặp Bờ biển (Hoàng hôn vòm đá & Trụ đá biển)
    /// - Mọi trường hợp khác / All: Mặc định cặp Thiên nhiên
    public static func pairID(for category: TransitionCategory) -> String {
        switch category {
        case .basic, .zoom, .blur:
            return naturePairID
        case .slideWipe, .camera, .glitch:
            return cityPairID
        case .light, .advanced3D:
            return coastalPairID
        case .all:
            return naturePairID
        }
    }
}
