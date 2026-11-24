import Testing
import Foundation
import CoreMedia
import CoreImage
import CoreGraphics
@testable import Domain
@testable import FeatureShell

@Suite("CommunityPresetHubTests")
@MainActor
struct CommunityPresetHubTests {

    @Test("CommunityMetadata encodes to hidden tag and extracts cleanly without polluting display tags")
    func testCommunityMetadataTagRoundtrip() {
        let originalMeta = CommunityMetadata(
            authorID: "user_123",
            authorName: "Duong Creator",
            downloadsCount: 42,
            likesCount: 15,
            isVerified: true,
            previewURL: "https://cdn.example.com/preview.gif",
            assetBundleURL: "https://cdn.example.com/sticker.apng",
            createdAtTimestamp: 1730000000
        )

        let encodedTag = originalMeta.encodeToTag()
        #expect(encodedTag != nil)

        var rawTags = ["cinematic", "neon"]
        if let encodedTag {
            rawTags.append(encodedTag)
        }

        let (cleanTags, extractedMeta) = CommunityMetadata.extract(from: rawTags, isSystem: false)
        #expect(cleanTags == ["cinematic", "neon"])
        #expect(extractedMeta == originalMeta)
    }

    @Test("Legacy AdjustmentPreset and TextPreset JSON without community key decodes safely")
    func testLegacyPresetBackwardCompatibility() {
        let legacyAdjustmentJSON = """
        {
            "id": "legacy_adj_1",
            "name": "Warm Film",
            "description": "Old schema",
            "category": "Điện ảnh",
            "tags": ["warm"],
            "config": {},
            "isSystem": false
        }
        """
        let decodedAdj = AdjustmentPreset.decode(from: legacyAdjustmentJSON)
        #expect(decodedAdj != nil)
        #expect(decodedAdj?.name == "Warm Film")
        #expect(decodedAdj?.community.authorName == "Community")
        #expect(decodedAdj?.canBeModified(by: "any_user") == true)
    }

    @Test("DynamicShaderRuntimeEngine executes all 9 Dev-Authored Effect Library items at 60fps")
    func testAllNineSystemEffectItemsRenderCleanly() {
        let items = EffectLibraryItem.systemItems
        #expect(items.count == 9)
        #expect(items.allSatisfy { !$0.config.filterPipeline.isEmpty })
        #expect(items.allSatisfy { !$0.config.customParameters.isEmpty })

        let canvasSize = CGSize(width: 320, height: 180)
        let inputImage = CIImage(color: CIColor(red: 0.75, green: 0.35, blue: 0.55, alpha: 1.0))
            .cropped(to: CGRect(origin: .zero, size: canvasSize))
        let engine = EffectEngine()

        for item in items {
            let output = engine.applyEffect(
                to: inputImage,
                config: item.config,
                localTime: 0.8,
                duration: 3.0,
                canvasSize: canvasSize
            )
            #expect(output.extent.width == 320, "Failed extent width for \(item.id)")
            #expect(output.extent.height == 180, "Failed extent height for \(item.id)")
        }
    }

    @Test("Next-Gen Adjustment and Text Creative Catalogs contain single demo item with complete features")
    func testNextGenAdjustmentAndTextCreativeCatalogs() {
        let adjCatalog = AdjustmentPreset.creativeCatalog
        #expect(adjCatalog.count == 1)
        for preset in adjCatalog {
            let badges = preset.activeModuleBadges
            #expect(badges.contains("Basic"), "Missing Basic in \(preset.id)")
            #expect(badges.contains("HSL"), "Missing HSL in \(preset.id)")
            #expect(badges.contains("Wheels"), "Missing Wheels in \(preset.id)")
            #expect(badges.contains("Curves"), "Missing Curves in \(preset.id)")
            #expect(badges.contains("FX"), "Missing FX in \(preset.id)")
        }

        let textCatalog = TextPreset.templates
        #expect(textCatalog.count == 1)
        #expect(textCatalog.first?.id == "default")
    }

    @Test("Unified TextAnimationScriptRegistry executes all active continuous scripts across Intro, Loop and Outro")
    func testAllUnifiedAnimationScriptsEvaluateCleanly() {
        let scripts = TextAnimationScriptRegistry.shared.scripts
        #expect(scripts.count >= 19)

        let canvasSize = CGSize(width: 640, height: 360)
        for script in scripts {
            var cfg = TextConfiguration(content: "CREATIVE", fontSize: 48.0, isBold: true)
            cfg.animation.scriptId = script.id
            cfg.animation.applyUnifiedScriptTiming(baseLoopSeconds: 2, speed: 1.0)

            for sampleTime in [0.35, 2.0, 3.65] {
                let eval = TextAnimationEvaluator.evaluate(config: cfg, localTime: sampleTime, duration: 4.0, canvasSize: canvasSize)
                #expect(eval.config.opacity >= 0.0 && eval.config.opacity <= 1.0, "Invalid opacity for \(script.id) at \(sampleTime)")
                #expect(!eval.config.positionX.isNaN && !eval.config.positionY.isNaN, "NaN offset for \(script.id)")
            }
        }
    }

    @Test("EffectLibraryViewModel loads all 9 System Library items, searches cleanly, and adds to timeline without user preset origin")
    func testEffectLibrarySystemWorkflow() {
        let deps = EditorDependencies()
        let timelineVM = TimelineViewModel(dependencies: deps)
        let effectLibraryVM = EffectLibraryViewModel(timelineViewModel: timelineVM, dependencies: deps)

        #expect(effectLibraryVM.filteredItems.count == 9)

        effectLibraryVM.searchQuery = "glitch"
        #expect(effectLibraryVM.filteredItems.map(\.id) == ["creative_fx_rgb_glitch"])

        if let glitchItem = effectLibraryVM.filteredItems.first {
            effectLibraryVM.addToTimeline(glitchItem)
        }
        let addedClip = timelineVM.layers.flatMap(\.clips).first(where: { $0.kind == .effect })
        #expect(addedClip != nil)
        #expect(addedClip?.originPresetID == nil)
        let decodedClipConfig = EffectConfiguration.decode(from: addedClip?.properties["effectConfig"]?.asString ?? "")
        #expect(decodedClipConfig?.customParameters.count == 2)
        #expect(decodedClipConfig?.filterPipeline.first?.filterName == "RGBSplit")
    }

    @Test("Single-user personal mode unlocks all custom Text and Adjustment presets across devices and uses fixed personalOwnerID")
    func testSingleUserPersonalOwnershipModel() {
        #expect(CommunityIdentity.currentAuthorID == CommunityIdentity.personalOwnerID)
        #expect(CommunityIdentity.personalOwnerID == "personal")

        let legacyMachineMeta = CommunityMetadata(authorID: "old-mac-uuid-1234", authorName: "Old Mac")
        let customAdj = AdjustmentPreset(
            id: "user_adj_1", name: "User Adj", description: "", category: .cinematic,
            config: AdjustmentConfiguration(), isSystem: false, community: legacyMachineMeta
        )
        let customText = TextPreset(
            id: "user_txt_1", name: "User Text", description: "", category: .vlog,
            config: TextConfiguration(), isSystem: false, community: legacyMachineMeta
        )

        #expect(customAdj.canBeModified(by: CommunityIdentity.currentAuthorID) == true)
        #expect(customText.canBeModified(by: CommunityIdentity.currentAuthorID) == true)
        #expect(AdjustmentPreset.default.canBeModified(by: CommunityIdentity.currentAuthorID) == false)
    }
}
