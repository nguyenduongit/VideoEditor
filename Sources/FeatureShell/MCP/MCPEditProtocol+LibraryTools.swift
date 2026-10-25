import Foundation
import CoreMedia
import Domain

extension MCPTimelineToolDispatcher {
    func getLibraryCatalogArgument() throws -> String {
        let assetsList: [[String: String]] = (mediaLibraryViewModel?.assets ?? []).map {
            ["id": $0.id.uuidString, "name": $0.name, "type": $0.type.rawValue, "url": $0.url.absoluteString]
        }
        let textPresets: [[String: String]] = TextPreset.templates.map {
            ["id": $0.id, "name": $0.name, "category": $0.category.rawValue, "description": $0.description]
        }
        let adjustmentPresets: [[String: String]] = AdjustmentPreset.templates.map {
            ["id": $0.id, "name": $0.name, "category": $0.category.rawValue, "description": $0.description]
        }
        let payload: [String: Any] = [
            "mediaAssets": assetsList,
            "textTemplates": textPresets,
            "adjustmentTemplates": adjustmentPresets
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    func addMediaAssetArgument(_ argumentsJSON: String) throws -> String {
        guard let data = argumentsJSON.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AppError.invalidParameter("Invalid JSON arguments for timeline_add_media_asset")
        }

        let assets = mediaLibraryViewModel?.assets ?? []
        guard !assets.isEmpty else {
            throw AppError.invalidParameter("Media Library is currently empty. Please import a video/audio/image file first.")
        }

        let assetId = dict["assetId"] as? String
        let fileName = dict["fileName"] as? String
        let startSeconds = (dict["startTimeSeconds"] as? Double) ?? 0.0

        let matchedAsset: MediaAsset?
        if let assetId, let exact = assets.first(where: { $0.id.uuidString.caseInsensitiveCompare(assetId) == .orderedSame }) {
            matchedAsset = exact
        } else if let fileName, !fileName.isEmpty {
            let query = fileName.lowercased()
            matchedAsset = assets.first(where: { $0.name.lowercased().contains(query) }) ?? assets.first
        } else {
            matchedAsset = assets.first
        }

        guard let targetAsset = matchedAsset else {
            throw AppError.invalidParameter("No matching media asset found")
        }

        let vm = scriptEngine.currentViewModel
        let preservedSelection = vm.selectedClipIDs
        let targetTime = CMTime(seconds: max(0, startSeconds), preferredTimescale: TimeRational.defaultFPS)
        vm.addAsset(targetAsset, at: targetTime)
        vm.selectedClipIDs = preservedSelection

        return "{\"status\":\"success\",\"addedAssetName\":\"\(targetAsset.name)\"}"
    }

    func applyTemplateArgument(_ argumentsJSON: String) throws -> String {
        guard let data = argumentsJSON.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let kind = (dict["kind"] as? String)?.lowercased() else {
            throw AppError.invalidParameter("Missing required 'kind' in timeline_apply_template")
        }

        if kind == "text" {
            return try applyOrUpdateTextConfiguration(dict)
        } else if kind == "adjustment" {
            return try applyOrUpdateAdjustmentConfiguration(dict)
        } else {
            throw AppError.invalidParameter("Unsupported kind: \(kind). Expected 'text' or 'adjustment'.")
        }
    }

    private func applyOrUpdateTextConfiguration(_ dict: [String: Any]) throws -> String {
        let vm = scriptEngine.currentViewModel
        let preservedSelection = vm.selectedClipIDs
        let updateExisting = (dict["updateExisting"] as? Bool) ?? false

        var cfg = TextConfiguration(
            content: "TIÊU ĐỀ", fontName: "System", fontSize: 64.0, textColorHex: "#FFFFFF",
            isBold: true, characterSpacing: 1.5, hasStroke: true, strokeColorHex: "#0F172A",
            strokeWidth: 4.0, hasShadow: true, shadowColorHex: "#000000B3", shadowRadius: 8.0,
            shadowOffsetY: 3.0, hasGlow: true, glowColorHex: "#38BDF8", glowRadius: 16.0, positionY: -180.0
        )
        cfg.animation.inType = .springDrop
        cfg.animation.outType = .fadeOut
        cfg.animation.loopType = .liquidWave
        cfg.animation.comboType = .none
        cfg.animation.scope = .perWord

        if let templateId = dict["templateId"] as? String, !templateId.isEmpty {
            let query = templateId.lowercased()
            if let matched = TextPreset.templates.first(where: { $0.id.lowercased() == query }) {
                cfg = matched.config
                // Luôn dùng font System hỗ trợ đầy đủ dấu Tiếng Việt nếu chữ có dấu
                cfg.fontName = "System"
                if cfg.animation.comboType == .karaokeBox {
                    cfg.animation.comboType = .none
                }
            }
        }

        if updateExisting,
           let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .text }),
           let existingJSON = existingClip.properties["textConfig"]?.asString,
           let decoded = TextConfiguration.decode(from: existingJSON) {
            cfg = decoded
        }

