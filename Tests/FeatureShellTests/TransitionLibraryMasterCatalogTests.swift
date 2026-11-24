import Testing
import Foundation
import CoreMedia
import SwiftUI
import Domain
@testable import FeatureShell

@Suite("Transition Library Master Catalog & Animated Thumbnail Tests")
@MainActor
struct TransitionLibraryMasterCatalogTests {

    @Test("TransitionLibraryItem systemItems contains exactly 83 items across 8 international NLE categories with 2.0s default duration")
    func testCatalogSizeCategoriesAndDefaults() {
        let catalog = TransitionLibraryItem.systemItems
        #expect(catalog.count == 83, "Thư viện phải có chính xác 83 mẫu chuyển cảnh")

        let ids = catalog.map(\.id)
        #expect(Set(ids).count == 83, "Tất cả 83 mẫu chuyển cảnh phải có ID duy nhất không trùng lặp")

        // 1. Basic (10 items)
        let basic = catalog.filter { $0.category == .basic }
        #expect(basic.count == 10)

        // 2. Slide & Wipe (12 items)
        let slideWipe = catalog.filter { $0.category == .slideWipe }
        #expect(slideWipe.count == 12)

        // 3. Zoom (9 items)
        let zoom = catalog.filter { $0.category == .zoom }
        #expect(zoom.count == 9)

        // 4. Blur (9 items)
        let blur = catalog.filter { $0.category == .blur }
        #expect(blur.count == 9)

        // 5. Camera & Motion (10 items)
        let camera = catalog.filter { $0.category == .camera }
        #expect(camera.count == 10)

        // 6. Glitch & Distortion (11 items)
        let glitch = catalog.filter { $0.category == .glitch }
        #expect(glitch.count == 11)

        // 7. Light Effects (10 items)
        let light = catalog.filter { $0.category == .light }
        #expect(light.count == 10)

        // 8. 3D & Mask (12 items)
        let advanced3D = catalog.filter { $0.category == .advanced3D }
        #expect(advanced3D.count == 12)

        for item in catalog {
            #expect(item.defaultDuration == 2.0, "Item \(item.id) must default to 2.0s")
            #expect(!item.name.isEmpty)
            #expect(!item.description.isEmpty)
            #expect(!item.iconName.isEmpty)
        }
    }

    @Test("TransitionAnimatedThumbnailView uses 2.0s hover duration and executes exact GPU transition algorithm for all 83 items")
    func testAnimatedThumbnailViewAndRealGPUAlgorithmExecution() throws {
        #expect(TransitionAnimatedThumbnailView.hoverDurationSeconds == 2.0)

        let provider = TransitionThumbnailAssetProvider.shared
        for item in TransitionLibraryItem.systemItems {
            let view = TransitionAnimatedThumbnailView(item: item)
            _ = view.body
            let frameMid = provider.renderTransitionFrame(for: item, rawProgress: 0.5)
            #expect(frameMid != nil, "GPU transition frame must render for item \(item.id)")
        }

        for whiteFlashID in ["trans_basic_white_flash", "trans_light_white_flash"] {
            let item = try #require(TransitionLibraryItem.systemItems.first(where: { $0.id == whiteFlashID }))
            let cgImg = try #require(provider.renderTransitionFrame(for: item, rawProgress: 0.5))
            let (r, g, b) = sampleCenterPixelRGB(of: cgImg)
            #expect(r >= 245 && g >= 245 && b >= 245, "Item \(whiteFlashID) at p=0.5 must flash pure white, RGB=(\(r),\(g),\(b))")
            #expect(abs(Int(r) - Int(b)) <= 3, "Item \(whiteFlashID) must not tint yellow")
        }

        let blackFade = try #require(TransitionLibraryItem.systemItems.first(where: { $0.id == "trans_basic_black_fade" }))
        let blackCG = try #require(provider.renderTransitionFrame(for: blackFade, rawProgress: 0.5))
        let (br, bg, bb) = sampleCenterPixelRGB(of: blackCG)
        #expect(br <= 15 && bg <= 15 && bb <= 15, "Black Fade at p=0.5 must be black, RGB=(\(br),\(bg),\(bb))")
    }

