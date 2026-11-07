import Foundation
import CoreMedia

/// Lịch phát âm thanh đếm nhịp cho Dance Beat Counter trong vũ đạo (nhịp 8 mỗi vòng).
/// Tuân thủ AGENTS.md R2.3 (thuần Domain, chỉ import Foundation & CoreMedia) và R3.1 (File <= 300 dòng, Hàm <= 50 dòng).
public struct DanceBeatVoiceItem: Sendable, Equatable {
    public let time: CMTime
    public let voiceNumber: Int
    public let roundIndex: Int
    public let beatInRound: Int

    public init(time: CMTime, voiceNumber: Int, roundIndex: Int, beatInRound: Int) {
        self.time = time
        self.voiceNumber = voiceNumber
        self.roundIndex = roundIndex
        self.beatInRound = beatInRound
    }
}

public enum DanceBeatCounterSchedule {
    /// Tính toán danh sách các tiếng đếm tương ứng với các beat nằm trong phạm vi thời lượng của clip.
    /// Mỗi khối clip luôn bắt đầu độc lập từ vòng 1 (`1 2 3 4 5 6 7 8`, `2 2 3 4 5 6 7 8`...).
    public static func schedule(
        beatTimes: [CMTime],
        within clipRange: CMTimeRange
    ) -> [DanceBeatVoiceItem] {
        guard clipRange.duration > .zero else { return [] }
        let start = clipRange.start
        let end = clipRange.end

        let insideBeats = beatTimes
            .filter { $0 >= start && $0 < end }
            .sorted { CMTimeCompare($0, $1) < 0 }

        var result: [DanceBeatVoiceItem] = []
        result.reserveCapacity(insideBeats.count)

        for (index, beatTime) in insideBeats.enumerated() {
            let beatInRound = (index % 8) + 1 // 1..8
            let roundIndex = 1 + (index / 8)  // 1, 2, 3...
            let voiceNumber: Int
            if beatInRound == 1 {
                voiceNumber = min(99, max(1, roundIndex))
            } else {
                voiceNumber = beatInRound
            }

            result.append(
                DanceBeatVoiceItem(
                    time: beatTime,
                    voiceNumber: voiceNumber,
                    roundIndex: roundIndex,
                    beatInRound: beatInRound
                )
            )
        }

        return result
    }
}

