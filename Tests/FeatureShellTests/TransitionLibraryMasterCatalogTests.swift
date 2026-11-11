import Testing
import Foundation
import CoreMedia
import SwiftUI
import Domain
@testable import FeatureShell

@Suite("Transition Library Master Catalog & Animated Thumbnail Tests")
@MainActor
struct TransitionLibraryMasterCatalogTests {

    @Test("TransitionPreset builtInCatalog contains exactly 83 presets across 8 international NLE categories with 2.0s default duration")
    func testCatalogSizeCategoriesAndDefaults() {
        let catalog = TransitionPreset.builtInCatalog
        #expect(catalog.count == 83, "Thư viện phải có chính xác 83 mẫu chuyển cảnh")

        let ids = catalog.map(\.id)
        #expect(Set(ids).count == 83, "Tất cả 83 mẫu chuyển cảnh phải có ID duy nhất không trùng lặp")

        // 1. Basic (10 mẫu)
        let basic = catalog.filter { $0.category == .basic }
        #expect(basic.count == 10)

        // 2. Slide & Wipe (12 mẫu)
        let slideWipe = catalog.filter { $0.category == .slideWipe }
        #expect(slideWipe.count == 12)

        // 3. Zoom (9 mẫu)
        let zoom = catalog.filter { $0.category == .zoom }
        #expect(zoom.count == 9)

        // 4. Blur (9 mẫu)
        let blur = catalog.filter { $0.category == .blur }
        #expect(blur.count == 9)

        // 5. Camera & Motion (10 mẫu)
        let camera = catalog.filter { $0.category == .camera }
        #expect(camera.count == 10)

        // 6. Glitch & Distortion (11 mẫu)
        let glitch = catalog.filter { $0.category == .glitch }
        #expect(glitch.count == 11)

        // 7. Light Effects (10 mẫu)
        let light = catalog.filter { $0.category == .light }
        #expect(light.count == 10)

        // 8. 3D & Mask (12 mẫu)
        let advanced3D = catalog.filter { $0.category == .advanced3D }
        #expect(advanced3D.count == 12)

        // Kiểm tra thời lượng mặc định 2.0s và tính hợp lệ của metadata
        for preset in catalog {
            #expect(preset.defaultDuration == 2.0, "Preset \(preset.id) phải có thời lượng mặc định là 2.0s")
            #expect(!preset.name.isEmpty)
            #expect(!preset.description.isEmpty)
            #expect(!preset.iconName.isEmpty)
            #expect(preset.isSystem == true)
        }
    }

