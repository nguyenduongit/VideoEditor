import SwiftUI

/// Tuỳ chọn đường cong nội suy (Interpolation Curve) hiển thị trong menu ngữ cảnh của DSKeyframeControl.
public struct DSKeyframeCurveOption: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let iconName: String

    public init(id: String, title: String, iconName: String) {
        self.id = id
        self.title = title
        self.iconName = iconName
    }
}

/// Cụm nút điều khiển Keyframe `< ◆ >` chuẩn NLE chuyên nghiệp cho Inspector.
/// Thiết kế hình thoi góc vuông bo nhẹ (rotated square) khớp chuẩn 3 trạng thái:
/// - No active (chưa tại keyframe & không hover): viền hình thoi góc vuông rỗng.
/// - Hover (chưa tại keyframe & đang hover): hình thoi góc vuông tô nền xám đậm có dấu `+` ở giữa.
/// - Active (đang tại keyframe): hình thoi góc vuông tô đặc màu xanh cyan.
/// Tuân thủ quy tắc R3.1, R8.1 và R8.2 của AGENTS.md.
public struct DSKeyframeControl: View {
    private let hasKeyframesOnTrack: Bool
    private let isAtKeyframe: Bool
    private let canGoPrevious: Bool
    private let canGoNext: Bool
    private let selectedCurveID: String
    private let curveOptions: [DSKeyframeCurveOption]
    private let onToggleKeyframe: () -> Void
    private let onPreviousKeyframe: () -> Void
    private let onNextKeyframe: () -> Void
    private let onSelectCurve: ((String) -> Void)?
    private let onClearAllKeyframes: (() -> Void)?

    @State private var isHoveringDiamond = false
    @State private var isHoveringPrev = false
    @State private var isHoveringNext = false

    public static let cyanAccent = Color(red: 0.0, green: 0.78, blue: 0.85)

    public init(
        hasKeyframesOnTrack: Bool,
        isAtKeyframe: Bool,
        canGoPrevious: Bool = false,
        canGoNext: Bool = false,
        selectedCurveID: String = "smooth",
        curveOptions: [DSKeyframeCurveOption] = [],
        onToggleKeyframe: @escaping () -> Void,
        onPreviousKeyframe: @escaping () -> Void = {},
        onNextKeyframe: @escaping () -> Void = {},
        onSelectCurve: ((String) -> Void)? = nil,
        onClearAllKeyframes: (() -> Void)? = nil
    ) {
        self.hasKeyframesOnTrack = hasKeyframesOnTrack
        self.isAtKeyframe = isAtKeyframe
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.selectedCurveID = selectedCurveID
        self.curveOptions = curveOptions
        self.onToggleKeyframe = onToggleKeyframe
        self.onPreviousKeyframe = onPreviousKeyframe
        self.onNextKeyframe = onNextKeyframe
        self.onSelectCurve = onSelectCurve
        self.onClearAllKeyframes = onClearAllKeyframes
    }

    public var body: some View {
        HStack(spacing: 1.5) {
            navChevronButton(
                icon: "chevron.left",
                isEnabled: hasKeyframesOnTrack && canGoPrevious,
                isHovering: $isHoveringPrev,
                help: "Lùi 1 Keyframe",
                action: onPreviousKeyframe
            )

            diamondButton

            navChevronButton(
                icon: "chevron.right",
                isEnabled: hasKeyframesOnTrack && canGoNext,
                isHovering: $isHoveringNext,
                help: "Tới 1 Keyframe",
                action: onNextKeyframe
            )
        }
        .frame(height: 18)
        .fixedSize()
        .contextMenu {
            if hasKeyframesOnTrack {
                keyframeContextMenu
            }
        }
    }

    private var diamondButton: some View {
        Button(action: onToggleKeyframe) {
            squareDiamondIcon
                .frame(width: 14, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHoveringDiamond = $0 }
        .help(isAtKeyframe ? "Xoá Keyframe tại vị trí Playhead (Chuột phải để chọn đường cong)" : "Thêm Keyframe tại vị trí Playhead")
    }

    @ViewBuilder
    private var squareDiamondIcon: some View {
        let boxSize: CGFloat = 8.2
        let cornerRadius: CGFloat = 1.6
        if isAtKeyframe {
            // Trạng thái Active: Hình thoi góc vuông bo nhẹ tô đặc màu xanh cyan
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Self.cyanAccent)
                .frame(width: boxSize, height: boxSize)
                .rotationEffect(.degrees(45))
        } else if isHoveringDiamond {
            // Trạng thái Hover: Hình thoi góc vuông bo nhẹ nền xám đậm + dấu cộng trắng ở tâm
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(white: 0.34))
                    .frame(width: boxSize + 1.0, height: boxSize + 1.0)
                    .rotationEffect(.degrees(45))

                Path { path in
                    path.move(to: CGPoint(x: 7.0, y: 5.5))
                    path.addLine(to: CGPoint(x: 7.0, y: 10.5))
                    path.move(to: CGPoint(x: 4.5, y: 8.0))
                    path.addLine(to: CGPoint(x: 9.5, y: 8.0))
                }
                .stroke(Color(white: 0.88), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                .frame(width: 14, height: 16)
            }
        } else {
            // Trạng thái No Active: Viền hình thoi góc vuông rỗng (sáng hơn khi track đã có keyframe)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    hasKeyframesOnTrack ? Color(white: 0.80) : Color(white: 0.50),
                    lineWidth: 1.35
                )
                .frame(width: boxSize, height: boxSize)
                .rotationEffect(.degrees(45))
        }
    }

    private func navChevronButton(
        icon: String,
        isEnabled: Bool,
        isHovering: Binding<Bool>,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(
                    isEnabled
                        ? (isHovering.wrappedValue ? Color.white : Color(white: 0.68))
                        : Color(white: 0.30)
                )
                .frame(width: 9, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovering.wrappedValue = $0 }
        .help(help)
    }

    @ViewBuilder
    private var keyframeContextMenu: some View {
        if !curveOptions.isEmpty {
            Section("Đường cong nội suy (Interpolation)") {
                ForEach(curveOptions) { opt in
                    Button {
                        onSelectCurve?(opt.id)
                    } label: {
                        HStack {
                            Label(opt.title, systemImage: opt.iconName)
                            if opt.id == selectedCurveID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
        if let onClearAllKeyframes {
            Divider()
            Button(role: .destructive) {
                onClearAllKeyframes()
            } label: {
                Label("Xoá toàn bộ Keyframe của mục này", systemImage: "trash")
            }
        }
    }
}
