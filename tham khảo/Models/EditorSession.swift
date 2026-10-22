import Foundation
import CoreMedia
import AppKit

struct EditorBlock: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var startBeat: Int
    var beatCount: Int = 32
    var endBeat: Int { startBeat + beatCount }
}
struct FadeAnchor: Codable, Equatable, Sendable {
    var blockID: UUID
    var atEnd: Bool
}
enum EditorFadeKind: String, Codable, Equatable, Sendable {
    case fadeIn
    case fadeOutIn
    case fadeOut

    var defaultBeatCount: Int { self == .fadeOutIn ? 8 : 4 }
    var title: String {
        switch self {
        case .fadeIn: return "Fade In"
        case .fadeOutIn: return "Fade Out/In"
        case .fadeOut: return "Fade Out"
        }
    }
}
struct EditorFade: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var startBeat: Int?
    var beatCount: Int?
    var kind: EditorFadeKind?
    // Chỉ dùng để mở các phiên cũ, nơi fade phải bám vào biên block đếm.
    var anchors: [FadeAnchor]?

    init(id: UUID = UUID(), startBeat: Int, beatCount: Int, kind: EditorFadeKind) {
        self.id = id; self.startBeat = startBeat; self.beatCount = beatCount; self.kind = kind; anchors = nil
    }
    init(id: UUID = UUID(), anchors: [FadeAnchor]) {
        self.id = id; startBeat = nil; beatCount = nil; kind = nil; self.anchors = anchors
    }

    var resolvedBeatCount: Int { max(1, beatCount ?? 8) }
    var resolvedKind: EditorFadeKind { kind ?? .fadeOutIn }
}
enum VideoEffectKind: String, Codable, Equatable, CaseIterable, Sendable {
    case fadeIn
    case fadeOut

    var title: String { self == .fadeIn ? "Fade In" : "Fade Out" }
}
struct VideoEffect: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var startTime: Double
    var duration: Double = 1.0
    var kind: VideoEffectKind

    var endTime: Double { startTime + duration }
}
struct SourceIdentity: Codable, Equatable, Sendable {
    var path: String
    var size: Int64
    var modified: Double
    init(url: URL) {
        path = url.path
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
    }
    var isCurrent: Bool { self == SourceIdentity(url: URL(fileURLWithPath: path)) && FileManager.default.fileExists(atPath: path) }
}
struct EditorMatch: Codable, Equatable, Sendable {
    var video: SourceIdentity
    var audio: SourceIdentity
    var offset: Double
    var score: Double
    var correlation: Double
}
struct PoseSnapshot: Codable, Equatable, Sendable {
    struct Box: Codable, Equatable, Sendable { var time: Double; var x: Double; var y: Double; var width: Double; var height: Double }
    struct Guide: Codable, Equatable, Sendable { var time: Double; var hip: Double; var ankle: Double }
    var name: String
    var initial: Double
    var target: Double
    var scale: Double
    var hip: Double
    var ankle: Double
    var width: Double
    var height: Double
    var people: Int
    var maxHeight: Double
    var boxes: [Box]
    // Optional để các file phiên bản cũ không có dữ liệu theo frame vẫn mở được.
    var guides: [Guide]?
    init(_ p: BodyProportionResult) {
        name = p.videoName; initial = p.initialRatio; target = p.targetRatio; scale = p.scaleFactor
        hip = p.hipYNorm; ankle = p.ankleYNorm; width = Double(p.videoSize.width); height = Double(p.videoSize.height)
        people = p.personCount; maxHeight = p.maxPersonHeightRatio
        boxes = p.trackingData.map { Box(time: $0.time.seconds, x: Double($0.rect.minX), y: Double($0.rect.minY), width: Double($0.rect.width), height: Double($0.rect.height)) }
        guides = p.legGuideFrames.map { Guide(time: $0.time.seconds, hip: $0.hipYNorm, ankle: $0.ankleYNorm) }
    }
    func result(scale override: Double? = nil) -> BodyProportionResult {
        BodyProportionResult(videoName: name, initialRatio: initial, targetRatio: target, scaleFactor: override ?? scale, hipYNorm: hip, ankleYNorm: ankle, videoSize: CGSize(width: width, height: height), trackingData: boxes.map { FrameBoundingBox(time: CMTime(seconds: $0.time, preferredTimescale: 600), rect: CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)) }, legGuideFrames: (guides ?? []).map { FrameLegGuide(time: CMTime(seconds: $0.time, preferredTimescale: 600), hipYNorm: $0.hip, ankleYNorm: $0.ankle) }, personCount: people, maxPersonHeightRatio: maxHeight)
    }
}
struct EditorAdjustments: Codable, Equatable, Sendable {
    var enabled = true
    var saturation: Float = 1
    var contrast: Float = 1
    var brightness: Float = 0
    var shadows: Float = 0
    var highlights: Float = 0
    var vibrance: Float = 0
    var temperature: Float = 0
    var tint: Float = 0
    var whites: Float = 0
    var blacks: Float = 0
    var presetIndex: Int = 0
    var presetIntensity: Float = 1.0
    var hsl = HSLAdjustments()

