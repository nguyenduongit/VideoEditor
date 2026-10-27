import SwiftUI
import Domain
import DesignSystem

/// Thanh hiển thị trực quan phân bổ thời lượng [In | Loop/Combo | Out] và chọn hướng Stagger / Tâm xoay.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng, View body <= 80 dòng).
public struct TextAnimationTimelineBarView: View {
    public let config: TextConfiguration
    public let onCommit: (TextConfiguration) -> Void

    public init(
        config: TextConfiguration,
        onCommit: @escaping (TextConfiguration) -> Void
    ) {
        self.config = config
        self.onCommit = onCommit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            durationVisualBar
            if config.animation.scope != .wholeBlock {
                staggerDirectionRow
            }
            anchorPointRow
        }
        .padding(DSSpacing.xs)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .stroke(DSColors.blockBorder, lineWidth: 0.8)
        )
    }

    // MARK: - Visual Duration Bar

    private var durationVisualBar: some View {
        let referenceTotal = 3.0
        let inRatio = config.animation.inType == .none ? 0.0 : min(0.48, config.animation.inDuration / referenceTotal)
        let outRatio = config.animation.outType == .none ? 0.0 : min(0.48, config.animation.outDuration / referenceTotal)
        let midRatio = max(0.04, 1.0 - inRatio - outRatio)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(String(localized: "Tiến trình hoạt ảnh"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Text(summaryLabel)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DSColors.toggleCyan)
                if hasAnyActiveAnimation {
                    Button {
                        clearAllAnimations()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(DSColors.textSecondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Bỏ toàn bộ hoạt ảnh Text"))
                }
            }

            GeometryReader { geo in
                let totalW = max(10.0, geo.size.width)
                HStack(spacing: 2) {
                    if inRatio > 0.01 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DSColors.toggleCyan.opacity(0.75))
                            .frame(width: totalW * CGFloat(inRatio))
                    }
                    RoundedRectangle(cornerRadius: 3)
                        .fill(hasLoop ? DSColors.clipText.opacity(0.65) : DSColors.controlTrack)
                        .frame(width: max(8.0, totalW * CGFloat(midRatio)))
                    if outRatio > 0.01 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DSColors.trafficMinimize.opacity(0.75))
                            .frame(width: totalW * CGFloat(outRatio))
                    }
                }
            }
            .frame(height: 8)
        }
    }

    private var hasLoop: Bool {
        config.animation.loopType != .none
    }

    private var hasAnyActiveAnimation: Bool {
        config.animation.inType != .none
            || config.animation.outType != .none
            || config.animation.loopType != .none
    }

    private func clearAllAnimations() {
        var updated = config
        updated.animation.inType = .none
        updated.animation.outType = .none
        updated.animation.loopType = .none
        onCommit(updated)
    }

    private var summaryLabel: String {
        var parts: [String] = []
        if config.animation.inType != .none {
            parts.append(String(format: "In %.1fs", config.animation.inDuration))
        }
        if config.animation.loopType != .none {
            parts.append(String(format: "Loop %.1fx", config.animation.loopSpeed))
        }
        if config.animation.outType != .none {
            parts.append(String(format: "Out %.1fs", config.animation.outDuration))
        }
        let defaultLabel = String(localized: "Mặc định")
        return parts.isEmpty ? defaultLabel : parts.joined(separator: " • ")
    }

    // MARK: - Stagger Direction & Anchor Point

    private var staggerDirectionRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Thứ tự xuất hiện"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(TextStaggerDirection.allCases) { dir in
                        let selected = config.animation.staggerDirection == dir
                        Button {
                            var updated = config
                            updated.animation.staggerDirection = dir
                            onCommit(updated)
                        } label: {
                            Text(dir.title)
                                .font(.system(size: 9, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? DSColors.textPrimary : DSColors.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(selected ? DSColors.activeTabBackground : DSColors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DSRadius.small)
                                        .stroke(selected ? DSColors.toggleCyan.opacity(0.7) : Color.clear, lineWidth: 0.8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var anchorPointRow: some View {
        HStack(spacing: DSSpacing.xs) {
            Text(String(localized: "Tâm biến đổi"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
            HStack(spacing: 4) {
                ForEach(TextAnchorPoint.allCases) { anchor in
                    let selected = config.animation.anchorPoint == anchor
                    Button {
                        var updated = config
                        updated.animation.anchorPoint = anchor
                        onCommit(updated)
                    } label: {
                        Text(anchor.title)
                            .font(.system(size: 9, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? DSColors.textPrimary : DSColors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(selected ? DSColors.activeTabBackground : DSColors.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
