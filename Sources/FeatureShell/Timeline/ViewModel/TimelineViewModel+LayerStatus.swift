import Foundation
import CoreMedia
import Domain
import DesignSystem

extension TimelineViewModel {
    public func toggleLock(for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].isLocked.toggle()
        onLayerLockToggled?(layerID, layers[index].isLocked)
    }

    public func toggleHide(for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        guard layers[index].kind != .audio else { return }
        layers[index].isHidden.toggle()
        onLayerHideToggled?(layerID, layers[index].isHidden)
    }

    public func toggleMute(for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].isMuted.toggle()
        onLayerMuteToggled?(layerID, layers[index].isMuted)
    }

    public func layerHeight(for kind: ClipKind) -> CGFloat {
        kind.presentation.defaultLayerHeight
    }

    public var contentWidth: CGFloat {
        let totalSec = CMTimeGetSeconds(totalDuration)
        let totalWidth = CGFloat(totalSec) * pixelsPerSecond + TimelineZoom.trailingPadding
        return max(viewportWidth, totalWidth)
    }

    public var totalLayersHeight: CGFloat {
        layers.reduce(CGFloat.zero) { $0 + layerHeight(for: $1.kind) }
    }
}
