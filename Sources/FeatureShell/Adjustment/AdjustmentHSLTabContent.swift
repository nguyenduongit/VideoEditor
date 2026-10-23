import SwiftUI
import Domain
import DesignSystem
#if os(macOS)
import AppKit
#endif

/// Tab HSL cho đối tượng Adjustment Layer với 8 dải màu và công cụ Eyedropper.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct AdjustmentHSLTabContent: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var selectedChannelIndex: Int = 1 // Mặc định: Orange (như ảnh mẫu)

    private struct ColorInfo {
        let name: String
        let color: Color
        let centerDegrees: Double
        let baseHue: Double
    }

    private let channels: [ColorInfo] = [
        ColorInfo(name: "Red", color: Color(red: 0.95, green: 0.26, blue: 0.21), centerDegrees: 0, baseHue: 0.0),
        ColorInfo(name: "Orange", color: Color(red: 1.0, green: 0.58, blue: 0.0), centerDegrees: 30, baseHue: 0.0833),
        ColorInfo(name: "Yellow", color: Color(red: 1.0, green: 0.84, blue: 0.04), centerDegrees: 60, baseHue: 0.1667),
        ColorInfo(name: "Green", color: Color(red: 0.29, green: 0.78, blue: 0.35), centerDegrees: 120, baseHue: 0.3333),
        ColorInfo(name: "Cyan", color: Color(red: 0.2, green: 0.68, blue: 0.9), centerDegrees: 180, baseHue: 0.5),
        ColorInfo(name: "Blue", color: Color(red: 0.0, green: 0.48, blue: 1.0), centerDegrees: 240, baseHue: 0.6667),
        ColorInfo(name: "Purple", color: Color(red: 0.69, green: 0.32, blue: 0.87), centerDegrees: 285, baseHue: 0.7917),
        ColorInfo(name: "Magenta", color: Color(red: 1.0, green: 0.18, blue: 0.53), centerDegrees: 325, baseHue: 0.9028)
    ]

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            colorSelectorRow
            slidersSection
        }
        .padding(.vertical, DSSpacing.sm)
    }

    private var colorSelectorRow: some View {
        HStack(spacing: DSSpacing.sm) {
            eyedropperButton
            ForEach(0..<channels.count, id: \.self) { idx in
                colorCircleButton(index: idx)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eyedropperButton: some View {
        Button(action: pickScreenColor) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "eyedropper.halffull")
                    .font(.system(size: 13))
                    .foregroundStyle(DSColors.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .help("Chọn màu trực tiếp trên màn hình")
    }

    private func colorCircleButton(index: Int) -> some View {
        let isSelected = selectedChannelIndex == index
        let info = channels[index]

        return Button(action: {
            selectedChannelIndex = index
        }) {
            ZStack {
                if isSelected {
                    Circle()
                        .stroke(info.color, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
                Circle()
                    .fill(info.color)
                    .frame(width: isSelected ? 18 : 20, height: isSelected ? 18 : 20)
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    private var slidersSection: some View {
        let config = currentConfig
        let channel = config.hsl[selectedChannelIndex]
        let baseHue = channels[selectedChannelIndex].baseHue

        return VStack(spacing: DSSpacing.md) {
            DSGradientSlider(
                title: "Hue",
                value: Binding(
                    get: { Double(channel.hue) },
                    set: { updateChannel(hue: Float($0)) }
                ),
                gradient: hueGradient(baseHue: baseHue),
                onEditingChanged: { editing in if !editing { commitConfig() } }
            )

            DSGradientSlider(
                title: "Saturation",
                value: Binding(
                    get: { Double(channel.saturation) },
                    set: { updateChannel(saturation: Float($0)) }
                ),
                gradient: saturationGradient(baseHue: baseHue),
                onEditingChanged: { editing in if !editing { commitConfig() } }
            )

            DSGradientSlider(
                title: "Brightness",
                value: Binding(
                    get: { Double(channel.luminance) },
                    set: { updateChannel(luminance: Float($0)) }
                ),
                gradient: brightnessGradient(baseHue: baseHue),
                onEditingChanged: { editing in if !editing { commitConfig() } }
            )
        }
    }

    // MARK: - Gradient Generators

    private func hueGradient(baseHue: Double) -> LinearGradient {
        let leftHue = (baseHue - 0.08 + 1.0).truncatingRemainder(dividingBy: 1.0)
        let midHue = baseHue
        let rightHue = (baseHue + 0.08).truncatingRemainder(dividingBy: 1.0)
        return LinearGradient(
            colors: [
                Color(hue: leftHue, saturation: 0.9, brightness: 0.9),
                Color(hue: midHue, saturation: 0.9, brightness: 0.9),
                Color(hue: rightHue, saturation: 0.9, brightness: 0.9)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func saturationGradient(baseHue: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: baseHue, saturation: 0.15, brightness: 0.55),
                Color(hue: baseHue, saturation: 0.65, brightness: 0.85),
                Color(hue: baseHue, saturation: 1.0, brightness: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func brightnessGradient(baseHue: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: baseHue, saturation: 0.85, brightness: 0.15),
                Color(hue: baseHue, saturation: 0.8, brightness: 0.7),
                Color(hue: baseHue, saturation: 0.2, brightness: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Config Manipulation & State

    private var currentConfig: AdjustmentConfiguration {
        let str = viewModel.liveProperties["adjustmentConfig"]?.asString
            ?? viewModel.selectedClip?.properties["adjustmentConfig"]?.asString ?? ""
        return AdjustmentConfiguration.decode(from: str) ?? AdjustmentConfiguration()
    }

    private func updateChannel(hue: Float? = nil, saturation: Float? = nil, luminance: Float? = nil) {
        var cfg = currentConfig
        var ch = cfg.hsl[selectedChannelIndex]
        if let hue { ch.hue = hue }
        if let saturation { ch.saturation = saturation }
        if let luminance { ch.luminance = luminance }
        cfg.hsl[selectedChannelIndex] = ch
        if let json = cfg.encodeToJSON() {
            viewModel.updateLiveText(key: "adjustmentConfig", text: json)
        }
    }

    private func commitConfig() {
        if let json = currentConfig.encodeToJSON() {
            viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
        }
    }

    private func pickScreenColor() {
        #if os(macOS)
        NSColorSampler().show { color in
            guard let color else { return }
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.usingColorSpace(.sRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            let deg = Double(h * 360.0)
            var bestIdx = 0
            var minDiff = 360.0
            for (idx, ch) in channels.enumerated() {
                var d = abs(deg - ch.centerDegrees)
                if d > 180 { d = 360 - d }
                if d < minDiff {
                    minDiff = d
                    bestIdx = idx
                }
            }
            Task { @MainActor in
                self.selectedChannelIndex = bestIdx
            }
        }
        #endif
    }
}
