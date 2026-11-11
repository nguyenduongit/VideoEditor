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
        let kfMap = currentKeyframeMap
        if kfMap.hasKeyframes(for: key) {
            let base = liveProperties[key]?.asNumber ?? selectedClip?.properties[key]?.asNumber ?? defaultValue
            return KeyframeEvaluator.evaluate(
                propertyKey: key,
                baseValue: base,
                atLocalTime: currentClipLocalTime,
                map: kfMap
            )
        }
        if let live = liveProperties[key]?.asNumber {
            return live
        }
        if let clip = selectedClip, let prop = clip.properties[key]?.asNumber {
            return prop
        }
        if key == "scaleWidth" || key == "scaleHeight" {
            if let liveScale = liveProperties["scale"]?.asNumber ?? selectedClip?.properties["scale"]?.asNumber {
                return liveScale
            }
        }
        return defaultValue
    }

    func handleScaleLiveProperty(key: String, value: Double) {
        let isUniform = liveBool(for: "uniformScale", default: true)
        if key == "scale" && isUniform {
            liveProperties["scaleWidth"] = .number(value)
            let ratio = liveProperties["scaleHeightRatio"]?.asNumber
                ?? selectedClip?.properties["scaleHeightRatio"]?.asNumber
                ?? 1.0
            let newHeight = value * ratio
            liveProperties["scaleHeight"] = .number(Double(round(10000.0 * newHeight) / 10000.0))
        } else if key == "scaleWidth" && !isUniform {
            liveProperties["scale"] = .number(value)
        }
    }

    func handleUniformScaleToggled(value: Bool) {
        if value {
            let currentW = liveProperties["scaleWidth"]?.asNumber
                ?? selectedClip?.properties["scaleWidth"]?.asNumber
                ?? liveProperties["scale"]?.asNumber
                ?? selectedClip?.properties["scale"]?.asNumber
                ?? 1.0
            let currentH = liveProperties["scaleHeight"]?.asNumber
                ?? selectedClip?.properties["scaleHeight"]?.asNumber
                ?? liveProperties["scale"]?.asNumber
                ?? selectedClip?.properties["scale"]?.asNumber
                ?? 1.0
            liveProperties["scale"] = .number(currentW)
            let ratio = currentW > 0.0001 ? (currentH / currentW) : 1.0
            liveProperties["scaleHeightRatio"] = .number(ratio)
        }
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

    public var activeSubtabs: [String] {
        var result: [String] = []
        for desc in tabDescriptors {
            if let condition = desc.condition, !condition.isSatisfied(by: liveProperties) { continue }
            if !result.contains(where: { $0.caseInsensitiveCompare(desc.subtab) == .orderedSame }) {
                result.append(desc.subtab)
            }
        }
        return result
    }

    public func groups(forSubtab subtab: String) -> [(group: String, descriptors: [PropertyDescriptor])] {
        groupedDescriptors.compactMap { item in
            let filtered = item.descriptors.filter {
                $0.subtab.caseInsensitiveCompare(subtab) == .orderedSame
            }
            guard !filtered.isEmpty else { return nil }
            return (group: item.group, descriptors: filtered)
        }
    }
}
