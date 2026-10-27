import Foundation
import CoreMedia
import Domain

extension MCPTimelineToolDispatcher {
    func editClipArgument(_ argumentsJSON: String) throws -> String {
        guard let data = argumentsJSON.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let op = (dict["operation"] as? String)?.lowercased() else {
            throw AppError.invalidParameter("Missing 'operation' in timeline_edit_clip")
        }

        let vm = scriptEngine.currentViewModel
        let preservedSelection = vm.selectedClipIDs

        if op == "setaspectratio" {
            let ratioStr = (dict["aspectRatio"] as? String) ?? "16:9"
            let ratio = CanvasAspectRatio(rawValue: ratioStr) ?? .ratio16x9
            vm.setAspectRatio(ratio)
            return "{\"status\":\"success\",\"aspectRatio\":\"\(ratio.rawValue)\"}"
        }

        if op == "seek" {
            let atSec = (dict["atTimeSeconds"] as? Double) ?? 0.0
            let time = CMTime(seconds: max(0, atSec), preferredTimescale: TimeRational.defaultFPS)
            vm.seek(to: time)
            return "{\"status\":\"success\",\"operation\":\"seek\",\"timeSeconds\":\(atSec)}"
        }

        let clipQuery = (dict["clipId"] as? String)?.lowercased() ?? "video"
        let allClips = vm.layers.flatMap(\.clips)
        let matchedClip = allClips.first(where: {
            $0.id.uuidString.lowercased() == clipQuery ||
            $0.name.lowercased().contains(clipQuery) ||
            $0.kind.rawValue.lowercased() == clipQuery
        }) ?? allClips.first

        guard let clip = matchedClip else {
            throw AppError.invalidParameter("No clip found matching '\(clipQuery)'")
        }

        let atSec = (dict["atTimeSeconds"] as? Double) ?? CMTimeGetSeconds(clip.timeRange.start)
        let newDurSec = (dict["newDurationSeconds"] as? Double) ?? CMTimeGetSeconds(clip.timeRange.duration)
        let rationalAt = RationalTime(cmTime: CMTime(seconds: max(0, atSec), preferredTimescale: TimeRational.defaultFPS))
        let rationalDur = RationalTime(cmTime: CMTime(seconds: max(0.2, newDurSec), preferredTimescale: TimeRational.defaultFPS))

        switch op {
        case "split":
            _ = scriptEngine.executeCommands([.splitClip(clipID: clip.id, atTime: rationalAt)])
        case "trim":
            _ = scriptEngine.executeCommands([.trimClip(clipID: clip.id, newStart: rationalAt, newDuration: rationalDur, newSourceStart: nil)])
        case "remove", "delete":
            _ = scriptEngine.executeCommands([.removeClip(clipID: clip.id)])
        case "move":
            if let layer = vm.layers.first(where: { $0.clips.contains(where: { $0.id == clip.id }) }) {
                _ = scriptEngine.executeCommands([.moveClip(clipID: clip.id, targetLayerID: layer.id, newStartTime: rationalAt)])
            }
        default:
            throw AppError.invalidParameter("Unknown edit operation: \(op)")
        }
        vm.selectedClipIDs = preservedSelection
        return "{\"status\":\"success\",\"operation\":\"\(op)\",\"clipName\":\"\(clip.name)\"}"
    }
}
