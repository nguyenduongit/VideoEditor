import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    /// Kiểm tra xem clip đang chọn có hỗ trợ đánh dấu nhịp (Audio hoặc Video có file nguồn) hay không.
    public var canMarkBeats: Bool {
        guard !selectedClipIDs.isEmpty else { return false }
        let selectedClips = layers.flatMap(\.clips).filter { selectedClipIDs.contains($0.id) }
        return selectedClips.contains { ($0.kind == .audio || $0.kind == .video) && $0.mediaURL != nil }
    }

    /// Kiểm tra xem clip đang chọn đã có các điểm beat hiển thị hay chưa.
    public var selectedClipHasBeats: Bool {
        let selectedClips = layers.flatMap(\.clips).filter { selectedClipIDs.contains($0.id) }
        return selectedClips.contains { clip in
            guard let config = AudioBeatConfiguration.from(clip: clip) else { return false }
            return config.isVisible && !config.markers.isEmpty
        }
    }

    /// Trả về chế độ bắt nhịp hiện tại của clip đang chọn (nếu có và đang hiển thị).
    public var selectedClipBeatMode: AudioBeatDetectionMode? {
        let selectedClips = layers.flatMap(\.clips).filter { selectedClipIDs.contains($0.id) }
        for clip in selectedClips {
            if let config = AudioBeatConfiguration.from(clip: clip), config.isVisible, !config.markers.isEmpty {
                return config.mode
            }
        }
        return nil
    }

    /// Tự động phân tích âm thanh hoặc bật/tắt hiển thị các ghim nhịp (Beat Markers).
    public func autoMarkBeats(mode: AudioBeatDetectionMode = .majorOnly) {
        guard canMarkBeats, !isDetectingBeats else { return }
        let targetClips = layers.flatMap(\.clips).filter {
            selectedClipIDs.contains($0.id) && ($0.kind == .audio || $0.kind == .video) && $0.mediaURL != nil
        }
        guard !targetClips.isEmpty else { return }

        // Fast-path: Nếu clip đã được phân tích ngầm từ trước cho mode này, bật/tắt hiển thị tức thì (zero latency)
        let allPrecomputed = targetClips.allSatisfy { clip in
            if let config = AudioBeatConfiguration.from(clip: clip), !config.markers.isEmpty, config.mode == mode {
                return true
            }
            return false
        }

        if allPrecomputed {
            var commands: [TimelineCommand] = []
            for clip in targetClips {
                guard var config = AudioBeatConfiguration.from(clip: clip) else { continue }
                config.isVisible.toggle()
                guard let json = config.encodeToJSON() else { continue }
                var updatedProps = clip.properties
                updatedProps[AudioBeatConfiguration.propertyKey] = .string(json)
                commands.append(.updateClipProperties(clipID: clip.id, properties: updatedProps))
            }
            if let executor = commandExecutor, !isApplyingCommand, !commands.isEmpty {
                let cmd: TimelineCommand = commands.count == 1 ? commands[0] : .batch(commands: commands)
                executor.execute(cmd, title: "Bật/tắt hiển thị nhịp (\(mode.displayName))")
            }
            return
        }

        guard let beatService = audioBeatDetectionService else {
            onBeatDetectionResult?(false, "Dịch vụ phân tích nhịp chưa được khởi tạo.")
            return
        }

        isDetectingBeats = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isDetectingBeats = false }

            var commands: [TimelineCommand] = []
            var totalDetected = 0

            for clip in targetClips {
                guard let url = clip.mediaURL else { continue }
                let markers = await beatService.detectBeats(url: url, mode: mode)
                let config = AudioBeatConfiguration(mode: mode, markers: markers, isVisible: true)
                guard let json = config.encodeToJSON() else { continue }

                var updatedProps = clip.properties
                updatedProps[AudioBeatConfiguration.propertyKey] = .string(json)
                commands.append(.updateClipProperties(clipID: clip.id, properties: updatedProps))
                totalDetected += markers.count
            }

            guard !commands.isEmpty else {
                self.onBeatDetectionResult?(false, "Không tìm thấy điểm nhịp rõ ràng trong đoạn âm thanh.")
                return
            }

            if let executor = self.commandExecutor, !self.isApplyingCommand {
                let cmd: TimelineCommand = commands.count == 1 ? commands[0] : .batch(commands: commands)
                executor.execute(cmd, title: "Tự động bắt nhịp (\(mode.displayName))")
            }

            self.onBeatDetectionResult?(true, "Đã đánh dấu \(totalDetected) điểm nhịp (\(mode.displayName)).")
        }
    }

    /// Phân tích nhịp ngầm cho clip âm thanh mới thêm vào timeline mà không hiển thị marker.
    public func backgroundAnalyzeBeats(for clipID: UUID, url: URL) {
        guard let beatService = audioBeatDetectionService else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let markers = await beatService.detectBeats(url: url, mode: .majorOnly)
            guard !markers.isEmpty else { return }
            guard let currentClip = self.layers.flatMap(\.clips).first(where: { $0.id == clipID }) else { return }
            if AudioBeatConfiguration.from(clip: currentClip) == nil {
                let config = AudioBeatConfiguration(mode: .majorOnly, markers: markers, isVisible: false)
                if let json = config.encodeToJSON() {
                    var updated = currentClip.properties
                    updated[AudioBeatConfiguration.propertyKey] = .string(json)
                    for lIdx in self.layers.indices {
                        if let cIdx = self.layers[lIdx].clips.firstIndex(where: { $0.id == clipID }) {
                            self.layers[lIdx].clips[cIdx].properties = updated
                            break
                        }
                    }
                }
            }
        }
    }

    /// Thêm hoặc xóa thủ công một điểm beat ngay tại vị trí Playhead (phím tắt `M`).
    @discardableResult
    public func toggleBeatMarkerAtPlayhead(at timelineTime: CMTime? = nil) -> Bool {
        let playhead = timelineTime ?? currentTime
        guard let targetClip = resolveTargetClipForManualBeat(at: playhead) else { return false }

        let speed = max(0.01, targetClip.properties["speed"]?.asNumber ?? 1.0)
        let relSec = max(0.0, CMTimeGetSeconds(playhead - targetClip.timeRange.start))
        let sourceSec = max(0.0, CMTimeGetSeconds(targetClip.sourceStartTime) + (relSec * speed))
        let sourceTime = CMTime(seconds: sourceSec, preferredTimescale: 600)

        var config = AudioBeatConfiguration.from(clip: targetClip) ?? AudioBeatConfiguration(mode: .majorOnly, markers: [], isVisible: true)
        config.isVisible = true
        let toleranceSourceSec = 0.06 * speed
        let didAdd = config.toggleMarker(atSourceTime: sourceTime, toleranceSeconds: toleranceSourceSec, kind: .major)

        var updatedProps = targetClip.properties
        if config.markers.isEmpty {
            updatedProps[AudioBeatConfiguration.propertyKey] = .string("")
        } else if let json = config.encodeToJSON() {
            updatedProps[AudioBeatConfiguration.propertyKey] = .string(json)
        }

        if let executor = commandExecutor, !isApplyingCommand {
            executor.execute(
                .updateClipProperties(clipID: targetClip.id, properties: updatedProps),
                title: didAdd ? "Thêm điểm nhịp" : "Xóa điểm nhịp"
            )
        }
        return true
    }

    /// Xóa toàn bộ điểm beat trên các clip đang được chọn.
    public func clearSelectedBeatMarkers() {
        let targetClips = layers.flatMap(\.clips).filter { selectedClipIDs.contains($0.id) }
        var commands: [TimelineCommand] = []

        for clip in targetClips {
            guard let config = AudioBeatConfiguration.from(clip: clip), !config.markers.isEmpty else { continue }
            var updatedProps = clip.properties
            updatedProps[AudioBeatConfiguration.propertyKey] = .string("")
            commands.append(.updateClipProperties(clipID: clip.id, properties: updatedProps))
        }

        guard !commands.isEmpty, let executor = commandExecutor, !isApplyingCommand else { return }
        let cmd: TimelineCommand = commands.count == 1 ? commands[0] : .batch(commands: commands)
        executor.execute(cmd, title: "Xóa toàn bộ điểm nhịp")
    }

    private func resolveTargetClipForManualBeat(at time: CMTime) -> TimelineClip? {
        let unlockedClips = layers.filter { !$0.isLocked }.flatMap(\.clips)
        let selectedMatching = unlockedClips.first { clip in
            selectedClipIDs.contains(clip.id)
                && (clip.kind == .audio || clip.kind == .video)
                && time >= clip.timeRange.start
                && time <= clip.timeRange.end
        }
        if let selectedMatching { return selectedMatching }

        let firstAudioAtTime = unlockedClips.first { clip in
            clip.kind == .audio && time >= clip.timeRange.start && time <= clip.timeRange.end
        }
        if let firstAudioAtTime { return firstAudioAtTime }

        return unlockedClips.first { clip in
            clip.kind == .video && time >= clip.timeRange.start && time <= clip.timeRange.end
        }
    }
}

