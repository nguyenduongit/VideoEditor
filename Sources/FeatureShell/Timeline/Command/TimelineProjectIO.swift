import AppKit
import Foundation
import Domain

/// Handles system file dialogs (NSOpenPanel, NSSavePanel) for importing and exporting project scripts.
@MainActor
public enum TimelineProjectIO {
    public static func exportProjectScript(from viewModel: TimelineViewModel) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.nameFieldStringValue = "ProjectScript.json"
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            let script = viewModel.exportScript(title: url.deletingPathExtension().lastPathComponent)
            let jsonString = try script.toJSONString(prettyPrinted: true)
            try jsonString.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    public static func importProjectScript(
        into viewModel: TimelineViewModel,
        mediaLibraryViewModel: MediaLibraryViewModel? = nil
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let script = try ProjectScript.from(data: data)
            viewModel.loadScript(script)
            let sourceURLs = script.extractSourceURLs()
            mediaLibraryViewModel?.importURLs(sourceURLs)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
}
