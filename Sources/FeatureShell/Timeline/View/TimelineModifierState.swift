import Foundation
import Observation

/// Theo dõi trạng thái phím bổ trợ (như Option `⌥`) theo thời gian thực trong các thao tác kéo thả trên Timeline.
/// Tuân thủ AGENTS.md (1 File = 1 Primary Type, @MainActor Observation).
@Observable
@MainActor
public final class TimelineModifierState {
    public var isOptionPressed: Bool = false

    public init() {}
}
