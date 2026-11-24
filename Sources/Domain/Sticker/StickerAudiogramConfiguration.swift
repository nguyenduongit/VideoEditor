import Foundation

/// Customization parameters for an Audio-Reactive Audiogram Sticker.
public struct StickerAudiogramConfiguration: Codable, Sendable, Equatable, Hashable {
    public var style: StickerAudiogramStyle
    public var primaryColorHex: String
    public var secondaryColorHex: String
    public var sensitivity: Double
    public var barCount: Int
    public var isGlowEnabled: Bool
    public var reactsToBeat: Bool

    public init(
        style: StickerAudiogramStyle = .spectrumBars,
        primaryColorHex: String = "#06B6D4",
        secondaryColorHex: String = "#8B5CF6",
        sensitivity: Double = 1.15,
        barCount: Int = 20,
        isGlowEnabled: Bool = true,
        reactsToBeat: Bool = true
    ) {
        self.style = style
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
        self.sensitivity = max(0.3, min(2.5, sensitivity))
        self.barCount = max(8, min(36, barCount))
        self.isGlowEnabled = isGlowEnabled
        self.reactsToBeat = reactsToBeat
    }
}
