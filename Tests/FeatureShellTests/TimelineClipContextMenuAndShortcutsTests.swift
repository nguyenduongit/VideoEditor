import Testing
import Foundation
import CoreMedia
import Domain
@testable import FeatureShell

@Suite("TimelineClipContextMenuAndShortcutsTests")
@MainActor
struct TimelineClipContextMenuAndShortcutsTests {
    private func time(_ seconds: Double) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: 600)
    }

    private func range(_ start: Double, _ duration: Double) -> CMTimeRange {
        CMTimeRange(start: time(start), duration: time(duration))
    }

    @Test("Copy, paste at playhead, cut, and Undo/Redo")
    func testCopyCutPasteAtPlayheadAndUndoRedo() throws {
        let videoClip = TimelineClip(name: "V1 Clip", kind: .video, timeRange: range(0, 4))
        let layer = TimelineLayer(name: "Video 1", kind: .video, clips: [videoClip])
        let vm = TimelineViewModel(initialLayers: [layer])

        vm.selectClip(videoClip.id)
        vm.copyClips()
        vm.pasteClips(at: time(6))

        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 2)
        let pastedAt6 = vm.layers[0].clips.first { $0.id != videoClip.id }
        let pastedClip = try #require(pastedAt6)
        #expect(abs(CMTimeGetSeconds(pastedClip.timeRange.start) - 6.0) < 0.05)
        #expect(vm.selectedClipIDs == [pastedClip.id])

        // Pasting onto occupied range creates a non-overlapping track of the same kind
        vm.pasteClips(at: time(1))
        #expect(vm.layers.count == 2)

        #expect(vm.undo())
        #expect(vm.layers.count == 1)

        vm.cutClips(targetClipID: videoClip.id)
        #expect(vm.clipboardClips.count == 1)
        #expect(vm.clip(by: videoClip.id) == nil)
        #expect(vm.undo())
        #expect(vm.clip(by: videoClip.id) != nil)
    }

    @Test("Duplicate places cloned clip at exact timestamp on new track immediately above")
    func testDuplicateClipsPlacesCopyAboveAtSameTimestampAndUndoCleansLayer() throws {
        let clip = TimelineClip(name: "Source", kind: .video, timeRange: range(2, 5))
        let baseLayer = TimelineLayer(name: "Video 1", kind: .video, clips: [clip])
        let vm = TimelineViewModel(initialLayers: [baseLayer])

        vm.selectClip(clip.id)
        vm.duplicateClips()

        #expect(vm.layers.count == 2)
        #expect(vm.layers[1].id == baseLayer.id)
        let aboveLayer = vm.layers[0]
        #expect(aboveLayer.kind == .video)
        #expect(aboveLayer.clips.count == 1)
        let dup = try #require(aboveLayer.clips.first)
        #expect(dup.id != clip.id)
        #expect(abs(CMTimeGetSeconds(dup.timeRange.start) - 2.0) < 0.02)
        #expect(abs(CMTimeGetSeconds(dup.timeRange.duration) - 5.0) < 0.02)

        #expect(vm.undo())
        #expect(vm.layers.count == 1)
        #expect(vm.layers[0].clips.count == 1)
    }

    @Test("Option-drag duplicate keeps original intact and creates clone at drop target")
    func testDuplicateClipViaDragKeepsOriginAndPlacesCopyAtTarget() throws {
        let source = TimelineClip(name: "Orig", kind: .video, timeRange: range(0, 3))
        let topLayer = TimelineLayer(name: "Video 2", kind: .video, clips: [])
        let bottomLayer = TimelineLayer(name: "Video 1", kind: .video, clips: [source])
        let vm = TimelineViewModel(initialLayers: [topLayer, bottomLayer])

        vm.duplicateClipViaDrag(
            clipID: source.id,
            from: bottomLayer.id,
            to: topLayer.id,
            insertAtIndex: nil,
            newStartTime: time(5)
        )

        #expect(vm.layers[1].clips.count == 1)
        #expect(vm.layers[1].clips[0].id == source.id)
        #expect(abs(CMTimeGetSeconds(vm.layers[1].clips[0].timeRange.start) - 0.0) < 0.02)

        #expect(vm.layers[0].clips.count == 1)
        let cloned = try #require(vm.layers[0].clips.first)
        #expect(cloned.id != source.id)
        #expect(abs(CMTimeGetSeconds(cloned.timeRange.start) - 5.0) < 0.02)

        #expect(vm.undo())
        #expect(vm.layers.flatMap(\.clips).count == 1)
        #expect(vm.clip(by: source.id) != nil)
    }

    @Test("Multi-selection Option-drag duplicate clones all selected clips with relative delta and 1-step Undo")
    func testDuplicateSelectedClipsViaDrag() throws {
        let vClip = TimelineClip(name: "V1", kind: .video, timeRange: range(0, 3))
        let aClip = TimelineClip(name: "A1", kind: .audio, timeRange: range(1, 3))
        let vm = TimelineViewModel(initialLayers: [
            TimelineLayer(name: "Video 1", kind: .video, clips: [vClip]),
            TimelineLayer(name: "Audio 1", kind: .audio, clips: [aClip])
        ])
        vm.selectedClipIDs = [vClip.id, aClip.id]
        vm.duplicateSelectedClipsViaDrag(delta: time(5))

        #expect(vm.layers.flatMap(\.clips).count == 4)
        let dupV = try #require(vm.layers.flatMap(\.clips).first { $0.kind == .video && $0.id != vClip.id })
        let dupA = try #require(vm.layers.flatMap(\.clips).first { $0.kind == .audio && $0.id != aClip.id })
        #expect(abs(CMTimeGetSeconds(dupV.timeRange.start) - 5.0) < 0.02)
        #expect(abs(CMTimeGetSeconds(dupA.timeRange.start) - 6.0) < 0.02)

        #expect(vm.undo())
        #expect(vm.layers.flatMap(\.clips).count == 2)
    }

    @Test("Copy Attributes and selective Paste Attributes preserve text content and transfer color grading")
    func testCopyAndSelectivePasteAttributes() throws {
        var srcCfg = TextConfiguration(content: "Source Text")
        srcCfg.fontName = "Impact"
        srcCfg.fontSize = 64.0
        srcCfg.textColorHex = "#FFCC00"
        let srcJson = try #require(srcCfg.encodeToJSON())

        var dstCfg = TextConfiguration(content: "Keep My Text")
        dstCfg.fontName = "Helvetica"
        dstCfg.fontSize = 36.0
        let dstJson = try #require(dstCfg.encodeToJSON())

        let srcText = TimelineClip(name: "SrcText", kind: .text, timeRange: range(0, 4))
        let dstText = TimelineClip(name: "DstText", kind: .text, timeRange: range(5, 4))
        let textLayer = TimelineLayer(name: "Text 1", kind: .text, clips: [srcText, dstText])
        let vm = TimelineViewModel(initialLayers: [textLayer])
        vm.commitClipProperties(clipID: srcText.id, properties: ["textConfig": .string(srcJson), "textContent": .string("Source Text")])
        vm.commitClipProperties(clipID: dstText.id, properties: ["textConfig": .string(dstJson), "textContent": .string("Keep My Text")])

        vm.copyAttributes(from: srcText.id)
        vm.openPasteAttributesModal(for: dstText.id)
        #expect(vm.isPasteAttributesPresented)
        #expect(vm.pasteAttributesCategories.contains(.textStyle))

        vm.selectedAttributeCategories = [.textStyle]
        vm.confirmPasteAttributes()
        #expect(!vm.isPasteAttributesPresented)

        let updatedDst = try #require(vm.clip(by: dstText.id))
        let decodedDst = try #require(updatedDst.properties["textConfig"]?.asString.flatMap { TextConfiguration.decode(from: $0) })
        #expect(decodedDst.content == "Keep My Text")
        #expect(decodedDst.fontName == "Impact")
        #expect(decodedDst.fontSize == 64.0)
        #expect(decodedDst.textColorHex == "#FFCC00")

        // Cross-kind colorGrading transfer: Adjustment -> Video
        var adjCfg = AdjustmentConfiguration()
        adjCfg.basic.contrast = 25.0
        vm.addAdjustmentClip(named: "Grade", config: adjCfg)
        let adjClip = try #require(vm.layers.flatMap(\.clips).first { $0.kind == .adjustment })
        let videoClip = TimelineClip(name: "TargetVideo", kind: .video, timeRange: range(0, 4))
        let videoLayer = TimelineLayer(name: "Video 1", kind: .video, clips: [videoClip])
        vm.layers.append(videoLayer)

        vm.copyAttributes(from: adjClip.id)
        vm.openPasteAttributesModal(for: videoClip.id)
        #expect(vm.pasteAttributesCategories.contains(.colorGrading))
        vm.selectedAttributeCategories = [.colorGrading]
        vm.confirmPasteAttributes()

        let gradedVideo = try #require(vm.clip(by: videoClip.id))
        let videoGrade = try #require(gradedVideo.properties["adjustmentConfig"]?.asString.flatMap { AdjustmentConfiguration.decode(from: $0) })
        #expect(videoGrade.basic.contrast == 25.0)
    }

    @Test("Trim to playhead, apply text style to track, mute, flip, and reset attributes")
    func testTrimToPlayheadAndContextMenuActions() throws {
        let video = TimelineClip(name: "Video", kind: .video, timeRange: range(0, 10))
        var t1Cfg = TextConfiguration(content: "Styled"); t1Cfg.fontName = "Impact"; t1Cfg.fontSize = 54.0
        var t2Cfg = TextConfiguration(content: "Plain"); t2Cfg.fontName = "Helvetica"; t2Cfg.fontSize = 32.0
        let t1 = TimelineClip(name: "T1", kind: .text, timeRange: range(0, 3))
        let t2 = TimelineClip(name: "T2", kind: .text, timeRange: range(4, 3))

        let vm = TimelineViewModel(initialLayers: [
            TimelineLayer(name: "Text 1", kind: .text, clips: [t1, t2]),
            TimelineLayer(name: "Video 1", kind: .video, clips: [video])
        ])
        vm.commitClipProperties(clipID: t1.id, properties: ["textConfig": .string(try #require(t1Cfg.encodeToJSON())), "textContent": .string("Styled")])
        vm.commitClipProperties(clipID: t2.id, properties: ["textConfig": .string(try #require(t2Cfg.encodeToJSON())), "textContent": .string("Plain")])

        vm.selectClip(video.id)
        vm.trimSelectedClipsToPlayhead(at: time(2), isStart: true)
        var trimmed = try #require(vm.clip(by: video.id))
        #expect(abs(CMTimeGetSeconds(trimmed.timeRange.start) - 2.0) < 0.02)
        #expect(abs(CMTimeGetSeconds(trimmed.timeRange.duration) - 8.0) < 0.02)
        #expect(abs(CMTimeGetSeconds(trimmed.sourceStartTime) - 2.0) < 0.02)

        vm.trimSelectedClipsToPlayhead(at: time(7), isStart: false)
        trimmed = try #require(vm.clip(by: video.id))
        #expect(abs(CMTimeGetSeconds(trimmed.timeRange.duration) - 5.0) < 0.02)

        vm.toggleClipAudioMute(clipID: video.id)
        #expect(vm.clip(by: video.id)?.properties["volume"]?.asNumber == 0.0)
        vm.toggleClipAudioMute(clipID: video.id)
        #expect((vm.clip(by: video.id)?.properties["volume"]?.asNumber ?? 0.0) > 0.5)

        vm.toggleClipFlip(clipID: video.id, horizontal: true)
        #expect(vm.clip(by: video.id)?.properties["flipHorizontal"]?.asBool == true)

        vm.applyTextStyleToAllInTrack(clipID: t1.id)
        let styledT2 = try #require(vm.clip(by: t2.id))
        let decodedT2 = try #require(styledT2.properties["textConfig"]?.asString.flatMap { TextConfiguration.decode(from: $0) })
        #expect(decodedT2.content == "Plain")
        #expect(decodedT2.fontName == "Impact")
        #expect(decodedT2.fontSize == 54.0)

        vm.resetClipAttributes(clipID: t2.id)
        let resetT2 = try #require(vm.clip(by: t2.id))
        #expect(resetT2.properties["textContent"]?.asString == "Plain")
        let resetCfg = try #require(resetT2.properties["textConfig"]?.asString.flatMap { TextConfiguration.decode(from: $0) })
        #expect(resetCfg.content == "Plain")
        #expect(resetCfg.fontName != "Impact")
    }

    @Test("Save as Preset gating allows only .text and .adjustment clips")
    func testSaveAsPresetAllowsOnlyTextAndAdjustment() {
        let vm = TimelineViewModel(initialLayers: [])
        let view = TimelineView(viewModel: vm)
        let dur = range(0, 3)

        #expect(view.savePresetKind(for: TimelineClip(name: "Text", kind: .text, timeRange: dur)) != nil)
        #expect(view.savePresetKind(for: TimelineClip(name: "Adj", kind: .adjustment, timeRange: dur)) != nil)
        #expect(view.savePresetKind(for: TimelineClip(name: "Effect", kind: .effect, timeRange: dur)) == nil)
        #expect(view.savePresetKind(for: TimelineClip(name: "Sticker", kind: .sticker, timeRange: dur)) == nil)
        #expect(view.savePresetKind(for: TimelineClip(name: "Video", kind: .video, timeRange: dur)) == nil)
        #expect(view.savePresetKind(for: TimelineClip(name: "Audio", kind: .audio, timeRange: dur)) == nil)
        #expect(view.savePresetKind(for: TimelineClip(name: "Image", kind: .image, timeRange: dur)) == nil)
    }
}