    var isNeutral: Bool {
        abs(saturation - 1) < 0.001 &&
        abs(contrast - 1) < 0.001 &&
        abs(brightness) < 0.001 &&
        abs(shadows) < 0.001 &&
        abs(highlights) < 0.001 &&
        abs(vibrance) < 0.001 &&
        abs(temperature) < 0.001 &&
        abs(tint) < 0.001 &&
        abs(whites) < 0.001 &&
        abs(blacks) < 0.001 &&
        presetIndex == 0 &&
        hsl.isNeutral
    }

    var params: ColorGradingParams {
        ColorGradingParams(
            saturation: saturation,
            contrast: contrast,
            brightness: brightness,
            shadowAmount: shadows,
            highlightAmount: highlights,
            vibrance: vibrance,
            temperatureOffset: temperature,
            tintOffset: tint,
            whites: whites,
            blacks: blacks,
            hsl: hsl,
            presetIndex: presetIndex,
            presetIntensity: presetIntensity
        )
    }

    mutating func apply(_ p: ColorGradingParams) {
        saturation = p.saturation
        contrast = p.contrast
        brightness = p.brightness
        shadows = p.shadowAmount
        highlights = p.highlightAmount
        vibrance = p.vibrance
        temperature = p.temperatureOffset
        tint = p.tintOffset
        whites = p.whites
        blacks = p.blacks
        hsl = p.hsl
        presetIndex = p.presetIndex
        presetIntensity = p.presetIntensity
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        saturation = try container.decodeIfPresent(Float.self, forKey: .saturation) ?? 1.0
        contrast = try container.decodeIfPresent(Float.self, forKey: .contrast) ?? 1.0
        brightness = try container.decodeIfPresent(Float.self, forKey: .brightness) ?? 0.0
        shadows = try container.decodeIfPresent(Float.self, forKey: .shadows) ?? 0.0
        highlights = try container.decodeIfPresent(Float.self, forKey: .highlights) ?? 0.0
        vibrance = try container.decodeIfPresent(Float.self, forKey: .vibrance) ?? 0.0
        temperature = try container.decodeIfPresent(Float.self, forKey: .temperature) ?? 0.0
        tint = try container.decodeIfPresent(Float.self, forKey: .tint) ?? 0.0
        whites = try container.decodeIfPresent(Float.self, forKey: .whites) ?? 0.0
        blacks = try container.decodeIfPresent(Float.self, forKey: .blacks) ?? 0.0
        presetIndex = try container.decodeIfPresent(Int.self, forKey: .presetIndex) ?? 0
        presetIntensity = try container.decodeIfPresent(Float.self, forKey: .presetIntensity) ?? 1.0
        hsl = try container.decodeIfPresent(HSLAdjustments.self, forKey: .hsl) ?? HSLAdjustments()
    }
}

// MARK: - Vietnamese Font Option (100% Unicode Support on macOS)
public struct VietnameseFontOption: Equatable, Sendable {
    public let id: Int
    public let name: String
    public let displayName: String
    public let category: String

    public static let allOptions: [VietnameseFontOption] = [
        VietnameseFontOption(id: 0, name: "SF Pro Rounded", displayName: "SF Pro Rounded (Bo tròn)", category: "Hiện đại"),
        VietnameseFontOption(id: 1, name: "SF Pro", displayName: "SF Pro (Hệ thống)", category: "Hiện đại"),
        VietnameseFontOption(id: 2, name: "Helvetica Neue", displayName: "Helvetica Neue (Thanh lịch)", category: "Không chân"),
        VietnameseFontOption(id: 3, name: "Arial", displayName: "Arial (Rõ nét)", category: "Không chân"),
        VietnameseFontOption(id: 4, name: "Avenir Next", displayName: "Avenir Next (Hình học)", category: "Hình học"),
        VietnameseFontOption(id: 5, name: "Verdana", displayName: "Verdana (Nổi bật)", category: "Không chân"),
        VietnameseFontOption(id: 6, name: "Georgia", displayName: "Georgia (Quý phái)", category: "Có chân"),
        VietnameseFontOption(id: 7, name: "Times New Roman", displayName: "Times New Roman (Cổ điển)", category: "Có chân"),
        VietnameseFontOption(id: 8, name: "Palatino", displayName: "Palatino (Thư pháp)", category: "Có chân"),
        VietnameseFontOption(id: 9, name: "Marker Felt", displayName: "Marker Felt (Bút dạ)", category: "Viết tay"),
        VietnameseFontOption(id: 10, name: "Chalkboard SE", displayName: "Chalkboard SE (Phấn bảng)", category: "Viết tay"),
        VietnameseFontOption(id: 11, name: "Courier New", displayName: "Courier New (Máy đánh chữ)", category: "Đơn cách")
    ]

