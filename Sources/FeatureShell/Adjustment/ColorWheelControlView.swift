import SwiftUI
import Domain
import DesignSystem

/// Linh kiện bánh xe màu tương tác quang phổ HSL kèm thanh gạt Master Luma.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) và R8.1 của AGENTS.md.
public struct ColorWheelControlView: View {
    private let title: String
    @Binding private var offset: ColorWheelOffset
    private let onEditingChanged: ((Bool) -> Void)?

    private let wheelDiameter: CGFloat = 140.0
    private var wheelRadius: CGFloat { wheelDiameter / 2.0 }

    public init(
        title: String,
        offset: Binding<ColorWheelOffset>,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._offset = offset
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            headerRow
            wheelArea
            lumaRow
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var headerRow: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)

            Spacer()

            if !offset.isNeutral {
                Button(action: reset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DSColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Đặt lại về mặc định")
            }
        }
    }

    private var wheelArea: some View {
        ZStack {
            // Vòng tròn quang phổ màu HSL
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                        center: .center
                    )
                )
                .overlay(
                    // Lớp trắng mờ ở tâm để giảm bão hòa dần về giữa
                    RadialGradient(
                        colors: [Color.white.opacity(0.85), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: wheelRadius
                    )
                )
                .frame(width: wheelDiameter, height: wheelDiameter)
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

            // Điểm tâm chữ thập tham chiếu
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: 8, height: 8)

            // Con trỏ điều hướng vị trí màu hiện tại
            let thumbX = CGFloat(offset.x) * (wheelRadius - 6.0)
            let thumbY = CGFloat(-offset.y) * (wheelRadius - 6.0)

            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                .offset(x: thumbX, y: thumbY)
        }
        .frame(width: wheelDiameter, height: wheelDiameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    onEditingChanged?(true)
                    updateOffset(from: gesture.location)
                }
                .onEnded { _ in
                    onEditingChanged?(false)
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    reset()
                }
        )
    }

    private var lumaRow: some View {
        HStack(spacing: DSSpacing.sm) {
            Text("Luma")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DSColors.textSecondary)
                .frame(width: 36, alignment: .leading)

            DSGradientSlider(
                title: "",
                value: Binding(
                    get: { Double(offset.luma) },
                    set: { offset.luma = Float($0) }
                ),
                range: -100.0...100.0,
                defaultValue: 0.0,
                gradient: LinearGradient(
                    colors: [Color.black, Color.white],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                onEditingChanged: onEditingChanged
            )
        }
    }

    private func updateOffset(from location: CGPoint) {
        let dx = location.x - wheelRadius
        let dy = -(location.y - wheelRadius) // Đảo chiều trục Y để hướng lên là dương
        let maxDist = wheelRadius - 6.0
        let dist = sqrt(dx * dx + dy * dy)

        if dist < 0.001 {
            offset.x = 0.0
            offset.y = 0.0
        } else {
            let clampedDist = min(dist, maxDist)
            offset.x = Float((dx / dist) * (clampedDist / maxDist))
            offset.y = Float((dy / dist) * (clampedDist / maxDist))
        }
    }

    private func reset() {
        onEditingChanged?(true)
        offset.x = 0.0
        offset.y = 0.0
        offset.luma = 0.0
        onEditingChanged?(false)
    }
}