    private func sampleCenterPixelRGB(of cgImage: CGImage) -> (UInt8, UInt8, UInt8) {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (0, 0, 0)
        }
        let cx = CGFloat(cgImage.width) * 0.5
        let cy = CGFloat(cgImage.height) * 0.5
        ctx.draw(cgImage, in: CGRect(x: -cx, y: -cy, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        return (pixel[0], pixel[1], pixel[2])
    }

    @Test("TransitionThumbnailAssetProvider loads, squares and caches 3 demo asset pairs and routes categories")
    func testThumbnailAssetProviderSquareAssets() throws {
        let provider = TransitionThumbnailAssetProvider.shared

        // 1. Kiểm tra 3 cặp ảnh demo theo cấu hình Extensible Catalog
        let pairIDs = [
            TransitionDemoAssetCatalog.naturePairID,
            TransitionDemoAssetCatalog.cityPairID,
            TransitionDemoAssetCatalog.coastalPairID
        ]
        for pid in pairIDs {
            let pair = try #require(provider.assetPair(id: pid), "Cặp ảnh demo '\(pid)' phải được nạp thành công")
            #expect(!pair.displayName.isEmpty)
            if let nsA = pair.nsImageA {
                #expect(nsA.size.width > 0)
                #expect(abs(nsA.size.width - nsA.size.height) <= 1.0, "Cảnh A của \(pid) phải được crop vuông 1:1")
            }
            if let nsB = pair.nsImageB {
                #expect(nsB.size.width > 0)
                #expect(abs(nsB.size.width - nsB.size.height) <= 1.0, "Cảnh B của \(pid) phải được crop vuông 1:1")
            }
        }

        // 2. Kiểm tra định tuyến danh mục chuẩn xác
        #expect(TransitionDemoAssetCatalog.pairID(for: .basic) == "nature")
        #expect(TransitionDemoAssetCatalog.pairID(for: .zoom) == "nature")
        #expect(TransitionDemoAssetCatalog.pairID(for: .blur) == "nature")
        #expect(TransitionDemoAssetCatalog.pairID(for: .slideWipe) == "city")
        #expect(TransitionDemoAssetCatalog.pairID(for: .camera) == "city")
        #expect(TransitionDemoAssetCatalog.pairID(for: .glitch) == "city")
        #expect(TransitionDemoAssetCatalog.pairID(for: .light) == "coastal")
        #expect(TransitionDemoAssetCatalog.pairID(for: .advanced3D) == "coastal")

        // 3. Verify valid GPU transition frames across categories
        if let fadeItem = TransitionLibraryItem.systemItems.first(where: { $0.id == "trans_basic_fade" }) {
            let frame = provider.renderTransitionFrame(for: fadeItem, rawProgress: 0.5)
            #expect(frame != nil)
        }
        if let slideItem = TransitionLibraryItem.systemItems.first(where: { $0.id == "trans_slide_right" }) {
            let frame = provider.renderTransitionFrame(for: slideItem, rawProgress: 0.5)
            #expect(frame != nil)
        }
        if let flashItem = TransitionLibraryItem.systemItems.first(where: { $0.id == "trans_light_white_flash" }) {
            let frame = provider.renderTransitionFrame(for: flashItem, rawProgress: 0.5)
            #expect(frame != nil)
        }
    }

    @Test("TimelineViewModel applies 2.0s default duration and clamps safely for short clips")
    func testTimelineAddTransitionDurationClamping() throws {
        // Cặp clip dài 5.0s -> Transition nhận đủ 2.0s
        let c0 = TimelineClip(name: "A", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5.0, preferredTimescale: 600)))
        let c1 = TimelineClip(name: "B", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5.0, preferredTimescale: 600), duration: CMTime(seconds: 5.0, preferredTimescale: 600)))
        let layer1 = TimelineLayer(name: "V1", kind: .video, clips: [c0, c1])
        let vm = TimelineViewModel(initialLayers: [layer1])

        let preset = try #require(TransitionLibraryItem.systemItems.first(where: { $0.id == "trans_slide_right" }))
        let trans1 = try #require(vm.addOrUpdateCutTransition(preset, between: c0.id, and: c1.id))
        #expect(abs(trans1.duration.seconds - 2.0) < 0.001)

        // Cặp clip ngắn (0.4s mỗi clip) -> Transition bị clamp ở 2 * 0.4 = 0.8s
        let s0 = TimelineClip(name: "S0", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 0.4, preferredTimescale: 600)))
        let s1 = TimelineClip(name: "S1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 0.4, preferredTimescale: 600), duration: CMTime(seconds: 0.4, preferredTimescale: 600)))
        let layer2 = TimelineLayer(name: "V2", kind: .video, clips: [s0, s1])
        let vm2 = TimelineViewModel(initialLayers: [layer2])

        let trans2 = try #require(vm2.addOrUpdateCutTransition(preset, between: s0.id, and: s1.id))
        #expect(abs(trans2.duration.seconds - 0.8) < 0.001)
    }

    @Test("Transition enforces zero-gap contiguous clips, validates drag-drop join zone, and supports overwriting existing transition with Undo/Redo")
    func testContiguousConstraintDragDropJoinZoneAndOverwrite() throws {
        let fadeItem = try #require(TransitionLibraryItem.systemItems.first(where: { $0.id == "trans_basic_fade" }))
        let flashItem = try #require(TransitionLibraryItem.systemItems.first(where: { $0.id == "trans_light_white_flash" }))

        // 1. Two video clips with a 0.5s gap -> cannot add transition
        let g0 = TimelineClip(name: "G0", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 4.0, preferredTimescale: 600)))
        let g1 = TimelineClip(name: "G1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 4.5, preferredTimescale: 600), duration: CMTime(seconds: 4.0, preferredTimescale: 600)))
        let gapLayer = TimelineLayer(name: "VGap", kind: .video, clips: [g0, g1])
        let gapVM = TimelineViewModel(initialLayers: [gapLayer])
        #expect(gapLayer.areClipsContiguous(leadingID: g0.id, trailingID: g1.id) == false)
        #expect(gapVM.addOrUpdateCutTransition(fadeItem, between: g0.id, and: g1.id) == nil)
        #expect(gapVM.layers[0].transitions.isEmpty)

        // 2. Two contiguous video clips
        let c0 = TimelineClip(name: "C0", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5.0, preferredTimescale: 600)))
        let c1 = TimelineClip(name: "C1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5.0, preferredTimescale: 600), duration: CMTime(seconds: 5.0, preferredTimescale: 600)))
        let contLayer = TimelineLayer(name: "V1", kind: .video, clips: [c0, c1])
        let vm = TimelineViewModel(initialLayers: [contLayer])
        let pps = vm.pixelsPerSecond
        let cutX = 5.0 * pps
        let topSpacer: CGFloat = 20.0
        let trackHeight = vm.layerHeight(for: .video)
        let midY = topSpacer + trackHeight * 0.5

        #expect(vm.resolveTransitionDropTarget(item: fadeItem, canvasX: 1.0 * pps, canvasY: midY, topSpacerHeight: topSpacer) == nil)
        #expect(vm.dropTransition(fadeItem, atCanvasX: 1.0 * pps, canvasY: midY, topSpacerHeight: topSpacer) == nil)

        let target = try #require(vm.resolveTransitionDropTarget(item: fadeItem, canvasX: cutX - 15.0, canvasY: midY, topSpacerHeight: topSpacer))
        #expect(target.leadingClipID == c0.id)
        #expect(target.trailingClipID == c1.id)
        #expect(abs(target.cutCanvasX - cutX) < 0.01)

        let added = try #require(vm.dropTransition(fadeItem, atCanvasX: cutX - 15.0, canvasY: midY, topSpacerHeight: topSpacer))
        #expect(added.presetID == "trans_basic_fade")
        #expect(vm.layers[0].transitions.count == 1)

        let replaced = try #require(vm.dropTransition(flashItem, atCanvasX: cutX + 12.0, canvasY: midY, topSpacerHeight: topSpacer))
        #expect(replaced.id == added.id)
        #expect(replaced.presetID == "trans_light_white_flash")
        #expect(vm.layers[0].transitions.count == 1)
        #expect(vm.layers[0].transitions[0].name == "White Flash")

        #expect(vm.undo() == true)
        #expect(vm.layers[0].transitions.first?.presetID == "trans_basic_fade")
        #expect(vm.redo() == true)
        #expect(vm.layers[0].transitions.first?.presetID == "trans_light_white_flash")

        vm.moveClip(clipID: c1.id, from: contLayer.id, to: contLayer.id, insertAtIndex: nil, newStartTime: CMTime(seconds: 6.0, preferredTimescale: 600))
        #expect(vm.layers[0].transitions.isEmpty)
    }

    @Test("Transition drag representation renders cyan overlay rectangle image and highlights active seam on timeline")
    func testTransitionDragCyanOverlayAndTimelineHighlight() throws {
        let item = try #require(TransitionLibraryItem.systemItems.first(where: { $0.id == "trans_basic_fade" }))

        let dragImg = TransitionDragSourceNSView.renderCyanOverlayImage(for: item, width: 100, height: 32)
        #expect(dragImg.size.width == 100)
        #expect(dragImg.size.height == 32)

        let c0 = TimelineClip(name: "A", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 4.0, preferredTimescale: 600)))
        let c1 = TimelineClip(name: "B", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 4.0, preferredTimescale: 600), duration: CMTime(seconds: 4.0, preferredTimescale: 600)))
        let layer = TimelineLayer(name: "V1", kind: .video, clips: [c0, c1])
        let vm = TimelineViewModel(initialLayers: [layer])
        let cutX = 4.0 * vm.pixelsPerSecond
        let topSpacer: CGFloat = 20.0
        let trackH = vm.layerHeight(for: .video)
        let midY = topSpacer + trackH * 0.5

        let targetOutside = vm.resolveTransitionDropTarget(item: item, canvasX: 50.0, canvasY: midY, topSpacerHeight: topSpacer)
        vm.activeTransitionDropTarget = targetOutside
        #expect(vm.activeTransitionDropTarget == nil)

        // Valid target right on seam -> resolves activeTransitionDropTarget and snaps to cutX
        let targetInside = vm.resolveTransitionDropTarget(item: item, canvasX: cutX - 10.0, canvasY: midY, topSpacerHeight: topSpacer)
        vm.activeTransitionDropTarget = targetInside
        #expect(vm.activeTransitionDropTarget != nil)
        #expect(vm.activeTransitionDropTarget?.cutCanvasX == cutX)
        #expect(vm.activeTransitionDropTarget?.layerID == layer.id)
    }
}

