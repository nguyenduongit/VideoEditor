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
        ensureSecurityBookmarks(in: viewModel)

        if !saveAs, let currentURL = viewModel.currentProjectURL {
            _ = currentURL.startAccessingSecurityScopedResource()
            defer { currentURL.stopAccessingSecurityScopedResource() }
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

        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

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

        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let script = try ProjectScript.from(data: data)
            resolveSecurityBookmarks(in: script)
            viewModel.loadScript(script)
            viewModel.currentProjectURL = url
            let sourceURLs = script.extractSourceURLs()
            for srcURL in sourceURLs {
                _ = srcURL.startAccessingSecurityScopedResource()
            }
            mediaLibraryViewModel?.importURLs(sourceURLs)
            return url
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return nil
        }
    }

    private static func ensureSecurityBookmarks(in viewModel: TimelineViewModel) {
        for layerIndex in 0..<viewModel.layers.count {
            for clipIndex in 0..<viewModel.layers[layerIndex].clips.count {
                let clip = viewModel.layers[layerIndex].clips[clipIndex]
                if let mediaURL = clip.mediaURL, clip.properties["securityBookmark"] == nil {
                    if let bm = try? mediaURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                        viewModel.layers[layerIndex].clips[clipIndex].properties["securityBookmark"] = .string(bm.base64EncodedString())
                    }
                }
            }
        }
    }

    private static func resolveSecurityBookmarks(in script: ProjectScript) {
        for layer in script.layers {
            for clip in layer.clips {
                if let b64 = clip.properties["securityBookmark"]?.asString,
                   let bmData = Data(base64Encoded: b64) {
                    var isStale = false
                    if let resolved = try? URL(resolvingBookmarkData: bmData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                        _ = resolved.startAccessingSecurityScopedResource()
                    }
                }
            }
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
