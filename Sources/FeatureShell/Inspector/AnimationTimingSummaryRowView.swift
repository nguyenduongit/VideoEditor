import SwiftUI
import Domain
import DesignSystem

/// Shared monospace timing breakdown footer (`In • Loop (N× / Bar) • Out | Clip: Xs`) for Text & Sticker Animations.
public struct AnimationTimingSummaryRowView: View {
    public let phases: ResolvedAnimationPhases

    public init(phases: ResolvedAnimationPhases) {
        self.phases = phases
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Text("In: \(fmt(phases.inDuration))s")
            Text("•")
            Text(loopLabel)
            Text("•")
            Text("Out: \(fmt(phases.outDuration))s")
            Spacer(minLength: 4)
            Text("Clip: \(fmt(phases.totalDuration))s")
                .fontWeight(.semibold)
                .foregroundStyle(DSColors.toggleCyan)
        }
        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
        .foregroundStyle(DSColors.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private var loopLabel: String {
        if let badge = phases.cycleLabel {
            return "Loop: \(fmt(phases.loopDuration))s (\(badge))"
        }
        return "Loop: \(fmt(phases.loopDuration))s"
    }

    private func fmt(_ seconds: Double) -> String {
        String(format: "%.2f", seconds).replacingOccurrences(of: #"0$"#, with: "", options: .regularExpression)
    }
}
