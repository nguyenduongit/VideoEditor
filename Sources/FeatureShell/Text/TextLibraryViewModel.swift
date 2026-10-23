import Foundation
import Observation
import Domain

/// Quản lý trạng thái và thao tác trong thư viện Text Layer (Sidebar trái).
/// Tuân thủ R3.2 (@Observable) và R7.1 của AGENTS.md.
@Observable
@MainActor
public final class TextLibraryViewModel {
    public enum SubTab: String, CaseIterable, Sendable {
        case `default` = "Mặc định"
        case templates = "Templates"
    }

    public var selectedSubTab: SubTab = .default
    public weak var timelineViewModel: TimelineViewModel?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
    }

    public var defaultPreset: TextPreset {
        .default
    }

    public var templatePresets: [TextPreset] {
        TextPreset.templates
    }

    public func addPresetToTimeline(_ preset: TextPreset) {
        guard let timelineViewModel else { return }
        timelineViewModel.addTextClip(
            named: preset.name,
            config: preset.config
        )
    }
}
