import SwiftUI
import AppKit
import DesignSystem

/// Tiện ích phân tích mã màu Hex và hàng chọn màu nhanh (Quick Swatches) cho Text Inspector.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public extension Color {
    init(hex: String) {
        if hex.uppercased() == "NONE" {
            self = .clear
            return
        }
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if clean.count == 6 {
            clean.append("FF")
        }
        guard clean.count == 8, let num = UInt64(clean, radix: 16) else {
            self = .white
            return
        }
        let r = Double((num & 0xFF000000) >> 24) / 255.0
        let g = Double((num & 0x00FF0000) >> 16) / 255.0
        let b = Double((num & 0x0000FF00) >> 8) / 255.0
        let a = Double(num & 0x000000FF) / 255.0
        self = Color(red: r, green: g, blue: b, opacity: a)
    }
}

/// Bộ điều phối mở NSColorPanel trên macOS để chọn màu chi tiết và hỗ trợ eyedropper.
@MainActor
public final class DSColorPickerPresenter: NSObject {
    public static let shared = DSColorPickerPresenter()
    private var onSelect: ((String) -> Void)?

    public func show(currentHex: String, onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
        let panel = NSColorPanel.shared
        panel.color = NSColor(Color(hex: currentHex))
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.isContinuous = true
        panel.showsAlpha = false

        positionPanelNearMouse(panel)
        panel.orderFront(nil)
        positionPanelNearMouse(panel)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func positionPanelNearMouse(_ panel: NSColorPanel) {
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen else { return }
        let visible = screen.visibleFrame
        let panelWidth = panel.frame.width > 50 ? panel.frame.width : 224
        let panelHeight = panel.frame.height > 50 ? panel.frame.height : 360

        // Ưu tiên hiển thị ngay bên trái con trỏ chuột (ngang tầm với Inspector bên phải)
        var targetX = mouseLoc.x - panelWidth - 24
        if targetX < visible.minX + 16 {
            // Nếu mép trái màn hình không đủ chỗ thì đặt sang bên phải con trỏ
            targetX = mouseLoc.x + 24
        }

        // Đỉnh của panel nằm gần vị trí chuột, hơi chếch lên trên để con trỏ chuột ngang tầm bảng điều khiển
        let targetY = mouseLoc.y + 60

        let maxX = visible.maxX - panelWidth - 16
        let minX = visible.minX + 16
        let clampedX = minX <= maxX ? max(minX, min(maxX, targetX)) : minX

        let maxY = visible.maxY - 16
        let minY = visible.minY + panelHeight + 16
        let clampedY = minY <= maxY ? max(minY, min(maxY, targetY)) : maxY

        panel.setFrameTopLeftPoint(NSPoint(x: clampedX, y: clampedY))
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        guard let rgb = sender.color.usingColorSpace(.sRGB) else { return }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        let hex = String(format: "#%02X%02X%02X", r, g, b)
        onSelect?(hex)
    }
}

/// Hàng nút tròn chọn bảng màu nhanh kèm nút mở bảng màu tùy chỉnh.
public struct TextColorSwatchesRow: View {
    public static let defaultSwatches: [String] = [
        "#FFFFFF", "#000000", "#EF4444", "#F97316",
        "#FDE047", "#22C55E", "#06B6D4", "#3B82F6", "#A855F7"
    ]

    public let title: String?
    public let selectedHex: String
    public let swatches: [String]
    public let allowNone: Bool
    public let showCustomPicker: Bool
    public let onSelect: (String) -> Void

    public init(
        title: String? = nil,
        selectedHex: String,
        swatches: [String] = TextColorSwatchesRow.defaultSwatches,
        allowNone: Bool = false,
        showCustomPicker: Bool = true,
        onSelect: @escaping (String) -> Void
    ) {
        self.title = title
        self.selectedHex = selectedHex
        self.swatches = swatches
        self.allowNone = allowNone
        self.showCustomPicker = showCustomPicker
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }

            HStack(spacing: DSSpacing.sm) {
                if allowNone {
                    noneColorButton
                }

                ForEach(swatches, id: \.self) { hex in
                    let isSelected = Self.isColorMatching(swatchHex: hex, selectedHex: selectedHex)
                    Button(action: { onSelect(hex) }) {
                        swatchCircle(color: Color(hex: hex), isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }

                if showCustomPicker {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 1)

                    customColorButton
                }
            }
        }
    }

    private var isNoneSelected: Bool {
        selectedHex.uppercased() == "NONE" || selectedHex.isEmpty
    }

    private var noneColorButton: some View {
        Button(action: { onSelect("NONE") }) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                Path { path in
                    path.move(to: CGPoint(x: 4, y: 14))
                    path.addLine(to: CGPoint(x: 14, y: 4))
                }
                .stroke(Color.red, lineWidth: 1.8)
                .frame(width: 18, height: 18)

                if isNoneSelected {
                    Circle()
                        .stroke(DSColors.accent, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help("Không màu / Tắt hiệu ứng (None)")
    }

    @ViewBuilder
    private func swatchCircle(color: Color, isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
            if isSelected {
                Circle()
                    .stroke(DSColors.accent, lineWidth: 2)
                    .frame(width: 24, height: 24)
            }
        }
        .frame(width: 24, height: 24)
    }

    private var isCustomSelected: Bool {
        guard !isNoneSelected else { return false }
        return !swatches.contains { Self.isColorMatching(swatchHex: $0, selectedHex: selectedHex) }
    }

    private var customColorButton: some View {
        Button(action: {
            let initialHex = isNoneSelected ? "#FFFFFF" : selectedHex
            DSColorPickerPresenter.shared.show(currentHex: initialHex, onSelect: onSelect)
        }) {
            ZStack {
                if isCustomSelected {
                    Circle()
                        .fill(Color(hex: selectedHex))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    Circle()
                        .stroke(DSColors.accent, lineWidth: 2)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red]),
                                center: .center
                            )
                        )
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help("Chọn màu tùy chỉnh")
    }

    public static func cleanHex(_ hex: String) -> String {
        let stripped = hex.trimmingCharacters(in: .whitespacesAndNewlines)
                          .replacingOccurrences(of: "#", with: "")
        return String(stripped.prefix(6)).uppercased()
    }

    public static func isColorMatching(swatchHex: String, selectedHex: String) -> Bool {
        if selectedHex.uppercased() == "NONE" || swatchHex.uppercased() == "NONE" {
            return false
        }
        let cleanSwatch = cleanHex(swatchHex)
        let cleanSelected = cleanHex(selectedHex)
        guard !cleanSwatch.isEmpty && !cleanSelected.isEmpty else { return false }
        if cleanSwatch == cleanSelected { return true }

        // Đồng bộ các biến thể màu legacy từ preset sang swatch tương ứng
        if cleanSwatch == "FDE047" && (cleanSelected == "FFF566" || cleanSelected == "FFEA00" || cleanSelected == "FFE600") {
            return true
        }
        if cleanSwatch == "F97316" && (cleanSelected == "FF7A45" || cleanSelected == "FF7700") {
            return true
        }
        if cleanSwatch == "06B6D4" && (cleanSelected == "36CFC9" || cleanSelected == "08979C") {
            return true
        }
        if cleanSwatch == "EF4444" && cleanSelected == "CF1322" {
            return true
        }
        return false
    }
}
