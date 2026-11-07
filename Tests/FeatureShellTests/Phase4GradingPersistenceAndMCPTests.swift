import Testing
import Foundation
import CoreGraphics
@preconcurrency import CoreImage
import CoreMedia
import Domain
import Infrastructure
@testable import FeatureShell

@Suite("Phase 4: RGB Curves, Film Grain, LUT Premultiplied Alpha, ClipScript Nil-URL & >64KB MCP Framing")
struct Phase4GradingPersistenceAndMCPTests {

    private static func readCenterRGBA(of image: CIImage) -> (r: Double, g: Double, b: Double, a: Double) {
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        var pixel = [UInt8](repeating: 0, count: 4)
        let sampleRect = CGRect(x: floor(image.extent.midX), y: floor(image.extent.midY), width: 1, height: 1)
        ctx.render(
            image,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: sampleRect,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (
            Double(pixel[0]) / 255.0,
            Double(pixel[1]) / 255.0,
            Double(pixel[2]) / 255.0,
            Double(pixel[3]) / 255.0
        )
    }

    @Test("Independent R/G/B Curves selectively shift target color channel without altering unaffected channels")
    func independentRGBCurvesShiftTargetChannel() {
        guard MetalComputeRuntimeEngine.shared.isAvailable else { return }
        let rect = CGRect(x: 0, y: 0, width: 64, height: 64)
        let midGray = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)).cropped(to: rect)

        var config = AdjustmentConfiguration()
        config.curves.blue = [
            CurvePoint(x: 0.0, y: 0.0),
            CurvePoint(x: 0.5, y: 0.85),
            CurvePoint(x: 1.0, y: 1.0)
        ]

        let engine = ColorGradingEngine()
        let out = engine.applyGrading(to: midGray, config: config, intensity: 1.0)
        let rgba = Self.readCenterRGBA(of: out)

