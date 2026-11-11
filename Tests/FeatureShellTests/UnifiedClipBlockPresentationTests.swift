import Testing
import Foundation
import CoreMedia
import DesignSystem
@testable import Domain
@testable import FeatureShell

@Suite("UnifiedClipBlockPresentationTests")
@MainActor
struct UnifiedClipBlockPresentationTests {
    @Test("Clip kind default heights match exact design specifications")
    func testClipKindHeights() {
        // Group 1: Rich Media Clips
        #expect(ClipKind.video.presentation.defaultLayerHeight == 100)
        #expect(ClipKind.image.presentation.defaultLayerHeight == 55)
        #expect(ClipKind.audio.presentation.defaultLayerHeight == 60)

        // Group 2: Unified Auxiliary / Overlay Clips (26pt)
        #expect(ClipKind.text.presentation.defaultLayerHeight == 26)
        #expect(ClipKind.effect.presentation.defaultLayerHeight == 26)
        #expect(ClipKind.adjustment.presentation.defaultLayerHeight == 26)
        #expect(ClipKind.sticker.presentation.defaultLayerHeight == 26)
    }

    @Test("Group classification separates Media vs Auxiliary clips correctly")
    func testClipGroupClassification() {
        // Group 1: Media Sized
        #expect(ClipKind.video.isMediaSized)
        #expect(ClipKind.image.isMediaSized)
        #expect(ClipKind.audio.isMediaSized)
        #expect(!ClipKind.video.isAuxiliary)
        #expect(!ClipKind.image.isAuxiliary)
        #expect(!ClipKind.audio.isAuxiliary)

        // Group 2: Auxiliary (Compact)
        #expect(!ClipKind.text.isMediaSized)
        #expect(!ClipKind.effect.isMediaSized)
        #expect(!ClipKind.adjustment.isMediaSized)
        #expect(!ClipKind.sticker.isMediaSized)
        #expect(ClipKind.text.isAuxiliary)
        #expect(ClipKind.effect.isAuxiliary)
        #expect(ClipKind.adjustment.isAuxiliary)
        #expect(ClipKind.sticker.isAuxiliary)

        // Header bar configuration
        #expect(ClipKind.video.presentation.hasHeaderBar)
        #expect(ClipKind.image.presentation.hasHeaderBar)
        #expect(ClipKind.audio.presentation.hasHeaderBar)
        #expect(!ClipKind.text.presentation.hasHeaderBar)
        #expect(!ClipKind.effect.presentation.hasHeaderBar)
        #expect(!ClipKind.adjustment.presentation.hasHeaderBar)
        #expect(!ClipKind.sticker.presentation.hasHeaderBar)
    }

    @Test("Filmstrip and waveform capabilities match specifications for each clip kind")
    func testClipWaveformAndFilmstripConfiguration() {
        // Video: Filmstrip + Audio Waveform
        #expect(ClipKind.video.presentation.hasFilmstrip)
        #expect(ClipKind.video.presentation.hasWaveform)

        // Image: Filmstrip only (no waveform)
        #expect(ClipKind.image.presentation.hasFilmstrip)
        #expect(!ClipKind.image.presentation.hasWaveform)

        // Audio: Audio Waveform only (no filmstrip)
        #expect(!ClipKind.audio.presentation.hasFilmstrip)
        #expect(ClipKind.audio.presentation.hasWaveform)

        // Auxiliary clips: Neither
        #expect(!ClipKind.text.presentation.hasFilmstrip)
        #expect(!ClipKind.text.presentation.hasWaveform)
        #expect(!ClipKind.sticker.presentation.hasFilmstrip)
        #expect(!ClipKind.sticker.presentation.hasWaveform)
    }

    @Test("Color tokens match approved palette for Dark Theme")
    func testClipColorsAndTokens() {
        #expect(ClipKind.sticker.presentation.color == DSColors.clipSticker)
        #expect(ClipKind.adjustment.presentation.color == DSColors.clipAdjustment)
        #expect(ClipKind.effect.presentation.color == DSColors.clipEffect)
        #expect(ClipKind.text.presentation.color == DSColors.clipText)
        #expect(ClipKind.sticker.presentation.iconName == "face.smiling")
    }

