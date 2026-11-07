import Testing
import Foundation
@preconcurrency import AVFoundation
import CoreMedia
@testable import Domain
@testable import FeatureShell

@Suite("Dance Beat Counter Tests")
struct DanceBeatCounterTests {

    @Test("DanceBeatCounterSchedule sinh chính xác chuỗi nhịp 8 chuẩn vũ đạo (1..8, 2 2..8, 3 2..8...)")
    func testScheduleGeneration() {
        // Tạo 20 mốc beat cách nhau 0.5s (tương đương 120 BPM)
        var beats: [CMTime] = []
        for i in 0..<20 {
            beats.append(CMTime(seconds: Double(i) * 0.5, preferredTimescale: 600))
        }

        // Clip kéo dài từ 0.0s đến 10.0s
        let clipRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 10.0, preferredTimescale: 600))
        let items = DanceBeatCounterSchedule.schedule(beatTimes: beats, within: clipRange)

        #expect(items.count == 20)

        // Vòng 1: 1, 2, 3, 4, 5, 6, 7, 8
        #expect(items[0].voiceNumber == 1 && items[0].beatInRound == 1 && items[0].roundIndex == 1)
        #expect(items[1].voiceNumber == 2 && items[1].beatInRound == 2 && items[1].roundIndex == 1)
        #expect(items[2].voiceNumber == 3 && items[2].beatInRound == 3 && items[2].roundIndex == 1)
        #expect(items[7].voiceNumber == 8 && items[7].beatInRound == 8 && items[7].roundIndex == 1)

        // Vòng 2: 2 (Hai), 2, 3, 4, 5, 6, 7, 8
        #expect(items[8].voiceNumber == 2 && items[8].beatInRound == 1 && items[8].roundIndex == 2)
        #expect(items[9].voiceNumber == 2 && items[9].beatInRound == 2 && items[9].roundIndex == 2)
        #expect(items[10].voiceNumber == 3 && items[10].beatInRound == 3 && items[10].roundIndex == 2)
        #expect(items[15].voiceNumber == 8 && items[15].beatInRound == 8 && items[15].roundIndex == 2)

        // Vòng 3: 3 (Ba), 2, 3, 4
        #expect(items[16].voiceNumber == 3 && items[16].beatInRound == 1 && items[16].roundIndex == 3)
        #expect(items[17].voiceNumber == 2 && items[17].beatInRound == 2 && items[17].roundIndex == 3)
        #expect(items[18].voiceNumber == 3 && items[18].beatInRound == 3 && items[18].roundIndex == 3)
        #expect(items[19].voiceNumber == 4 && items[19].beatInRound == 4 && items[19].roundIndex == 3)
    }

    @Test("DanceBeatCounterSchedule lọc chính xác các beat nằm ngoài clipRange")
    func testScheduleFilteringOutsideBeats() {
        let beats = [
            CMTime(seconds: 1.0, preferredTimescale: 600),
            CMTime(seconds: 2.0, preferredTimescale: 600),
            CMTime(seconds: 3.0, preferredTimescale: 600),
            CMTime(seconds: 4.0, preferredTimescale: 600),
            CMTime(seconds: 5.0, preferredTimescale: 600)
        ]
        // Clip chỉ bao trùm từ 2.0s đến 4.0s
        let clipRange = CMTimeRange(start: CMTime(seconds: 2.0, preferredTimescale: 600), duration: CMTime(seconds: 2.0, preferredTimescale: 600))
        let items = DanceBeatCounterSchedule.schedule(beatTimes: beats, within: clipRange)

        #expect(items.count == 2)
        #expect(items[0].time.seconds == 2.0)
        #expect(items[0].voiceNumber == 1) // Luôn bắt đầu từ 1
        #expect(items[1].time.seconds == 3.0)
        #expect(items[1].voiceNumber == 2)
    }

    @Test("VoiceAssetCache tìm và nạp thành công các file wav từ Sources/Voice")
    func testVoiceAssetCacheLoading() {
        let cache = VoiceAssetCache.shared
        // Kiểm tra nạp file 1 đến 8
        for i in 1...8 {
            let url = cache.voiceURL(for: i)
            #expect(url != nil, "File number_\(i).wav phải tồn tại trong Sources/Voice")
            let asset = cache.voiceAsset(for: i)
            #expect(asset != nil, "VoiceAssetCache phải tạo được AVURLAsset cho số \(i)")
        }

        // Kiểm tra file số lớn
        #expect(cache.voiceURL(for: 10) != nil)
        #expect(cache.voiceURL(for: 99) != nil)
    }

    @Test("TimelineViewModel nhận diện canAddDanceBeatCounter khi có track audio chính")
    @MainActor
    func testCanAddDanceBeatCounter() {
        let vm = TimelineViewModel(initialLayers: [])
        #expect(vm.canAddDanceBeatCounter == false, "Timeline trống thì chưa thể thêm Dance Beat Counter")

        // Thêm một layer audio có clip nhạc chính
        let dummyURL = URL(fileURLWithPath: "/dummy/audio.mp3")
        let mainAudioClip = TimelineClip(
            name: "Main Music",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 30.0, preferredTimescale: 600)),
            mediaURL: dummyURL
        )
        let audioLayer = TimelineLayer(id: UUID(), name: "Audio 1", kind: .audio, clips: [mainAudioClip])
        vm.layers = [audioLayer]

        #expect(vm.canAddDanceBeatCounter == true, "Có track audio thì cho phép thêm Dance Beat Counter")
    }

    @Test("TimelineViewModel.addDanceBeatCounter tạo clip có isBeatCounter = true và snap vào beat")
    @MainActor
    func testAddDanceBeatCounterClip() {
        let dummyURL = URL(fileURLWithPath: "/dummy/audio.mp3")
        let beat1 = AudioBeatMarker(sourceTime: CMTime(seconds: 1.0, preferredTimescale: 600), kind: .major)
        let beat2 = AudioBeatMarker(sourceTime: CMTime(seconds: 2.0, preferredTimescale: 600), kind: .major)
        let beatConfig = AudioBeatConfiguration(mode: .majorOnly, markers: [beat1, beat2])

        var props: [String: PropertyValue] = [:]
        props[AudioBeatConfiguration.propertyKey] = .string(beatConfig.encodeToJSON() ?? "")

        let mainAudioClip = TimelineClip(
            name: "Main Music",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10.0, preferredTimescale: 600)),
            mediaURL: dummyURL,
            properties: props
        )
        let audioLayer = TimelineLayer(id: UUID(), name: "Audio 1", kind: .audio, clips: [mainAudioClip])
        let vm = TimelineViewModel(initialLayers: [audioLayer])

        // Đặt playhead gần 0.95s -> snap trúng beat 1.0s
        vm.currentTime = CMTime(seconds: 0.95, preferredTimescale: 600)
        let counterClip = vm.addDanceBeatCounter()

        #expect(counterClip != nil)
        #expect(counterClip?.properties["isBeatCounter"]?.asBool == true)
        #expect(abs(counterClip!.timeRange.start.seconds - 1.0) < 0.05, "Điểm bắt đầu phải snap trúng beat 1.0s")
    }

    @Test("TimelineViewModel.timelineBeatTimes và DanceBeatCounterSchedule không bị ảnh hưởng khi playhead di chuyển")
    @MainActor
    func testTimelineBeatTimesInvariantToPlayhead() {
        let dummyURL = URL(fileURLWithPath: "/dummy/audio.mp3")
        let markers = (0..<10).map { i in
            AudioBeatMarker(sourceTime: CMTime(seconds: Double(i), preferredTimescale: 600), kind: .major)
        }
        let beatConfig = AudioBeatConfiguration(mode: .majorOnly, markers: markers)
        var props: [String: PropertyValue] = [:]
        props[AudioBeatConfiguration.propertyKey] = .string(beatConfig.encodeToJSON() ?? "")

        let mainAudioClip = TimelineClip(
            name: "Main Music",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 10.0, preferredTimescale: 600)),
            mediaURL: dummyURL,
            properties: props
        )
        let audioLayer = TimelineLayer(id: UUID(), name: "Audio 1", kind: .audio, clips: [mainAudioClip])
        let vm = TimelineViewModel(initialLayers: [audioLayer])

        let clipRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 10.0, preferredTimescale: 600))

        // Khi playhead ở 0.0s
        vm.currentTime = .zero
        let beatsAtZero = vm.timelineBeatTimes
        let scheduleAtZero = DanceBeatCounterSchedule.schedule(beatTimes: beatsAtZero, within: clipRange)

        // Khi playhead di chuyển tới 2.5s (ở giữa clip)
        vm.currentTime = CMTime(seconds: 2.5, preferredTimescale: 600)
        let beatsAtMid = vm.timelineBeatTimes
        let scheduleAtMid = DanceBeatCounterSchedule.schedule(beatTimes: beatsAtMid, within: clipRange)

        #expect(beatsAtZero == beatsAtMid, "Mốc beat thực tế không được phép thay đổi theo playhead")
        #expect(scheduleAtZero == scheduleAtMid, "Chuỗi số đếm hiển thị trên UI phải cố định, không nhảy số khi playhead chạy")
    }
}