    public static func resolveFont(at index: Int, size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        let safeIndex = max(0, min(allOptions.count - 1, index))
        let option = allOptions[safeIndex]
        var font: NSFont?

        switch option.name {
        case "SF Pro Rounded":
            let weight: NSFont.Weight = bold ? .heavy : .bold
            if let desc = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded) {
                font = NSFont(descriptor: desc, size: size)
            }
        case "SF Pro":
            let weight: NSFont.Weight = bold ? .bold : .regular
            font = NSFont.systemFont(ofSize: size, weight: weight)
        default:
            font = NSFont(name: option.name, size: size)
        }

        var resolved = font ?? NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        let manager = NSFontManager.shared
        if italic {
            resolved = manager.convert(resolved, toHaveTrait: .italicFontMask)
        }
        if bold && option.name != "SF Pro Rounded" && option.name != "SF Pro" {
            resolved = manager.convert(resolved, toHaveTrait: .boldFontMask)
        }
        return resolved
    }
}

// MARK: - Text Style Preset
public enum TextStylePreset: Int, CaseIterable, Codable, Sendable {
    case popDance = 0      // Neon Pop: Red face, white outline, dark contour, lime glow
    case cinemaGold = 1    // Cinema Gold: Metallic gold face, subtle border, warm soft shadow
    case cyberNeon = 2     // Cyber Neon: Cyan ice face, magenta/purple electric glow
    case cleanSubtitle = 3 // Clean Sub: Pure white face, dark outline, rounded dark banner box
    case tiktokHook = 4    // TikTok Hook: Neon yellow face, heavy black stroke, punchy impact
    case vintageRetro = 5  // Vintage: Cream face, deep coffee outline, 3D drop shadow
    case minimalist = 6    // Minimalist: Clean white face, subtle shadow, wide tracking
    case custom = 7        // Custom user overrides

    public var title: String {
        switch self {
        case .popDance: return "Pop Dance"
        case .cinemaGold: return "Cinema Gold"
        case .cyberNeon: return "Cyber Neon"
        case .cleanSubtitle: return "Clean Sub"
        case .tiktokHook: return "TikTok Hook"
        case .vintageRetro: return "Vintage"
        case .minimalist: return "Minimalist"
        case .custom: return "Tùy chỉnh"
        }
    }

    public var icon: String {
        switch self {
        case .popDance: return "🔥"
        case .cinemaGold: return "✨"
        case .cyberNeon: return "⚡"
        case .cleanSubtitle: return "💬"
        case .tiktokHook: return "🎯"
        case .vintageRetro: return "🎞️"
        case .minimalist: return "🖤"
        case .custom: return "🎨"
        }
    }
}

// MARK: - Text Animation Preset
public enum TextAnimationPreset: Int, CaseIterable, Codable, Sendable {
    case none = 0       // Static
    case fadeZoom = 1   // Fade in + subtle slow zoom + fade out
    case popBounce = 2  // Elastic bounce from center
    case slideIn = 3    // Smooth ease-out slide from bottom
    case beatPulse = 4  // Pulses rhythmically on every dance beat

    public var title: String {
        switch self {
        case .none: return "Không hiệu ứng"
        case .fadeZoom: return "Fade & Zoom"
        case .popBounce: return "Pop & Bounce"
        case .slideIn: return "Slide In"
        case .beatPulse: return "Beat Pulse 🎵"
        }
    }

    public var icon: String {
        switch self {
        case .none: return "🚫"
        case .fadeZoom: return "🌊"
        case .popBounce: return "💥"
        case .slideIn: return "🚀"
        case .beatPulse: return "🎵"
        }
    }
}

// MARK: - Editor Text Settings
public struct EditorTextSettings: Codable, Equatable, Sendable {
    // Content & Typography
    public var text: String = ""
    public var fontIndex: Int = 0 // 0...11 (VietnameseFontOption)
    public var fontSizeScale: Double = 1.0 // 0.5 ... 2.5
    public var isBold: Bool = true
    public var isItalic: Bool = true
    public var isAllUpper: Bool = false
    public var alignment: Int = 1 // 0: Left, 1: Center, 2: Right

    // Transform & Position
    public var positionPreset: Int = 0 // 0: Top (20%), 1: Center (50%), 2: Bottom (80%), 3: Custom
    public var positionY: Double = 0.20 // 0.05 ... 0.95
    public var positionX: Double = 0.50 // 0.05 ... 0.95
    public var letterSpacing: Double = 1.0 // Kerning factor

    // Style & Colors
    public var stylePreset: TextStylePreset = .popDance
    public var fillColor: String = "#F21429" // Pop red
    public var fillAlpha: Double = 1.0

    // Stroke
    public var strokeEnabled: Bool = true
    public var strokeColor: String = "#FFFFFF"
    public var strokeWidth: Double = 12.0 // px

    // Glow & Shadow
    public var glowEnabled: Bool = true
    public var glowColor: String = "#EBFF4D" // Lime yellow neon
    public var glowRadius: Double = 20.0

