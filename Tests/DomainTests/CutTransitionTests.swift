import Testing
import Foundation
import CoreMedia
@testable import Domain

@Suite("CutTransition Domain Model Tests")
struct CutTransitionTests {
    @Test("CutTransition initialization and JSON serialization")
    func cutTransitionInitializationAndSerialization() throws {
        let leadID = UUID()
        let trailID = UUID()
        let transition = CutTransition(
            presetID: "whip_pan_left",
            name: "Whip Pan Trái",
            leadingClipID: leadID,
            trailingClipID: trailID,
            duration: RationalTime(value: 300, timescale: 600),
            alignment: .center,
            shaderType: .whipPanLeft
        )

        #expect(transition.presetID == "whip_pan_left")
        #expect(transition.alignment == .center)
        #expect(transition.shaderType == .whipPanLeft)
        #expect(abs(transition.duration.seconds - 0.5) < 0.001)

        let data = try JSONEncoder().encode(transition)
        let decoded = try JSONDecoder().decode(CutTransition.self, from: data)
        #expect(decoded.id == transition.id)
        #expect(decoded.leadingClipID == leadID)
        #expect(decoded.trailingClipID == trailID)
        #expect(decoded.shaderType == .whipPanLeft)
    }

    @Test("TimelineLayer transition pruning when neighbor clip is removed")
    func timelineLayerTransitionLifecycleAndPruning() {
        let clip1 = TimelineClip(name: "Clip 1", kind: .video, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 3000, timescale: 600)))
        let clip2 = TimelineClip(name: "Clip 2", kind: .video, timeRange: CMTimeRange(start: CMTime(value: 3000, timescale: 600), duration: CMTime(value: 3000, timescale: 600)))
        let clip3 = TimelineClip(name: "Clip 3", kind: .video, timeRange: CMTimeRange(start: CMTime(value: 6000, timescale: 600), duration: CMTime(value: 3000, timescale: 600)))

        var layer = TimelineLayer(kind: .video, clips: [clip1, clip2, clip3])
        let trans1 = CutTransition(presetID: "dissolve_default", name: "Dissolve", leadingClipID: clip1.id, trailingClipID: clip2.id)
        let trans2 = CutTransition(presetID: "zoom_blur", name: "Zoom", leadingClipID: clip2.id, trailingClipID: clip3.id)

        layer.addOrUpdateTransition(trans1)
        layer.addOrUpdateTransition(trans2)
        #expect(layer.transitions.count == 2)

        // Xóa clip ở giữa (clip2) -> Cả 2 transition đều phải tự động bị dọn dẹp
        _ = layer.removeClip(by: clip2.id)
        #expect(layer.transitions.isEmpty)
    }

    @Test("Clip template locking property")
    func clipTemplateLockProperty() {
        let basicClip = TimelineClip(name: "Basic Text", kind: .text, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 600, timescale: 600)))
        #expect(!basicClip.isLockedTemplate)

        var templateClipProps = BuiltInClipPropertyDefaults.properties(for: .text)
        templateClipProps["originPresetId"] = .string("cyber_neon_3d")
        let templateClip = TimelineClip(name: "Cyber Neon", kind: .text, timeRange: CMTimeRange(start: .zero, duration: CMTime(value: 600, timescale: 600)), properties: templateClipProps)
        #expect(!templateClip.isLockedTemplate)
        #expect(templateClip.originPresetID == "cyber_neon_3d")
    }
}
