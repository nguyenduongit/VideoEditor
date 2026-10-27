import Foundation
import CoreMedia
import Domain

extension MCPTimelineToolDispatcher {
    func getLibraryCatalogArgument() throws -> String {
        let assetsList: [[String: String]] = (mediaLibraryViewModel?.assets ?? []).map {
            ["id": $0.id.uuidString, "name": $0.name, "type": $0.type.rawValue, "url": $0.url.absoluteString]
        }
        let textPresets: [[String: String]] = dependencies.textTemplates.loadAllTemplates().map {
            ["id": $0.id, "name": $0.name, "category": $0.category.rawValue, "description": $0.description]
        }
        let adjustmentPresets: [[String: String]] = dependencies.adjustmentTemplates.loadAllTemplates().map {
            ["id": $0.id, "name": $0.name, "category": $0.category.rawValue, "description": $0.description]
        }
        let vm = scriptEngine.currentViewModel
        let fontItems = vm.fontManager.fonts
        let popularFonts = fontItems.prefix(40).map { ["id": $0.id, "displayName": $0.displayName] }
        let favoriteFonts = fontItems.filter { vm.fontManager.isFavorite(fontID: $0.id) }.map { ["id": $0.id, "displayName": $0.displayName] }
        let payload: [String: Any] = [
            "mediaAssets": assetsList,
            "textTemplates": textPresets,
            "adjustmentTemplates": adjustmentPresets,
            "favoriteFonts": favoriteFonts,
            "availableFonts": popularFonts
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

        var defaultFont = "UVN Ke Chuyen"
        if let fav = vm.fontManager.favoriteFontIDs.first {
            defaultFont = fav
        }

        let canvasH = Double(vm.aspectRatio.renderSize.height)
        let isVertical = vm.aspectRatio.renderSize.height > vm.aspectRatio.renderSize.width
        let safeTopY = isVertical ? -(canvasH * 0.32).rounded() : -(canvasH * 0.35).rounded()
        let safeBottomY = isVertical ? (canvasH * 0.32).rounded() : (canvasH * 0.32).rounded()

        let isSubtitle = (dict["hasBackground"] as? Bool) == true ||
            (dict["templateId"] as? String)?.lowercased().contains("subtitle") == true ||
            (dict["templateId"] as? String)?.lowercased().contains("karaoke") == true
        let defaultPosY = isSubtitle ? safeBottomY : safeTopY

        var cfg = TextConfiguration(
            content: "TIÊU ĐỀ", fontName: defaultFont, fontSize: 64.0, textColorHex: "#FFFFFF",
            isBold: true, characterSpacing: 1.5, hasStroke: true, strokeColorHex: "#0F172A",
            strokeWidth: 4.0, hasShadow: true, shadowColorHex: "#000000B3", shadowRadius: 8.0,
            shadowOffsetY: 3.0, hasGlow: true, glowColorHex: "#38BDF8", glowRadius: 16.0, positionY: defaultPosY
        )
        cfg.animation.inType = .slideDown
        cfg.animation.outType = .fadeOut
        cfg.animation.loopType = .none

        if let templateId = dict["templateId"] as? String, !templateId.isEmpty {
            let query = templateId.lowercased()
            if let matched = dependencies.textTemplates.loadAllTemplates().first(where: { $0.id.lowercased() == query }) {
                cfg = matched.config
            }
        }

        if updateExisting,
           let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .text }),
           let existingJSON = existingClip.properties["textConfig"]?.asString,
           let decoded = TextConfiguration.decode(from: existingJSON) {
            cfg = decoded
        }

        applyTextOverrides(from: dict, to: &cfg, safeTopY: safeTopY, safeBottomY: safeBottomY)

        let allMediaClips = vm.layers.flatMap(\.clips).filter { $0.kind == .video || $0.kind == .image }
        let defaultStartSec = allMediaClips.map { CMTimeGetSeconds($0.timeRange.start) }.min() ?? 0.0
        let startSeconds = (dict["startTimeSeconds"] as? Double) ?? defaultStartSec
        let durationSeconds = (dict["durationSeconds"] as? Double) ?? 5.0
        let targetTime = CMTime(seconds: max(0, startSeconds), preferredTimescale: TimeRational.defaultFPS)

