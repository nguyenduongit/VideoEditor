import Foundation
import CoreMedia
import Domain

/// Extension on InspectorViewModel providing type-safe live property accessors.
/// Keeps InspectorViewModel within the 300-line limit mandated by AGENTS.md R3.1.
extension InspectorViewModel {
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