        applyTextOverrides(from: dict, to: &cfg)

        if updateExisting, let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .text }) {
            var newProps = existingClip.properties
            if let encoded = cfg.encodeToJSON() { newProps["textConfig"] = .string(encoded) }
            newProps["textContent"] = .string(cfg.content)
            newProps["fontSize"] = .number(cfg.fontSize)
            newProps["positionX"] = .number(cfg.positionX)
            newProps["positionY"] = .number(cfg.positionY)
            _ = scriptEngine.executeCommands([.updateClipProperties(clipID: existingClip.id, properties: newProps)])
            vm.selectedClipIDs = preservedSelection
            return "{\"status\":\"success\",\"updatedTextClip\":\"\(cfg.content)\"}"
        }

        let durationSeconds = (dict["durationSeconds"] as? Double) ?? 5.0
        let startSeconds = dict["startTimeSeconds"] as? Double
        let targetTime = startSeconds.map { CMTime(seconds: max(0, $0), preferredTimescale: TimeRational.defaultFPS) }
        vm.addTextClip(named: cfg.content, config: cfg, durationSeconds: max(1.0, durationSeconds), at: targetTime)
        vm.selectedClipIDs = preservedSelection
        return "{\"status\":\"success\",\"createdCustomText\":\"\(cfg.content)\"}"
    }

    private func applyTextOverrides(from dict: [String: Any], to cfg: inout TextConfiguration) {
        if let customText = dict["customText"] as? String, !customText.isEmpty { cfg.content = customText }
        if let fontSize = dict["fontSize"] as? Double, fontSize > 8 { cfg.fontSize = fontSize }
        if let textColor = dict["textColorHex"] as? String, !textColor.isEmpty { cfg.textColorHex = textColor }
        if let strokeColor = dict["strokeColorHex"] as? String, !strokeColor.isEmpty {
            cfg.strokeColorHex = strokeColor
            cfg.hasStroke = true
            if cfg.strokeWidth <= 0 { cfg.strokeWidth = 4.0 }
        }
        if let strokeWidth = dict["strokeWidth"] as? Double { cfg.strokeWidth = strokeWidth; cfg.hasStroke = strokeWidth > 0 }
        if let glowColor = dict["glowColorHex"] as? String, !glowColor.isEmpty {
            cfg.glowColorHex = glowColor
            cfg.hasGlow = true
            if cfg.glowRadius <= 0 { cfg.glowRadius = 18.0 }
        }
        if let glowRadius = dict["glowRadius"] as? Double { cfg.glowRadius = glowRadius; cfg.hasGlow = glowRadius > 0 }
        if let posX = dict["positionX"] as? Double { cfg.positionX = posX }
        if let posY = dict["positionY"] as? Double { cfg.positionY = posY }
        if let inAnim = dict["inAnimation"] as? String { cfg.animation.inType = resolveInAnimation(inAnim) }
        if let loopAnim = dict["loopAnimation"] as? String { cfg.animation.loopType = resolveLoopAnimation(loopAnim) }
    }

    private func resolveInAnimation(_ raw: String) -> TextInAnimationType {
        if let exact = TextInAnimationType(rawValue: raw) { return exact }
        let lower = raw.lowercased()
        if lower.contains("spring") || lower.contains("drop") { return .springDrop }
        if lower.contains("wave") { return .waveBounce }
        if lower.contains("jelly") || lower.contains("elastic") || lower.contains("pop") { return .elasticJellyIn }
        if lower.contains("neon") || lower.contains("flicker") { return .neonFlicker }
        if lower.contains("type") { return .typewriter }
        if lower.contains("expand") || lower.contains("cinema") { return .trackingExpand }
        if lower.contains("glitch") { return .glitchSliceIn }
        if lower.contains("slide") { return .slideUp }
        return .springDrop
    }

    private func resolveLoopAnimation(_ raw: String) -> TextLoopAnimationType {
        if let exact = TextLoopAnimationType(rawValue: raw) { return exact }
        let lower = raw.lowercased()
        if lower.contains("wave") { return .liquidWave }
        if lower.contains("float") { return .floating }
        if lower.contains("heart") || lower.contains("pulse") { return .heartbeat }
        if lower.contains("neon") || lower.contains("flicker") { return .neonPulse }
        if lower.contains("none") { return .none }
        return .liquidWave
    }

    private func applyOrUpdateAdjustmentConfiguration(_ dict: [String: Any]) throws -> String {
        let vm = scriptEngine.currentViewModel
        let preservedSelection = vm.selectedClipIDs
        let updateExisting = (dict["updateExisting"] as? Bool) ?? false

        var cfg = AdjustmentConfiguration()
        var clipTitle = "Tùy chỉnh Màu AI"

        if let templateId = dict["templateId"] as? String, !templateId.isEmpty {
            let query = templateId.lowercased()
            if let matched = AdjustmentPreset.templates.first(where: { $0.id.lowercased() == query }) {
                cfg = matched.config
                clipTitle = matched.name
            }
        }

        if let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .adjustment }),
           let existingJSON = existingClip.properties["adjustmentConfig"]?.asString,
           let decoded = AdjustmentConfiguration.decode(from: existingJSON),
           (updateExisting || dict["templateId"] == nil) {
            cfg = decoded
        }

        applyAdjustmentOverrides(from: dict, to: &cfg)

        if let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .adjustment }) {
            var newProps = existingClip.properties
            if let encoded = cfg.encodeToJSON() { newProps["adjustmentConfig"] = .string(encoded) }
            _ = scriptEngine.executeCommands([.updateClipProperties(clipID: existingClip.id, properties: newProps)])
            vm.selectedClipIDs = preservedSelection
            return "{\"status\":\"success\",\"updatedAdjustmentClip\":\"\(existingClip.name)\"}"
        }

        let startSeconds = dict["startTimeSeconds"] as? Double
        let durationSeconds = dict["durationSeconds"] as? Double
        let targetTime = startSeconds.map { CMTime(seconds: max(0, $0), preferredTimescale: TimeRational.defaultFPS) }
        vm.addAdjustmentClip(
            named: clipTitle,
            config: cfg,
            durationSeconds: durationSeconds,
            at: targetTime
        )
        vm.selectedClipIDs = preservedSelection
        return "{\"status\":\"success\",\"createdCustomAdjustment\":\"\(clipTitle)\"}"
    }

    private func applyAdjustmentOverrides(from dict: [String: Any], to cfg: inout AdjustmentConfiguration) {
        if let v = dict["exposure"] as? Double { cfg.basic.exposure = Float(v) }
        if let v = dict["contrast"] as? Double { cfg.basic.contrast = Float(v) }
        if let v = dict["highlight"] as? Double { cfg.basic.highlight = Float(v) }
        if let v = dict["shadow"] as? Double { cfg.basic.shadow = Float(v) }
        if let v = dict["white"] as? Double { cfg.basic.white = Float(v) }
        if let v = dict["black"] as? Double { cfg.basic.black = Float(v) }
        if let v = dict["saturation"] as? Double { cfg.basic.saturation = Float(v) }
        if let v = dict["brilliance"] as? Double { cfg.basic.brilliance = Float(v) }
        if let v = dict["temp"] as? Double { cfg.basic.temp = Float(v) }
        if let v = dict["tint"] as? Double { cfg.basic.tint = Float(v) }
        if let v = dict["vignetteAmount"] as? Double { cfg.effects.vignetteAmount = Float(v) }
        if let v = dict["grainAmount"] as? Double { cfg.effects.grainAmount = Float(v) }
        if let v = dict["sharpenAmount"] as? Double { cfg.effects.sharpenAmount = Float(v) }
    }

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
