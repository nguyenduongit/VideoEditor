import SwiftUI
import Domain
import DesignSystem

/// Grid hiển thị danh sách Gói Hoạt Ảnh Sáng Tạo Mở (`AnimationPreset`) cho 3 pha (In, Out, Loop) kèm mô phỏng trực tiếp.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng) và R4.3 (đơn nhiệm).
public struct TextAnimationCardsGrid: View {
    public let selectedSubTab: TextAnimationTabContent.AnimationSubTab
    public let config: TextConfiguration
    public let inPresets: [AnimationPreset]
    public let outPresets: [AnimationPreset]
    public let loopPresets: [AnimationPreset]
    public let onSelectInPreset: (AnimationPreset?) -> Void
    public let onSelectOutPreset: (AnimationPreset?) -> Void
    public let onSelectLoopPreset: (AnimationPreset?) -> Void

    public init(
        selectedSubTab: TextAnimationTabContent.AnimationSubTab,
        config: TextConfiguration,
        inPresets: [AnimationPreset] = AnimationPreset.inCatalog,
        outPresets: [AnimationPreset] = AnimationPreset.outCatalog,
        loopPresets: [AnimationPreset] = AnimationPreset.loopCatalog,
        onSelectInPreset: @escaping (AnimationPreset?) -> Void,
        onSelectOutPreset: @escaping (AnimationPreset?) -> Void,
        onSelectLoopPreset: @escaping (AnimationPreset?) -> Void
    ) {
        self.selectedSubTab = selectedSubTab
        self.config = config
        self.inPresets = inPresets
        self.outPresets = outPresets
        self.loopPresets = loopPresets
        self.onSelectInPreset = onSelectInPreset
        self.onSelectOutPreset = onSelectOutPreset
        self.onSelectLoopPreset = onSelectLoopPreset
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 82), spacing: DSSpacing.xs)],
                spacing: DSSpacing.xs
            ) {
                switch selectedSubTab {
                case .inAnimation:
                    noneCard(isSelected: !config.animation.hasInAnimation) { onSelectInPreset(nil) }
                    ForEach(inPresets) { preset in
                        let isSelected = config.animation.inManifest?.id == preset.manifest.id
                        TextAnimationPreviewCardView(
                            title: preset.name,
                            iconName: preset.manifest.iconName,
                            isSelected: isSelected,
                            previewConfig: makePreviewConfig(inManifest: preset.manifest)
                        ) {
                            onSelectInPreset(preset)
                        }
                        .id("in-\(preset.id)-\(isSelected)")
                    }
                case .outAnimation:
                    noneCard(isSelected: !config.animation.hasOutAnimation) { onSelectOutPreset(nil) }
                    ForEach(outPresets) { preset in
                        let isSelected = config.animation.outManifest?.id == preset.manifest.id
                        TextAnimationPreviewCardView(
                            title: preset.name,
                            iconName: preset.manifest.iconName,
                            isSelected: isSelected,
                            previewConfig: makePreviewConfig(outManifest: preset.manifest)
                        ) {
                            onSelectOutPreset(preset)
                        }
                        .id("out-\(preset.id)-\(isSelected)")
                    }
                case .loopAnimation:
                    noneCard(isSelected: !config.animation.hasLoopAnimation) { onSelectLoopPreset(nil) }
                    ForEach(loopPresets) { preset in
                        let isSelected = config.animation.loopManifest?.id == preset.manifest.id
                        TextAnimationPreviewCardView(
                            title: preset.name,
                            iconName: preset.manifest.iconName,
                            isSelected: isSelected,
                            previewConfig: makePreviewConfig(loopManifest: preset.manifest)
                        ) {
                            onSelectLoopPreset(preset)
                        }
                        .id("loop-\(preset.id)-\(isSelected)")
                    }
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.top, DSSpacing.xs)
            .padding(.bottom, DSSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func noneCard(isSelected: Bool, action: @escaping () -> Void) -> some View {
        TextAnimationPreviewCardView(
            title: "None",
            iconName: "slash.circle",
            isSelected: isSelected,
            previewConfig: TextConfiguration(content: "Aa", fontSize: 16.0, isBold: true),
            action: action
        )
    }

    private func makePreviewConfig(
        inManifest: CreativeAnimationManifest? = nil,
        outManifest: CreativeAnimationManifest? = nil,
        loopManifest: CreativeAnimationManifest? = nil
    ) -> TextConfiguration {
        var sample = TextConfiguration(content: "Aa", fontSize: 16.0, isBold: true)
        sample.animation = TextAnimationConfiguration(
            inDuration: 1.0,
            outDuration: 1.0,
            loopSpeed: 1.2,
            motionEasing: config.animation.motionEasing,
            inManifest: inManifest,
            outManifest: outManifest,
            loopManifest: loopManifest
        )
        return sample
    }
}
