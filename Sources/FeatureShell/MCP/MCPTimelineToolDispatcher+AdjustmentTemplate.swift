import Foundation
import CoreMedia
import Domain

extension MCPTimelineToolDispatcher {
    func applyOrUpdateAdjustmentConfiguration(_ dict: [String: Any]) throws -> String {
        let vm = scriptEngine.currentViewModel
        let preservedSelection = vm.selectedClipIDs
        let updateExisting = (dict["updateExisting"] as? Bool) ?? false

        var cfg = AdjustmentConfiguration()
        var clipTitle = "Tùy chỉnh Màu AI"

        if let templateId = dict["templateId"] as? String, !templateId.isEmpty {
            let query = templateId.lowercased()
            if let matched = dependencies.adjustmentTemplates.loadAllTemplates().first(where: {
                $0.id.lowercased() == query || $0.name.lowercased() == query
            }) {
                cfg = matched.config
                clipTitle = matched.name
            }
        }
        if let customName = dict["name"] as? String, !customName.isEmpty {
            clipTitle = customName
        }

        if let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .adjustment }),
           let existingJSON = existingClip.properties["adjustmentConfig"]?.asString,
           let decoded = AdjustmentConfiguration.decode(from: existingJSON),
           (updateExisting || dict["templateId"] == nil) {
            cfg = decoded
        }

        applyAdjustmentOverrides(from: dict, to: &cfg)

        let allMediaClips = vm.layers.flatMap(\.clips).filter { $0.kind == .video || $0.kind == .image }
        let defaultStartSec = allMediaClips.map { CMTimeGetSeconds($0.timeRange.start) }.min() ?? 0.0
        let defaultEndSec = allMediaClips.map { CMTimeGetSeconds($0.timeRange.end) }.max() ?? max(5.0, CMTimeGetSeconds(vm.totalDuration))
        let resolvedStart = dict["startTimeSeconds"] as? Double ?? defaultStartSec
        let resolvedDur = dict["durationSeconds"] as? Double ?? max(1.0, defaultEndSec - resolvedStart)
        let targetTime = CMTime(seconds: max(0, resolvedStart), preferredTimescale: TimeRational.defaultFPS)

        if let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .adjustment }) {
            var newProps = existingClip.properties
            if let encoded = cfg.encodeToJSON() { newProps["adjustmentConfig"] = .string(encoded) }
            var cmds: [TimelineCommand] = [.updateClipProperties(clipID: existingClip.id, properties: newProps)]
            if existingClip.timeRange.start > targetTime || CMTimeGetSeconds(existingClip.timeRange.duration) < (resolvedDur - 0.2) {
                let rStart = RationalTime(cmTime: targetTime)
                let rDur = RationalTime(cmTime: CMTime(seconds: resolvedDur, preferredTimescale: TimeRational.defaultFPS))
                cmds.append(.trimClip(clipID: existingClip.id, newStart: rStart, newDuration: rDur, newSourceStart: nil))
            }
            _ = scriptEngine.executeCommands(cmds)
            vm.selectedClipIDs = preservedSelection
            return "{\"status\":\"success\",\"updatedAdjustmentClip\":\"\(existingClip.name)\"}"
        }

        vm.addAdjustmentClip(
            named: clipTitle,
            config: cfg,
            durationSeconds: resolvedDur,
            at: targetTime
        )
        vm.selectedClipIDs = preservedSelection
        return "{\"status\":\"success\",\"createdCustomAdjustment\":\"\(clipTitle)\"}"
    }

    private func applyAdjustmentOverrides(from dict: [String: Any], to cfg: inout AdjustmentConfiguration) {
        func num(_ key: String) -> Float? {
            (dict[key] as? NSNumber)?.floatValue ?? (dict[key] as? Double).map(Float.init)
        }
        if let v = num("exposure") { cfg.basic.exposure = v }
        if let v = num("contrast") { cfg.basic.contrast = v }
        if let v = num("highlight") { cfg.basic.highlight = v }
        if let v = num("shadow") { cfg.basic.shadow = v }
        if let v = num("white") { cfg.basic.white = v }
        if let v = num("black") { cfg.basic.black = v }
        if let v = num("saturation") { cfg.basic.saturation = v }
        if let v = num("brilliance") { cfg.basic.brilliance = v }
        if let v = num("temp") { cfg.basic.temp = v }
        if let v = num("tint") { cfg.basic.tint = v }
        if let v = num("vignetteAmount") { cfg.effects.vignetteAmount = v }
        if let v = num("grainAmount") { cfg.effects.grainAmount = v }
        if let v = num("sharpenAmount") { cfg.effects.sharpenAmount = v }
    }
}
