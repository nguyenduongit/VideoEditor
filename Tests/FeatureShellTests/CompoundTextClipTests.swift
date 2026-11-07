import Testing
import Foundation
import CoreGraphics
import CoreImage
import Domain
@testable import FeatureShell

@Suite("Unified Single-Line Text Core & Inspector Workflow Tests")
@MainActor
struct CompoundTextClipTests {

    @Test("Adding TextPreset creates a single unified TimelineClip on 1 track with unlocked 3 tabs")
    func presetCreatesSingleUnifiedClipWithUnlockedTabs() {
        let vm = TimelineViewModel(initialLayers: [])
        let preset = TextPreset.vlogBadgeBanner

        vm.addTextPreset(preset)

        let textLayers = vm.layers.filter { $0.kind == .text }
        #expect(textLayers.count == 1, "Chỉ được tạo 1 track Text duy nhất")
        let allTextClips = textLayers.flatMap(\.clips)
        #expect(allTextClips.count == 1)

        guard let clip = allTextClips.first,
              let json = clip.properties["textConfig"]?.asString,
              let decoded = TextConfiguration.decode(from: json) else {
            Issue.record("Không giải mã được textConfig từ clip")
            return
        }

        #expect(decoded.content == preset.config.content)
        #expect(decoded.background.isEnabled == true)
        #expect(clip.originPresetID == preset.id)
        #expect(clip.isLockedTemplate == false)

        let inspectorVM = InspectorViewModel(timelineViewModel: vm)
        inspectorVM.syncWithSelection()
        #expect(inspectorVM.availableTabs == ["Text", "Color", "Background", "Animation"])
    }

    @Test("Single-line sanitization flattens CR/LF newlines into clean spaces")
    func singleLineSanitizationFlattensNewlines() {
        var config = TextConfiguration(content: "Dòng 1\r\nDòng 2\nDòng 3")
        #expect(!config.content.contains("\n"))
        #expect(!config.content.contains("\r"))
        #expect(config.content == "Dòng 1 Dòng 2 Dòng 3")

        config.content = "Chào\nbạn\rmới"
        #expect(config.content == "Chào bạn mới")
    }

