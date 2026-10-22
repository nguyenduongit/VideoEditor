import Testing
import Foundation
@testable import Domain

@Suite("ProjectHistorySerializationTests")
struct ProjectHistorySerializationTests {
    @Test("ProjectScript serializes and deserializes history records accurately")
    func testProjectScriptHistoryRoundTrip() throws {
        let clip = ClipScript(
            id: UUID(),
            name: "Test Clip",
            kind: .video,
            source: .file(url: URL(fileURLWithPath: "/tmp/sample.mp4")),
            timelineRange: RationalTimeRange(start: .zero, duration: RationalTime(value: 5, timescale: 1)),
            sourceStartTime: .zero
        )
        let layerID = UUID()
        let command = TimelineCommand.addClip(layerID: layerID, clip: clip)
        let inverse = TimelineCommand.removeClip(clipID: clip.id)
        let record = TimelineHistoryRecord(
            title: "Add Sample Clip",
            command: command,
            inverse: inverse
        )

        let script = ProjectScript(
            title: "History Project",
            fps: 30,
            layers: [LayerScript(id: layerID, name: "Video Layer", kind: .video, clips: [clip])],
            history: [record],
            historyIndex: 1
        )

        let jsonString = try script.toJSONString()
        #expect(jsonString.contains("history"))
        #expect(jsonString.contains("1.1.0"))
        #expect(jsonString.contains("Add Sample Clip"))

        let restored = try ProjectScript.from(jsonString: jsonString)
        #expect(restored.schemaVersion == "1.1.0")
        #expect(restored.history.count == 1)
        #expect(restored.historyIndex == 1)
        #expect(restored.history[0].title == "Add Sample Clip")
        #expect(restored.history[0].command == command)
        #expect(restored.history[0].inverse == inverse)
    }

    @Test("Legacy schema 1.0.0 without history field decodes safely with empty history")
    func testLegacySchema100Compatibility() throws {
        let legacyJSON = """
        {
          "schemaVersion": "1.0.0",
          "metadata": {
            "title": "Legacy Project",
            "createdAt": "2026-10-18T10:00:00Z",
            "modifiedAt": "2026-10-18T10:00:00Z"
          },
          "fps": 30,
          "layers": []
        }
        """

        let script = try ProjectScript.from(jsonString: legacyJSON)
        #expect(script.metadata.title == "Legacy Project")
        #expect(script.layers.isEmpty)
        #expect(script.history.isEmpty)
        #expect(script.historyIndex == 0)
    }
}
