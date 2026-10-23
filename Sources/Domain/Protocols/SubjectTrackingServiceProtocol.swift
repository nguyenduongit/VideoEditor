import Foundation
import CoreMedia

/// Service protocol for tracking subjects (humans, faces) in a video clip.
/// Complies with R2.6 and R4.3 of AGENTS.md.
public protocol SubjectTrackingServiceProtocol: Sendable {
    func trackSubject(
        in mediaURL: URL,
        timeRange: CMTimeRange,
        samplesPerSecond: Double,
        smoothness: Double,
        onProgress: (@Sendable (Double) -> Void)?
    ) async throws -> [AutoPanKeyframe]
}
