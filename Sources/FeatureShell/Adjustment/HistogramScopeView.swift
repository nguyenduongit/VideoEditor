import SwiftUI
import CoreImage
import DesignSystem

/// View hiển thị biểu đồ Histogram thời gian thực (RGB & Luma) kèm cảnh báo clipping.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) và R8.1 của AGENTS.md.
public struct HistogramScopeView: View {
    private let histogramData: HistogramData
    @State private var scopeMode: ScopeMode = .combinedRGB

    private enum ScopeMode: String, CaseIterable {
        case combinedRGB = "RGB"
        case luma = "Luma"
    }

    private let scopeWidth: CGFloat = 260.0
    private let scopeHeight: CGFloat = 140.0

    public init(histogramData: HistogramData = .empty) {
        self.histogramData = histogramData
    }

    public var body: some View {
        VStack(spacing: DSSpacing.sm) {
            topBarRow
            graphArea
            bottomInfoRow
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var topBarRow: some View {
        HStack {
            Text("Biểu đồ Histogram")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)

            Spacer()

            Picker("", selection: $scopeMode) {
                ForEach(ScopeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
    }

    private var graphArea: some View {
        ZStack {
            gridLines

            if scopeMode == .combinedRGB {
                channelPath(bins: histogramData.redBins, color: Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.65))
                channelPath(bins: histogramData.greenBins, color: Color(red: 0.2, green: 0.9, blue: 0.3).opacity(0.65))
                channelPath(bins: histogramData.blueBins, color: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.65))
            } else {
                channelPath(bins: histogramData.lumaBins, color: Color.white.opacity(0.85))
            }
        }
        .frame(width: scopeWidth, height: scopeHeight)
        .background(Color.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private var gridLines: some View {
        GeometryReader { _ in
            Path { path in
                // Vạch chia 0%, 25%, 50%, 75%, 100%
                for i in 1..<4 {
                    let y = (scopeHeight / 4.0) * CGFloat(i)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: scopeWidth, y: y))
                }
                for i in 1..<4 {
                    let x = (scopeWidth / 4.0) * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: scopeHeight))
                }
            }
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private func channelPath(bins: [Float], color: Color) -> some View {
        GeometryReader { _ in
            Path { path in
                guard bins.count == 256 else { return }
                let stepX = scopeWidth / 255.0

                path.move(to: CGPoint(x: 0, y: scopeHeight))
                for i in 0..<256 {
                    let x = CGFloat(i) * stepX
                    let val = CGFloat(max(0.0, min(1.0, bins[i])))
                    let y = scopeHeight - (val * scopeHeight)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: scopeWidth, y: scopeHeight))
                path.closeSubpath()
            }
            .fill(color)
        }
    }

    private var bottomInfoRow: some View {
        HStack(spacing: DSSpacing.md) {
            if histogramData.hasShadowClipping {
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                    Text("Bết tối (<5)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.blue)
                }
            }

            if histogramData.hasHighlightClipping {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("Cháy sáng (>250)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.red)
                }
            }

            Spacer()

            Text("0 — 255 IRE")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DSColors.textSecondary)
        }
    }
}
