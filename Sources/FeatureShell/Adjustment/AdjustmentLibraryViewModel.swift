import Foundation
import Observation
import Domain

/// Quản lý trạng thái và thao tác trong thư viện Adjustment Layer (Sidebar trái).
/// Tuân thủ R3.2 (@Observable) và R7.1 của AGENTS.md.
@Observable
@MainActor
public final class AdjustmentLibraryViewModel {
    public enum SubTab: String, CaseIterable, Sendable {
        case `default` = "Mặc định"
        case templates = "Templates"
    }

    public var selectedSubTab: SubTab = .default
    public weak var timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
    }

    public var defaultPreset: AdjustmentPreset {
        .default
    }

    public var templatePresets: [AdjustmentPreset] {
        AdjustmentPreset.templates
    }

    public func addPresetToTimeline(_ preset: AdjustmentPreset) {
        guard let timelineViewModel else { return }
        timelineViewModel.addAdjustmentClip(
            named: preset.name,
            config: preset.config
        )
    }
}
