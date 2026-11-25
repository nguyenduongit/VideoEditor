import SwiftUI
import Domain
import DesignSystem

/// Text Script & Graph Animation catalog powered by the shared `DSAnimationScriptBrowser` layout.
/// Both static Hero thumbnails and live hover previews render 1:1 via `TextRendererEngine`.
public struct TextScriptAnimationCardsGrid<BottomPanel: View>: View {
    public let selectedScriptId: String
    public let showBottomPanel: Bool
    public let onSelectItem: (TextAnimationCatalogItem) -> Void
    public let onClearScript: () -> Void
    private let bottomPanel: BottomPanel

    @State private var selectedCategoryId: String?

    public init(
        selectedScriptId: String,
        showBottomPanel: Bool,
        onSelectItem: @escaping (TextAnimationCatalogItem) -> Void,
        onClearScript: @escaping () -> Void,
        @ViewBuilder bottomPanel: () -> BottomPanel
    ) {
        self.selectedScriptId = selectedScriptId
        self.showBottomPanel = showBottomPanel
        self.onSelectItem = onSelectItem
        self.onClearScript = onClearScript
        self.bottomPanel = bottomPanel()
    }

    public init(
        selectedScriptId: String,
        showBottomPanel: Bool,
        onSelectScript: @escaping (any TextAnimationScript) -> Void,
        onClearScript: @escaping () -> Void,
        @ViewBuilder bottomPanel: () -> BottomPanel
    ) {
        self.init(
            selectedScriptId: selectedScriptId,
            showBottomPanel: showBottomPanel,
            onSelectItem: { item in
                if case .script(let script) = item {
                    onSelectScript(script)
                }
            },
            onClearScript: onClearScript,
            bottomPanel: bottomPanel
        )
    }

    private var selectedCategory: TextAnimationCategory? {
        selectedCategoryId.flatMap(TextAnimationCategory.init(rawValue:))
    }

    private var browserCategories: [DSAnimationBrowserCategory] {
        TextAnimationCategory.allCases.map { cat in
            DSAnimationBrowserCategory(
                id: cat.rawValue,
                title: cat.displayName,
                count: TextAnimationCatalogItem.items(in: cat).count
            )
        }
    }

    private var filteredItems: [TextAnimationCatalogItem] {
        TextAnimationCatalogItem.items(in: selectedCategory)
    }

    public var body: some View {
        DSAnimationScriptBrowser(
            selectedCategoryId: $selectedCategoryId,
            totalCount: TextAnimationCatalogItem.allItems.count,
            categories: browserCategories,
            items: filteredItems,
            selectedItemId: selectedScriptId,
            showBottomPanel: showBottomPanel,
            onClearSelection: onClearScript,
            onSelectItem: onSelectItem,
            itemTitle: { $0.displayName },
            itemTooltip: { $0.description },
            itemPreview: { item, isSelected, isHovered in
                scriptPreviewStage(item: item, isSelected: isSelected, isHovered: isHovered)
            },
            bottomPanel: { bottomPanel }
        )
    }

    @ViewBuilder
    private func scriptPreviewStage(item: TextAnimationCatalogItem, isSelected: Bool, isHovered: Bool) -> some View {
        if isHovered || isSelected {
            TextScriptLivePreviewStage(
                item: item,
                isSelected: isSelected,
                isHovered: isHovered
            )
        } else {
            staticHeroStage(item: item, isSelected: isSelected)
        }
    }

    private func staticHeroStage(item: TextAnimationCatalogItem, isSelected: Bool) -> some View {
        let heroT = TextThumbnailRenderer.heroPreviewTime(for: item.id)
        let heroFrame = TextThumbnailRenderer.renderScriptPreviewFrame(
            scriptId: item.id,
            localTime: heroT,
            duration: TextThumbnailRenderer.scriptPreviewDuration(for: item)
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

            Image(systemName: iconName(for: item))
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.accent)
                .padding(3)
        }
    }

    private func iconName(for item: TextAnimationCatalogItem) -> String {
        TextScriptIconLookup.map[item.id] ?? item.category.iconName
    }
}

private enum TextScriptIconLookup {
    static let map: [String: String] = [
        "title_wave_float": "water.waves",
        "typewriter_cursor": "character.cursor.ibeam",
        "kinetic_drop_glow": "arrow.down.to.line",
        "elastic_flip_3d": "cube.transparent",
        "pop_up_hinge_3d": "rectangle.portrait.bottomhalf.inset.filled",
        "tornado_spiral_pop": "tornado",
        "pendulum_hinge_swing": "metronome",
        "ripple_drop_wave": "drop.circle",
        "dna_helix_twist": "waveform.path.ecg",
        "curtain_baseline_rise": "arrow.up.to.line.compact",
        "flip_counter_roll": "123.rectangle",
        "karaoke_glow_flow": "waveform.badge.mic",
        "blur_focus_dissolve": "camera.aperture",
        "beat_pulse_slam": "metronome.fill",
        "three_d_tumble_drop": "rotate.3d",
        "fx_pixel_dissolve": "square.grid.3x3.fill",
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
        "slide_right_right": "arrow.right",
        "graph_chrome_bevel_3d": "cube.fill",
        "graph_quantum_particles": "sparkles",
        "graph_audio_beat_pulse": "waveform.path.ecg",
        "graph_door_hinge_3d": "door.left.hand.open",
        "graph_orbit_carousel_3d": "globe.americas.fill",
        "graph_bezier_ribbon_fly": "point.topleft.down.curvedto.point.bottomright.up",
        "graph_flag_mesh_flutter": "flag.fill",
        "graph_arc_bend_bounce": "archway",
        "graph_tracked_expand": "arrow.left.and.right.text.vertical",
        "graph_origami_corner_unfold": "square.topthird.inset.filled",
        "graph_spiral_vortex_orbit": "hurricane",
        "graph_ribbon_twist_snap": "tornado.circle",
        "graph_lens_bubble_pop": "circle.hexagongrid.fill",
        "graph_domino_bottom_cascade": "rectangle.split.3x1.fill",
        "graph_audio_eq_bounce": "slider.vertical.3",
        "graph_slalom_spline_glide": "scribble",
        "graph_right_hinge_trapdoor": "door.right.hand.open",
        "graph_jelly_mercury_wave": "water.waves.and.arrow.up",
        "graph_pendulum_top_corner": "gyroscope",
        "graph_iris_laser_carve": "circle.dashed.inset.filled",
        "graph_cipher_scramble_draw": "chevron.left.forwardslash.chevron.right"
    ]
}

private struct TextScriptLivePreviewStage: View {
    let item: TextAnimationCatalogItem
    let isSelected: Bool
    let isHovered: Bool

    @State private var previewStartDate = Date()

    var body: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let cycle = TextThumbnailRenderer.scriptPreviewDuration(for: item)
            let t = TextThumbnailRenderer.scriptPreviewLocalTime(
                startDate: previewStartDate,
                currentDate: context.date,
                duration: cycle
            )
            if let frame = TextThumbnailRenderer.renderScriptPreviewFrame(
                scriptId: item.id,
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
