import Foundation
import CoreMedia
import AVFoundation
import Observation
import Domain
import DesignSystem

@Observable
@MainActor
public final class TimelineViewModel {
    public var layers: [TimelineLayer] = []
    public var pixelsPerSecond: CGFloat = 60.0
    public var currentTimeProvider: (() -> CMTime)?
    private var _storedCurrentTime: CMTime = .zero
    public var currentTime: CMTime {
        get { currentTimeProvider?() ?? _storedCurrentTime }
        set { _storedCurrentTime = newValue }
    }
    public var viewportWidth: CGFloat = 1200.0

    public var draggingClipID: UUID?
    public var sourceLayerID: UUID?
    public var hoverLayerID: UUID?
    public var dropBetweenIndex: Int?
    public var selectedClipIDs: Set<UUID> = []
    public var canSplit: Bool { !selectedClipIDs.isEmpty }
    public var groupMoveOffset: CGFloat = 0
    public var onClipsDeleted: (([UUID]) -> Void)?
    public var onClipsSplit: (([UUID]) -> Void)?
    public var onClipsTrimmed: (() -> Void)?
    public var onClipsRestored: (([TimelineClip]) -> Void)?
    public var onLayerLockToggled: ((UUID, Bool) -> Void)?
    public var onLayerHideToggled: ((UUID, Bool) -> Void)?
    public var onLayerMuteToggled: ((UUID, Bool) -> Void)?
    public var aspectRatio: CanvasAspectRatio = .ratio16x9
    public var onAspectRatioChanged: ((CanvasAspectRatio) -> Void)?

    public var selectedClipID: UUID? {
        get { selectedClipIDs.first }
        set {
            if let newValue {
                selectedClipIDs = [newValue]
            } else {
                selectedClipIDs.removeAll()
            }
        }
    }

    public let thumbnailService: (any TimelineThumbnailServiceProtocol)?
    public let waveformService: (any AudioWaveformServiceProtocol)?
    public let audioAlignmentService: (any AudioAlignmentServiceProtocol)?
    public var isSyncingAudio: Bool = false
    public var onAudioSyncResult: ((Bool, String) -> Void)?
    public var commandExecutor: TimelineCommandExecutor? {
        didSet { updateUndoRedoState() }
    }
    public var isApplyingCommand: Bool = false
    public private(set) var canUndo: Bool = false
    public private(set) var canRedo: Bool = false

    public func updateUndoRedoState() {
        canUndo = commandExecutor?.canUndo ?? false
        canRedo = commandExecutor?.canRedo ?? false
    }

    @discardableResult
    public func undo() -> Bool {
        guard let executor = commandExecutor else { return false }
        let success = executor.undo()
        if success {
            onClipsTrimmed?()
        }
        return success
    }

    @discardableResult
    public func redo() -> Bool {
        guard let executor = commandExecutor else { return false }
        let success = executor.redo()
        if success {
            onClipsTrimmed?()
        }
        return success
    }

    public init(
        thumbnailService: (any TimelineThumbnailServiceProtocol)? = nil,
        waveformService: (any AudioWaveformServiceProtocol)? = nil,
        audioAlignmentService: (any AudioAlignmentServiceProtocol)? = nil,
        initialLayers: [TimelineLayer]? = nil
    ) {
        self.thumbnailService = thumbnailService
        self.waveformService = waveformService
        self.audioAlignmentService = audioAlignmentService
        self.layers = initialLayers ?? []
        self.commandExecutor = TimelineCommandExecutor(viewModel: self)
        updateUndoRedoState()
    }

    public func defaultInsertionIndex(for kind: ClipKind) -> Int {
        if kind == .audio {
            return layers.firstIndex { $0.kind.defaultTier > kind.defaultTier } ?? layers.count
        } else {
            return layers.firstIndex { $0.kind.defaultTier >= kind.defaultTier } ?? layers.count
        }
    }

    @discardableResult
    public func createLayer(for kind: ClipKind, at index: Int? = nil) -> TimelineLayer {
        let count = layers.filter { $0.kind == kind }.count + 1
        let layerName = "\(kind.title) \(count)"
        let newLayer = TimelineLayer(name: layerName, kind: kind)
        if let index, index >= 0, index <= layers.count {
            layers.insert(newLayer, at: index)
        } else {
            let targetIndex = defaultInsertionIndex(for: kind)
            layers.insert(newLayer, at: targetIndex)
        }
        return newLayer
    }

    public func addClip(_ clip: TimelineClip, to targetLayerID: UUID? = nil) {
        if let targetLayerID,
           let index = layers.firstIndex(where: { $0.id == targetLayerID && $0.kind == clip.kind && !$0.isLocked && !$0.isHidden }),
           layers[index].appendClip(clip) {
            onClipsTrimmed?()
            return
        }

        if let existingIndex = layers.firstIndex(where: { $0.kind == clip.kind && !$0.isLocked && !$0.isHidden && !$0.hasCollision(with: clip.timeRange) }) {
            layers[existingIndex].appendClip(clip)
            onClipsTrimmed?()
            return
        }

        var newLayer = createLayer(for: clip.kind)
        newLayer.appendClip(clip)
        if let index = layers.firstIndex(where: { $0.id == newLayer.id }) {
            layers[index] = newLayer
        }
        onClipsTrimmed?()
    }

    public func cleanEmptyLayers() {
        layers.removeAll(where: { $0.clips.isEmpty })
    }

    public func clip(by id: UUID) -> TimelineClip? {
        for layer in layers {
            if let clip = layer.clips.first(where: { $0.id == id }) {
                return clip
            }
        }
        return nil
    }

    public func updateClipLiveProperties(clipID: UUID, properties: [String: PropertyValue]) {
        for layerIndex in 0..<layers.count {
            if let clipIndex = layers[layerIndex].clips.firstIndex(where: { $0.id == clipID }) {
                layers[layerIndex].clips[clipIndex].properties = properties
                onClipsTrimmed?()
                return
            }
        }
    }

    public func commitClipProperties(clipID: UUID, properties: [String: PropertyValue]) {
        let cmd = TimelineCommand.updateClipProperties(clipID: clipID, properties: properties)
        commandExecutor?.execute(cmd)
    }

}
