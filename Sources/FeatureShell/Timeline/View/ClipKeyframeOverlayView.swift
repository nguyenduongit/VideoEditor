import SwiftUI
import CoreMedia
import Domain
import DesignSystem

/// Lớp phủ hiển thị các hạt kim cương (Keyframe Diamond Markers `◆`) dọc theo dải Clip trên Timeline.
/// Cho phép người dùng nhìn rõ vị trí mọi Keyframe và click trực tiếp vào hạt kim cương để nhảy Playhead tới đúng mốc đó.
/// Tuân thủ quy tắc R3.1 của AGENTS.md.
public struct ClipKeyframeOverlayView: View {
    private let keyframeMap: ClipKeyframeMap
    private let clipStart: CMTime
    private let pixelsPerSecond: CGFloat
    private let onSeek: ((CMTime) -> Void)?

    public init(
        keyframeMap: ClipKeyframeMap,
        clipStart: CMTime,
        pixelsPerSecond: CGFloat,
        onSeek: ((CMTime) -> Void)? = nil
    ) {
        self.keyframeMap = keyframeMap
        self.clipStart = clipStart
        self.pixelsPerSecond = max(1.0, pixelsPerSecond)
        self.onSeek = onSeek
    }

    public var body: some View {
        let offsets = keyframeMap.allKeyframeTimeOffsets()
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Đường nối mảnh giữa các mốc Keyframe đầu và cuối
                if let firstSec = offsets.first, let lastSec = offsets.last, offsets.count >= 2 {
                    let x0 = max(4.0, min(geo.size.width - 4.0, CGFloat(firstSec) * pixelsPerSecond))
                    let x1 = max(4.0, min(geo.size.width - 4.0, CGFloat(lastSec) * pixelsPerSecond))
                    if x1 > x0 {
                        Path { path in
                            let y = geo.size.height - 5.5
                            path.move(to: CGPoint(x: x0, y: y))
                            path.addLine(to: CGPoint(x: x1, y: y))
                        }
                        .stroke(DSKeyframeControl.cyanAccent.opacity(0.65), lineWidth: 1.0)
                        .allowsHitTesting(false)
                    }
                }

                ForEach(Array(offsets.enumerated()), id: \.offset) { _, localSec in
                    let x = CGFloat(localSec) * pixelsPerSecond
                    if x >= 3.0 && x <= geo.size.width - 3.0 {
                        diamondPin(atX: x, clipHeight: geo.size.height, localSeconds: localSec)
                    }
                }
            }
        }
    }

    private func diamondPin(atX x: CGFloat, clipHeight: CGFloat, localSeconds: Double) -> some View {
        Button {
            let targetTime = CMTimeAdd(
                clipStart,
                CMTime(seconds: localSeconds, preferredTimescale: 600)
            )
            onSeek?(targetTime)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                    .fill(DSKeyframeControl.cyanAccent)
                    .frame(width: 6.2, height: 6.2)
                    .rotationEffect(.degrees(45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                            .stroke(Color.black.opacity(0.65), lineWidth: 0.7)
                            .frame(width: 6.2, height: 6.2)
                            .rotationEffect(.degrees(45))
                    )
            }
            .frame(width: 11, height: 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(x: x, y: max(6.0, clipHeight - 5.5))
        .help(String(format: "Keyframe @ %.2fs", localSeconds))
    }
}

