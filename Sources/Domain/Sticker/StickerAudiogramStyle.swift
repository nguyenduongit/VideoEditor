import Foundation

/// Curated vector visual styles for Audio-Reactive Audiogram Stickers.
public enum StickerAudiogramStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case spectrumBars
    case mirrorWave
    case circularRing
    case flowingRibbon
    case bassSpeaker
    case musicNotePulse
    case vinylEqualizer
    case dotMatrix

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .spectrumBars: return "Spectrum Bars"
        case .mirrorWave: return "Mirror Equalizer"
        case .circularRing: return "Circular Spectrum"
        case .flowingRibbon: return "Sound Wave Ribbon"
        case .bassSpeaker: return "Boombox Woofer"
        case .musicNotePulse: return "Beat Note Pulse"
        case .vinylEqualizer: return "Rhythm Vinyl Disc"
        case .dotMatrix: return "LED Particle Matrix"
        }
    }

    public var symbolName: String {
        switch self {
        case .spectrumBars: return "chart.bar.fill"
        case .mirrorWave: return "waveform"
        case .circularRing: return "circle.dotted.and.circle"
        case .flowingRibbon: return "waveform.path.ecg"
        case .bassSpeaker: return "hifispeaker.fill"
        case .musicNotePulse: return "music.note"
        case .vinylEqualizer: return "opticaldisc.fill"
        case .dotMatrix: return "square.grid.3x3.fill"
        }
    }
}