        if updateExisting, let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .text }) {
            var newProps = existingClip.properties
            if let encoded = cfg.encodeToJSON() { newProps["textConfig"] = .string(encoded) }
            newProps["textContent"] = .string(cfg.content)
            newProps["fontSize"] = .number(cfg.fontSize)
            newProps["positionX"] = .number(cfg.positionX)
            newProps["positionY"] = .number(cfg.positionY)
            var cmds: [TimelineCommand] = [.updateClipProperties(clipID: existingClip.id, properties: newProps)]
            if dict["startTimeSeconds"] != nil || (existingClip.timeRange.start > targetTime && existingClip.timeRange.start == vm.currentTime) {
                let rStart = RationalTime(cmTime: targetTime)
                let rDur = RationalTime(cmTime: CMTime(seconds: max(1.0, durationSeconds), preferredTimescale: TimeRational.defaultFPS))
                cmds.append(.trimClip(clipID: existingClip.id, newStart: rStart, newDuration: rDur, newSourceStart: nil))
            }
            _ = scriptEngine.executeCommands(cmds)
            vm.selectedClipIDs = preservedSelection
            return "{\"status\":\"success\",\"updatedTextClip\":\"\(cfg.content)\",\"fontName\":\"\(cfg.fontName)\"}"
        }

        vm.addTextClip(named: cfg.content, config: cfg, durationSeconds: max(1.0, durationSeconds), at: targetTime)
        vm.selectedClipIDs = preservedSelection
        return "{\"status\":\"success\",\"createdCustomText\":\"\(cfg.content)\",\"fontName\":\"\(cfg.fontName)\"}"
    }

    private func applyTextOverrides(
        from dict: [String: Any],
        to cfg: inout TextConfiguration,
        safeTopY: Double,
        safeBottomY: Double
    ) {
        if let customText = dict["customText"] as? String, !customText.isEmpty { cfg.content = customText }
        if let fontName = dict["fontName"] as? String, !fontName.isEmpty {
            cfg.fontName = MCPTextPropertyResolver.resolveFontName(fontName)
        }
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
        if let hasBg = dict["hasBackground"] as? Bool { cfg.hasBackground = hasBg }
        if let bgHex = dict["backgroundColorHex"] as? String, !bgHex.isEmpty {
            cfg.backgroundColorHex = bgHex
            cfg.hasBackground = true
        }
        if let bgOpacity = dict["backgroundOpacity"] as? Double {
            let clean = cfg.backgroundColorHex.replacingOccurrences(of: "#", with: "")
            let rgb = clean.count >= 6 ? String(clean.prefix(6)) : "000000"
            let alphaByte = Int(round(max(0.0, min(1.0, bgOpacity)) * 255.0))
            cfg.backgroundColorHex = String(format: "#%@%02X", rgb.uppercased(), alphaByte)
            cfg.hasBackground = true
        }
        if let bgPadding = dict["backgroundPadding"] as? Double { cfg.backgroundPadding = bgPadding }
        if let bgRadius = dict["backgroundCornerRadius"] as? Double { cfg.backgroundCornerRadius = bgRadius }
        if let posX = dict["positionX"] as? Double { cfg.positionX = posX }
        if let posStr = (dict["position"] as? String)?.lowercased() {
            switch posStr {
            case "top", "header", "title", "tren", "trên":
                cfg.positionY = safeTopY
            case "bottom", "footer", "subtitle", "duoi", "dưới":
                cfg.positionY = safeBottomY
            case "center", "giua", "giữa":
                cfg.positionY = 0.0
            default:
                break
            }
        } else if let posY = dict["positionY"] as? Double {
            cfg.positionY = posY
        }
        if let inAnim = dict["inAnimation"] as? String { cfg.animation.inType = MCPTextPropertyResolver.resolveInAnimation(inAnim) }
        if let outAnim = dict["outAnimation"] as? String { cfg.animation.outType = MCPTextPropertyResolver.resolveOutAnimation(outAnim) }
        if let loopAnim = dict["loopAnimation"] as? String { cfg.animation.loopType = MCPTextPropertyResolver.resolveLoopAnimation(loopAnim) }
        if let easingStr = dict["motionEasing"] as? String, let easing = TextMotionEasing(rawValue: easingStr) {
            cfg.animation.motionEasing = easing
        }
    }

    private func applyOrUpdateAdjustmentConfiguration(_ dict: [String: Any]) throws -> String {
        let vm = scriptEngine.currentViewModel
        let preservedSelection = vm.selectedClipIDs
        let updateExisting = (dict["updateExisting"] as? Bool) ?? false

        var cfg = AdjustmentConfiguration()
        var clipTitle = "Tùy chỉnh Màu AI"

        if let templateId = dict["templateId"] as? String, !templateId.isEmpty {
            let query = templateId.lowercased()
            if let matched = dependencies.adjustmentTemplates.loadAllTemplates().first(where: { $0.id.lowercased() == query }) {
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
}
