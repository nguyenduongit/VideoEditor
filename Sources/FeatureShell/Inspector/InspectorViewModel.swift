import Foundation
import CoreMedia
import Observation
import Domain

/// Manages Inspector state for the currently selected clip on the timeline.
/// Conforms to R6.2 and R7.5 of AGENTS.md: builds controls dynamically from descriptors
/// and batches continuous slider changes into single transactional commands.
@Observable
@MainActor
public final class InspectorViewModel {
    public weak var timelineViewModel: TimelineViewModel?
    public let actionsPanelViewModel: ActionsPanelViewModel
    public var liveProperties: [String: PropertyValue] = [:]
    public var preMuteVolumeByClipID: [UUID: Double] = [:]
    public var selectedTab: String = "Video"
    public var selectedTransitionID: UUID? {
        get { timelineViewModel?.selectedTransitionID }
        set {
            timelineViewModel?.selectedTransitionID = newValue
            if newValue != nil {
                selectedTab = "Transition"
            }
        }
    }

    public var selectedTransition: CutTransition? {
        guard let selectedTransitionID, let timelineViewModel else { return nil }
        for layer in timelineViewModel.layers {
            if let t = layer.transition(by: selectedTransitionID) {
                return t
            }
        }
        return nil
    }

    public var isSelectedClipLockedTemplate: Bool {
        false
    }

    private var currentLoadedClipID: UUID?
    private var lastClipKind: ClipKind?
    var dragInitialProperties: [String: PropertyValue]?
    var dragInitialTransition: CutTransition?

    public let propertyRegistry: ClipPropertyRegistry
    public var dependencies: EditorDependencies {
        timelineViewModel?.dependencies ?? EditorDependencies(propertyRegistry: propertyRegistry)
    }
    public var fontManager: CustomFontManager {
        timelineViewModel?.fontManager ?? CustomFontManager()
    }

    public init(
        timelineViewModel: TimelineViewModel? = nil,
        mediaLibraryViewModel: MediaLibraryViewModel? = nil,
        propertyRegistry: ClipPropertyRegistry? = nil
    ) {
        self.timelineViewModel = timelineViewModel
        self.propertyRegistry = propertyRegistry ?? timelineViewModel?.dependencies.propertyRegistry ?? ClipPropertyRegistry()
        self.actionsPanelViewModel = ActionsPanelViewModel(
            timelineViewModel: timelineViewModel,
            mediaLibraryViewModel: mediaLibraryViewModel,
            dependencies: timelineViewModel?.dependencies
        )
        syncWithSelection()
    }

    public var selectedClip: TimelineClip? {
        guard let timelineViewModel,
              timelineViewModel.selectedClipIDs.count == 1,
              let clipID = timelineViewModel.selectedClipIDs.first else {
            return nil
        }
        return timelineViewModel.clip(by: clipID)
    }

    public var availableTabs: [String] {
        if selectedTransition != nil {
            return ["Transition"]
        }
        guard let clip = selectedClip else { return [] }
        return propertyRegistry.tabs(for: clip.kind)
    }

    public var effectiveTab: String {
        if selectedTransition != nil {
            return "Transition"
        }
        guard selectedClip != nil else { return selectedTab }
        let tabs = availableTabs
        if tabs.contains(where: { $0.caseInsensitiveCompare(selectedTab) == .orderedSame }) {
            return selectedTab
        }
        return tabs.first ?? "General"
    }

    public var isAutoPanActive: Bool {
        guard let str = liveProperties["autoPanConfig"]?.asString ?? selectedClip?.properties["autoPanConfig"]?.asString,
              let config = AutoPanConfiguration.decode(from: str) else {
            return false
        }
        return config.isEnabled && !config.keyframes.isEmpty
    }

    public var descriptors: [PropertyDescriptor] {
        guard let clip = selectedClip else { return [] }
        return propertyRegistry.descriptors(for: clip.kind)
    }

    public var tabDescriptors: [PropertyDescriptor] {
        guard let clip = selectedClip else { return [] }
        return propertyRegistry.descriptors(for: clip.kind, tab: effectiveTab)
    }

    public var groupedDescriptors: [(group: String, descriptors: [PropertyDescriptor])] {
        var groups: [(group: String, descriptors: [PropertyDescriptor])] = []
        for desc in tabDescriptors {
            if let condition = desc.condition, !condition.isSatisfied(by: liveProperties) {
                continue
            }
            if let index = groups.firstIndex(where: { $0.group == desc.group }) {
                groups[index].descriptors.append(desc)
            } else {
                groups.append((group: desc.group, descriptors: [desc]))
            }
        }
        return groups
    }

    public func syncWithSelection() {
        if let clip = selectedClip {
            selectedTransitionID = nil
            if currentLoadedClipID != clip.id {
                currentLoadedClipID = clip.id
                liveProperties = clip.properties
                let tabs = availableTabs
                if lastClipKind != clip.kind || !tabs.contains(where: { $0.caseInsensitiveCompare(selectedTab) == .orderedSame }) {
                    selectedTab = tabs.first ?? "General"
                }
                lastClipKind = clip.kind
            } else if dragInitialProperties == nil {
                liveProperties = clip.properties
            }
        } else if selectedTransition != nil {
            currentLoadedClipID = nil
            lastClipKind = nil
            liveProperties = [:]
            dragInitialProperties = nil
            selectedTab = "Transition"
        } else {
            currentLoadedClipID = nil
            lastClipKind = nil
            liveProperties = [:]
            dragInitialProperties = nil
            dragInitialTransition = nil
        }
    }

