import SwiftUI
import Domain
import DesignSystem

/// Presentation metadata and visual tokens for clip kinds.
/// Enforces AGENTS.md R5.1 & R5.2 (Open-Closed Principle: no hardcoded switch-case in UI views).
public struct ClipPresentationDescriptor: Sendable {
    public let color: Color
    public let headerColor: Color
    public let borderColor: Color
    public let iconName: String
    public let defaultLayerHeight: CGFloat
    public let hasHeaderBar: Bool
    public let showsHeaderIcon: Bool
    public let showsHeaderDuration: Bool
    public let hasAudioFadeHandles: Bool
    public let hasWaveform: Bool
    public let hasFilmstrip: Bool

    public init(
        color: Color,
        headerColor: Color? = nil,
        borderColor: Color? = nil,
        iconName: String,
        defaultLayerHeight: CGFloat,
        hasHeaderBar: Bool = true,
        showsHeaderIcon: Bool = false,
        showsHeaderDuration: Bool = true,
        hasAudioFadeHandles: Bool = false,
        hasWaveform: Bool = false,
        hasFilmstrip: Bool = false
    ) {
        self.color = color
        self.headerColor = headerColor ?? color
        self.borderColor = borderColor ?? Color.white.opacity(0.4)
        self.iconName = iconName
        self.defaultLayerHeight = defaultLayerHeight
        self.hasHeaderBar = hasHeaderBar
        self.showsHeaderIcon = showsHeaderIcon
        self.showsHeaderDuration = showsHeaderDuration
        self.hasAudioFadeHandles = hasAudioFadeHandles
        self.hasWaveform = hasWaveform
        self.hasFilmstrip = hasFilmstrip
    }
}

/// Registry mapping clip kinds to their visual presentation descriptors.
public enum ClipPresentationRegistry: Sendable {
    private static let descriptors: [ClipKind: ClipPresentationDescriptor] = [
        .video: ClipPresentationDescriptor(
            color: DSColors.clipVideo,
            headerColor: DSColors.clipVideoHeader,
            borderColor: Color(red: 0.15, green: 0.65, blue: 0.65),
            iconName: "video.fill",
            defaultLayerHeight: DSSize.videoLayerHeight,
            hasHeaderBar: true,
            showsHeaderIcon: false,
            showsHeaderDuration: true,
            hasAudioFadeHandles: true,
            hasWaveform: true,
            hasFilmstrip: true
        ),
        .audio: ClipPresentationDescriptor(
            color: DSColors.clipAudio,
            headerColor: DSColors.clipAudioHeader,
            borderColor: Color(red: 0.20, green: 0.50, blue: 0.90),
            iconName: "waveform",
            defaultLayerHeight: DSSize.mediaLayerHeight,
            hasHeaderBar: true,
            showsHeaderIcon: false,
            showsHeaderDuration: false,
            hasAudioFadeHandles: true,
            hasWaveform: true,
            hasFilmstrip: false
        ),
        .image: ClipPresentationDescriptor(
            color: DSColors.clipImage,
            headerColor: DSColors.clipHeaderBackground,
            borderColor: Color.white.opacity(0.4),
            iconName: "photo",
            defaultLayerHeight: DSSize.mediaLayerHeight,
            hasHeaderBar: false,
            showsHeaderIcon: false,
            showsHeaderDuration: false,
            hasAudioFadeHandles: false,
            hasWaveform: false,
            hasFilmstrip: false
        ),
        .text: ClipPresentationDescriptor(
            color: DSColors.clipText,
            headerColor: DSColors.clipHeaderBackground,
            borderColor: Color.white.opacity(0.4),
            iconName: "textformat",
            defaultLayerHeight: DSSize.compactLayerHeight,
            hasHeaderBar: false,
            showsHeaderIcon: false,
            showsHeaderDuration: false,
            hasAudioFadeHandles: false,
            hasWaveform: false,
            hasFilmstrip: false
        ),
        .adjustment: ClipPresentationDescriptor(
            color: DSColors.clipAdjustment,
            headerColor: DSColors.clipAdjustmentHeader,
            borderColor: Color.white.opacity(0.4),
            iconName: "slider.horizontal.3",
            defaultLayerHeight: DSSize.compactLayerHeight,
            hasHeaderBar: false,
            showsHeaderIcon: true,
            showsHeaderDuration: true,
            hasAudioFadeHandles: false,
            hasWaveform: false,
            hasFilmstrip: false
        )
    ]

    public static func descriptor(for kind: ClipKind) -> ClipPresentationDescriptor {
        descriptors[kind] ?? ClipPresentationDescriptor(
            color: DSColors.clipVideo,
            iconName: "square.fill",
            defaultLayerHeight: DSSize.videoLayerHeight
        )
    }
}

public extension ClipKind {
    var presentation: ClipPresentationDescriptor {
        ClipPresentationRegistry.descriptor(for: self)
    }

    var color: Color {
        presentation.color
    }

    var headerBackgroundColor: Color {
        presentation.headerColor
    }

    var backgroundColor: Color {
        color.opacity(0.85)
    }
}
