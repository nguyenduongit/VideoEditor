import AppKit
import Foundation
import Domain

/// Handles system file dialogs (NSOpenPanel, NSSavePanel) for opening and saving projects.
@MainActor
public enum TimelineProjectIO {
    @discardableResult
    public static func saveProject(
        from viewModel: TimelineViewModel,
        saveAs: Bool = false
    ) -> URL? {
        if !saveAs, let currentURL = viewModel.currentProjectURL {
            do {
                let script = viewModel.exportScript(title: currentURL.deletingPathExtension().lastPathComponent)
                let jsonString = try script.toJSONString(prettyPrinted: true)
                try jsonString.write(to: currentURL, atomically: true, encoding: .utf8)
                return currentURL
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
                return nil
            }
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = false
        panel.nameFieldStringValue = viewModel.currentProjectURL?.lastPathComponent ?? "Project.json"
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }

        do {
            let script = viewModel.exportScript(title: url.deletingPathExtension().lastPathComponent)
            let jsonString = try script.toJSONString(prettyPrinted: true)
            try jsonString.write(to: url, atomically: true, encoding: .utf8)
            viewModel.currentProjectURL = url
            return url
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return nil
        }
    }

    @discardableResult
    public static func openProject(
        into viewModel: TimelineViewModel,
        mediaLibraryViewModel: MediaLibraryViewModel? = nil
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let script = try ProjectScript.from(data: data)
            viewModel.loadScript(script)
            viewModel.currentProjectURL = url
            let sourceURLs = script.extractSourceURLs()
            mediaLibraryViewModel?.importURLs(sourceURLs)
            return url
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return nil
        }
    }

    public static func exportProjectScript(from viewModel: TimelineViewModel) {
        saveProject(from: viewModel, saveAs: true)
    }

    public static func importProjectScript(
        into viewModel: TimelineViewModel,
        mediaLibraryViewModel: MediaLibraryViewModel? = nil
    ) {
        openProject(into: viewModel, mediaLibraryViewModel: mediaLibraryViewModel)
    }
}