    @Test("InspectorViewModel updates unified TextConfiguration and syncs flat transform properties")
    func inspectorUnifiedTextWorkflow() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        timelineVM.addTextClip(named: "Main Title", config: TextConfiguration(content: "LINE ONE", textColorHex: "#FFFFFF"))
        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)
        inspectorVM.syncWithSelection()

        var updated = inspectorVM.textConfiguration
        updated.content = "TIÊU ĐỀ MỚI"
        updated.textColorHex = "#00F5D4"
        updated.positionX = 120.0
        updated.positionY = -180.0
        updated.scale = 1.35
        updated.animation.inType = .typewriter
        inspectorVM.updateTextConfiguration(updated, commit: true)

        let committed = inspectorVM.textConfiguration
        #expect(committed.content == "TIÊU ĐỀ MỚI")
        #expect(committed.textColorHex == "#00F5D4")
        #expect(committed.positionX == 120.0)
        #expect(committed.positionY == -180.0)
        #expect(committed.scale == 1.35)
        #expect(committed.animation.inType == .typewriter)
        #expect(inspectorVM.liveNumber(for: "positionX", default: 0) == 120.0)
        #expect(inspectorVM.liveNumber(for: "scale", default: 1) == 1.35)
    }

    @Test("TextConfiguration backgroundFeather JSON serialization and GPU render pipeline")
    func backgroundFeatherPropertyAndRendering() {
        var cfg = TextConfiguration(content: "CINEMATIC QUOTE", fontSize: 40.0)
        cfg.hasBackground = true
        cfg.backgroundColorHex = "#000000CC"
        cfg.backgroundPadding = 16.0
        cfg.background.featherRadius = 14.0
        cfg.background.borderWidth = 2.5
        cfg.background.borderColorHex = "#FFFFFF"
        cfg.background.hasShadow = true

        guard let json = cfg.encodeToJSON(),
              let decoded = TextConfiguration.decode(from: json) else {
            Issue.record("Mã hóa/giải mã TextConfiguration với background.featherRadius thất bại")
            return
        }
        #expect(decoded.hasBackground == true)
        #expect(decoded.background.featherRadius == 14.0)
        #expect(decoded.background.borderWidth == 2.5)
        #expect(decoded.background.hasShadow == true)

        let renderer = TextRendererEngine()
        let canvasSize = CGSize(width: 320, height: 180)
        let baseCanvas = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: canvasSize))
        let img = renderer.composite(config: decoded, over: baseCanvas, localTime: 0.5, duration: 3.0, canvasSize: canvasSize)
        #expect(img.extent == CGRect(origin: .zero, size: canvasSize))
    }

    @Test("TextConfiguration Curved Arc (-360..360) and Sine Wave CoreText vector rendering with Vietnamese & Emoji")
    func curvedArcAndSineWaveVietnameseEmojiRendering() {
        var arcCfg = TextConfiguration(content: "Đường Cong Tuyệt Đẹp 🔥", fontSize: 36.0)
        arcCfg.hasBackground = true
        arcCfg.background.paddingX = 24.0
        arcCfg.background.paddingY = 8.0
        arcCfg.curve = TextCurveStyle(shape: .arc, angleDegrees: 90.0, radiusOffset: 20.0, followTangent: true)

        guard let json = arcCfg.encodeToJSON(),
              let decoded = TextConfiguration.decode(from: json) else {
            Issue.record("Mã hóa/giải mã TextConfiguration với curved text thất bại")
            return
        }
        #expect(decoded.background.paddingX == 24.0)
        #expect(decoded.background.paddingY == 8.0)
        #expect(decoded.isCurved == true)
        #expect(decoded.curve.shape == .arc)
        #expect(decoded.curve.angleDegrees == 90.0)

        let renderer = TextRendererEngine()
        let canvasSize = CGSize(width: 480, height: 270)
        let positiveCurvedImg = renderer.renderAnimatedImage(for: decoded, localTime: 0.0, duration: 2.0, canvasSize: canvasSize)
        #expect(positiveCurvedImg != nil)

        var waveCfg = decoded
        waveCfg.curve = TextCurveStyle(shape: .wave, waveAmplitude: 32.0, wavelength: 200.0, followTangent: true)
        let waveImg = renderer.renderAnimatedImage(for: waveCfg, localTime: 0.0, duration: 2.0, canvasSize: canvasSize)
        #expect(waveImg != nil)
    }

    @Test("Switching colorFillMode and stroke fillMode from solid to linearGradient and back to solid persists accurately")
    func colorFillModeAndStrokeFillModeRoundtrip() {
        let timelineVM = TimelineViewModel(initialLayers: [])
        timelineVM.addTextClip(named: "Fill Test", config: TextConfiguration(content: "TEST", textColorHex: "#FFFFFF"))
        let inspectorVM = InspectorViewModel(timelineViewModel: timelineVM)
        inspectorVM.syncWithSelection()

        #expect(inspectorVM.textConfiguration.colorFillMode == .solid)
        #expect(inspectorVM.textConfiguration.innerStroke.fillMode == .solid)

        var toGrad = inspectorVM.textConfiguration
        toGrad.colorFillMode = .linearGradient
        toGrad.innerStroke.isEnabled = true
        toGrad.innerStroke.fillMode = .linearGradient
        inspectorVM.updateTextConfiguration(toGrad, commit: true)

        #expect(inspectorVM.textConfiguration.colorFillMode == .linearGradient)
        #expect(inspectorVM.textConfiguration.innerStroke.fillMode == .linearGradient)

        var backToSolid = inspectorVM.textConfiguration
        backToSolid.colorFillMode = .solid
        backToSolid.innerStroke.fillMode = .solid
        inspectorVM.updateTextConfiguration(backToSolid, commit: true)

        #expect(inspectorVM.textConfiguration.colorFillMode == .solid)
        #expect(inspectorVM.textConfiguration.innerStroke.fillMode == .solid)
        #expect(inspectorVM.textConfiguration.innerStroke.isGradient == false)
    }
}
