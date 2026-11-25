import Foundation

/// Unified catalog item bridging compiled `TextAnimationScript` styles and data-driven `TextAnimationGraph` presets.
public enum TextAnimationCatalogItem: Identifiable, Sendable {
    case script(any TextAnimationScript)
    case graph(TextAnimationGraph, category: TextAnimationCategory, description: String)

    public var id: String {
        switch self {
        case .script(let s): return s.id
        case .graph(let g, _, _): return g.id
        }
    }

    public var displayName: String {
        switch self {
        case .script(let s): return s.displayName
        case .graph(let g, _, _): return g.name
        }
    }

    public var description: String {
        switch self {
        case .script(let s): return s.description
        case .graph(_, _, let desc): return desc
        }
    }

    public var category: TextAnimationCategory {
        switch self {
        case .script(let s): return s.category
        case .graph(_, let cat, _): return cat
        }
    }

    public var tags: [TextAnimationCategory] {
        switch self {
        case .script(let s): return s.tags
        case .graph(_, let cat, _): return [cat]
        }
    }

    public var loopCycleDuration: Double {
        switch self {
        case .script(let s): return s.loopCycleDuration
        case .graph(let g, _, _): return g.loopCycleDuration
        }
    }

    public var scope: TextAnimationScope {
        switch self {
        case .script(let s): return s.scope
        case .graph(let g, _, _): return g.scope
        }
    }

    public var graphValue: TextAnimationGraph? {
        if case .graph(let g, _, _) = self { return g }
        return nil
    }

    public static var allItems: [TextAnimationCatalogItem] {
        let scripts = TextAnimationScriptRegistry.shared.scripts.map { TextAnimationCatalogItem.script($0) }
        let graphs = TextAnimationGraphLibrary.allGraphs.map { graph in
            TextAnimationCatalogItem.graph(
                graph,
                category: TextAnimationGraphLibrary.category(for: graph.id),
                description: TextAnimationGraphLibrary.description(for: graph.id)
            )
        }
        return scripts + graphs
    }

    public static func items(in category: TextAnimationCategory?) -> [TextAnimationCatalogItem] {
        guard let category else { return allItems }
        return allItems.filter { $0.tags.contains(category) || $0.category == category }
    }

    public static func item(for id: String) -> TextAnimationCatalogItem? {
        allItems.first { $0.id == id }
    }
}
