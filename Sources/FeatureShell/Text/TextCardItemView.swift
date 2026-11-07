import SwiftUI
import AppKit
import Domain
import DesignSystem

/// Card hình vuông hiển thị mẫu chữ Text với hình thu nhỏ kết xuất điểm ảnh chuẩn xác từ `TextRendererEngine`
/// kèm nền đặc tương phản tự động theo màu chủ đạo, hỗ trợ xem trước khi Hover (trên thẻ) và khi Click (trên Preview chính).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, Hàm <= 50 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextCardItemView: View {
    private let preset: TextPreset
    private let isSelected: Bool
    private let onSelect: (() -> Void)?
    private let onAdd: () -> Void
    private let onDelete: (() -> Void)?
    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?

    public init(
        preset: TextPreset,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil,
        onAdd: @escaping () -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.preset = preset
        self.isSelected = isSelected
        self.onSelect = onSelect
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
            if let onSelect {
                onSelect()
            } else {
                onAdd()
            }
        }
        .contextMenu {
            Button("Preview on Canvas") {
                onSelect?()
            }
            Button("Add to Timeline") {
                onAdd()
            }
            if !preset.isSystem, let onDelete {
                Divider()
                Button("Delete Preset", role: .destructive) {
                    onDelete()
                }
            }
        }
        .task(id: "\(preset.id)_\(preset.config.hashValue)") {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        if preset.id != "default" {
            thumbnailImage = TextThumbnailRenderer.renderThumbnail(for: preset)
        }
    }

    private var theme: TextThumbnailRenderer.ThumbnailTheme {
        TextThumbnailRenderer.computeTheme(for: preset.config)
    }

    private var squareThumbnailBox: some View {
        ZStack {
            presetBackground
            centerTextPreview
        }
        .aspectRatio(1.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.block)
                .stroke(borderStrokeColor, lineWidth: (isSelected || isHovered) ? 1.8 : 1.0)
        )
        .overlay(alignment: .bottomTrailing) {
            if isHovered || isSelected {
                plusButton
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovered && !preset.isSystem, let onDelete {
                deleteButton(action: onDelete)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .onHover { isHovered = $0 }
    }

    private var borderStrokeColor: Color {
        if isSelected {
            return DSColors.toggleCyan
        }
        if isHovered {
            return DSColors.toggleCyan.opacity(0.85)
        }
        return theme.isLightDominant ? DSColors.blockBorder : Color.black.opacity(0.15)
    }

    private var presetBackground: some View {
        LinearGradient(
            colors: theme.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var nameLabel: some View {
        Text(preset.id == "default" ? "Default Text" : preset.name)
            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textPrimary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var plusButton: some View {
        Button(action: onAdd) {
            ZStack {
                Circle().fill(DSColors.trafficZoom)
                Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
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
        .help("Add to Timeline")
    }

    private func deleteButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.white)
                .padding(4)
                .background(Color.black.opacity(0.65))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(DSSpacing.xs)
        .help("Delete preset from library and Supabase")
    }

    @ViewBuilder
    private var centerTextPreview: some View {
        if preset.id == "default" {
            VStack(spacing: 4) {
                Image(systemName: "character.textbox")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(isHovered ? DSColors.toggleCyan : DSColors.textSecondary)
                    .scaleEffect(isHovered ? 1.08 : 1.0)
                Text("Text")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
            }
        } else if isHovered {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let cycle = 2.0
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                animatedTemplateStage(localTime: t, duration: cycle)
            }
        } else {
            staticTemplateStage
        }
    }

    private var staticTemplateStage: some View {
        Group {
            if let thumbnailImage {
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func animatedTemplateStage(localTime: Double, duration: Double) -> some View {
        let liveFrame = TextThumbnailRenderer.renderAnimatedFrame(
            for: preset,
            localTime: localTime,
            duration: duration,
            targetSize: CGSize(width: 160, height: 160)
        ) ?? thumbnailImage

        return ZStack {
            if let liveFrame {
                Image(nsImage: liveFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
