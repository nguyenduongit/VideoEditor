import SwiftUI
import Domain
import DesignSystem

/// Thẻ Thumbnail chuyển cảnh thông minh:
/// - Trạng thái chưa hover: Hiển thị trực tiếp hình ảnh đầu tiên (`scene_a_sea_square.jpg`).
/// - Trạng thái hover: Chạy hoạt ảnh chuyển cảnh thời lượng 2.0s sử dụng chính thuật toán Metal Compute Kernel
///   của preset đó (`DynamicShaderRuntimeEngine.shared.executeTransition`) từ Ảnh 1 (Biển Đảo) sang Ảnh 2 (Núi Hoa).
/// Tuân thủ AGENTS.md (Cấp 1 Control/Molecule, File <= 300 dòng, View body <= 40 dòng).
public struct TransitionAnimatedThumbnailView: View {
    public static let hoverDurationSeconds: Double = 2.0

    let preset: TransitionPreset

    @State private var isHovered: Bool = false
    @State private var hoverStartDate: Date = Date()

    public init(preset: TransitionPreset) {
        self.preset = preset
    }

    public var body: some View {
        ZStack {
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
            isHovered = hovering
        }
    }

    // MARK: - Static Thumbnail Content (First Scene A Image)

    private var staticThumbnailContent: some View {
        sceneAView
    }

    // MARK: - Hover Animated GPU Transition (2.0s Cycle using exact Preset Algorithm)

    private var hoverAnimatedCanvas: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let elapsed = max(0.0, context.date.timeIntervalSince(hoverStartDate))
            let cycle = Self.hoverDurationSeconds
            let rawP = elapsed.truncatingRemainder(dividingBy: cycle) / cycle

            if let cgFrame = TransitionThumbnailAssetProvider.shared.renderTransitionFrame(
                for: preset,
                rawProgress: rawP
            ) {
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
        TransitionThumbnailAssetProvider.shared.imageA
            .resizable()
            .scaledToFill()
    }
}
