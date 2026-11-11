import SwiftUI

public enum DSColors {
    public static let windowBackground = Color(red: 0.09, green: 0.09, blue: 0.10)
    public static let blockBackground = Color(red: 0.13, green: 0.13, blue: 0.15)
    public static let blockBorder = Color.white.opacity(0.08)
    public static let activeTabBackground = Color.white.opacity(0.12)
    public static let tabHoverBackground = Color.white.opacity(0.06)

    public static let accent = Color.accentColor
    public static let textPrimary = Color.white.opacity(0.92)
    public static let textSecondary = Color.white.opacity(0.55)

    public static let trafficClose = Color(red: 0.98, green: 0.36, blue: 0.35)
    public static let trafficMinimize = Color(red: 0.98, green: 0.74, blue: 0.18)
    public static let trafficZoom = Color(red: 0.16, green: 0.79, blue: 0.38)

    public static let clipVideo = Color(red: 0.05, green: 0.32, blue: 0.35)
    public static let clipAudio = Color(red: 0.08, green: 0.20, blue: 0.34)
    public static let clipImage = Color(red: 0.88, green: 0.58, blue: 0.18)
    public static let clipText = Color(red: 0.55, green: 0.33, blue: 0.20)
    public static let clipEffect = Color(red: 0.88, green: 0.21, blue: 0.40)
    public static let clipAdjustment = Color(red: 0.90, green: 0.54, blue: 0.11)
    public static let clipSticker = Color(red: 0.56, green: 0.27, blue: 0.68)

    public static let dropIndicator = Color(red: 0.25, green: 0.65, blue: 1.0)
    public static let layerHeaderBackground = Color(red: 0.11, green: 0.11, blue: 0.13)
    public static let layerTrackBackground = Color(red: 0.08, green: 0.08, blue: 0.09)

    public static let clipHeaderBackground = Color(red: 0.04, green: 0.15, blue: 0.20)
    public static let clipVideoHeader = Color(red: 0.03, green: 0.24, blue: 0.27)
    public static let clipAudioHeader = Color(red: 0.06, green: 0.15, blue: 0.27)
    public static let clipTextHeader = Color(red: 0.44, green: 0.26, blue: 0.16)
    public static let clipEffectHeader = Color(red: 0.70, green: 0.16, blue: 0.32)
    public static let clipAdjustmentHeader = Color(red: 0.72, green: 0.42, blue: 0.08)
    public static let clipStickerHeader = Color(red: 0.45, green: 0.21, blue: 0.55)
    public static let waveformBar = Color(red: 0.15, green: 0.58, blue: 0.90)
    public static let waveformPeak = Color(red: 0.98, green: 0.48, blue: 0.16)
    public static let waveformVideoBackground = Color(red: 0.03, green: 0.18, blue: 0.20)
    public static let waveformAudioBackground = Color(red: 0.05, green: 0.13, blue: 0.22)
    public static let waveformBackground = Color(red: 0.03, green: 0.18, blue: 0.20)
    public static let scrollerTrack = Color(red: 0.08, green: 0.08, blue: 0.10)
    public static let scrollerThumb = Color(red: 0.38, green: 0.42, blue: 0.48)
    public static let scrollerThumbHover = Color(red: 0.50, green: 0.55, blue: 0.62)

    public static let toggleCyan = Color(red: 0.12, green: 0.78, blue: 0.83)
    public static let favoriteStar = Color(red: 1.0, green: 0.66, blue: 0.0) // #FFA800
    public static let inputBackground = Color(red: 0.14, green: 0.14, blue: 0.16)
    public static let inputBorder = Color.white.opacity(0.08)
    public static let controlTrack = Color.white.opacity(0.18)
    public static let controlProgress = Color.white.opacity(0.92)
}

public extension Color {
    init(hex: String) {
        if hex.uppercased() == "NONE" {
            self = .clear
            return
        }
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if clean.count == 3 {
            clean = clean.map { "\($0)\($0)" }.joined()
        }
        if clean.count == 6 {
            clean.append("FF")
        }
        guard clean.count == 8, let num = UInt64(clean, radix: 16) else {
            self = .white
            return
        }
        let r = Double((num & 0xFF000000) >> 24) / 255.0
        let g = Double((num & 0x00FF0000) >> 16) / 255.0
        let b = Double((num & 0x0000FF00) >> 8) / 255.0
        let a = Double(num & 0x000000FF) / 255.0
        self = Color(red: r, green: g, blue: b, opacity: a)
    }
}
