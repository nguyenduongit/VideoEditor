import Foundation

/// Detected musical tempo resolved from an overlapping audio/video clip underneath a timeline overlay.
public struct ResolvedAudioTempo: Sendable, Equatable {
    public let bpm: Double?
    public let sourceClipID: UUID?
    public let sourceClipName: String?
    public let hasAudioUnderneath: Bool
    public let needsBeatAnalysis: Bool

    public init(
        bpm: Double? = nil,
        sourceClipID: UUID? = nil,
        sourceClipName: String? = nil,
        hasAudioUnderneath: Bool = false,
        needsBeatAnalysis: Bool = false
    ) {
        self.bpm = bpm
        self.sourceClipID = sourceClipID
        self.sourceClipName = sourceClipName
        self.hasAudioUnderneath = hasAudioUnderneath
        self.needsBeatAnalysis = needsBeatAnalysis
    }
}
