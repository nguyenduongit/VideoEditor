import SwiftUI
import Domain
import DesignSystem

/// Lưới thẻ hiển thị 25 kịch bản diễn hoạt đóng gói sẵn chia theo 5 chủ đề (Script-Driven Animation Catalog).
/// Cả ảnh tĩnh (Hero Frame) lẫn Live Hover Preview đều kết xuất 1:1 từ `TextRendererEngine` để đồng nhất tuyệt đối với Canvas.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextScriptAnimationCardsGrid: View {
    public let selectedScriptId: String
    public let onSelectScript: (any TextAnimationScript) -> Void
    public let onClearScript: () -> Void

    @State private var selectedCategory: TextAnimationCategory?
    @State private var hoveredScriptId: String?

    public init(
        selectedScriptId: String,
        onSelectScript: @escaping (any TextAnimationScript) -> Void,
        onClearScript: @escaping () -> Void
    ) {
        self.selectedScriptId = selectedScriptId
        self.onSelectScript = onSelectScript
        self.onClearScript = onClearScript
    }

    private var filteredScripts: [any TextAnimationScript] {
        TextAnimationScriptRegistry.shared.scripts(in: selectedCategory)
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: DSSpacing.xs),
        GridItem(.flexible(), spacing: DSSpacing.xs),
        GridItem(.flexible(), spacing: DSSpacing.xs)
    ]

    public var body: some View {
        HStack(spacing: DSSpacing.none) {
            categorySidebar
                .frame(width: 82)
                .background(DSColors.windowBackground.opacity(0.45))

            Divider()
                .background(DSColors.blockBorder)

            cardsScrollView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var categorySidebar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                sidebarButton(
                    title: "All",
                    count: TextAnimationScriptRegistry.shared.scripts.count,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(TextAnimationCategory.allCases, id: \.rawValue) { category in
                    let count = TextAnimationScriptRegistry.shared.scripts(in: category).count
                    sidebarButton(
                        title: category.displayName,
                        count: count,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.vertical, 0)
        }
    }

    private func sidebarButton(
        title: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary.opacity(0.8))
                }
            }
            .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
            .background(isSelected ? DSColors.toggleCyan.opacity(0.18) : Color.clear)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? DSColors.toggleCyan.opacity(0.85) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var cardsScrollView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: DSSpacing.xs) {
                if selectedCategory == nil {
                    noneCard(isSelected: selectedScriptId == "none" || selectedScriptId.isEmpty)
                }

                ForEach(filteredScripts, id: \.id) { script in
                    let isSelected = selectedScriptId == script.id
                    let isHovered = hoveredScriptId == script.id
                    scriptCard(script: script, isSelected: isSelected, isHovered: isHovered)
                }
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
        }
    }

    private func noneCard(isSelected: Bool) -> some View {
        Button(action: onClearScript) {
            VStack(spacing: DSSpacing.xs) {
                Image(systemName: "slash.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.textSecondary)
                    .frame(height: 42)
                Text(String(localized: "None"))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(isSelected ? DSColors.windowBackground : DSColors.blockBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(isSelected ? DSColors.toggleCyan : DSColors.blockBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func scriptCard(script: any TextAnimationScript, isSelected: Bool, isHovered: Bool) -> some View {
        Button(action: { onSelectScript(script) }) {
            VStack(spacing: 3) {
                scriptPreviewStage(script: script, isSelected: isSelected, isHovered: isHovered)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .clipped()

                Text(script.displayName)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? DSColors.textPrimary : DSColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(isSelected ? DSColors.windowBackground : (isHovered ? DSColors.tabHoverBackground : DSColors.blockBackground))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small)
                    .stroke(isSelected ? DSColors.toggleCyan : (isHovered ? DSColors.toggleCyan.opacity(0.45) : DSColors.blockBorder), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveredScriptId = script.id
            } else if hoveredScriptId == script.id {
                hoveredScriptId = nil
            }
        }
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
        default: return script.category.iconName
        }
    }
}
