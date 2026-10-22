import Foundation

/// Data structure representing the result of an audio alignment correlation match.
public struct AudioAlignmentResult: Sendable, Equatable {
    public let offsetSeconds: Double
    public let correlation: Double
    public let score: Double
    public let isMatch: Bool

    public init(
        offsetSeconds: Double,
        correlation: Double,
        score: Double,
        isMatch: Bool
    ) {
        self.offsetSeconds = offsetSeconds
        self.correlation = correlation
        self.score = score
        self.isMatch = isMatch
    }
}

/// Protocol defining the contract for audio alignment / synchronization services.
public protocol AudioAlignmentServiceProtocol: Sendable {
    func calculateAlignmentOffset(sourceURL1: URL, sourceURL2: URL) async -> AudioAlignmentResult?
}
