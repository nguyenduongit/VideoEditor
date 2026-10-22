import AppKit
import AVFoundation

extension EditorViewController {
    @discardableResult func saveSession() -> Bool {
        guard !busy else { return false }
        view.window?.makeFirstResponder(nil)
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["vaeproject"]
        panel.nameFieldStringValue = sessionURL?.lastPathComponent ?? "Video.vaeproject"
        if let url = sessionURL { panel.directoryURL = url.deletingLastPathComponent() }
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(EditorProjectFile(session: session, lastExport: lastExport)).write(to: url, options: .atomic)
            sessionURL = url
            savedSession = session
            refresh()
            report("Đã lưu phiên.")
            return true
        } catch {
            report(error.localizedDescription)
            return false
        }
    }

    func confirmDiscard() -> Bool {
        view.window?.makeFirstResponder(nil)
        if busy {
            report("Đợi tác vụ hiện tại hoàn tất trước khi đóng hoặc thay phiên.")
            return false
        }
        guard session != savedSession else { return true }
        let alert = NSAlert()
        alert.messageText = "Lưu phiên trước khi tiếp tục?"
        alert.informativeText = "Phiên có chỉnh sửa chưa lưu."
        alert.addButton(withTitle: "Lưu")
        alert.addButton(withTitle: "Hủy")
        alert.addButton(withTitle: "Không lưu")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveSession()
        case .alertThirdButtonReturn:
            return true
        default:
            return false
        }
    }

    func newSession() {
        guard confirmDiscard() else { return }
        cancelPoseAnalysis()
        cancelColorAnalysis()
        session = EditorSession()
        savedSession = session
        sessionURL = nil
        lastExport = nil
        history.removeAllActions()
        waveformGeneration += 1
        timeline.peaks = []
        group = 0
        selector.selectedSegment = 0
        refresh()
        rebuild()
    }

    func openSession() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["vaeproject"]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, confirmDiscard() else { return }
        cancelPoseAnalysis()
        cancelColorAnalysis()
        do {
            let data = try Data(contentsOf: url)
            let file: EditorProjectFile
            if let envelope = try? JSONDecoder().decode(EditorProjectFile.self, from: data) {
                file = envelope
            } else {
                file = EditorProjectFile(session: try JSONDecoder().decode(EditorSession.self, from: data), lastExport: nil)
            }
            guard file.version == 1 else { throw EditorError.message("Phiên bản file chưa được hỗ trợ.") }
            var loaded = file.session
            try loaded.validate()
            // Không ghi đè adjustments.enabled — file đã lưu enabled=false phải được tôn trọng.
            // Migration cho file cũ không có key 'adjustments' đã được xử lý bởi ?? EditorAdjustments() (default enabled=true).
            var changedSource = false
            for video in [true, false] {
                if let source = video ? loaded.video : loaded.audio, !source.isCurrent {
                    let relink = NSOpenPanel()
                    relink.message = "Liên kết lại \(video ? "video" : "audio"): \(URL(fileURLWithPath: source.path).lastPathComponent)"
                    relink.allowsMultipleSelection = false
                    guard relink.runModal() == .OK, let replacement = relink.url else { return }
                    let asset = AVURLAsset(url: replacement)
                    guard asset.duration.seconds.isFinite, asset.duration.seconds > 0, !asset.tracks(withMediaType: video ? .video : .audio).isEmpty else {
                        throw EditorError.message("Nguồn thay thế không hợp lệ.")
                    }
                    if video {
                        loaded.video = SourceIdentity(url: replacement)
                        loaded.sourceDuration = asset.duration.seconds
                        loaded.pose = nil
                        loaded.legScale = 1.0
                        loaded.legHipY = 0.55
                        loaded.legAnkleY = 0.25
                    } else {
                        loaded.audio = SourceIdentity(url: replacement)
                        loaded.audioDuration = asset.duration.seconds
                    }
                    changedSource = true
                }
            }
            if changedSource {
                loaded.match = nil
                loaded.blocks = []
                loaded.fades = []
                loaded.videoEffects = []
            }
            let needsLegGuideAnalysis = loaded.video != nil && (loaded.pose?.guides?.isEmpty ?? true)
            loaded.normalizeFades()
            loaded.normalizeVideoEffects()
            session = loaded
            savedSession = changedSource ? file.session : loaded
            sessionURL = url
            lastExport = file.lastExport
            history.removeAllActions()
            timeline.peaks = []
            refresh()
            rebuild()
            report(changedSource ? "Đã liên kết nguồn mới; cần đồng bộ và đặt lại block." : "Đã khôi phục phiên.")
            if needsLegGuideAnalysis { analyzePose(background: true) }
            analyzeWaveform(updateBeat: false)
        } catch {
            report(error.localizedDescription)
        }
    }

    func showLog() {
        let alert = NSAlert()
        alert.messageText = "Nhật ký"
        alert.informativeText = logMessages.suffix(16).joined(separator: "\n")
        alert.runModal()
    }
}
