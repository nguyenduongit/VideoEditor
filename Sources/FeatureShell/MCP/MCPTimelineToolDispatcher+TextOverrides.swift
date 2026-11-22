import Foundation
import CoreMedia
import Domain

/// Mở rộng hỗ trợ áp dụng cấu hình và ghi đè thuộc tính cho Text Clip từ Agent qua MCP.
/// Hỗ trợ đầy đủ kiến trúc 3 Lớp (Background/Foreground SVG), Họa tiết (Ornaments/VFX), Dual Gradient Stroke và Palette.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng) của AGENTS.md.
extension MCPTimelineToolDispatcher {

    func applyOrUpdateTextConfiguration(_ dict: [String: Any]) throws -> String {
        let vm = scriptEngine.currentViewModel
        let preservedSelection = vm.selectedClipIDs
        let updateExisting = (dict["updateExisting"] as? Bool) ?? false

        var defaultFont = "UVN Ke Chuyen"
        if let fav = vm.fontManager.favoriteFontIDs.first {
            defaultFont = fav
        }

        let canvasH = Double(vm.aspectRatio.renderSize.height)
        let titleHeightRatio = 290.0 / 1080.0
        let safeTopY = -(canvasH * titleHeightRatio).rounded()
        let safeBottomY = (canvasH * 0.32).rounded()

        let isSubtitle = (dict["hasBackground"] as? Bool) == true ||
            (dict["templateId"] as? String)?.lowercased().contains("subtitle") == true ||
            (dict["templateId"] as? String)?.lowercased().contains("karaoke") == true
        let defaultPosY = isSubtitle ? safeBottomY : safeTopY

        var (cfg, matchedPreset) = resolveInitialTextConfiguration(
            from: dict,
            defaultPosY: defaultPosY,
            defaultFont: defaultFont
        )

        if updateExisting,
           let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .text }),
           let existingJSON = existingClip.properties["textConfig"]?.asString,
           let decoded = TextConfiguration.decode(from: existingJSON) {
            cfg = decoded
        }

        applyTextOverrides(from: dict, to: &cfg, safeTopY: safeTopY, safeBottomY: safeBottomY, canvasH: canvasH)
        TextAutoFitter.autoScaleFontSize(config: &cfg, canvasSize: vm.aspectRatio.renderSize)

        let allMediaClips = vm.layers.flatMap(\.clips).filter { $0.kind == .video || $0.kind == .image }
        let defaultStartSec = allMediaClips.map { CMTimeGetSeconds($0.timeRange.start) }.min() ?? 0.0
        let startSeconds = (dict["startTimeSeconds"] as? Double) ?? defaultStartSec
        let durationSeconds = (dict["durationSeconds"] as? Double) ?? 5.0
        let targetTime = CMTime(seconds: max(0, startSeconds), preferredTimescale: TimeRational.defaultFPS)

        if updateExisting, let existingClip = vm.layers.flatMap(\.clips).first(where: { $0.kind == .text }) {
            return updateExistingTextClip(
                clip: existingClip, cfg: cfg, targetTime: targetTime, durationSeconds: durationSeconds,
                hasCustomStart: dict["startTimeSeconds"] != nil, vm: vm, preservedSelection: preservedSelection
            )
        }

        vm.addTextClip(
            named: cfg.content, config: cfg, durationSeconds: max(1.0, durationSeconds), at: targetTime,
            originPresetID: matchedPreset?.id, originPresetName: matchedPreset?.name
        )
        vm.selectedClipIDs = preservedSelection
        return "{\"status\":\"success\",\"createdCustomText\":\"\(cfg.content)\",\"fontName\":\"\(cfg.fontName)\"}"
    }

    private func resolveInitialTextConfiguration(
        from dict: [String: Any],
        defaultPosY: Double,
        defaultFont: String
    ) -> (TextConfiguration, TextPreset?) {
        let allTemplates = dependencies.textTemplates.loadAllTemplates()
        var matchedPreset: TextPreset?
        if let templateId = dict["templateId"] as? String, !templateId.isEmpty {
            let query = templateId.lowercased()
            matchedPreset = allTemplates.first(where: {
                $0.id.lowercased() == query || $0.name.lowercased() == query
            })
        }
        if matchedPreset == nil, dict["fontName"] == nil && dict["textColorHex"] == nil {
            matchedPreset = allTemplates.first(where: { $0.id != "default" }) ?? allTemplates.first
        }

        if let matched = matchedPreset {
            return (matched.config, matched)
        }
        var fallback = TextConfiguration(
            content: "TIÊU ĐỀ", fontName: defaultFont, fontSize: 64.0, textColorHex: "#FFFFFF",
            isBold: true, characterSpacing: 1.5,
            innerStroke: TextStrokeStyle(isEnabled: true, width: 4.0, colorHex: "#0F172A"),
            glow: TextGlowStyle(isEnabled: true, colorHex: "#38BDF8", intensity: 85.0, range: 16.0),
            shadow: TextShadowStyle(isEnabled: true, colorHex: "#000000", opacity: 70.0, blur: 8.0, distance: 3.0, angleDegrees: -90.0),
            positionY: defaultPosY
        )
        fallback.animation.inType = .slideUp
        fallback.animation.outType = .fadeOut
        fallback.animation.loopType = .none
        return (fallback, nil)
    }

    private func updateExistingTextClip(
        clip: TimelineClip, cfg: TextConfiguration, targetTime: CMTime, durationSeconds: Double,
        hasCustomStart: Bool, vm: TimelineViewModel, preservedSelection: Set<UUID>
    ) -> String {
        var newProps = clip.properties
        if let encoded = cfg.encodeToJSON() { newProps["textConfig"] = .string(encoded) }
        newProps["textContent"] = .string(cfg.content)
        newProps["fontSize"] = .number(cfg.fontSize)
        newProps["positionX"] = .number(cfg.positionX)
        newProps["positionY"] = .number(cfg.positionY)
        var cmds: [TimelineCommand] = [.updateClipProperties(clipID: clip.id, properties: newProps)]
        if hasCustomStart || (clip.timeRange.start > targetTime && clip.timeRange.start == vm.currentTime) {
            let rStart = RationalTime(cmTime: targetTime)
            let rDur = RationalTime(cmTime: CMTime(seconds: max(1.0, durationSeconds), preferredTimescale: TimeRational.defaultFPS))
            cmds.append(.trimClip(clipID: clip.id, newStart: rStart, newDuration: rDur, newSourceStart: nil))
        }
        _ = scriptEngine.executeCommands(cmds)
        vm.selectedClipIDs = preservedSelection
        return "{\"status\":\"success\",\"updatedTextClip\":\"\(cfg.content)\",\"fontName\":\"\(cfg.fontName)\"}"
    }

    private func applyTextOverrides(
        from dict: [String: Any], to cfg: inout TextConfiguration,
        safeTopY: Double, safeBottomY: Double, canvasH: Double
    ) {
        applyTypographyOverrides(from: dict, to: &cfg)
        applyStyleOverrides(from: dict, to: &cfg)
        applyAdvancedVisualOverrides(from: dict, to: &cfg)
        applyPositionAndAnimationOverrides(from: dict, to: &cfg, safeTopY: safeTopY, safeBottomY: safeBottomY, canvasH: canvasH)
    }

    private func applyTypographyOverrides(from dict: [String: Any], to cfg: inout TextConfiguration) {
        if let customText = dict["customText"] as? String, !customText.isEmpty { cfg.content = customText }
        if let fontName = dict["fontName"] as? String, !fontName.isEmpty {
            cfg.fontName = MCPTextPropertyResolver.resolveFontName(fontName)
        }
        if let fontSize = dict["fontSize"] as? Double, fontSize > 8 { cfg.fontSize = fontSize }
        if let textColor = dict["textColorHex"] as? String, !textColor.isEmpty { cfg.textColorHex = textColor }
    }

    private func applyStyleOverrides(from dict: [String: Any], to cfg: inout TextConfiguration) {
        if let strokeColor = dict["strokeColorHex"] as? String, !strokeColor.isEmpty {
            cfg.strokeColorHex = strokeColor; cfg.hasStroke = true
            if cfg.strokeWidth <= 0 { cfg.strokeWidth = 4.0 }
        }
        if let strokeWidth = dict["strokeWidth"] as? Double { cfg.strokeWidth = strokeWidth; cfg.hasStroke = strokeWidth > 0 }
        if let glowColor = dict["glowColorHex"] as? String, !glowColor.isEmpty {
            cfg.glowColorHex = glowColor; cfg.hasGlow = true
            if cfg.glowRadius <= 0 { cfg.glowRadius = 18.0 }
        }
        if let glowRadius = dict["glowRadius"] as? Double { cfg.glowRadius = glowRadius; cfg.hasGlow = glowRadius > 0 }
        if let hasBg = dict["hasBackground"] as? Bool { cfg.hasBackground = hasBg }
        if let bgHex = dict["backgroundColorHex"] as? String, !bgHex.isEmpty {
            cfg.backgroundColorHex = bgHex; cfg.hasBackground = true
        }
        if let bgOpacity = dict["backgroundOpacity"] as? Double {
            cfg.background.opacity = max(0.0, min(1.0, bgOpacity))
            cfg.background.isEnabled = true
        }
        if let bgPadding = dict["backgroundPadding"] as? Double { cfg.backgroundPadding = bgPadding }
        if let bgRadius = dict["backgroundCornerRadius"] as? Double { cfg.backgroundCornerRadius = bgRadius }
        if let bgFeather = dict["backgroundFeather"] as? Double { cfg.background.featherRadius = bgFeather }
    }

    private func applyAdvancedVisualOverrides(from dict: [String: Any], to cfg: inout TextConfiguration) {
        if let fillModeStr = dict["colorFillMode"] as? String, let mode = TextColorFillMode(rawValue: fillModeStr) {
            cfg.colorFillMode = mode
        }
        if let gradColors = dict["gradientColors"] as? [String], gradColors.count >= 2 {
            cfg.gradientColors = gradColors
            cfg.colorFillMode = .linearGradient
        }
        if let outerColor = dict["outerStrokeColorHex"] as? String {
            cfg.outerStrokeColorHex = outerColor
            cfg.hasOuterStroke = true
        }
        if let outerW = dict["outerStrokeWidth"] as? Double {
            cfg.outerStrokeWidth = outerW
            cfg.hasOuterStroke = outerW > 0
        }
        if let curveShapeStr = dict["curveShape"] as? String, let shape = TextCurveShape(rawValue: curveShapeStr) {
            cfg.curve.shape = shape
        }
        if let curveAngle = dict["curveAngle"] as? Double {
            cfg.curveAngle = curveAngle
        }
        if let bgSVG = dict["backgroundSVG"] as? String, !bgSVG.isEmpty {
            cfg.background.isEnabled = true
            cfg.background.sourceKind = .inlineSVG
            cfg.background.svgMarkup = bgSVG
        }
        if let bgAsset = dict["backgroundAssetURL"] as? String, !bgAsset.isEmpty {
            cfg.background.isEnabled = true
            cfg.background.sourceKind = .animatedAsset
            cfg.background.assetPathOrURL = bgAsset
        }
    }

    private func applyPositionAndAnimationOverrides(
        from dict: [String: Any], to cfg: inout TextConfiguration,
        safeTopY: Double, safeBottomY: Double, canvasH: Double
    ) {
        if let posX = dict["positionX"] as? Double { cfg.positionX = posX }
        if let ratioY = dict["positionRatioY"] as? Double {
            cfg.positionY = -(canvasH * abs(ratioY)).rounded()
        } else if let posStr = (dict["position"] as? String)?.lowercased() {
            switch posStr {
            case "top", "header", "title", "tren", "trên": cfg.positionY = safeTopY
            case "bottom", "footer", "subtitle", "duoi", "dưới": cfg.positionY = safeBottomY
            case "center", "giua", "giữa": cfg.positionY = 0.0
            default: break
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
}

