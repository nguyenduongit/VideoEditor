import SwiftUI
import Domain
import DesignSystem

/// Text Script-Driven Animation catalog powered by the shared `DSAnimationScriptBrowser` layout.
/// Both static Hero thumbnails and live hover previews render 1:1 via `TextRendererEngine`.
public struct TextScriptAnimationCardsGrid<BottomPanel: View>: View {
    public let selectedScriptId: String
    public let showBottomPanel: Bool
    public let onSelectScript: (any TextAnimationScript) -> Void
    public let onClearScript: () -> Void
    private let bottomPanel: BottomPanel

    @State private var selectedCategoryId: String?

    public init(
        selectedScriptId: String,
        showBottomPanel: Bool,
        onSelectScript: @escaping (any TextAnimationScript) -> Void,
        onClearScript: @escaping () -> Void,
        @ViewBuilder bottomPanel: () -> BottomPanel
    ) {
        self.selectedScriptId = selectedScriptId
        self.showBottomPanel = showBottomPanel
        self.onSelectScript = onSelectScript
        self.onClearScript = onClearScript
        self.bottomPanel = bottomPanel()
    }

    private var selectedCategory: TextAnimationCategory? {
        selectedCategoryId.flatMap(TextAnimationCategory.init(rawValue:))
    }

    private var browserCategories: [DSAnimationBrowserCategory] {
        TextAnimationCategory.allCases.map { cat in
            DSAnimationBrowserCategory(
                id: cat.rawValue,
                title: cat.displayName,
                count: TextAnimationScriptRegistry.shared.scripts(in: cat).count
            )
        }
    }

    private var filteredItems: [TextBrowserScriptItem] {
        TextAnimationScriptRegistry.shared.scripts(in: selectedCategory)
            .map { TextBrowserScriptItem(id: $0.id, script: $0) }
    }

    public var body: some View {
        DSAnimationScriptBrowser(
            selectedCategoryId: $selectedCategoryId,
            totalCount: TextAnimationScriptRegistry.shared.scripts.count,
            categories: browserCategories,
            items: filteredItems,
            selectedItemId: selectedScriptId,
            showBottomPanel: showBottomPanel,
            onClearSelection: onClearScript,
            onSelectItem: { onSelectScript($0.script) },
            itemTitle: { $0.script.displayName },
            itemTooltip: { $0.script.description },
            itemPreview: { item, isSelected, isHovered in
                scriptPreviewStage(script: item.script, isSelected: isSelected, isHovered: isHovered)
            },
            bottomPanel: { bottomPanel }
        )
    }

    @ViewBuilder
    private func scriptPreviewStage(script: any TextAnimationScript, isSelected: Bool, isHovered: Bool) -> some View {
        if isHovered || isSelected {
            TextScriptLivePreviewStage(
                script: script,
                isSelected: isSelected,
                isHovered: isHovered
            )
        } else {
            staticHeroStage(script: script, isSelected: isSelected)
        }
    }

    private func staticHeroStage(script: any TextAnimationScript, isSelected: Bool) -> some View {
        let heroT = TextThumbnailRenderer.heroPreviewTime(for: script.id)
        let heroFrame = TextThumbnailRenderer.renderScriptPreviewFrame(
            scriptId: script.id,
            localTime: heroT,
            duration: script.defaultDuration
        )
        return ZStack(alignment: .topTrailing) {
            if let heroFrame {
                Image(nsImage: heroFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Text")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Image(systemName: iconName(for: script))
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.accent)
                .padding(3)
        }
    }

    private func iconName(for script: any TextAnimationScript) -> String {
        TextScriptIconLookup.map[script.id] ?? script.category.iconName
    }
}

private enum TextScriptIconLookup {
    static let map: [String: String] = [
        "title_wave_float": "water.waves",
        "typewriter_cursor": "character.cursor.ibeam",
        "kinetic_drop_glow": "arrow.down.to.line",
        "curved_arc_roller": "skew",
        "neon_cyber_shift": "sparkles",
        "liquid_wave_pulse": "water.waves",
        "glitch_rgb_pop": "bolt.horizontal.fill",
        "smooth_word_glide": "arrow.up.right",
        "elastic_flip_3d": "cube.transparent",
        "pop_up_hinge_3d": "rectangle.portrait.bottomhalf.inset.filled",
        "whip_echo_slam": "wind",
        "tornado_spiral_pop": "tornado",
        "trailer_tracking_expand": "arrow.left.and.right.text.vertical",
        "pendulum_hinge_swing": "metronome",
        "anamorphic_split_reveal": "rectangle.split.1x2",
        "ripple_drop_wave": "drop.circle",
        "dna_helix_twist": "waveform.path.ecg",
        "jelly_trampoline_wave": "figure.jumprope",
        "hologram_scan_beam": "barcode.viewfinder",
        "vhs_tracking_drift": "recordingtape",
        "quantum_teleport_flicker": "sparkle.magnifyingglass",
        "cyber_shutter_slice": "slider.horizontal.below.square.and.square.filled",
        "curtain_baseline_rise": "arrow.up.to.line.compact",
        "shutter_blind_reveal": "sidebar.left",
        "soft_breathe_cascade": "aqi.medium",
        "flip_counter_roll": "123.rectangle",
        "karaoke_glow_flow": "waveform.badge.mic",
        "line_cascade_rise": "text.alignleft",
        "blur_focus_dissolve": "camera.aperture",
        "beat_pulse_slam": "metronome.fill",
        "three_d_tumble_drop": "rotate.3d",
        "three_d_swinging_door": "door.left.hand.open",
        "three_d_depth_rush": "view.3d",
        "fx_pixel_dissolve": "square.grid.3x3.fill",
        "slide_directional_whip": "arrow.forward.circle",
        "slide_zipper_cross": "arrow.left.and.right",
        "wave_flag_flutter": "flag.fill",
        "wave_liquid_ripple": "drop.halffull",
        "typewriter_neon_draw": "scribble.variable",
        "typewriter_cipher_decode": "lock.rotation",
        "three_d_card_carousel": "square.3.layers.3d",
        "fade_diagonal_slash": "line.diagonal",
        "slide_center_split": "arrow.left.and.right.square",
        "pop_collision_slam": "bolt.horizontal.circle.fill",
        "slide_up_up": "arrow.up",
        "slide_down_down": "arrow.down",
        "slide_up_down": "arrow.uturn.down",
        "slide_down_up": "arrow.uturn.up",
        "slide_left_left": "arrow.left",
        "slide_left_right": "arrow.uturn.right",
        "slide_right_left": "arrow.uturn.left",
        "slide_right_right": "arrow.right"
    ]
}

private struct TextScriptLivePreviewStage: View {
    let script: any TextAnimationScript
    let isSelected: Bool
    let isHovered: Bool

    @State private var previewStartDate = Date()

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let cycle = TextThumbnailRenderer.scriptPreviewDuration(for: script)
            let t = TextThumbnailRenderer.scriptPreviewLocalTime(
                startDate: previewStartDate,
                currentDate: context.date,
                duration: cycle
            )
            if let frame = TextThumbnailRenderer.renderScriptPreviewFrame(
                scriptId: script.id,
                localTime: t,
                duration: cycle
            ) {
                Image(nsImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Text")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { previewStartDate = Date() }
        .onChange(of: isHovered) { _, hovering in
            if hovering { previewStartDate = Date() }
        }
    }
}

private struct TextBrowserScriptItem: Identifiable {
    let id: String
    let script: any TextAnimationScript
}
