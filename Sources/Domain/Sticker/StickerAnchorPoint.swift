import Foundation

/// Pivot anchor point used by continuous Sticker animation transforms (mirrors local bounds).
public enum StickerAnchorPoint: String, Codable, Sendable, CaseIterable, Identifiable {
    case center
    case bottom
    case top

    public var id: Self { self }
}
