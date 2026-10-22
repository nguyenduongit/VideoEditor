import Foundation
import CoreMedia
import AudioToolbox
import AVFoundation
import os
import Domain

public enum TimelineMediaDurationResolver: Sendable {
    private static let durationCache = LRUCache<URL, CMTime>(capacity: 256)

    public static func cachedDuration(for url: URL) -> CMTime? {
        durationCache.get(url)
    }

    public static func cacheDuration(_ duration: CMTime, for url: URL) {
        durationCache.set(duration, for: url)
    }

    public static func clearCache() {
        durationCache.removeAll()
    }

    public static func resolveDuration(for url: URL, type: MediaType) -> CMTime? {
        if let cached = cachedDuration(for: url) {
            return cached
        }

        if type == .audio, let headerDur = resolveAudioHeaderDuration(for: url) {
            cacheDuration(headerDur, for: url)
            return headerDur
        }

        // Trigger background async load to warm the cache without blocking the caller
        Task {
            _ = await resolveDurationAsync(for: url, type: type)
        }
        return nil
    }

    public static func resolveDurationAsync(for url: URL, type: MediaType) async -> CMTime? {
        if let cached = cachedDuration(for: url) {
            return cached
        }

        if type == .audio, let headerDur = resolveAudioHeaderDuration(for: url) {
            cacheDuration(headerDur, for: url)
            return headerDur
        }

        let avAsset = AVURLAsset(url: url)
        do {
            let dur = try await avAsset.load(.duration)
            if dur.seconds.isFinite, !dur.seconds.isNaN, dur.seconds > 0 {
                cacheDuration(dur, for: url)
                return dur
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func resolveAudioHeaderDuration(for url: URL) -> CMTime? {
        var audioFileID: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFileID) == noErr,
              let af = audioFileID else {
            return nil
        }
        var durSec: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        let status = AudioFileGetProperty(af, kAudioFilePropertyEstimatedDuration, &size, &durSec)
        AudioFileClose(af)
        guard status == noErr, durSec.isFinite, !durSec.isNaN, durSec > 0 else {
            return nil
        }
        return CMTime(seconds: durSec, preferredTimescale: TimeRational.defaultFPS)
    }
}

