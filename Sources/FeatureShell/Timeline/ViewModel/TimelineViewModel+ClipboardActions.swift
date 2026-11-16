import Foundation
import CoreMedia
import Domain

extension TimelineViewModel {
    public func selectAllClips() {
        selectedTransitionID = nil
        var allIDs: Set<UUID> = []
        for layer in layers where !layer.isLocked {
            for clip in layer.clips {
                allIDs.insert(clip.id)
            }
        }
        selectedClipIDs = allIDs
    }

    public func deleteClip(id clipID: UUID) {
        if !selectedClipIDs.contains(clipID) || selectedClipIDs.count == 1 {
            selectClip(clipID)
        }
        deleteSelectedClips()
    }

    public func copyClips(targetClipID: UUID? = nil) {
        let targets = resolveActionClips(targetClipID: targetClipID, requireUnlocked: false)
        guard !targets.isEmpty else { return }
        clipboardClips = targets.map { ClipScript(from: $0.clip) }
    }

    public func cutClips(targetClipID: UUID? = nil) {
        let targets = resolveActionClips(targetClipID: targetClipID, requireUnlocked: true)
        guard !targets.isEmpty else { return }
        clipboardClips = targets.map { ClipScript(from: $0.clip) }
        let idsToRemove = targets.map(\.clip.id)
        let idSet = Set(idsToRemove)

        if let executor = commandExecutor, !isApplyingCommand {
            let cmds = idsToRemove.map { TimelineCommand.removeClip(clipID: $0) }
            executor.execute(cmds.count == 1 ? cmds[0] : .batch(commands: cmds))
            selectedClipIDs.subtract(idSet)
            cleanEmptyLayers()
            if currentTime > totalDuration { currentTime = totalDuration }
            resetZoom()
            onClipsDeleted?(idsToRemove)
        }
    }

    public func pasteClips(at playheadTime: CMTime) {
        guard !clipboardClips.isEmpty else { return }
        let minStart = clipboardClips.map { $0.timelineRange.start.cmTime }.min() ?? .zero
        let anchorTime = CMTimeMaximum(.zero, TimeRational.snapToFrame(time: playheadTime))

        var occupiedByLayer = Dictionary(uniqueKeysWithValues: layers.map { ($0.id, $0.clips.map(\.timeRange)) })
        var addCommands: [TimelineCommand] = []
        var pastedIDs: [UUID] = []

        for sourceScript in clipboardClips {
            let offset = CMTimeSubtract(sourceScript.timelineRange.start.cmTime, minStart)
            let targetStart = CMTimeMaximum(.zero, TimeRational.snapToFrame(time: CMTimeAdd(anchorTime, offset)))
            let targetRange = CMTimeRange(start: targetStart, duration: sourceScript.timelineRange.duration.cmTime)
            let newID = UUID()
            var newScript = makeCopiedScript(from: sourceScript, newID: newID, newStart: targetStart)
            newScript.timelineRange = RationalTimeRange(cmTimeRange: targetRange)

            let targetLayerID = findAvailableLayerID(for: sourceScript.kind, range: targetRange, occupiedByLayer: &occupiedByLayer)
            addCommands.append(.addClip(layerID: targetLayerID, clip: newScript))
            pastedIDs.append(newID)
        }

        executeAddCommands(addCommands, newClipIDs: pastedIDs)
    }

    public func duplicateClips(targetClipID: UUID? = nil) {
        let targets = resolveActionClips(targetClipID: targetClipID, requireUnlocked: true)
        guard !targets.isEmpty else { return }

        var addCommands: [TimelineCommand] = []
        var duplicatedIDs: [UUID] = []

        for item in targets {
            let sourceScript = ClipScript(from: item.clip)
            let newID = UUID()
            let dupScript = makeCopiedScript(from: sourceScript, newID: newID, newStart: item.clip.timeRange.start)
            let aboveLayerID = allocateNewLayerAbove(sourceLayerID: item.layerID, kind: item.clip.kind)
            addCommands.append(.addClip(layerID: aboveLayerID, clip: dupScript))
            duplicatedIDs.append(newID)
        }

        executeAddCommands(addCommands, newClipIDs: duplicatedIDs)
    }

