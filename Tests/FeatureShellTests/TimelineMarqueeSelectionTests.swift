import Testing
import Foundation
import CoreGraphics
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("TimelineMarqueeSelectionTests")
@MainActor
struct TimelineMarqueeSelectionTests {
    private func makeTimelineViewModel() -> (TimelineViewModel, TimelineClip, TimelineClip, TimelineClip) {
        let clip1 = TimelineClip(
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 5, timescale: 1)) // 0s - 5s
        )
        let clip2 = TimelineClip(
            name: "Clip 2",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(value: 6, timescale: 1), duration: CMTime(value: 4, timescale: 1)) // 6s - 10s
        )
        let clip3 = TimelineClip(
            name: "Clip 3",
            kind: .audio,
            timeRange: CMTimeRange(start: CMTime(value: 2, timescale: 1), duration: CMTime(value: 6, timescale: 1)) // 2s - 8s
        )

        let layer0 = TimelineLayer(name: "Video 1", kind: .video, clips: [clip1, clip2])
        let layer1 = TimelineLayer(name: "Audio 1", kind: .audio, clips: [clip3])

        let vm = TimelineViewModel(initialLayers: [layer0, layer1])
        vm.setZoomPixelsPerSecond(50.0) // 50 px per second
        return (vm, clip1, clip2, clip3)
    }

    @Test("Marquee intersecting single clip in layer 0 selects only that clip")
    func testMarqueeSelectSingleClip() {
        let (vm, clip1, _, _) = makeTimelineViewModel()
        let topSpacer: CGFloat = 100.0
        // Layer 0 starts at Y: 100, height: 80 (video layer)
        // Clip 1 is at X: 0...250 (5s * 50pps = 250)
        let marquee = CGRect(x: 10, y: 110, width: 50, height: 40)
        let selected = vm.clipsIntersecting(rect: marquee, topSpacerHeight: topSpacer)

        #expect(selected == [clip1.id])
    }

    @Test("Marquee spanning multiple tracks selects clips across layers in real-time")
    func testMarqueeSelectMultipleTracks() {
        let (vm, clip1, _, clip3) = makeTimelineViewModel()
        let topSpacer: CGFloat = 100.0
        // Layer 0: Y = 100...180 (height 80)
        // Layer 1: Y = 180...240 (height 60)
        // Clip 1: 0s - 5s (X: 0...250)
        // Clip 3: 2s - 8s (X: 100...400)
        // Marquee spanning Y: 120...200, X: 110...190 -> touches both Clip 1 and Clip 3
        let marquee = CGRect(x: 110, y: 120, width: 80, height: 80)
        let selected = vm.clipsIntersecting(rect: marquee, topSpacerHeight: topSpacer)

        #expect(selected == [clip1.id, clip3.id])

        vm.updateMarqueeSelection(rect: marquee, topSpacerHeight: topSpacer)
        #expect(vm.selectedClipIDs == [clip1.id, clip3.id])
    }

    @Test("Marquee in empty top spacer selects no clips")
    func testMarqueeInEmptyTopSpacer() {
        let (vm, _, _, _) = makeTimelineViewModel()
        let topSpacer: CGFloat = 100.0
        // Marquee purely inside topSpacer (Y: 10...50)
        let marquee = CGRect(x: 0, y: 10, width: 500, height: 40)
        let selected = vm.clipsIntersecting(rect: marquee, topSpacerHeight: topSpacer)

        #expect(selected.isEmpty)
    }

    @Test("Marquee between clips selects nothing")
    func testMarqueeBetweenClips() {
        let (vm, _, _, _) = makeTimelineViewModel()
        let topSpacer: CGFloat = 100.0
        // In Layer 0, gap between Clip 1 (0...250) and Clip 2 (300...500) is 250...300 (5s to 6s)
        // Clip 3 is in Layer 1 (Y: 180...240). So in Layer 0 Y: 100...180, X: 260...280 is completely empty
        let marquee = CGRect(x: 260, y: 110, width: 20, height: 40)
        let selected = vm.clipsIntersecting(rect: marquee, topSpacerHeight: topSpacer)

        #expect(selected.isEmpty)
    }

    @Test("Marquee with reverse drag direction standardizes and detects clips accurately")
    func testMarqueeReverseDrag() {
        let (vm, clip1, _, _) = makeTimelineViewModel()
        let topSpacer: CGFloat = 100.0
        // Reverse drag: origin at (150, 150), negative width/height
        let reverseRect = CGRect(x: 150, y: 150, width: -100, height: -30)
        let selected = vm.clipsIntersecting(rect: reverseRect, topSpacerHeight: topSpacer)

        #expect(selected == [clip1.id])
    }

    @Test("TimelineMarqueeSelectionView initializes with rect")
    func testMarqueeSelectionViewInit() {
        let rect = CGRect(x: 20, y: 30, width: 200, height: 100)
        let view = TimelineMarqueeSelectionView(rect: rect)
        #expect(view.rect == rect)
    }
}
