import SwiftUI
import AppKit
import Domain
import DesignSystem

/// Sticker Script-Driven Animation catalog powered by the shared `DSAnimationScriptBrowser` layout.
/// Displays 1:1 real-time previews via `StickerThumbnailRenderer` using the selected sticker config.
public struct StickerScriptAnimationCardsGrid<BottomPanel: View>: View {
    public let selectedScriptId: String
    public let sourceStickerConfig: StickerConfiguration
    public let showBottomPanel: Bool
    public let onSelectScript: (String) -> Void
    public let onClearScript: () -> Void
    private let bottomPanel: BottomPanel

    @State private var selectedCategoryId: String?

    public init(
        selectedScriptId: String,
        sourceStickerConfig: StickerConfiguration,
        showBottomPanel: Bool,
        onSelectScript: @escaping (String) -> Void,
        onClearScript: @escaping () -> Void,
        @ViewBuilder bottomPanel: () -> BottomPanel
    ) {
        self.selectedScriptId = selectedScriptId
        self.sourceStickerConfig = sourceStickerConfig
        self.showBottomPanel = showBottomPanel
        self.onSelectScript = onSelectScript
        self.onClearScript = onClearScript
        self.bottomPanel = bottomPanel()
    }

    private var selectedCategory: StickerAnimationCategory? {
        selectedCategoryId.flatMap(StickerAnimationCategory.init(rawValue:))
    }

    private var browserCategories: [DSAnimationBrowserCategory] {
        StickerAnimationCategory.allCases.map { cat in
            DSAnimationBrowserCategory(
                id: cat.rawValue,
                title: cat.displayName,
                count: StickerAnimationScriptRegistry.shared.scripts(in: cat).count
            )
        }
    }

    private var filteredItems: [StickerBrowserScriptItem] {
        let scripts: [any StickerAnimationScript] = if let selectedCategory {
            StickerAnimationScriptRegistry.shared.scripts(in: selectedCategory)
        } else {
            StickerAnimationScriptRegistry.shared.allScripts
        }
        return scripts.map { StickerBrowserScriptItem(id: $0.id, script: $0) }
    }

    public var body: some View {
        DSAnimationScriptBrowser(
            selectedCategoryId: $selectedCategoryId,
            totalCount: StickerAnimationScriptRegistry.shared.allScripts.count,
            categories: browserCategories,
            items: filteredItems,
            selectedItemId: selectedScriptId,
            showBottomPanel: showBottomPanel,
            onClearSelection: onClearScript,
            onSelectItem: { onSelectScript($0.id) },
            itemTitle: { $0.script.name },
            itemTooltip: { $0.script.description },
            itemPreview: { item, isSelected, isHovered in
                scriptPreviewStage(script: item.script, isSelected: isSelected, isHovered: isHovered)
            },
            bottomPanel: { bottomPanel }
        )
    }

    @ViewBuilder
    private func scriptPreviewStage(script: any StickerAnimationScript, isSelected: Bool, isHovered: Bool) -> some View {
        if isHovered || isSelected {
            SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                let cycle = StickerThumbnailRenderer.previewClipDuration
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                let frame = StickerThumbnailRenderer.renderThumbnail(
                    for: script,
                    sourceConfig: sourceStickerConfig,
                    time: max(0.0, t)
                )
                Image(nsImage: frame)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            staticHeroStage(script: script, isSelected: isSelected)
        }
    }

    private func staticHeroStage(script: any StickerAnimationScript, isSelected: Bool) -> some View {
        let heroT = StickerThumbnailRenderer.heroPreviewTime(for: script)
        let frame = StickerThumbnailRenderer.renderThumbnail(
            for: script,
            sourceConfig: sourceStickerConfig,
            time: heroT
        )
        return ZStack(alignment: .topTrailing) {
            Image(nsImage: frame)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Image(systemName: script.previewSymbolName)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(isSelected ? DSColors.toggleCyan : DSColors.accent)
                .padding(3)
        }
    }
}

private struct StickerBrowserScriptItem: Identifiable {
    let id: String
    let script: any StickerAnimationScript
}