    public func duplicateClipViaDrag(
        clipID: UUID,
        from sourceLayerID: UUID,
        to targetLayerID: UUID?,
        insertAtIndex: Int?,
        newStartTime: CMTime
    ) {
        guard let sourceClip = clip(by: clipID) else { return }
        let clampedStart = CMTimeMaximum(.zero, TimeRational.snapToFrame(time: newStartTime))
        let newRange = CMTimeRange(start: clampedStart, duration: sourceClip.timeRange.duration)
        let newID = UUID()
        let dupScript = makeCopiedScript(from: ClipScript(from: sourceClip), newID: newID, newStart: clampedStart)

        let resolvedLayerID = resolveDragDuplicateLayerID(
            kind: sourceClip.kind,
            range: newRange,
            preferredLayerID: targetLayerID ?? sourceLayerID,
            insertAtIndex: insertAtIndex
        )
        executeAddCommands([.addClip(layerID: resolvedLayerID, clip: dupScript)], newClipIDs: [newID])
    }

    public func copyAttributes(from clipID: UUID? = nil) {
        let targets = resolveActionClips(targetClipID: clipID, requireUnlocked: false)
        guard let first = targets.first else { return }
        attributeClipboardClip = first.clip
    }

    public func openPasteAttributesModal(for clipID: UUID? = nil) {
        guard let source = attributeClipboardClip else { return }
        let targets = resolveActionClips(targetClipID: clipID, requireUnlocked: true)
        guard !targets.isEmpty else { return }

        let compatible = Set(targets.flatMap {
            TimelineClipAttributeExtractor.compatibleCategories(from: source, to: $0.clip)
        })
        guard !compatible.isEmpty else { return }

        pasteAttributesTargetClipIDs = Set(targets.map(\.clip.id))
        selectedAttributeCategories = compatible
        isPasteAttributesPresented = true
    }

    public var pasteAttributesCategories: [ClipAttributeCategory] {
        guard let source = attributeClipboardClip else { return [] }
        let targets = pasteAttributesTargetClipIDs.compactMap { clip(by: $0) }
        let unionSet = Set(targets.flatMap { TimelineClipAttributeExtractor.compatibleCategories(from: source, to: $0) })
        return ClipAttributeCategory.allCases.filter { unionSet.contains($0) }
    }

    public func confirmPasteAttributes() {
        defer { isPasteAttributesPresented = false }
        guard let source = attributeClipboardClip, !selectedAttributeCategories.isEmpty else { return }

        var commands: [TimelineCommand] = []
        for targetID in pasteAttributesTargetClipIDs {
            guard let targetLayer = layers.first(where: { !$0.isLocked && $0.clips.contains(where: { $0.id == targetID }) }),
                  let targetClip = targetLayer.clips.first(where: { $0.id == targetID }) else { continue }
            let merged = TimelineClipAttributeExtractor.apply(from: source, categories: selectedAttributeCategories, to: targetClip)
            commands.append(.updateClipProperties(clipID: targetClip.id, properties: merged))
            if let trimCmd = speedTrimCommandIfNeeded(target: targetClip, newProps: merged) {
                commands.append(trimCmd)
            }
        }
        guard !commands.isEmpty, let executor = commandExecutor, !isApplyingCommand else { return }
        executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
        onClipsTrimmed?()
    }

    func resolveActionClips(targetClipID: UUID?, requireUnlocked: Bool) -> [(layerID: UUID, clip: TimelineClip)] {
        if let targetClipID, !selectedClipIDs.contains(targetClipID) {
            selectClip(targetClipID)
        }
        let targetIDs: Set<UUID> = targetClipID.map { id in
            selectedClipIDs.contains(id) ? selectedClipIDs : [id]
        } ?? selectedClipIDs

        var result: [(UUID, TimelineClip)] = []
        for layer in layers {
            if requireUnlocked && layer.isLocked { continue }
            for clip in layer.clips where targetIDs.contains(clip.id) {
                result.append((layer.id, clip))
            }
        }
        return result
    }

