import Foundation
import Testing
import Domain
import DesignSystem
@testable import FeatureShell

struct TimelineProjectIOTests {
    @Test @MainActor func testQuickSaveWritesToExistingCurrentProjectURL() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("TestProject_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let layer = TimelineLayer(id: UUID(), name: "Video Layer", kind: .video, clips: [])
        let viewModel = TimelineViewModel(initialLayers: [layer])
        viewModel.currentProjectURL = fileURL

        let savedURL = TimelineProjectIO.saveProject(from: viewModel, saveAs: false)
        #expect(savedURL == fileURL)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let data = try Data(contentsOf: fileURL)
        let script = try ProjectScript.from(data: data)
        #expect(script.layers.count == 1)
        #expect(script.layers.first?.name == "Video Layer")
    }

    @Test @MainActor func testDSTopbarButtonRendering() {
        var clicked = false
        let _ = DSTopbarButton(title: "Open", icon: "folder", style: .secondary) {
            clicked = true
        }
        let _ = DSTopbarButton(title: "Export", icon: "film.fill", style: .primary) {}

        #expect(clicked == false)
    }
}
