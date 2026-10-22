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
    public var liveProperties: [String: PropertyValue] = [:]
    public var selectedTab: String = "Video"

    private var currentLoadedClipID: UUID?
    private var lastClipKind: ClipKind?
    private var dragInitialProperties: [String: PropertyValue]?

    public init(timelineViewModel: TimelineViewModel? = nil) {
        self.timelineViewModel = timelineViewModel
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
        guard let clip = selectedClip else { return [] }
        return ClipPropertyRegistry.shared.tabs(for: clip.kind)
    }

    public var effectiveTab: String {
        guard let clip = selectedClip else { return selectedTab }
        let tabs = ClipPropertyRegistry.shared.tabs(for: clip.kind)
        if tabs.contains(where: { $0.caseInsensitiveCompare(selectedTab) == .orderedSame }) {
            return selectedTab
        }
        return tabs.first ?? "General"
    }

    public var descriptors: [PropertyDescriptor] {
        guard let clip = selectedClip else { return [] }
        return ClipPropertyRegistry.shared.descriptors(for: clip.kind)
    }

    public var tabDescriptors: [PropertyDescriptor] {
        guard let clip = selectedClip else { return [] }
        return ClipPropertyRegistry.shared.descriptors(for: clip.kind, tab: effectiveTab)
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
            if currentLoadedClipID != clip.id {
                currentLoadedClipID = clip.id
                liveProperties = clip.properties
                let tabs = ClipPropertyRegistry.shared.tabs(for: clip.kind)
                if lastClipKind != clip.kind || !tabs.contains(where: { $0.caseInsensitiveCompare(selectedTab) == .orderedSame }) {
                    selectedTab = tabs.first ?? "General"
                }
                lastClipKind = clip.kind
            } else if dragInitialProperties == nil {
                liveProperties = clip.properties
            }
        } else {
            currentLoadedClipID = nil
            lastClipKind = nil
            liveProperties = [:]
            dragInitialProperties = nil
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
                if key == "speed" || key == "duration" {
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
        liveProperties[key] = .string(text)
        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: liveProperties)
        timelineViewModel.commandExecutor?.execute(cmd)
        syncWithSelection()
    }

    public func updateLiveValue(key: String, value: Double) {
        guard let clip = selectedClip, let timelineViewModel else { return }
        if dragInitialProperties == nil {
            dragInitialProperties = clip.properties
        }
        liveProperties[key] = .number(value)
        if key == "speed" {
            let oldSpeed = max(0.01, dragInitialProperties?["speed"]?.asNumber ?? clip.properties["speed"]?.asNumber ?? 1.0)
            let currentDur = CMTimeGetSeconds(clip.timeRange.duration)
            let sourceDur = currentDur * oldSpeed
            let newDur = max(0.1, sourceDur / max(0.01, value))
            liveProperties["duration"] = .number(Double(round(100.0 * newDur) / 100.0))
        } else if key == "duration" {
            let oldSpeed = max(0.01, dragInitialProperties?["speed"]?.asNumber ?? clip.properties["speed"]?.asNumber ?? 1.0)
            let currentDur = CMTimeGetSeconds(clip.timeRange.duration)
            let sourceDur = currentDur * oldSpeed
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
        guard let clip = selectedClip, let timelineViewModel else { return }
        timelineViewModel.updateClipLiveProperties(clipID: clip.id, properties: liveProperties)
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
        let allDesc = ClipPropertyRegistry.shared.descriptors(for: clip.kind)
        let groupDesc = allDesc.filter { $0.group == name }

        for desc in groupDesc {
            liveProperties[desc.id] = desc.defaultValue
            if case .position2D(let xID, let yID, _) = desc.control {
                liveProperties[xID] = .number(0.0)
                liveProperties[yID] = .number(0.0)
            }
        }

        let cmd = TimelineCommand.updateClipProperties(clipID: clip.id, properties: liveProperties)
        timelineViewModel.commandExecutor?.execute(cmd)
        syncWithSelection()
    }

    public func liveNumber(for key: String, default defaultValue: Double) -> Double {
        if key == "duration" {
            if let live = liveProperties["duration"]?.asNumber, live > 0 {
                return live
            }
            if let clip = selectedClip {
                return CMTimeGetSeconds(clip.timeRange.duration)
            }
        }
        if let live = liveProperties[key]?.asNumber {
            return live
        }
        if let clip = selectedClip, let prop = clip.properties[key]?.asNumber {
            return prop
        }
        return defaultValue
    }

    public func liveString(for key: String, default defaultValue: String) -> String {
        if let live = liveProperties[key]?.asString {
            return live
        }
        if let clip = selectedClip, let prop = clip.properties[key]?.asString {
            return prop
        }
        return defaultValue
    }

    public func liveBool(for key: String, default defaultValue: Bool) -> Bool {
        if let live = liveProperties[key]?.asBool {
            return live
        }
        if let clip = selectedClip, let prop = clip.properties[key]?.asBool {
            return prop
        }
        return defaultValue
    }
}