    // Background Banner
    public var backgroundEnabled: Bool = false
    public var backgroundColor: String = "#000000"
    public var backgroundAlpha: Double = 0.60
    public var backgroundCornerRadius: Double = 8.0

    // Animation & Timing
    public var animationPreset: TextAnimationPreset = .fadeZoom
    public var timingMode: Int = 0 // 0: Intro (startTime...startTime+duration), 1: FullVideo
    public var startTime: Double = 0.5
    public var duration: Double = 3.0

    public init(text: String = "") {
        self.text = text
    }

    /// Áp dụng mẫu phong cách
    public mutating func applyStylePreset(_ preset: TextStylePreset) {
        self.stylePreset = preset
        switch preset {
        case .popDance:
            fillColor = "#F21429"
            strokeEnabled = true
            strokeColor = "#FFFFFF"
            strokeWidth = 12.0
            glowEnabled = true
            glowColor = "#EBFF4D"
            glowRadius = 20.0
            backgroundEnabled = false
            fontIndex = 0 // SF Pro Rounded
            isBold = true
            isItalic = true
        case .cinemaGold:
            fillColor = "#FFD700"
            strokeEnabled = true
            strokeColor = "#5C4010"
            strokeWidth = 4.0
            glowEnabled = true
            glowColor = "#E6A100"
            glowRadius = 16.0
            backgroundEnabled = false
            fontIndex = 6 // Georgia
            isBold = true
            isItalic = false
        case .cyberNeon:
            fillColor = "#00F0FF"
            strokeEnabled = true
            strokeColor = "#FF007F"
            strokeWidth = 8.0
            glowEnabled = true
            glowColor = "#FF007F"
            glowRadius = 24.0
            backgroundEnabled = false
            fontIndex = 4 // Avenir Next
            isBold = true
            isItalic = false
        case .cleanSubtitle:
            fillColor = "#FFFFFF"
            strokeEnabled = true
            strokeColor = "#111111"
            strokeWidth = 4.0
            glowEnabled = false
            glowColor = "#000000"
            glowRadius = 0.0
            backgroundEnabled = true
            backgroundColor = "#000000"
            backgroundAlpha = 0.65
            backgroundCornerRadius = 8.0
            fontIndex = 2 // Helvetica Neue
            isBold = false
            isItalic = false
        case .tiktokHook:
            fillColor = "#FFFF00"
            strokeEnabled = true
            strokeColor = "#000000"
            strokeWidth = 14.0
            glowEnabled = false
            glowColor = "#000000"
            glowRadius = 0.0
            backgroundEnabled = false
            fontIndex = 5 // Verdana
            isBold = true
            isItalic = false
        case .vintageRetro:
            fillColor = "#FFF3D6"
            strokeEnabled = true
            strokeColor = "#3E2723"
            strokeWidth = 8.0
            glowEnabled = true
            glowColor = "#3E2723"
            glowRadius = 10.0
            backgroundEnabled = false
            fontIndex = 7 // Times New Roman
            isBold = true
            isItalic = true
        case .minimalist:
            fillColor = "#F5F5F7"
            strokeEnabled = false
            strokeColor = "#000000"
            strokeWidth = 0.0
            glowEnabled = true
            glowColor = "#000000"
            glowRadius = 8.0
            backgroundEnabled = false
            fontIndex = 1 // SF Pro
            isBold = false
            isItalic = false
            letterSpacing = 2.5
        case .custom:
            break
        }
    }
}

struct EditorSession: Codable, Equatable, Sendable {
    var version = 1
    var video: SourceIdentity?
    var audio: SourceIdentity?
    var match: EditorMatch?
    var sourceDuration = 0.0
    var audioDuration = 0.0
    var pose: PoseSnapshot?
    var legScale = 1.0 // 1.0 = original (no lengthening), 1.0...1.6
    var legHipY = 0.55 // Đường ngang đùi/hông (0.0 ... 1.0)
    var legAnkleY = 0.25 // Đường ngang mắt cá chân (0.0 ... 1.0)
    var showLegGuides: Bool? = nil // Optional để phiên cũ vẫn giải mã được; nil = tắt
    var targetRatio = 1.48
    var legsEnabled: Bool { abs(legScale - 1.0) > 0.001 }
    var cropMode = 0 // 0: Original, 1: 9:16, 2: 16:9, 3: 1:1, 4: 4:5
    var cropZoom = 1.0 // 1.0 ... 3.0
    var cropRotation = 0.0 // -180.0 ... 180.0 degrees
    var cropOffsetY = 0.5 // 0.0 (top) ... 1.0 (bottom), 0.5 = center
    var cropAutoPan = false // Default OFF: Auto-track subject X with AI Catmull-Rom spline
    var cropPanX = 0.5 // When cropAutoPan is false: 0.0 (left) ... 1.0 (right), 0.5 = center
    var cropEnabled: Bool { cropMode != 0 || abs(cropZoom - 1.0) > 0.001 || abs(cropRotation) > 0.001 || abs(cropOffsetY - 0.5) > 0.001 || abs(cropPanX - 0.5) > 0.001 || cropAutoPan }
    var adjustments = EditorAdjustments()
    var textEnabled = false
    var textSettings = EditorTextSettings()
    var title: String {
        get { textSettings.text }
        set { textSettings.text = newValue }
    }
    var baseBPM = 120.0
    var targetBPM = 120.0
    var phase = 0.0
    var musicVolume = 1.0
    var blocks: [EditorBlock] = []
    var fades: [EditorFade] = []
    var videoEffects: [VideoEffect] = []
    var fadeIn = false
    var fadeOut = false
    var audioTrimEnd: Double? = nil
    var videoTrimEnd: Double? = nil
    var audioFadeOutDuration: Double = 2.0
    var outputPreset = 0

