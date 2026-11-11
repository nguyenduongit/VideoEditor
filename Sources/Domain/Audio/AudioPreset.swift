import Foundation

/// Entity representing an Audio Preset in the Left Sidebar Audio Library.
/// Supports both Cloud URL streaming/downloading via Supabase Storage and offline resilience.
/// Complies with AGENTS.md rules (Pure Domain, Sendable, Codable, File <= 300 lines).
public struct AudioPreset: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var category: String
    public var duration: Double
    public var audioURL: URL?
    public var icon: String
    public var isSystem: Bool

    public init(
        id: String,
        name: String,
        category: String,
        duration: Double,
        audioURL: URL? = nil,
        icon: String = "music.note",
        isSystem: Bool = true
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.duration = duration
        self.audioURL = audioURL
        self.icon = icon
        self.isSystem = isSystem
    }

    public var durationFormatted: String {
        if id == "audio_dance_beat" { return "8-Beat" }
        if duration <= 0 { return "Auto" }
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Built-in fallback catalog for offline mode and initial seeding.
    public static let builtInCatalog: [AudioPreset] = [
        AudioPreset(
            id: "audio_dance_beat",
            name: "Dance Beat Counter",
            category: "Dance Beat",
            duration: 0,
            audioURL: nil,
            icon: "figure.dance",
            isSystem: true
        ),
        AudioPreset(
            id: "audio_bgm_sunny_day",
            name: "Sunny Day Acoustic",
            category: "Music",
            duration: 134,
            audioURL: URL(string: "https://assets.mixkit.co/music/preview/mixkit-sunny-day-acoustic-guitar-55.mp3"),
            icon: "music.note",
            isSystem: true
        )
    ]
}

