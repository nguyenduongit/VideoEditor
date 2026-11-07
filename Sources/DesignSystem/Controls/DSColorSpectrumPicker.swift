import SwiftUI
import AppKit

/// Component C1: Bảng chọn màu HSV/HSB chuyên sâu chuẩn video editor chuyên nghiệp.
/// Gồm khung 2D Saturation-Value, thanh Hue dọc quang phổ, bút hút màu (Eyedropper),
/// ô nhập HEX và hiển thị so sánh màu Trước / Sau.
/// Tuân thủ AGENTS.md R2.1 (100% Apple SDK) và R3.1 (File <= 300 dòng, View body <= 80 dòng).
public struct DSColorSpectrumPicker: View {
    public let initialHex: String
    public let onSelect: (String) -> Void

    @State private var hue: Double = 0.0
    @State private var saturation: Double = 1.0
    @State private var brightness: Double = 1.0
    @State private var hexInput: String = ""

    public init(initialHex: String, onSelect: @escaping (String) -> Void) {
        self.initialHex = initialHex
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: DSSpacing.sm) {
            spectrumAndHueArea
                .frame(width: 244, height: 180)

            bottomControlBar
                .frame(width: 244)
        }
        .padding(DSSpacing.sm)
        .background(DSColors.blockBackground)
        .onAppear {
            syncFromHex(initialHex)
        }
    }

    // MARK: - 2D Spectrum & Hue Bar Area

    private var spectrumAndHueArea: some View {
        HStack(spacing: DSSpacing.xs) {
            saturationBrightnessPad
            verticalHueBar
        }
    }

    private var saturationBrightnessPad: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                Color(hue: hue, saturation: 1.0, brightness: 1.0)

                LinearGradient(
                    colors: [.white, .white.opacity(0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    colors: [.black.opacity(0.0), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Vòng trỏ Reticle viền kép trắng/đen
                ZStack {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 13, height: 13)
                    Circle()
                        .stroke(Color.white, lineWidth: 1.5)
                        .frame(width: 11, height: 11)
                }
                .offset(
                    x: min(max(0.0, saturation * w - 6.5), w - 13),
                    y: min(max(0.0, (1.0 - brightness) * h - 6.5), h - 13)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(DSColors.blockBorder, lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let newSat = min(max(0.0, val.location.x / w), 1.0)
                        let newBri = min(max(0.0, 1.0 - (val.location.y / h)), 1.0)
                        saturation = newSat
                        brightness = newBri
                        notifyColorChanged()
                    }
            )
        }
    }

    private var verticalHueBar: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let barW = geo.size.width
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color(hue: 1.0, saturation: 1.0, brightness: 1.0),
                        Color(hue: 5.0 / 6.0, saturation: 1.0, brightness: 1.0),
                        Color(hue: 4.0 / 6.0, saturation: 1.0, brightness: 1.0),
                        Color(hue: 3.0 / 6.0, saturation: 1.0, brightness: 1.0),
                        Color(hue: 2.0 / 6.0, saturation: 1.0, brightness: 1.0),
                        Color(hue: 1.0 / 6.0, saturation: 1.0, brightness: 1.0),
                        Color(hue: 0.0, saturation: 1.0, brightness: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Vạch chỉ báo Hue ngang
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: barW + 2, height: 3)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.black, lineWidth: 0.8))
                    .offset(y: min(max(0.0, (1.0 - hue) * h - 1.5), h - 3))
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(DSColors.blockBorder, lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let newHue = min(max(0.0, 1.0 - (val.location.y / h)), 1.0)
                        hue = newHue
                        notifyColorChanged()
                    }
            )
        }
        .frame(width: 22)
    }

    // MARK: - Bottom Controls Bar

    private var bottomControlBar: some View {
        HStack(spacing: DSSpacing.xs) {
            eyedropperButton
            beforeAfterPreview
            hexInputField
        }
    }

    private var eyedropperButton: some View {
        Button(action: sampleScreenColor) {
            Image(systemName: "eyedropper.halffull")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)
                .frame(width: 24, height: 24)
                .background(DSColors.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(DSColors.blockBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("Sample color from screen")
    }

    private var beforeAfterPreview: some View {
        HStack(spacing: 0) {
            Button(action: { syncFromHex(initialHex); notifyColorChanged() }) {
                Rectangle()
                    .fill(Color(hex: initialHex))
                    .frame(width: 18, height: 24)
            }
            .buttonStyle(.plain)
            .help("Click to revert to original color")

            Rectangle()
                .fill(Color(hue: hue, saturation: saturation, brightness: brightness))
                .frame(width: 18, height: 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var hexInputField: some View {
        HStack(spacing: 2) {
            Text("#")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(DSColors.textSecondary)

            TextField("FFFFFF", text: $hexInput)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .textFieldStyle(.plain)
                .foregroundStyle(DSColors.textPrimary)
                .onSubmit { commitHexInput() }
        }
        .padding(.horizontal, 6)
        .frame(height: 24)
        .background(DSColors.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    // MARK: - Logic & Color Space Calculations

    private func notifyColorChanged() {
        let hex = currentHexColor()
        hexInput = String(hex.dropFirst())
        onSelect(hex)
    }

    private func currentHexColor() -> String {
        Self.hsbToHex(h: hue, s: saturation, b: brightness)
    }

    private func syncFromHex(_ hex: String) {
        let (h, s, b) = Self.hexToHSB(hex)
        hue = h
        saturation = s
        brightness = b
        let clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        hexInput = String(clean.prefix(6)).uppercased()
    }

    private func commitHexInput() {
        var clean = hexInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if clean.count == 3 {
            clean = clean.map { "\($0)\($0)" }.joined()
        }
        guard clean.count == 6 else { return }
        let validHex = "#" + clean.uppercased()
        syncFromHex(validHex)
        onSelect(validHex)
    }

    private func sampleScreenColor() {
        Task { @MainActor in
            guard let nsColor = await NSColorSampler().sample(),
                  let rgb = nsColor.usingColorSpace(NSColorSpace.sRGB) else { return }
            let r = Int(round(rgb.redComponent * 255))
            let g = Int(round(rgb.greenComponent * 255))
            let b = Int(round(rgb.blueComponent * 255))
            let hex = String(format: "#%02X%02X%02X", r, g, b)
            self.syncFromHex(hex)
            self.onSelect(hex)
        }
    }

    public static func hsbToHex(h: Double, s: Double, b: Double) -> String {
        let nsColor = NSColor(hue: CGFloat(h), saturation: CGFloat(s), brightness: CGFloat(b), alpha: 1.0)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let bl = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, bl)
    }

    public static func hexToHSB(_ hex: String) -> (h: Double, s: Double, b: Double) {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if clean.uppercased() == "NONE" || clean.isEmpty {
            return (0.0, 1.0, 1.0)
        }
        if clean.count == 3 {
            clean = clean.map { "\($0)\($0)" }.joined()
        }
        guard clean.count >= 6, let num = UInt64(clean.prefix(6), radix: 16) else {
            return (0.0, 1.0, 1.0)
        }
        let r = CGFloat((num & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((num & 0x00FF00) >> 8) / 255.0
        let bl = CGFloat(num & 0x0000FF) / 255.0
        let nsColor = NSColor(srgbRed: r, green: g, blue: bl, alpha: 1.0)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b))
    }
}
