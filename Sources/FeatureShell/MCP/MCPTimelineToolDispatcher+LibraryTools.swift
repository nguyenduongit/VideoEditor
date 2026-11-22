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
        let effectPresets: [[String: String]] = dependencies.effectTemplates.loadAllTemplates().map {
            ["id": $0.id, "name": $0.name, "category": $0.category.rawValue, "description": $0.description]
        }
        let transitionPresets: [[String: String]] = dependencies.transitionTemplates.loadAllTemplates().map {
            ["id": $0.id, "name": $0.name, "category": $0.category.rawValue, "description": $0.description]
        }
        let stickerPresets: [[String: String]] = dependencies.stickerTemplates.loadAllTemplates().map {
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
            "effectTemplates": effectPresets,
            "transitionTemplates": transitionPresets,
            "stickerTemplates": stickerPresets,
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

        let matchedAsset = (assetId.flatMap { id in assets.first { $0.id.uuidString.caseInsensitiveCompare(id) == .orderedSame } })
            ?? (fileName.flatMap { name in assets.first { $0.name.localizedCaseInsensitiveContains(name) } })
            ?? assets.first

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
        } else if kind == "effect" {
            let templateId = (dict["templateId"] as? String) ?? ""
            let presets = dependencies.effectTemplates.loadAllTemplates()
            let matched = presets.first { $0.id.caseInsensitiveCompare(templateId) == .orderedSame } ?? presets.first
            if let matched {
                scriptEngine.currentViewModel.addEffectClip(
                    named: matched.name,
                    config: matched.config,
                    durationSeconds: matched.defaultDuration,
                    originPresetID: matched.id
                )
                return "{\"status\":\"success\",\"appliedEffect\":\"\(matched.name)\"}"
            }
            throw AppError.invalidParameter("Effect preset not found")
        } else if kind == "transition" {
            let templateId = (dict["templateId"] as? String) ?? ""
            let presets = dependencies.transitionTemplates.loadAllTemplates()
            let matched = presets.first { $0.id.caseInsensitiveCompare(templateId) == .orderedSame } ?? TransitionPreset.default
            let vm = scriptEngine.currentViewModel
            if let firstLayer = vm.layers.first(where: { ($0.kind == .video || $0.kind == .image) && $0.clips.count >= 2 }) {
                vm.addOrUpdateCutTransition(matched, between: firstLayer.clips[0].id, and: firstLayer.clips[1].id)
                return "{\"status\":\"success\",\"appliedTransition\":\"\(matched.name)\"}"
            }
            throw AppError.invalidParameter("No adjacent video/image clips found for transition")
        } else if kind == "sticker" {
            let templateId = (dict["templateId"] as? String) ?? ""
            let presets = dependencies.stickerTemplates.loadAllTemplates()
            let matched = presets.first { $0.id.caseInsensitiveCompare(templateId) == .orderedSame } ?? presets.first
            if let matched {
                scriptEngine.currentViewModel.addStickerPreset(matched)
                return "{\"status\":\"success\",\"appliedSticker\":\"\(matched.name)\"}"
            }
            throw AppError.invalidParameter("Sticker preset not found")
        } else {
            throw AppError.invalidParameter("Unsupported kind: \(kind). Expected text, adjustment, effect, transition, or sticker.")
        }
    }

    func registerTemplatePackageArgument(_ argumentsJSON: String) throws -> String {
        guard let data = argumentsJSON.data(using: .utf8),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let kind = (dict["kind"] as? String)?.lowercased() else {
            throw AppError.invalidParameter("Missing required 'kind' in template_register_package")
        }

        let payloadString: String
        if let directPayload = dict["payload"] as? String {
            payloadString = directPayload
        } else if let payloadObj = dict["payload"] {
            let pData = try JSONSerialization.data(withJSONObject: payloadObj)
            payloadString = String(decoding: pData, as: UTF8.self)
        } else {
            payloadString = argumentsJSON
        }

        switch kind {
        case "text":
            if let preset = TextPreset.decode(from: payloadString) {
                dependencies.textTemplates.updateInMemoryPreset(preset)
                return "{\"status\":\"success\",\"registered\":\"text\",\"id\":\"\(preset.id)\"}"
            }
        case "adjustment":
            if let preset = AdjustmentPreset.decode(from: payloadString) {
                dependencies.adjustmentTemplates.updateInMemoryPreset(preset)
                return "{\"status\":\"success\",\"registered\":\"adjustment\",\"id\":\"\(preset.id)\"}"
            }
        case "effect":
            if let preset = EffectPreset.decode(from: payloadString) {
                dependencies.effectTemplates.updateInMemoryPreset(preset)
                return "{\"status\":\"success\",\"registered\":\"effect\",\"id\":\"\(preset.id)\"}"
            }
        case "transition":
            if let preset = TransitionPreset.decode(from: payloadString) {
                dependencies.transitionTemplates.updateInMemoryPreset(preset)
                return "{\"status\":\"success\",\"registered\":\"transition\",\"id\":\"\(preset.id)\"}"
            }
        case "sticker":
            if let preset = StickerPreset.decode(from: payloadString) {
                dependencies.stickerTemplates.updateInMemoryPreset(preset)
                return "{\"status\":\"success\",\"registered\":\"sticker\",\"id\":\"\(preset.id)\"}"
            }
        default:
            throw AppError.invalidParameter("Unsupported template kind: \(kind)")
        }
        throw AppError.invalidParameter("Failed to decode template payload for kind: \(kind)")
    }
}