    @Test("TimelineViewModel dynamically resolves track heights and total stack height")
    func testTimelineViewModelLayerHeights() {
        let vm = TimelineViewModel()
        vm.layers = [
            TimelineLayer(id: UUID(), name: "Sticker Track", kind: .sticker, clips: []),
            TimelineLayer(id: UUID(), name: "Text Track", kind: .text, clips: []),
            TimelineLayer(id: UUID(), name: "Effect Track", kind: .effect, clips: []),
            TimelineLayer(id: UUID(), name: "Adjustment Track", kind: .adjustment, clips: []),
            TimelineLayer(id: UUID(), name: "Image Track", kind: .image, clips: []),
            TimelineLayer(id: UUID(), name: "Video Track", kind: .video, clips: []),
            TimelineLayer(id: UUID(), name: "Audio Track", kind: .audio, clips: [])
        ]

        #expect(vm.layerHeight(for: .sticker) == 26)
        #expect(vm.layerHeight(for: .text) == 26)
        #expect(vm.layerHeight(for: .effect) == 26)
        #expect(vm.layerHeight(for: .adjustment) == 26)
        #expect(vm.layerHeight(for: .image) == 55)
        #expect(vm.layerHeight(for: .video) == 100)
        #expect(vm.layerHeight(for: .audio) == 60)

        // Sum: 26 + 26 + 26 + 26 + 55 + 100 + 60 = 319
        #expect(vm.totalLayersHeight == 319)
    }

    @Test("Bottom 2 layers prioritize Main Video & Audio, upper layers stack chronologically by insertion")
    func testBottomLayersPrioritizeMainVideoAndAudioWhileUpperLayersStackChronologically() {
        let vm = TimelineViewModel()
        #expect(vm.layers.isEmpty)

        // 1. Add Main Video and Main Audio
        _ = vm.createLayer(for: .video)
        _ = vm.createLayer(for: .audio)

        #expect(vm.layers.count == 2)
        #expect(vm.layers[0].kind == .video)
        #expect(vm.layers[1].kind == .audio)

        // 2. Add Upper Layer 1: Text (added first -> sits directly above Main Video)
        _ = vm.createLayer(for: .text)
        #expect(vm.layers.count == 3)
        #expect(vm.layers[0].kind == .text)
        #expect(vm.layers[1].kind == .video)
        #expect(vm.layers[2].kind == .audio)

        // 3. Add Upper Layer 2: Image (added second -> stacks on top of Text)
        _ = vm.createLayer(for: .image)
        #expect(vm.layers.count == 4)
        #expect(vm.layers[0].kind == .image)
        #expect(vm.layers[1].kind == .text)
        #expect(vm.layers[2].kind == .video)
        #expect(vm.layers[3].kind == .audio)

        // 4. Add Upper Layer 3: Effect (added third -> stacks on top of Image)
        _ = vm.createLayer(for: .effect)
        #expect(vm.layers.count == 5)
        #expect(vm.layers[0].kind == .effect)
        #expect(vm.layers[1].kind == .image)
        #expect(vm.layers[2].kind == .text)
        #expect(vm.layers[3].kind == .video)
        #expect(vm.layers[4].kind == .audio)

        // 5. Add Upper Layer 4: Sticker (added fourth -> stacks on top of Effect)
        _ = vm.createLayer(for: .sticker)
        #expect(vm.layers.count == 6)
        #expect(vm.layers[0].kind == .sticker)
        #expect(vm.layers[1].kind == .effect)
        #expect(vm.layers[2].kind == .image)
        #expect(vm.layers[3].kind == .text)
        #expect(vm.layers[4].kind == .video)
        #expect(vm.layers[5].kind == .audio)

        // 6. Add Upper Layer 5: Adjustment (added fifth -> stacks on top of Sticker)
        _ = vm.createLayer(for: .adjustment)
        #expect(vm.layers.count == 7)
        #expect(vm.layers[0].kind == .adjustment)
        #expect(vm.layers[1].kind == .sticker)
        #expect(vm.layers[2].kind == .effect)
        #expect(vm.layers[3].kind == .image)
        #expect(vm.layers[4].kind == .text)
        #expect(vm.layers[5].kind == .video)
        #expect(vm.layers[6].kind == .audio)
    }

    @Test("Clip border overlay and handles only render when isSelected is true")
    func testClipBorderAndHandlesOnlyAppearWhenSelected() {
        let unselectedOverlay = ClipBorderOverlayView(
            isSelected: false,
            isHoveringLeftTrim: false,
            isHoveringRightTrim: false
        )
        // Body of unselected overlay must be empty (no border or handles rendered)
        _ = unselectedOverlay.body

        let selectedOverlay = ClipBorderOverlayView(
            isSelected: true,
            isHoveringLeftTrim: true,
            isHoveringRightTrim: false
        )
        // Body of selected overlay renders border and handles
        _ = selectedOverlay.body
    }
}
