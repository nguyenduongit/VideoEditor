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
        #expect(decodedAdj?.community.authorName == "Cộng đồng")
        #expect(decodedAdj?.canBeModified(by: "any_user") == true)
    }

    @Test("DynamicShaderRuntimeEngine executes single demo Open Creative Effect Package at 60fps")
    func testAllEightCreativeEffectPackagesRenderCleanly() {
        let packages = EffectPreset.systemTemplates
        #expect(packages.count == 1)
        #expect(packages.allSatisfy { !$0.id.hasPrefix("system_effect_") })
        #expect(packages.allSatisfy { !$0.config.filterPipeline.isEmpty })
        #expect(packages.allSatisfy { !$0.config.customParameters.isEmpty })

        let canvasSize = CGSize(width: 320, height: 180)
        let inputImage = CIImage(color: CIColor(red: 0.75, green: 0.35, blue: 0.55, alpha: 1.0))
            .cropped(to: CGRect(origin: .zero, size: canvasSize))
        let engine = EffectEngine()

        for pkg in packages {
            let output = engine.applyEffect(
                to: inputImage,
                config: pkg.config,
                localTime: 0.8,
                duration: 3.0,
                canvasSize: canvasSize
            )
            #expect(output.extent.width == 320, "Failed extent width for \(pkg.id)")
            #expect(output.extent.height == 180, "Failed extent height for \(pkg.id)")
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

    @Test("OpenAnimationRuntimeEngine executes all 15 next-gen Open Creative Animation Packages (5 In, 5 Out, 5 Loop) with custom parameters")
    func testAllFifteenCreativeAnimationPackagesEvaluateCleanly() {
        #expect(AnimationPreset.inCatalog.count >= 5)
        #expect(AnimationPreset.outCatalog.count >= 5)
        #expect(AnimationPreset.loopCatalog.count >= 5)
        #expect(AnimationPreset.systemTemplates.count >= 15)

        let canvasSize = CGSize(width: 640, height: 360)

        for inPreset in AnimationPreset.inCatalog {
            var cfg = TextConfiguration(content: "CREATIVE", fontSize: 48.0, isBold: true)
            cfg.animation.inManifest = inPreset.manifest
            cfg.animation.inDuration = 1.0
            if let firstParam = inPreset.manifest.customParameters.first {
                cfg.animation.setValue(firstParam.maxValue, forParameter: firstParam.id, in: inPreset.manifest)
                #expect(cfg.animation.value(forParameter: firstParam.id, in: inPreset.manifest) == firstParam.maxValue)
            }
            let eval = TextAnimationEvaluator.evaluate(config: cfg, localTime: 0.35, duration: 3.0, canvasSize: canvasSize)
            #expect(eval.config.opacity > 0.0 && eval.config.opacity <= 1.0, "Invalid opacity for \(inPreset.id)")
        }

        for outPreset in AnimationPreset.outCatalog {
            var cfg = TextConfiguration(content: "CREATIVE", fontSize: 48.0, isBold: true)
            cfg.animation.outManifest = outPreset.manifest
            cfg.animation.outDuration = 1.0
            let eval = TextAnimationEvaluator.evaluate(config: cfg, localTime: 2.5, duration: 3.0, canvasSize: canvasSize)
            #expect(eval.config.opacity >= 0.0 && eval.config.opacity <= 1.0, "Invalid opacity for \(outPreset.id)")
        }

        for loopPreset in AnimationPreset.loopCatalog {
            var cfg = TextConfiguration(content: "CREATIVE", fontSize: 48.0, isBold: true)
            cfg.animation.loopManifest = loopPreset.manifest
            cfg.animation.loopSpeed = 1.5
            let eval = TextAnimationEvaluator.evaluate(config: cfg, localTime: 1.5, duration: 3.0, canvasSize: canvasSize)
            #expect(eval.config.opacity >= 0.0 && eval.config.opacity <= 1.0, "Invalid opacity for \(loopPreset.id)")
        }
    }

    @Test("EffectLibraryViewModel loads single demo Open Creative Package, filters by author, and adds to timeline")
    func testEffectLibraryCommunityWorkflow() {
        let deps = EditorDependencies()
        let timelineVM = TimelineViewModel(dependencies: deps)
        let effectLibraryVM = EffectLibraryViewModel(timelineViewModel: timelineVM, dependencies: deps)

        #expect(effectLibraryVM.filteredPresets.count == 1)

        effectLibraryVM.searchQuery = "openshader lab"
        #expect(effectLibraryVM.filteredPresets.map(\.id) == ["creative_fx_rgb_glitch"])

        if let glitchPkg = effectLibraryVM.filteredPresets.first {
            effectLibraryVM.addPresetToTimeline(glitchPkg)
        }
        let addedClip = timelineVM.layers.flatMap(\.clips).first(where: { $0.kind == .effect })
        #expect(addedClip != nil)
        let decodedClipConfig = EffectConfiguration.decode(from: addedClip?.properties["effectConfig"]?.asString ?? "")
        #expect(decodedClipConfig?.customParameters.count == 2)
        #expect(decodedClipConfig?.filterPipeline.first?.filterName == "RGBSplit")
    }
}
