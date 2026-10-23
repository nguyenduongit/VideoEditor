import SwiftUI
import DesignSystem

/// Tiện ích phân tích mã màu Hex và hàng chọn màu nhanh (Quick Swatches) cho Text Inspector.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng) của AGENTS.md.
public extension Color {
    init(hex: String) {
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

/// Hàng nút tròn chọn bảng màu nhanh.
public struct TextColorSwatchesRow: View {
    public let title: String?
    public let selectedHex: String
    public let swatches: [String]
    public let onSelect: (String) -> Void

    public init(
        title: String? = nil,
        selectedHex: String,
        swatches: [String] = ["#FFFFFF", "#000000", "#FDE047", "#EF4444", "#3B82F6", "#22C55E", "#F97316", "#A855F7"],
        onSelect: @escaping (String) -> Void
    ) {
        self.title = title
        self.selectedHex = selectedHex
        self.swatches = swatches
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
                ForEach(swatches, id: \.self) { hex in
                    let isSelected = selectedHex.uppercased().hasPrefix(hex.uppercased())
                    Button(action: { onSelect(hex) }) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
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
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
