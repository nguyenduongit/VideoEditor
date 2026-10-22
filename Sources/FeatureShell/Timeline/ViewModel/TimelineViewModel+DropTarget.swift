import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    public func updateDropTarget(sourceIndex: Int, movingClipKind: ClipKind, dragY: CGFloat) {
        guard !layers.isEmpty, sourceIndex >= 0, sourceIndex < layers.count else {
            if hoverLayerID != nil || dropBetweenIndex != nil {
                hoverLayerID = nil
                dropBetweenIndex = nil
            }
            return
        }

        var boundaryY: [CGFloat] = Array(repeating: 0, count: layers.count + 1)
        let sourceHeight = layerHeight(for: layers[sourceIndex].kind)

        var accUp: CGFloat = -sourceHeight / 2
        boundaryY[sourceIndex] = accUp
        for i in stride(from: sourceIndex - 1, through: 0, by: -1) {
            accUp -= layerHeight(for: layers[i].kind)
            boundaryY[i] = accUp
        }

        var accDown: CGFloat = sourceHeight / 2
        boundaryY[sourceIndex + 1] = accDown
        for i in (sourceIndex + 1)..<layers.count {
            accDown += layerHeight(for: layers[i].kind)
            boundaryY[i + 1] = accDown
        }

        var newHoverID: UUID?
        var newDropIndex: Int?

        if dragY <= boundaryY[0] {
            newDropIndex = 0
            newHoverID = nil
        } else if dragY >= boundaryY[layers.count] {
            newDropIndex = layers.count
            newHoverID = nil
        } else {
            var currentLayerIndex = sourceIndex
            for i in 0..<layers.count where dragY >= boundaryY[i] && dragY < boundaryY[i + 1] {
                currentLayerIndex = i
                break
            }

            let targetLayer = layers[currentLayerIndex]
            let isSameKind = (targetLayer.kind == movingClipKind) && !targetLayer.isLocked && !targetLayer.isHidden

            let topDist = dragY - boundaryY[currentLayerIndex]
            let bottomDist = boundaryY[currentLayerIndex + 1] - dragY

            if isSameKind {
                let edgeMargin: CGFloat = 8.0
                if topDist < edgeMargin {
                    newDropIndex = currentLayerIndex
                    newHoverID = nil
                } else if bottomDist < edgeMargin {
                    newDropIndex = currentLayerIndex + 1
                    newHoverID = nil
                } else {
                    newDropIndex = nil
                    newHoverID = targetLayer.id
                }
            } else {
                let layerH = boundaryY[currentLayerIndex + 1] - boundaryY[currentLayerIndex]
                if let existingDrop = dropBetweenIndex, existingDrop == currentLayerIndex {
                    newDropIndex = (topDist < layerH * 0.6) ? currentLayerIndex : (currentLayerIndex + 1)
                } else if let existingDrop = dropBetweenIndex, existingDrop == currentLayerIndex + 1 {
                    newDropIndex = (bottomDist < layerH * 0.6) ? (currentLayerIndex + 1) : currentLayerIndex
                } else {
                    newDropIndex = (topDist <= bottomDist) ? currentLayerIndex : (currentLayerIndex + 1)
                }
                newHoverID = nil
            }
        }

        if self.hoverLayerID != newHoverID || self.dropBetweenIndex != newDropIndex {
            self.hoverLayerID = newHoverID
            self.dropBetweenIndex = newDropIndex
        }
    }
}
