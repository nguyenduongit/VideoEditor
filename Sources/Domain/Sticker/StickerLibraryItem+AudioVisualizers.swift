import Foundation

extension StickerLibraryItem {
    /// Curated Dev-Authored Audio-Reactive Audiogram Stickers reacting 60fps to audio spectrum & beat kicks.
    public static var audioVisualizerItems: [StickerLibraryItem] {
        audiogramDefinitions.map { def in
            StickerLibraryItem(
                id: def.id,
                name: def.name,
                description: def.description,
                category: .audioVisualizer,
                format: .audiogram,
                tags: def.tags,
                defaultDuration: 5.0,
                systemSymbolFallback: def.style.symbolName,
                config: StickerConfiguration(
                    format: .audiogram,
                    loopMode: .loop,
                    playbackSpeed: 1.0,
                    systemSymbolFallback: def.style.symbolName,
                    audiogram: StickerAudiogramConfiguration(
                        style: def.style,
                        primaryColorHex: def.primaryHex,
                        secondaryColorHex: def.secondaryColorHex,
                        sensitivity: def.sensitivity,
                        barCount: def.barCount,
                        isGlowEnabled: true,
                        reactsToBeat: true
                    )
                )
            )
        }
    }

    private struct AudiogramDefinition {
        let id: String
        let name: String
        let description: String
        let style: StickerAudiogramStyle
        let primaryHex: String
        let secondaryColorHex: String
        let sensitivity: Double
        let barCount: Int
        let tags: [String]
    }

    private static let audiogramDefinitions: [AudiogramDefinition] = [
        AudiogramDefinition(
            id: "sticker_audiogram_spectrum_bars",
            name: "Spectrum Bars",
            description: "Multi-band neon equalizer bars with peak caps dancing to bass, mids, and treble.",
            style: .spectrumBars,
            primaryHex: "#06B6D4",
            secondaryColorHex: "#8B5CF6",
            sensitivity: 1.2,
            barCount: 20,
            tags: ["audio", "spectrum", "eq", "bars", "audiogram", "music", "visualizer"]
        ),
        AudiogramDefinition(
            id: "sticker_audiogram_mirror_wave",
            name: "Mirror Equalizer",
            description: "Symmetrical ColorMe-style mirrored audiogram bars pulsing around a center laser beam.",
            style: .mirrorWave,
            primaryHex: "#EC4899",
            secondaryColorHex: "#3B82F6",
            sensitivity: 1.2,
            barCount: 24,
            tags: ["audio", "mirror", "podcast", "audiogram", "waveform", "beat"]
        ),
        AudiogramDefinition(
            id: "sticker_audiogram_circular_ring",
            name: "Circular Spectrum",
            description: "Radial 360-degree frequency spikes erupting outward around a luminous bass halo.",
            style: .circularRing,
            primaryHex: "#22D3EE",
            secondaryColorHex: "#A855F7",
            sensitivity: 1.25,
            barCount: 32,
            tags: ["audio", "circle", "ring", "radial", "visualizer", "edm"]
        ),
        AudiogramDefinition(
            id: "sticker_audiogram_flowing_ribbon",
            name: "Sound Wave Ribbon",
            description: "Dual smooth flowing waveform ribbons driven by real-time loudness and treble energy.",
            style: .flowingRibbon,
            primaryHex: "#10B981",
            secondaryColorHex: "#06B6D4",
            sensitivity: 1.15,
            barCount: 24,
            tags: ["audio", "wave", "ribbon", "oscilloscope", "voice", "podcast"]
        ),
        AudiogramDefinition(
            id: "sticker_audiogram_bass_speaker",
            name: "Boombox Woofer",
            description: "Studio subwoofer cone that physically thumps on bass kicks and radiates shockwave rings.",
            style: .bassSpeaker,
            primaryHex: "#F59E0B",
            secondaryColorHex: "#EF4444",
            sensitivity: 1.3,
            barCount: 16,
            tags: ["speaker", "woofer", "bass", "boombox", "subwoofer", "beat", "kick"]
        ),
        AudiogramDefinition(
            id: "sticker_audiogram_music_note",
            name: "Beat Note Pulse",
            description: "Glowing music note emblem framed by reactive sound arcs synchronized to the beat.",
            style: .musicNotePulse,
            primaryHex: "#F472B6",
            secondaryColorHex: "#60A5FA",
            sensitivity: 1.2,
            barCount: 16,
            tags: ["music", "note", "beat", "melody", "song", "pulse"]
        ),
        AudiogramDefinition(
            id: "sticker_audiogram_vinyl_disc",
            name: "Rhythm Vinyl Disc",
            description: "Spinning neon vinyl platter ringed by live outer equalizer bars that bounce on beats.",
            style: .vinylEqualizer,
            primaryHex: "#A855F7",
            secondaryColorHex: "#F59E0B",
            sensitivity: 1.2,
            barCount: 28,
            tags: ["vinyl", "disc", "record", "dj", "turntable", "music"]
        ),
        AudiogramDefinition(
            id: "sticker_audiogram_dot_matrix",
            name: "LED Particle Matrix",
            description: "Illuminated segmented LED level meters with floating peak sparks reacting to sound.",
            style: .dotMatrix,
            primaryHex: "#34D399",
            secondaryColorHex: "#FBBF24",
            sensitivity: 1.2,
            barCount: 12,
            tags: ["led", "matrix", "particles", "dots", "eq", "audiogram"]
        )
    ]
}