    public func onSliderEditingChanged(key: String, isEditing: Bool) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        if isEditing {
            if dragInitialProperties == nil {
                dragInitialProperties = clip.properties
            }
        } else {
            if let initial = dragInitialProperties, initial != liveProperties {
                let retimeable = clip.kind == .video || clip.kind == .audio || clip.kind == .image
                if (key == "speed" || key == "duration") && retimeable {
                    timelineViewModel.applySpeedChange(clipID: clip.id, newProperties: liveProperties, oldProperties: initial)
                } else {
                    timelineViewModel.updateClipLiveProperties(clipID: clip.id, properties: initial)
                    let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: liveProperties)
                    timelineViewModel.commandExecutor?.execute(cmd)
                }
            }
            dragInitialProperties = nil
            syncWithSelection()
        }
    }

    public func commitTextProperty(key: String, text: String) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        dragInitialProperties = nil
        liveProperties[key] = .string(text)
        if key == "textConfig", let cfg = TextConfiguration.decode(from: text) {
            syncTextFlatProperties(from: cfg)
        }
        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: liveProperties)
        timelineViewModel.commandExecutor?.execute(cmd)
        ensurePlayheadWithinClip(clip: clip)
        syncWithSelection()
    }

    public func updateLiveValue(key: String, value: Double) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        if dragInitialProperties == nil {
            dragInitialProperties = clip.properties
        }
        liveProperties[key] = .number(value)
        applyAutoKeyframeIfNeeded(key: key, value: value)
        syncTextConfigFromLiveNumber(key: key, value: value, clip: clip)
        let retimeable = clip.kind == .video || clip.kind == .audio || clip.kind == .image
        if key == "speed" && retimeable {
            let oldSpeed = max(0.01, dragInitialProperties?["speed"]?.asNumber ?? clip.properties["speed"]?.asNumber ?? 1.0)
            let sourceDur = CMTimeGetSeconds(clip.timeRange.duration) * oldSpeed
            let newDur = max(0.1, sourceDur / max(0.01, value))
            liveProperties["duration"] = .number(Double(round(100.0 * newDur) / 100.0))
        } else if key == "duration" && retimeable {
            let oldSpeed = max(0.01, dragInitialProperties?["speed"]?.asNumber ?? clip.properties["speed"]?.asNumber ?? 1.0)
            let sourceDur = CMTimeGetSeconds(clip.timeRange.duration) * oldSpeed
            let newSpeed = max(0.1, min(10.0, sourceDur / max(0.1, value)))
            liveProperties["speed"] = .number(Double(round(100.0 * newSpeed) / 100.0))
        }
        timelineViewModel.updateClipLiveProperties(clipID: clip.id, properties: liveProperties)
    }

    public func updateLiveText(key: String, text: String) {
        if dragInitialProperties == nil, let clip = selectedClip {
            dragInitialProperties = clip.properties
        }
        liveProperties[key] = .string(text)
        if key == "textConfig", let cfg = TextConfiguration.decode(from: text) {
            syncTextFlatProperties(from: cfg)
        }
        guard let clip = selectedClip, let timelineViewModel else { return }
        timelineViewModel.updateClipLiveProperties(clipID: clip.id, properties: liveProperties)
        ensurePlayheadWithinClip(clip: clip)
    }

    private func ensurePlayheadWithinClip(clip: TimelineClip) {
        guard let timelineViewModel else { return }
        let curTime = timelineViewModel.currentTime
        let start = clip.timeRange.start
        let end = CMTimeAdd(start, clip.timeRange.duration)
        if curTime < start || curTime >= end {
            let offsetSec = min(0.5, max(0.05, CMTimeGetSeconds(clip.timeRange.duration) / 2.0))
            let targetTime = CMTimeAdd(start, CMTime(seconds: offsetSec, preferredTimescale: 600))
            timelineViewModel.seek(to: targetTime)
        }
    }

    public func updateLiveBool(key: String, value: Bool) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        liveProperties[key] = .bool(value)
        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: liveProperties)
        timelineViewModel.commandExecutor?.execute(cmd)
        syncWithSelection()
    }

    public func updateDiscreteString(key: String, value: String) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        liveProperties[key] = .string(value)
        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: liveProperties)
        timelineViewModel.commandExecutor?.execute(cmd)
        syncWithSelection()
    }

    public func resetGroup(name: String) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        let groupDesc = propertyRegistry.descriptors(for: clip.kind).filter { $0.group == name }
        for desc in groupDesc {
            liveProperties[desc.id] = desc.defaultValue
            if case .position2D(let xID, let yID, _) = desc.control {
                liveProperties[xID] = .number(0.0)
                liveProperties[yID] = .number(0.0)
            }
        }
        var kfMap = currentKeyframeMap
        for key in keyframeKeys(forGroup: groupDesc) {
            kfMap.removeAllKeyframes(for: key)
        }
        liveProperties[ClipKeyframeMap.propertyKey] = kfMap.encodeToJSON().map(PropertyValue.string)
        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: liveProperties)
        timelineViewModel.commandExecutor?.execute(cmd)
        syncWithSelection()
    }
}
