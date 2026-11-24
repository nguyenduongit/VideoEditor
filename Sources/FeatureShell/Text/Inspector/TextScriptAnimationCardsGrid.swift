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
            itemPreview: { item, isSelected, isHovered in
                scriptPreviewStage(script: item.script, isSelected: isSelected, isHovered: isHovered)
            },
            bottomPanel: { bottomPanel }
        )
    }

    @ViewBuilder
    private func scriptPreviewStage(script: any TextAnimationScript, isSelected: Bool, isHovered: Bool) -> some View {
        if isHovered || isSelected {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                let cycle = script.defaultDuration
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                if let frame = TextThumbnailRenderer.renderScriptPreviewFrame(scriptId: script.id, localTime: t, duration: cycle) {
                    Image(nsImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    staticHeroStage(script: script, isSelected: isSelected)
                }
            }
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
        switch script.id {
        case "title_wave_float": return "water.waves"
        case "typewriter_cursor": return "character.cursor.ibeam"
        case "kinetic_drop_glow": return "arrow.down.to.line"
        case "curved_arc_roller": return "skew"
        case "neon_cyber_shift": return "sparkles"
        case "liquid_wave_pulse": return "water.waves"
        case "glitch_rgb_pop": return "bolt.horizontal.fill"
        case "smooth_word_glide": return "arrow.up.right"
        case "elastic_flip_3d": return "cube.transparent"
        case "pop_up_hinge_3d": return "rectangle.portrait.bottomhalf.inset.filled"
        case "whip_echo_slam": return "wind"
        case "tornado_spiral_pop": return "tornado"
        case "trailer_tracking_expand": return "arrow.left.and.right.text.vertical"
        case "pendulum_hinge_swing": return "metronome"
        case "anamorphic_split_reveal": return "rectangle.split.1x2"
        case "ripple_drop_wave": return "drop.circle"
        case "dna_helix_twist": return "waveform.path.ecg"
        case "jelly_trampoline_wave": return "figure.jumprope"
        case "hologram_scan_beam": return "barcode.viewfinder"
        case "vhs_tracking_drift": return "recordingtape"
        case "quantum_teleport_flicker": return "sparkle.magnifyingglass"
        case "cyber_shutter_slice": return "slider.horizontal.below.square.and.square.filled"
        case "curtain_baseline_rise": return "arrow.up.to.line.compact"
        case "shutter_blind_reveal": return "sidebar.left"
        case "soft_breathe_cascade": return "aqi.medium"
        case "flip_counter_roll": return "123.rectangle"
        case "karaoke_box_pop": return "rectangle.fill.on.rectangle.angled.fill"
        case "karaoke_glow_flow": return "mic.and.signal.meter.fill"
        case "line_cascade_rise": return "text.alignleft"
        case "blur_focus_dissolve": return "camera.aperture"
        case "beat_pulse_slam": return "metronome.fill"
        case "three_d_tumble_drop": return "rotate.3d"
        case "three_d_swinging_door": return "door.left.hand.open"
        case "three_d_depth_rush": return "view.3d"
        case "fx_metallic_sweep": return "sun.max.fill"
        case "fx_pixel_dissolve": return "square.grid.3x3.fill"
        case "fx_neon_ignition": return "lightbulb.max.fill"
        case "fx_chromatic_vapor": return "rainbow"
        case "slide_directional_whip": return "arrow.forward.circle"
        case "slide_zipper_cross": return "arrow.left.and.right"
        case "wave_flag_flutter": return "flag.fill"
        case "wave_liquid_ripple": return "drop.halffull"
        case "glitch_crt_slice_tear": return "tv.fill"
        default: return script.category.iconName
        }
    }
}

private struct TextBrowserScriptItem: Identifiable {
    let id: String
    let script: any TextAnimationScript
}
