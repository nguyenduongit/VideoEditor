import SwiftUI
import Domain
import DesignSystem

/// Card hình vuông hiển thị mẫu Adjustment Layer, dựng trực tiếp ảnh mẫu đã qua `ColorGradingEngine`
/// từ cấu hình JSON của từng preset, hoàn toàn sạch sẽ không có các badge rườm rà.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) và R5.1 của AGENTS.md.
public struct AdjustmentCardItemView: View {
    private let preset: AdjustmentPreset
    private let onAdd: () -> Void
    private let onDelete: (() -> Void)?
    @State private var isHovered = false

    public init(preset: AdjustmentPreset, onAdd: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.preset = preset
        self.onAdd = onAdd
        self.onDelete = onDelete
    }

    public var body: some View {
        VStack(spacing: DSSpacing.xs) {
            squareThumbnailBox
            nameLabel
        }
        .contentShape(Rectangle())
        .help(preset.description.isEmpty ? preset.name : preset.description)
        .onTapGesture {
            onAdd()
        }
    }

    private var squareThumbnailBox: some View {
        ZStack {
            thumbnailSurface
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(isHovered ? DSColors.accent : DSColors.blockBorder, lineWidth: isHovered ? 1.5 : 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if isHovered {
                plusButton
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovered && !preset.isSystem, let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white)
                        .padding(4)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(DSSpacing.xs)
                .help("Xóa preset này khỏi thư viện và Supabase")
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var thumbnailSurface: some View {
        if preset.id == "default" {
            ZStack {
                DSColors.windowBackground
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }
        } else if let nsImage = AdjustmentThumbnailRenderer.shared.thumbnail(for: preset) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
        } else {
            LinearGradient(
                colors: preset.previewColorsHex.map { Color(hex: $0) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var nameLabel: some View {
        Text(preset.name)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isHovered ? DSColors.textPrimary : DSColors.textSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var plusButton: some View {
        Button(action: onAdd) {
            ZStack {
                Circle()
                    .fill(DSColors.trafficZoom)
                Circle()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 22, height: 22)
            .shadow(color: Color.black.opacity(0.35), radius: 2, x: 0, y: 1)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(DSSpacing.xs)
        .help("Thêm vào Timeline")
    }
}
