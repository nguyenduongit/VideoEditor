import SwiftUI
import AppKit
import Domain
import DesignSystem

/// Thẻ Thumbnail kiểu chữ (Text Preset) thông minh:
/// - Trạng thái chưa hover: Hiển thị hình ảnh render tĩnh chất lượng cao từ `TextThumbnailRenderer`.
/// - Trạng thái hover: Chạy hoạt ảnh động theo thời lượng thực của Preset (In -> Loop -> Out) kết xuất trực tiếp bằng `TextThumbnailRenderer.renderAnimatedFrame`.
/// Tuân thủ AGENTS.md (Cấp 1 Control/Molecule, File <= 300 dòng, View body <= 40 dòng).
public struct TextAnimatedThumbnailView: View {
    public static let hoverDurationSeconds: Double = 4.0

    let preset: TextPreset
    let externalIsHovered: Bool?

    @State private var localIsHovered: Bool = false
    @State private var hoverStartDate: Date = Date()
    @State private var staticImage: NSImage?

    private var isHovered: Bool {
        externalIsHovered ?? localIsHovered
    }

    private var effectiveDuration: Double {
        TextThumbnailRenderer.effectiveDuration(for: preset)
    }

    public init(preset: TextPreset, isHovered: Bool? = nil) {
        self.preset = preset
        self.externalIsHovered = isHovered
    }

    private var theme: TextThumbnailRenderer.ThumbnailTheme {
        TextThumbnailRenderer.computeTheme(for: preset.config)
    }

    public var body: some View {
        ZStack {
            presetBackground

            if isHovered {
                hoverAnimatedCanvas
            } else {
                staticThumbnailContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                hoverStartDate = Date()
            }
            localIsHovered = hovering
        }
        .onChange(of: isHovered) { _, hovering in
            if hovering {
                hoverStartDate = Date()
            }
        }
        .task(id: "\(preset.id)_\(preset.config.hashValue)") {
            if staticImage == nil {
                staticImage = TextThumbnailRenderer.renderThumbnail(for: preset)
            }
        }
    }

    // MARK: - Subviews

    private var presetBackground: some View {
        LinearGradient(
            colors: theme.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var staticThumbnailContent: some View {
        Group {
            if let img = staticImage ?? TextThumbnailRenderer.renderThumbnail(for: preset) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding(DSSpacing.xs)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var hoverAnimatedCanvas: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = max(0.0, context.date.timeIntervalSince(hoverStartDate))
            let cycle = effectiveDuration
            let localTime = elapsed.truncatingRemainder(dividingBy: cycle)

            if let frame = TextThumbnailRenderer.renderAnimatedFrame(
                for: preset,
                localTime: localTime,
                duration: cycle,
                targetSize: CGSize(width: 160, height: 160)
            ) ?? staticImage ?? TextThumbnailRenderer.renderThumbnail(for: preset) {
                Image(nsImage: frame)
                    .resizable()
                    .scaledToFit()
                    .padding(DSSpacing.xs)
            } else {
                staticThumbnailContent
            }
        }
    }
}