    private func makeCopiedScript(from source: ClipScript, newID: UUID, newStart: CMTime) -> ClipScript {
        ClipScript(
            id: newID,
            assetID: source.assetID,
            name: source.name,
            kind: source.kind,
            source: source.source,
            timelineRange: RationalTimeRange(cmTimeRange: CMTimeRange(start: newStart, duration: source.timelineRange.duration.cmTime)),
            sourceStartTime: source.sourceStartTime,
            maxDuration: source.maxDuration,
            opacity: source.opacity,
            volume: source.volume,
            originPresetID: source.originPresetID,
            beatMarkers: source.beatMarkers,
            properties: source.properties
        )
    }

    private func findAvailableLayerID(
        for kind: ClipKind,
        range: CMTimeRange,
        occupiedByLayer: inout [UUID: [CMTimeRange]]
    ) -> UUID {
        for layer in layers where layer.kind == kind && !layer.isLocked && !layer.isHidden {
            let ranges = occupiedByLayer[layer.id] ?? []
            let collides = ranges.contains { CMTimeMaximum($0.start, range.start) < CMTimeMinimum($0.end, range.end) }
            if !collides {
                occupiedByLayer[layer.id, default: []].append(range)
                return layer.id
            }
        }
        let newID = UUID()
        occupiedByLayer[newID] = [range]
        return newID
    }

    private func allocateNewLayerAbove(sourceLayerID: UUID, kind: ClipKind) -> UUID {
        let count = layers.filter { $0.kind == kind }.count + 1
        let newLayer = TimelineLayer(name: "\(kind.title) \(count)", kind: kind)
        let sourceIndex = layers.firstIndex(where: { $0.id == sourceLayerID }) ?? 0
        layers.insert(newLayer, at: sourceIndex)
        return newLayer.id
    }

    private func resolveDragDuplicateLayerID(
        kind: ClipKind,
        range: CMTimeRange,
        preferredLayerID: UUID,
        insertAtIndex: Int?
    ) -> UUID {
        if let insertAtIndex, insertAtIndex >= 0, insertAtIndex <= layers.count {
            return createLayer(for: kind, at: insertAtIndex).id
        }
        if let idx = layers.firstIndex(where: { $0.id == preferredLayerID && $0.kind == kind && !$0.isLocked && !$0.isHidden }),
           !layers[idx].hasCollision(with: range) {
            return preferredLayerID
        }
        if let open = layers.first(where: { $0.kind == kind && !$0.isLocked && !$0.isHidden && !$0.hasCollision(with: range) }) {
            return open.id
        }
        return createLayer(for: kind).id
    }

    private func executeAddCommands(_ commands: [TimelineCommand], newClipIDs: [UUID]) {
        guard !commands.isEmpty else { return }
        if let executor = commandExecutor, !isApplyingCommand {
            let success = executor.execute(commands.count == 1 ? commands[0] : .batch(commands: commands))
            if success {
                selectedTransitionID = nil
                selectedClipIDs = Set(newClipIDs)
            } else {
                cleanEmptyLayers()
            }
        }
    }

    private func speedTrimCommandIfNeeded(target: TimelineClip, newProps: [String: PropertyValue]) -> TimelineCommand? {
        guard target.kind == .video || target.kind == .audio else { return nil }
        let oldSpeed = max(0.01, target.properties["speed"]?.asNumber ?? 1.0)
        let newSpeed = max(0.01, newProps["speed"]?.asNumber ?? 1.0)
        guard abs(oldSpeed - newSpeed) > 0.001 else { return nil }
        let targetDurSec = max(0.1, (CMTimeGetSeconds(target.timeRange.duration) * oldSpeed) / newSpeed)
        let targetDuration = CMTime(seconds: targetDurSec, preferredTimescale: max(600, target.timeRange.duration.timescale))
        return .trimClip(
            clipID: target.id,
            newStart: RationalTime(cmTime: target.timeRange.start),
            newDuration: RationalTime(cmTime: targetDuration),
            newSourceStart: RationalTime(cmTime: target.sourceStartTime)
        )
    }
}
