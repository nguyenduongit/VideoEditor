import Foundation
import Observation
import Domain

/// Quản lý danh sách hiệu ứng thị giác (Effects) trong sidebar.
/// Tuân thủ AGENTS.md R3.2 (@Observable) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
@Observable
@MainActor
public final class EffectLibraryViewModel {
    public var searchQuery: String = ""
    public weak var timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
    }

    public var availableEffects: [EffectType] {
        let all = EffectType.allCases
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            return all
        }
        let query = searchQuery.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(query) || $0.description.lowercased().contains(query)
        }
    }

    public func addEffectToTimeline(type: EffectType) {
        let config = EffectConfiguration(type: type)
        timelineViewModel?.addEffectClip(named: type.displayName, config: config, durationSeconds: 3.0)
    }
}