    var videoStart: Double { max(0, match?.offset ?? 0) }
    var audioStart: Double { max(0, -(match?.offset ?? 0)) }
    var rawVideoDuration: Double { max(0, sourceDuration - videoStart) }
    var rawAudioDuration: Double { match != nil ? max(0, audioDuration - audioStart) : rawVideoDuration }
    var effectiveVideoDuration: Double {
        let maxAvailable = rawVideoDuration
        if let trim = videoTrimEnd {
            // Floor 0.5s chỉ áp dụng khi nguồn đủ dài (≥ 0.5s); tránh trường hợp nguồn 0.2s + trim 0.1s → trả 0.2s sai.
            let floor = maxAvailable >= 0.5 ? 0.5 : 0.0
            return max(floor, min(maxAvailable, trim))
        }
        guard match != nil else { return max(0, sourceDuration) }
        return max(0, min(maxAvailable, rawAudioDuration))
    }
    var effectiveAudioDuration: Double {
        let maxAudio = rawAudioDuration
        if let trim = audioTrimEnd {
            let floor = maxAudio >= 0.5 ? 0.5 : 0.0
            return max(floor, min(maxAudio, trim))
        }
        return min(maxAudio, effectiveVideoDuration)
    }
    var duration: Double {
        effectiveVideoDuration
    }
    var speed: Double { max(0.25, min(4, targetBPM / max(1, baseBPM))) }
    func beatTime(_ beat: Int) -> Double { phase + Double(beat) * 60 / max(1, baseBPM) }
    func beat(at time: Double) -> Int { Int(((time - phase) * max(1, baseBPM) / 60).rounded()) }
    func anchorBeat(_ anchor: FadeAnchor) -> Int? {
        guard let block = blocks.first(where: { $0.id == anchor.blockID }) else { return nil }
        return anchor.atEnd ? block.endBeat : block.startBeat
    }
    func anchors(at beat: Int) -> [FadeAnchor] {
        blocks.flatMap { b -> [FadeAnchor] in
            var a: [FadeAnchor] = []
            if b.startBeat == beat { a.append(FadeAnchor(blockID: b.id, atEnd: false)) }
            if b.endBeat == beat { a.append(FadeAnchor(blockID: b.id, atEnd: true)) }
            return a
        }
    }
    var boundaryBeats: [Int] {
        Array(Set(blocks.flatMap { [$0.startBeat, $0.endBeat] })).sorted().filter { beatTime($0) > 0.001 && beatTime($0) < duration - 0.001 }
    }
    func fadeBeat(_ fade: EditorFade) -> Int? {
        fade.startBeat ?? fade.anchors?.compactMap { anchorBeat($0) }.first
    }
    func accepts(_ fade: EditorFade) -> Bool {
        // Dùng so sánh khoảng thay cho abs() để tránh Int overflow khi beat = Int.min.
        guard let beat = fadeBeat(fade), fade.resolvedBeatCount > 0,
              beat > -10_000_000 && beat < 10_000_000,
              fade.resolvedBeatCount < 10_000_000 else { return false }
        let time = beatTime(beat)
        guard time >= -0.001, time <= duration + 0.001 else { return false }
        return !fades.contains { $0.id != fade.id && fadeBeat($0) == beat }
    }
    mutating func normalizeFades() {
        var occupied = Set<Int>()
        fades = fades.compactMap { fade in
            guard let beat = fadeBeat(fade), beatTime(beat) >= -0.001, beatTime(beat) <= duration + 0.001,
                  occupied.insert(beat).inserted else { return nil }
            return EditorFade(id: fade.id, startBeat: beat, beatCount: fade.resolvedBeatCount, kind: fade.resolvedKind)
        }
        // Guard trước Int conversion: phase hợp lệ đã được validate ở (-3600...3600).
        // baseBPM tối đa 300, max beat tính từ phase*BPM/60 ≈ 3600*300/60 = 18000 — nằm trong Int range.
        if fadeIn {
            let rawBeat = -phase * baseBPM / 60
            guard rawBeat.isFinite, rawBeat > -10_000_000, rawBeat < 10_000_000 else { fadeIn = false; return }
            let beat = Int(ceil(rawBeat))
            if !occupied.contains(beat) { fades.append(EditorFade(startBeat: beat, beatCount: 4, kind: .fadeIn)); occupied.insert(beat) }
            fadeIn = false
        }
        if fadeOut {
            let rawBeat = (duration - phase) * baseBPM / 60
            guard rawBeat.isFinite, rawBeat > -10_000_000, rawBeat < 10_000_000 else { fadeOut = false; return }
            let beat = Int(floor(rawBeat))
            if !occupied.contains(beat) { fades.append(EditorFade(startBeat: beat, beatCount: 4, kind: .fadeOut)) }
            fadeOut = false
        }
        fades.sort { ($0.startBeat ?? 0) < ($1.startBeat ?? 0) }
    }
    func accepts(_ block: EditorBlock) -> Bool {
        // Dùng so sánh khoảng thay cho abs() để tránh Int overflow khi startBeat = Int.min.
        guard block.beatCount > 0, block.beatCount < 10_000_000,
              block.startBeat > -10_000_000 && block.startBeat < 10_000_000,
              beatTime(block.startBeat) >= -0.001, beatTime(block.endBeat) <= duration + 0.001 else { return false }
        return !blocks.contains { $0.id != block.id && block.startBeat < $0.endBeat && block.endBeat > $0.startBeat }
    }
    mutating func insertFade(at beat: Int, kind: EditorFadeKind, beatCount: Int? = nil) -> Bool {
        let fade = EditorFade(startBeat: beat, beatCount: beatCount ?? kind.defaultBeatCount, kind: kind)
        guard accepts(fade) else { return false }
        fades.append(fade)
        fades.sort { ($0.startBeat ?? 0) < ($1.startBeat ?? 0) }
        return true
    }
    func accepts(_ effect: VideoEffect) -> Bool {
        let outputDuration = EditorTimeMap(self).duration
        guard effect.startTime.isFinite, effect.duration.isFinite,
              effect.startTime >= -0.0001, effect.duration >= 0.1,
              effect.endTime <= outputDuration + 0.0001 else { return false }
        return true
    }
    func snappedVideoEffectStart(_ proposed: Double, duration: Double) -> Double {
        let outputDuration = EditorTimeMap(self).duration
        let rounded = (max(0, proposed) * 10).rounded() / 10
        // Clamp sau khi snap 0,1s để cạnh phải vẫn khớp chính xác với cuối timeline,
        // kể cả khi duration của nguồn không nằm đúng trên lưới 0,1s.
        return min(rounded, max(0, outputDuration - max(0.1, duration)))
    }
    mutating func normalizeVideoEffects() {
        let outputDuration = EditorTimeMap(self).duration
        videoEffects = videoEffects.compactMap { effect in
            guard effect.startTime.isFinite, effect.duration.isFinite, outputDuration >= 0.1 else { return nil }
            var value = effect
            value.startTime = max(0, min(outputDuration - 0.1, value.startTime))
            value.duration = max(0.1, min(outputDuration - value.startTime, value.duration))
            return value
        }.sorted { $0.startTime < $1.startTime }
    }
    func validate() throws {
        let values = [sourceDuration, audioDuration, baseBPM, targetBPM, phase, legScale, legHipY, legAnkleY, targetRatio, musicVolume, cropZoom, cropRotation, cropOffsetY, cropPanX]
        guard version == 1, values.allSatisfy({ $0.isFinite }), sourceDuration >= 0, audioDuration >= 0,
              (31...300).contains(baseBPM), (31...300).contains(targetBPM), (1...2).contains(legScale),
              (0...1).contains(legHipY), (0...1).contains(legAnkleY),
              (0...2).contains(musicVolume), (0...4).contains(cropMode),
              (1...3).contains(cropZoom), (-180...180).contains(cropRotation), (0...1).contains(cropOffsetY), (0...1).contains(cropPanX),
              // Giới hạn phase để Int conversion trong normalizeFades() không overflow (3600s * 300BPM/60 = 18000 beat — an toàn).
              (-3600.0...3600.0).contains(phase),
              blocks.count < 10000, Set(blocks.map { $0.id }).count == blocks.count,
              // Dùng so sánh khoảng thay abs() để tránh Int.min trap.
              blocks.allSatisfy({ $0.startBeat > -10_000_000 && $0.startBeat < 10_000_000 && $0.beatCount > 0 && $0.beatCount < 10_000_000 && accepts($0) }),
              fades.count < 10000, Set(fades.map { $0.id }).count == fades.count,
              fades.allSatisfy({ accepts($0) }),
              videoEffects.count < 10000, Set(videoEffects.map { $0.id }).count == videoEffects.count,
              videoEffects.allSatisfy({ accepts($0) }),
              videoTrimEnd?.isFinite != false, audioTrimEnd?.isFinite != false,
              (videoTrimEnd ?? 1) > 0, (audioTrimEnd ?? 1) > 0,
              audioFadeOutDuration.isFinite, audioFadeOutDuration >= 0 else {
            throw EditorError.message("Phiên không hợp lệ hoặc không được hỗ trợ.")
        }
        if let m = match {
            guard m.offset.isFinite, m.video == video, m.audio == audio else { throw EditorError.message("Thông tin đồng bộ không hợp lệ.") }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case version, video, audio, match, sourceDuration, audioDuration, pose
        case legScale, legHipY, legAnkleY, showLegGuides, targetRatio
        case cropMode, cropZoom, cropRotation, cropOffsetY, cropAutoPan, cropPanX
        case adjustments, textEnabled, title, textSettings
        case baseBPM, targetBPM, phase, musicVolume
        case blocks, fades, fadeIn, fadeOut, videoEffects
        case audioTrimEnd, videoTrimEnd, audioFadeOutDuration, outputPreset
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        video = try container.decodeIfPresent(SourceIdentity.self, forKey: .video)
        audio = try container.decodeIfPresent(SourceIdentity.self, forKey: .audio)
        match = try container.decodeIfPresent(EditorMatch.self, forKey: .match)
        sourceDuration = try container.decodeIfPresent(Double.self, forKey: .sourceDuration) ?? 0.0
        audioDuration = try container.decodeIfPresent(Double.self, forKey: .audioDuration) ?? 0.0
        pose = try container.decodeIfPresent(PoseSnapshot.self, forKey: .pose)
        legScale = try container.decodeIfPresent(Double.self, forKey: .legScale) ?? 1.0
        legHipY = try container.decodeIfPresent(Double.self, forKey: .legHipY) ?? 0.55
        legAnkleY = try container.decodeIfPresent(Double.self, forKey: .legAnkleY) ?? 0.25
        showLegGuides = try container.decodeIfPresent(Bool.self, forKey: .showLegGuides)
        targetRatio = try container.decodeIfPresent(Double.self, forKey: .targetRatio) ?? 1.48
        cropMode = try container.decodeIfPresent(Int.self, forKey: .cropMode) ?? 0
        cropZoom = try container.decodeIfPresent(Double.self, forKey: .cropZoom) ?? 1.0
        cropRotation = try container.decodeIfPresent(Double.self, forKey: .cropRotation) ?? 0.0
        cropOffsetY = try container.decodeIfPresent(Double.self, forKey: .cropOffsetY) ?? 0.5
        cropAutoPan = try container.decodeIfPresent(Bool.self, forKey: .cropAutoPan) ?? false
        cropPanX = try container.decodeIfPresent(Double.self, forKey: .cropPanX) ?? 0.5
        adjustments = try container.decodeIfPresent(EditorAdjustments.self, forKey: .adjustments) ?? EditorAdjustments()
        textEnabled = try container.decodeIfPresent(Bool.self, forKey: .textEnabled) ?? false
        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        var ts = try container.decodeIfPresent(EditorTextSettings.self, forKey: .textSettings) ?? EditorTextSettings()
        if ts.text.isEmpty && !decodedTitle.isEmpty { ts.text = decodedTitle }
        textSettings = ts
        baseBPM = try container.decodeIfPresent(Double.self, forKey: .baseBPM) ?? 120.0
        targetBPM = try container.decodeIfPresent(Double.self, forKey: .targetBPM) ?? 120.0
        phase = try container.decodeIfPresent(Double.self, forKey: .phase) ?? 0.0
        musicVolume = try container.decodeIfPresent(Double.self, forKey: .musicVolume) ?? 1.0
        blocks = try container.decodeIfPresent([EditorBlock].self, forKey: .blocks) ?? []
        fades = try container.decodeIfPresent([EditorFade].self, forKey: .fades) ?? []
        videoEffects = try container.decodeIfPresent([VideoEffect].self, forKey: .videoEffects) ?? []
        fadeIn = try container.decodeIfPresent(Bool.self, forKey: .fadeIn) ?? false
        fadeOut = try container.decodeIfPresent(Bool.self, forKey: .fadeOut) ?? false
        audioTrimEnd = try container.decodeIfPresent(Double.self, forKey: .audioTrimEnd)
        videoTrimEnd = try container.decodeIfPresent(Double.self, forKey: .videoTrimEnd)
        audioFadeOutDuration = try container.decodeIfPresent(Double.self, forKey: .audioFadeOutDuration) ?? 2.0
        outputPreset = try container.decodeIfPresent(Int.self, forKey: .outputPreset) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(video, forKey: .video)
        try container.encodeIfPresent(audio, forKey: .audio)
        try container.encodeIfPresent(match, forKey: .match)
        try container.encode(sourceDuration, forKey: .sourceDuration)
        try container.encode(audioDuration, forKey: .audioDuration)
        try container.encodeIfPresent(pose, forKey: .pose)
        try container.encode(legScale, forKey: .legScale)
        try container.encode(legHipY, forKey: .legHipY)
        try container.encode(legAnkleY, forKey: .legAnkleY)
        try container.encodeIfPresent(showLegGuides, forKey: .showLegGuides)
        try container.encode(targetRatio, forKey: .targetRatio)
        try container.encode(cropMode, forKey: .cropMode)
        try container.encode(cropZoom, forKey: .cropZoom)
        try container.encode(cropRotation, forKey: .cropRotation)
        try container.encode(cropOffsetY, forKey: .cropOffsetY)
        try container.encode(cropAutoPan, forKey: .cropAutoPan)
        try container.encode(cropPanX, forKey: .cropPanX)
        try container.encode(adjustments, forKey: .adjustments)
        try container.encode(textEnabled, forKey: .textEnabled)
        try container.encode(title, forKey: .title)
        try container.encode(textSettings, forKey: .textSettings)
        try container.encode(baseBPM, forKey: .baseBPM)
        try container.encode(targetBPM, forKey: .targetBPM)
        try container.encode(phase, forKey: .phase)
        try container.encode(musicVolume, forKey: .musicVolume)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(fades, forKey: .fades)
        try container.encode(videoEffects, forKey: .videoEffects)
        try container.encode(fadeIn, forKey: .fadeIn)
        try container.encode(fadeOut, forKey: .fadeOut)
        try container.encodeIfPresent(audioTrimEnd, forKey: .audioTrimEnd)
        try container.encodeIfPresent(videoTrimEnd, forKey: .videoTrimEnd)
        try container.encode(audioFadeOutDuration, forKey: .audioFadeOutDuration)
        try container.encode(outputPreset, forKey: .outputPreset)
    }
}

/// One mapping is shared by playback, waveform, voices and export. Source time excludes inserted holds.
struct EditorTimeMap: Sendable {
    enum Kind: Sendable { case content, fadeIn, fadeOut }
    struct Span: Sendable {
        var start: Double
        var duration: Double
        var sourceStart: Double
        var sourceEnd: Double
        var kind: Kind
        var fadeID: UUID?
        var end: Double { start + duration }
    }
    var spans: [Span] = []
    var speed: Double
    var duration: Double { spans.last?.end ?? 0 }
    init(_ session: EditorSession) {
        speed = session.speed
        var cursor = 0.0
        func hold(_ source: Double, _ kind: Kind, _ duration: Double, _ id: UUID? = nil) {
            guard duration > 0 else { return }
            spans.append(Span(start: cursor, duration: duration, sourceStart: source, sourceEnd: source, kind: kind, fadeID: id)); cursor += duration
        }
        func content(_ from: Double, _ to: Double) {
            guard to > from else { return }
            let duration = (to - from) / speed
            spans.append(Span(start: cursor, duration: duration, sourceStart: from, sourceEnd: to, kind: .content, fadeID: nil)); cursor += duration
        }
        guard session.duration > 0 else { return }
        var source = 0.0
        var entries = session.fades.compactMap { f -> (time: Double, id: UUID?, kind: EditorFadeKind, beats: Int)? in
            guard let beat = session.fadeBeat(f) else { return nil }
            let t = session.beatTime(beat)
            return t >= -0.001 && t <= session.duration + 0.001 ? (min(session.duration, max(0, t)), f.id, f.resolvedKind, f.resolvedBeatCount) : nil
        }
        // Phiên cũ vẫn dựng đúng ngay cả trước khi được chuẩn hóa khi mở.
        if session.fadeIn { entries.append((0, nil, .fadeIn, 4)) }
        if session.fadeOut { entries.append((session.duration, nil, .fadeOut, 4)) }
        entries.sort { $0.time < $1.time }
        for entry in entries {
            let time = entry.time
            content(source, time)
            let duration = Double(entry.beats) * 60 / max(1, session.targetBPM)
            switch entry.kind {
            case .fadeIn:
                hold(time, .fadeIn, duration, entry.id)
            case .fadeOut:
                hold(time, .fadeOut, duration, entry.id)
            case .fadeOutIn:
                hold(time, .fadeOut, duration / 2, entry.id)
                hold(time, .fadeIn, duration / 2, entry.id)
            }
            source = time
        }
        content(source, session.duration)
    }
    func span(at output: Double) -> Span? { spans.first { output >= $0.start && output < $0.end } ?? spans.last }
    func sourceTime(at output: Double) -> Double {
        guard let span = span(at: output) else { return 0 }
        return span.kind == .content ? min(span.sourceEnd, span.sourceStart + max(0, output - span.start) * speed) : span.sourceStart
    }
    func outputTime(for source: Double, afterHold: Bool = true) -> Double {
        let candidates = spans.filter { $0.kind == .content && source >= $0.sourceStart - 0.000001 && source <= $0.sourceEnd + 0.000001 }
        if let s = afterHold ? candidates.last : candidates.first {
            return s.start + (source - s.sourceStart) / speed
        }
        // Source vượt quá tất cả các span: trả thời điểm kết thúc map thay vì 0.
        // Điều này ngăn audioMix.setVolume(0.0, at: .zero) xảy ra khi audioLimit > videoDuration.
        if source > (spans.last?.sourceEnd ?? 0) { return duration }
        return 0
    }
}

struct EditorProjectFile: Codable, Equatable, Sendable {
    var version = 1
    var session: EditorSession
    var lastExport: EditorSession?
}
