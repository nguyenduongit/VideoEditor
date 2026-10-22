import Testing
import Foundation
import CoreMedia
@testable import Domain

@Suite("ProjectScriptSerializationTests")
struct ProjectScriptSerializationTests {
    @Test("RationalTime and RationalTimeRange arithmetic and conversion")
    func testRationalTimeConversions() {
        let cmTime = CMTime(value: 60, timescale: 30)
        let rational = RationalTime(cmTime: cmTime)
        #expect(rational.value == 60)
        #expect(rational.timescale == 30)
        #expect(rational.seconds == 2.0)
        #expect(rational.cmTime == cmTime)

        let t1 = RationalTime(value: 30, timescale: 30)
        let t2 = RationalTime(value: 60, timescale: 30)
        #expect(t1 < t2)
        #expect((t1 + t2).seconds == 3.0)
        #expect((t2 - t1).seconds == 1.0)

        let range = RationalTimeRange(start: t1, duration: t2)
        #expect(range.end.seconds == 3.0)
        #expect(range.cmTimeRange.start.seconds == 1.0)
        #expect(range.cmTimeRange.duration.seconds == 2.0)
    }

    @Test("ClipSource envelope serialization")
    func testClipSourceSerialization() throws {
        let testURL = URL(fileURLWithPath: "/tmp/sample.mp4")
        let fileSource = ClipSource.file(url: testURL)
        let textSource = ClipSource.text(
            content: "Hello World",
            style: TextStyleDescriptor(fontSize: 48, textColorHex: "#FF0000", isBold: true)
        )
        let colorSource = ClipSource.color(hex: "#00FF00")
        let adjSource = ClipSource.adjustment

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for source in [fileSource, textSource, colorSource, adjSource] {
            let data = try encoder.encode(source)
            let decoded = try decoder.decode(ClipSource.self, from: data)
            #expect(decoded == source)
        }
    }

    @Test("ClipScript and TimelineClip round-trip")
    func testClipScriptConversion() {
        let clipID = UUID()
        let clip = TimelineClip(
            id: clipID,
            name: "Clip 1",
            kind: .video,
            timeRange: CMTimeRange(start: CMTime(seconds: 2, preferredTimescale: 30), duration: CMTime(seconds: 4, preferredTimescale: 30)),
            maxDuration: CMTime(seconds: 10, preferredTimescale: 30),
            mediaURL: URL(fileURLWithPath: "/tmp/video.mp4"),
            sourceStartTime: CMTime(seconds: 1, preferredTimescale: 30)
        )

        let script = ClipScript(from: clip)
        #expect(script.id == clipID)
        #expect(script.name == "Clip 1")
        #expect(script.kind == .video)
        #expect(script.timelineRange.start.seconds == 2.0)
        #expect(script.timelineRange.duration.seconds == 4.0)

        let restoredClip = script.toTimelineClip()
        #expect(restoredClip.id == clipID)
        #expect(restoredClip.name == "Clip 1")
        #expect(restoredClip.kind == .video)
        #expect(CMTimeGetSeconds(restoredClip.timeRange.start) == 2.0)
        #expect(CMTimeGetSeconds(restoredClip.timeRange.duration) == 4.0)
        #expect(restoredClip.mediaURL == URL(fileURLWithPath: "/tmp/video.mp4"))
    }

    @Test("ProjectScript full JSON export and load round-trip")
    func testProjectScriptJSONRoundTrip() throws {
        let videoClip = TimelineClip(
            id: UUID(),
            name: "Background Video",
            kind: .video,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 30)),
            mediaURL: URL(fileURLWithPath: "/tmp/bg.mp4")
        )
        let audioClip = TimelineClip(
            id: UUID(),
            name: "Voiceover",
            kind: .audio,
            timeRange: CMTimeRange(start: CMTime(seconds: 1, preferredTimescale: 30), duration: CMTime(seconds: 3, preferredTimescale: 30)),
            mediaURL: URL(fileURLWithPath: "/tmp/voice.m4a")
        )

        let videoLayer = TimelineLayer(name: "V1", kind: .video, isLocked: false, isHidden: false, isMuted: false, clips: [videoClip])
        let audioLayer = TimelineLayer(name: "A1", kind: .audio, isLocked: true, isHidden: false, isMuted: true, clips: [audioClip])

        let project = ProjectScript(
            title: "Test Project",
            fps: 30,
            timelineLayers: [videoLayer, audioLayer]
        )

        #expect(project.schemaVersion == ProjectScript.currentSchemaVersion)
        #expect(project.totalDuration.seconds == 5.0)

        let jsonString = try project.toJSONString(prettyPrinted: true)
        #expect(jsonString.contains("Background Video"))
        #expect(jsonString.contains("Voiceover"))

        let restoredProject = try ProjectScript.from(jsonString: jsonString)
        #expect(restoredProject.metadata.title == "Test Project")
        #expect(restoredProject.layers.count == 2)

        let restoredLayers = restoredProject.toTimelineLayers()
        #expect(restoredLayers.count == 2)
        #expect(restoredLayers[0].clips.count == 1)
        #expect(restoredLayers[0].clips[0].name == "Background Video")
        #expect(restoredLayers[1].isLocked == true)
        #expect(restoredLayers[1].isMuted == true)
        #expect(restoredLayers[1].clips[0].name == "Voiceover")
    }
}
