import Foundation
import CoreMedia

/// Resolves real musical tempo (BPM) from the active audio/video track overlapping a timeline range.
public enum AudioTempoResolver: Sendable {
    /// Finds the dominant unmuted audio clip overlapping `targetRange` (falling back to unmuted video with beats)
    /// and extracts its effective timeline BPM (accounting for clip playback speed).
    public static func resolveTempo(
        overlapping targetRange: CMTimeRange,
        in layers: [TimelineLayer]
    ) -> ResolvedAudioTempo {
        let candidates = overlappingCandidates(for: targetRange, in: layers)
        guard let best = candidates.first else {
            return ResolvedAudioTempo()
        }
        return ResolvedAudioTempo(
            bpm: best.bpm,
            sourceClipID: best.clip.id,
            sourceClipName: best.clip.name,
            hasAudioUnderneath: true,
            needsBeatAnalysis: best.bpm == nil && !best.hasBeatConfig && best.clip.mediaURL != nil
        )
    }

    /// Extracts median contiguous downbeat BPM from `AudioBeatConfiguration`, adjusted for clip `speed`.
    public static func extractBPM(from config: AudioBeatConfiguration, clipSpeed: Double = 1.0) -> Double? {
        let majors = config.markers.filter { $0.kind == .major }.sorted { $0.sourceSeconds < $1.sourceSeconds }
        let markers = majors.count >= 2 ? majors : config.markers.sorted { $0.sourceSeconds < $1.sourceSeconds }
        guard markers.count >= 2 else { return nil }

        let speed = max(0.1, clipSpeed)
        let rawDeltas = zip(markers, markers.dropFirst()).compactMap { lhs, rhs -> Double? in
            let dt = (rhs.sourceSeconds - lhs.sourceSeconds) / speed
            return (dt >= 0.22 && dt <= 1.60) ? dt : nil
        }
        guard !rawDeltas.isEmpty else { return nil }

        let sorted = rawDeltas.sorted()
        let median = sorted[sorted.count / 2]
        let contiguous = rawDeltas.filter { $0 >= median * 0.72 && $0 <= median * 1.38 }
        let samples = contiguous.isEmpty ? rawDeltas : contiguous
        let avgPeriod = samples.reduce(0.0, +) / Double(samples.count)
        guard avgPeriod > 0.1 else { return nil }

        return max(40.0, min(240.0, (60.0 / avgPeriod).rounded()))
    }

    private struct Candidate {
        let clip: TimelineClip
        let bpm: Double?
        let hasBeatConfig: Bool
        let isAudioKind: Bool
        let overlapSeconds: Double
    }

    private static func overlappingCandidates(for targetRange: CMTimeRange, in layers: [TimelineLayer]) -> [Candidate] {
        let tStart = CMTimeGetSeconds(targetRange.start)
        let tEnd = CMTimeGetSeconds(targetRange.end)
        var collected: [Candidate] = []

        for layer in layers where (layer.kind == .audio || layer.kind == .video) && !layer.isMuted && !layer.isHidden {
            for clip in layer.clips {
                if let candidate = makeCandidate(clip: clip, kind: layer.kind, targetStart: tStart, targetEnd: tEnd) {
                    collected.append(candidate)
                }
            }
        }

        return collected.sorted { lhs, rhs in
            if lhs.isAudioKind != rhs.isAudioKind { return lhs.isAudioKind }
            if (lhs.bpm != nil) != (rhs.bpm != nil) { return lhs.bpm != nil }
            return lhs.overlapSeconds > rhs.overlapSeconds
        }
    }

    private static func makeCandidate(
        clip: TimelineClip,
        kind: ClipKind,
        targetStart: Double,
        targetEnd: Double
    ) -> Candidate? {
        if kind == .audio && (clip.properties["isBeatCounter"]?.asBool ?? false) { return nil }
        let volume = clip.properties["volume"]?.asNumber ?? 1.0
        guard volume > 0.001 else { return nil }

        let cStart = CMTimeGetSeconds(clip.timeRange.start)
        let cEnd = CMTimeGetSeconds(clip.timeRange.end)
        let overlap = min(targetEnd, cEnd) - max(targetStart, cStart)
        guard overlap > 0.02 else { return nil }

        let beatCfg = AudioBeatConfiguration.from(clip: clip)
        let speed = max(0.1, clip.properties["speed"]?.asNumber ?? 1.0)
        let bpm = beatCfg.flatMap { extractBPM(from: $0, clipSpeed: speed) }
        return Candidate(
            clip: clip,
            bpm: bpm,
            hasBeatConfig: beatCfg != nil,
            isAudioKind: kind == .audio,
            overlapSeconds: overlap
        )
    }
}