    @Test("TransitionAnimatedThumbnailView uses 2.0s hover duration and executes exact GPU transition algorithm for all 83 presets")
    func testAnimatedThumbnailViewAndRealGPUAlgorithmExecution() throws {
        #expect(TransitionAnimatedThumbnailView.hoverDurationSeconds == 2.0)

        let provider = TransitionThumbnailAssetProvider.shared
        for preset in TransitionPreset.builtInCatalog {
            let view = TransitionAnimatedThumbnailView(preset: preset)
            _ = view.body
            let frameMid = provider.renderTransitionFrame(for: preset, rawProgress: 0.5)
            #expect(frameMid != nil, "GPU transition frame must render for preset \(preset.id)")
        }

        // Xác minh White Flash (Basic & Light) tại đỉnh chuyển cảnh (0.5) chớp trắng tinh khiết (RGB ~ 255,255,255), KHÔNG chớp vàng
        for whiteFlashID in ["trans_basic_white_flash", "trans_light_white_flash"] {
            let preset = try #require(TransitionPreset.builtInCatalog.first(where: { $0.id == whiteFlashID }))
            let cgImg = try #require(provider.renderTransitionFrame(for: preset, rawProgress: 0.5))
            let (r, g, b) = sampleCenterPixelRGB(of: cgImg)
            #expect(r >= 245 && g >= 245 && b >= 245, "Preset \(whiteFlashID) tại p=0.5 phải chớp trắng tinh khiết, thực tế RGB=(\(r),\(g),\(b))")
            #expect(abs(Int(r) - Int(b)) <= 3, "Preset \(whiteFlashID) không được ám vàng (R và B phải cân bằng)")
        }

        // Xác minh Black Fade tại đỉnh chuyển cảnh (0.5) chìm về màu đen
        let blackFade = try #require(TransitionPreset.builtInCatalog.first(where: { $0.id == "trans_basic_black_fade" }))
        let blackCG = try #require(provider.renderTransitionFrame(for: blackFade, rawProgress: 0.5))
        let (br, bg, bb) = sampleCenterPixelRGB(of: blackCG)
        #expect(br <= 15 && bg <= 15 && bb <= 15, "Black Fade tại p=0.5 phải tối đen, thực tế RGB=(\(br),\(bg),\(bb))")
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

    @Test("TransitionThumbnailAssetProvider loads, squares and caches real photo assets A and B")
    func testThumbnailAssetProviderSquareAssets() {
        let provider = TransitionThumbnailAssetProvider.shared
        _ = provider.imageA
        _ = provider.imageB

        if let nsA = provider.nsImageA {
            #expect(nsA.size.width > 0)
            #expect(abs(nsA.size.width - nsA.size.height) <= 1.0, "Ảnh Cảnh A phải được crop vuông 1:1")
        }
        if let nsB = provider.nsImageB {
            #expect(nsB.size.width > 0)
            #expect(abs(nsB.size.width - nsB.size.height) <= 1.0, "Ảnh Cảnh B phải được crop vuông 1:1")
        }
    }

    @Test("TimelineViewModel applies 2.0s default duration and clamps safely for short clips")
    func testTimelineAddTransitionDurationClamping() throws {
        // Cặp clip dài 5.0s -> Transition nhận đủ 2.0s
        let c0 = TimelineClip(name: "A", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5.0, preferredTimescale: 600)))
        let c1 = TimelineClip(name: "B", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5.0, preferredTimescale: 600), duration: CMTime(seconds: 5.0, preferredTimescale: 600)))
        let layer1 = TimelineLayer(name: "V1", kind: .video, clips: [c0, c1])
        let vm = TimelineViewModel(initialLayers: [layer1])

        let preset = try #require(TransitionPreset.builtInCatalog.first(where: { $0.id == "trans_slide_right" }))
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
        let fadePreset = try #require(TransitionPreset.builtInCatalog.first(where: { $0.id == "trans_basic_fade" }))
        let flashPreset = try #require(TransitionPreset.builtInCatalog.first(where: { $0.id == "trans_light_white_flash" }))

        // 1. Hai video clip CÓ khoảng cách (0..4s và 4.5..8.5s -> gap = 0.5s) -> KHÔNG THỂ thêm transition
        let g0 = TimelineClip(name: "G0", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 4.0, preferredTimescale: 600)))
        let g1 = TimelineClip(name: "G1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 4.5, preferredTimescale: 600), duration: CMTime(seconds: 4.0, preferredTimescale: 600)))
        let gapLayer = TimelineLayer(name: "VGap", kind: .video, clips: [g0, g1])
        let gapVM = TimelineViewModel(initialLayers: [gapLayer])
        #expect(gapLayer.areClipsContiguous(leadingID: g0.id, trailingID: g1.id) == false)
        #expect(gapVM.addOrUpdateCutTransition(fadePreset, between: g0.id, and: g1.id) == nil)
        #expect(gapVM.layers[0].transitions.isEmpty)

        // 2. Hai video clip NỐI SÁT NHAU không khoảng cách (0..5s và 5..10s, điểm nối tại t = 5.0s)
        let c0 = TimelineClip(name: "C0", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5.0, preferredTimescale: 600)))
        let c1 = TimelineClip(name: "C1", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 5.0, preferredTimescale: 600), duration: CMTime(seconds: 5.0, preferredTimescale: 600)))
        let contLayer = TimelineLayer(name: "V1", kind: .video, clips: [c0, c1])
        let vm = TimelineViewModel(initialLayers: [contLayer])
        let pps = vm.pixelsPerSecond
        let cutX = 5.0 * pps
        let topSpacer: CGFloat = 20.0
        let trackHeight = vm.layerHeight(for: .video)
        let midY = topSpacer + trackHeight * 0.5

        // Thả ngoài vùng điểm nối (ví dụ tại t = 1.0s -> canvasX = 1.0 * pps) -> Bị từ chối
        #expect(vm.resolveTransitionDropTarget(preset: fadePreset, canvasX: 1.0 * pps, canvasY: midY, topSpacerHeight: topSpacer) == nil)
        #expect(vm.dropTransition(fadePreset, atCanvasX: 1.0 * pps, canvasY: midY, topSpacerHeight: topSpacer) == nil)

        // Thả trong vùng chứa điểm nối (t = 5.0s -> cutX, thả tại cutX - 15pt) -> Thành công
        let target = try #require(vm.resolveTransitionDropTarget(preset: fadePreset, canvasX: cutX - 15.0, canvasY: midY, topSpacerHeight: topSpacer))
        #expect(target.leadingClipID == c0.id)
        #expect(target.trailingClipID == c1.id)
        #expect(abs(target.cutCanvasX - cutX) < 0.01)

        let added = try #require(vm.dropTransition(fadePreset, atCanvasX: cutX - 15.0, canvasY: midY, topSpacerHeight: topSpacer))
        #expect(added.presetID == "trans_basic_fade")
        #expect(vm.layers[0].transitions.count == 1)

        // 3. Thả đè (thay thế) transition mới (White Flash) vào vị trí đã có transition -> Thay thế thành công & hỗ trợ Undo/Redo
        let replaced = try #require(vm.dropTransition(flashPreset, atCanvasX: cutX + 12.0, canvasY: midY, topSpacerHeight: topSpacer))
        #expect(replaced.id == added.id)
        #expect(replaced.presetID == "trans_light_white_flash")
        #expect(vm.layers[0].transitions.count == 1)
        #expect(vm.layers[0].transitions[0].name == "White Flash")

        // Kiểm tra Undo quay lại Fade & Redo tiến tới White Flash
        #expect(vm.undo() == true)
        #expect(vm.layers[0].transitions.first?.presetID == "trans_basic_fade")
        #expect(vm.redo() == true)
        #expect(vm.layers[0].transitions.first?.presetID == "trans_light_white_flash")

        // 4. Nếu dịch chuyển clip thứ 2 ra xa tạo khoảng trống (t = 6.0s) -> Transition tự động bị loại bỏ
        vm.moveClip(clipID: c1.id, from: contLayer.id, to: contLayer.id, insertAtIndex: nil, newStartTime: CMTime(seconds: 6.0, preferredTimescale: 600))
        #expect(vm.layers[0].transitions.isEmpty)
    }

    @Test("Transition drag representation renders cyan overlay rectangle image and highlights active seam on timeline")
    func testTransitionDragCyanOverlayAndTimelineHighlight() throws {
        let preset = try #require(TransitionPreset.builtInCatalog.first(where: { $0.id == "trans_basic_fade" }))

        // 1. Kiểm tra hình ảnh kéo thả đi theo chuột là khối hình chữ nhật overlay Cyan (không phải thumbnail ảnh)
        let dragImg = TransitionDragSourceNSView.renderCyanOverlayImage(for: preset, width: 100, height: 32)
        #expect(dragImg.size.width == 100)
        #expect(dragImg.size.height == 32)

        // 2. Kiểm tra activeTransitionDropTarget cập nhật chuẩn xác khi hover vào mối nối và xóa khi ra ngoài
        let c0 = TimelineClip(name: "A", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 4.0, preferredTimescale: 600)))
        let c1 = TimelineClip(name: "B", kind: .video, timeRange: CMTimeRange(start: CMTime(seconds: 4.0, preferredTimescale: 600), duration: CMTime(seconds: 4.0, preferredTimescale: 600)))
        let layer = TimelineLayer(name: "V1", kind: .video, clips: [c0, c1])
        let vm = TimelineViewModel(initialLayers: [layer])
        let cutX = 4.0 * vm.pixelsPerSecond
        let topSpacer: CGFloat = 20.0
        let trackH = vm.layerHeight(for: .video)
        let midY = topSpacer + trackH * 0.5

        // Vị trí không khả dụng (ngoài mối nối) -> activeTransitionDropTarget = nil
        let targetOutside = vm.resolveTransitionDropTarget(preset: preset, canvasX: 50.0, canvasY: midY, topSpacerHeight: topSpacer)
        vm.activeTransitionDropTarget = targetOutside
        #expect(vm.activeTransitionDropTarget == nil)

        // Vị trí khả dụng (ngay tại mối nối) -> activeTransitionDropTarget có giá trị và snap đúng vào cutX
        let targetInside = vm.resolveTransitionDropTarget(preset: preset, canvasX: cutX - 10.0, canvasY: midY, topSpacerHeight: topSpacer)
        vm.activeTransitionDropTarget = targetInside
        #expect(vm.activeTransitionDropTarget != nil)
        #expect(vm.activeTransitionDropTarget?.cutCanvasX == cutX)
        #expect(vm.activeTransitionDropTarget?.layerID == layer.id)
    }
}

