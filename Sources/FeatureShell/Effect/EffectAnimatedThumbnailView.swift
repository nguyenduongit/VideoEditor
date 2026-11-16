import SwiftUI
import Domain
import DesignSystem

/// Thẻ Thumbnail hiệu ứng thông minh:
/// - Trạng thái chưa hover: Hiển thị trực tiếp hình ảnh gốc đại diện của danh mục tương ứng.
/// - Trạng thái hover: Chạy hoạt ảnh demo 2.0s áp dụng chính thuật toán Hybrid GPU Engine của Effect đó
///   (CIFilter, Metal Compute Shaders, hoặc Procedural Overlay) lên ảnh mẫu thời gian thực.
/// Tuân thủ AGENTS.md (Cấp 1 Control/Molecule, File <= 300 dòng, View body <= 40 dòng).
public struct EffectAnimatedThumbnailView: View {
    public static let hoverDurationSeconds: Double = 2.0

    let preset: EffectPreset
    let externalIsHovered: Bool?

    @State private var localIsHovered: Bool = false
    @State private var hoverStartDate: Date = Date()

    private var isHovered: Bool {
        externalIsHovered ?? localIsHovered
    }

    public init(preset: EffectPreset, isHovered: Bool? = nil) {
        self.preset = preset
        self.externalIsHovered = isHovered
    }

    public var body: some View {
        ZStack {
            if isHovered {
                hoverAnimatedCanvas
            } else {
                staticThumbnailContent
            }

            if preset.config.isBeatSynced {
                beatBadgeOverlay
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
    }

    // MARK: - Static Thumbnail Content

    private var staticThumbnailContent: some View {
        sceneAView
    }

    private var beatBadgeOverlay: some View {
        VStack {
            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "music.note")
                        .font(.system(size: 8, weight: .bold))
                    Text("BEAT")
                        .font(.system(size: 7.5, weight: .bold))
                }
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 2.5)
                .background(
                    Capsule()
                        .fill(DSColors.toggleCyan)
                )
                .padding(4)
                Spacer()
            }
            Spacer()
        }
    }

    // MARK: - Hover Animated Canvas (2.0s Cycle using exact EffectEngine Algorithm)

    private var hoverAnimatedCanvas: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = max(0.0, context.date.timeIntervalSince(hoverStartDate))
            let cycle = Self.hoverDurationSeconds
            let localTime = elapsed.truncatingRemainder(dividingBy: cycle)

            if let cgFrame = renderEffectFrame(localTime: localTime, duration: cycle) {
                Image(decorative: cgFrame, scale: 1.0)
                    .resizable()
                    .scaledToFill()
            } else {
                sceneAView
            }
        }
        .clipped()
    }

    private var sceneAView: some View {
        TransitionThumbnailAssetProvider.shared.imageA(for: transitionCategory(for: preset.category))
            .resizable()
            .scaledToFill()
    }

    private func renderEffectFrame(localTime: Double, duration: Double) -> CGImage? {
        let transCat = transitionCategory(for: preset.category)
        let pair = TransitionThumbnailAssetProvider.shared.assetPair(for: transCat)
        let size = TransitionThumbnailAssetProvider.thumbnailPixelSize
        let rect = CGRect(origin: .zero, size: size)

        let outCI = EffectEngine.shared.applyEffect(
            to: pair.ciImageA,
            config: preset.config,
            localTime: localTime,
            duration: duration,
            canvasSize: size
        ).cropped(to: rect)

        return MetalComputeRuntimeEngine.shared.renderCGImage(from: outCI, rect: rect)
    }

    private func transitionCategory(for effectCat: EffectTemplateCategory) -> TransitionCategory {
        switch effectCat {
        case .basic, .color, .nature:
            return .basic
        case .glitch, .camera, .motion, .overlay:
            return .slideWipe
        case .blur, .light, .retro, .artistic:
            return .light
        case .all:
            return .basic
        }
    }
}

