import Foundation
import CoreGraphics
import CoreImage
import Domain

/// Complete frame and unit timing snapshot delivered to a `TextAnimationRenderPlugin`.
public struct TextAnimationRenderPluginContext: Sendable, Equatable {
    public let localTime: Double
    public let duration: Double
    public let canvasSize: CGSize
    public let unitIndex: Int
    public let unitCount: Int

    public init(
        localTime: Double,
        duration: Double,
        canvasSize: CGSize,
        unitIndex: Int = 0,
        unitCount: Int = 1
    ) {
        self.localTime = localTime
        self.duration = duration
        self.canvasSize = canvasSize
        self.unitIndex = unitIndex
        self.unitCount = max(1, unitCount)
    }
}

/// Extension point for modular CoreImage / Metal effects driven by dynamic `TextAnimationGraph` channels.
public protocol TextAnimationRenderPlugin: Sendable {
    var id: String { get }
    var requiredChannels: Set<String> { get }

    func apply(
        to image: CIImage,
        parameters: TextAnimationParameterBag,
        context: TextAnimationRenderPluginContext
    ) -> CIImage
}

/// Immutable dependency-injected pipeline of custom text render plugins (no global mutable singleton).
public struct TextAnimationRenderPluginPipeline: Sendable {
    public let plugins: [any TextAnimationRenderPlugin]

    public init(plugins: [any TextAnimationRenderPlugin] = []) {
        self.plugins = plugins.sorted { $0.id < $1.id }
    }

    public var isEmpty: Bool { plugins.isEmpty }

    public func hasMatchingPlugin(for parameters: TextAnimationParameterBag) -> Bool {
        let channels = parameters.channelNames
        guard !channels.isEmpty else { return false }
        return plugins.contains { !$0.requiredChannels.isDisjoint(with: channels) }
    }

    public func apply(
        to image: CIImage,
        parameters: TextAnimationParameterBag,
        context: TextAnimationRenderPluginContext
    ) -> CIImage {
        let channels = parameters.channelNames
        guard !plugins.isEmpty, !channels.isEmpty else { return image }
        return plugins.reduce(image) { current, plugin in
            guard !plugin.requiredChannels.isDisjoint(with: channels) else { return current }
            return plugin.apply(to: current, parameters: parameters, context: context)
        }
    }
}