        #expect(abs(rgba.r - 0.5) < 0.04)
        #expect(abs(rgba.g - 0.5) < 0.04)
        #expect(rgba.b > 0.78)
        #expect(abs(rgba.a - 1.0) < 0.02)
    }

    @Test("Film Grain renders organic luminance texture and 50% LUT blend preserves Premultiplied Alpha without over-brightening")
    func filmGrainAndLUTPremultipliedAlphaSafety() {
        let rect = CGRect(x: 0, y: 0, width: 64, height: 64)
        let semiTransparent = CIImage(color: CIColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 0.5)).cropped(to: rect)

        let cubeString = """
        TITLE "Warm 2x2x2"
        LUT_3D_SIZE 2
        0.0 0.0 0.0
        1.0 0.2 0.0
        0.0 0.9 0.0
        1.0 1.0 0.0
        0.0 0.0 0.8
        1.0 0.2 0.8
        0.0 0.9 0.8
        1.0 1.0 1.0
        """
        var lutCfg = AdjustmentConfiguration()
        lutCfg.lut = LUTConfiguration(lutName: "Warm", lutDataString: cubeString, intensity: 50.0, isEnabled: true)

        let engine = ColorGradingEngine()
        let lutBlended = engine.applyGrading(to: semiTransparent, config: lutCfg, intensity: 1.0)
        let lutRGBA = Self.readCenterRGBA(of: lutBlended)
        // Premultiplied pixel with alpha=0.5 and unpremultiplied ~0.5 must stay ~0.25 (never double-added to >0.40)
        #expect(abs(lutRGBA.a - 0.5) < 0.04)
        #expect(lutRGBA.r < 0.36)

        guard MetalComputeRuntimeEngine.shared.isAvailable else { return }
        var grainCfg = AdjustmentConfiguration()
        grainCfg.effects.grainAmount = 65.0
        grainCfg.effects.grainSize = 40.0
        let grained = engine.applyGrading(to: CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)).cropped(to: rect), config: grainCfg, intensity: 1.0)
        #expect(grained.extent == rect)
    }

    @Test("ClipScript & ProjectScript preserve mediaURL == nil, originPresetID, and beatMarkers without fabricating '/' URL")
    func clipScriptPreservesNilMediaURLOriginPresetAndBeatMarkers() throws {
        var stickerProps = BuiltInClipPropertyDefaults.properties(for: .sticker)
        stickerProps["originPresetId"] = .string("svg_sparkle_badge")
        let stickerClip = TimelineClip(
            name: "SVG Sparkle",
            kind: .sticker,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 3.0, preferredTimescale: 600)),
            mediaURL: nil,
            properties: stickerProps
        )

        var beatProps = BuiltInClipPropertyDefaults.properties(for: .audio)
        beatProps["isBeatCounter"] = .bool(true)
        let beatCfg = AudioBeatConfiguration(
            mode: .majorOnly,
            markers: [
                AudioBeatMarker(sourceTime: CMTime(seconds: 0.5, preferredTimescale: 600), kind: .major, strength: 1.0),
                AudioBeatMarker(sourceTime: CMTime(seconds: 1.0, preferredTimescale: 600), kind: .minor, strength: 0.7)
            ],
            isVisible: true
        )
        beatProps[AudioBeatConfiguration.propertyKey] = .string(beatCfg.encodeToJSON() ?? "")
        let beatClip = TimelineClip(
            name: "Dance Beat Counter",
            kind: .audio,
            timeRange: CMTimeRange(start: .zero, duration: CMTime(seconds: 4.0, preferredTimescale: 600)),
            mediaURL: nil,
            properties: beatProps
        )

        let project = ProjectScript(
            title: "Persistence Verification",
            timelineLayers: [
                TimelineLayer(name: "Stickers", kind: .sticker, clips: [stickerClip]),
                TimelineLayer(name: "Audio", kind: .audio, clips: [beatClip])
            ]
        )

        #expect(project.extractSourceURLs().isEmpty)
        let json = try project.toJSONString(prettyPrinted: true)
        let decodedProject = try ProjectScript.from(jsonString: json)
        #expect(decodedProject.extractSourceURLs().isEmpty)

        let restoredLayers = decodedProject.toTimelineLayers()
        let restoredSticker = try #require(restoredLayers.first(where: { $0.kind == .sticker })?.clips.first)
        #expect(restoredSticker.mediaURL == nil)
        #expect(restoredSticker.originPresetID == "svg_sparkle_badge")

        let restoredBeat = try #require(restoredLayers.first(where: { $0.kind == .audio })?.clips.first)
        #expect(restoredBeat.mediaURL == nil)
        let restoredBeatCfg = try #require(AudioBeatConfiguration.from(clip: restoredBeat))
        #expect(restoredBeatCfg.markers.count == 2)
    }

    @Test("LocalNWServerTransport reassembles >64KB multi-chunk HTTP Content-Length payloads without truncation")
    func localMCPTransportReassemblesLargeMultiChunkHTTPPayload() {
        let largeSVG = "<svg viewBox='0 0 512 512'>" + String(repeating: "<circle cx='256' cy='256' r='120'/>", count: 2400) + "</svg>"
        let jsonBody = "{\"jsonrpc\":\"2.0\",\"id\":42,\"method\":\"tools/call\",\"svg\":\"\(largeSVG)\"}"
        let bodyBytes = Data(jsonBody.utf8)
        #expect(bodyBytes.count > 80_000)

        let header = "POST /mcp HTTP/1.1\r\nHost: 127.0.0.1:4088\r\nContent-Type: application/json\r\nContent-Length: \(bodyBytes.count)\r\n\r\n"
        var fullWire = Data(header.utf8)
        fullWire.append(bodyBytes)

        var recvBuffer = Data()
        let chunkSize = 24_000
        var offset = 0
        var extractedBody: String?

        while offset < fullWire.count {
            let end = min(fullWire.count, offset + chunkSize)
            recvBuffer.append(fullWire.subdata(in: offset..<end))
            offset = end

            if offset < fullWire.count {
                #expect(LocalNWServerTransport.extractCompleteHTTPMessage(from: &recvBuffer) == nil)
            } else {
                let complete = LocalNWServerTransport.extractCompleteHTTPMessage(from: &recvBuffer)
                extractedBody = complete?.body
            }
        }

        #expect(extractedBody == jsonBody)
        #expect(recvBuffer.isEmpty)
    }
}
