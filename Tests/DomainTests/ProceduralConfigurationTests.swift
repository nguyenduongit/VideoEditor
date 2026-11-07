import Testing
import Foundation
@testable import Domain

@Suite("ProceduralConfigurationTests")
struct ProceduralConfigurationTests {
    @Test("ProceduralType covers all 12 cases across 4 categories")
    func testProceduralTypeCoverage() {
        #expect(ProceduralType.allCases.count == 12)
        let categories = Set(ProceduralType.allCases.map { $0.category })
        #expect(categories.contains("Màu nền & Phông"))
        #expect(categories.contains("Nền chuyển động"))
        #expect(categories.contains("Lớp phủ điện ảnh"))
        #expect(categories.contains("Thị giác & Hiệu ứng"))
    }

    @Test("Overlays default to screen blend mode")
    func testOverlayBlendModes() {
        #expect(ProceduralType.filmGrain.defaultBlendMode == "screen")
        #expect(ProceduralType.floatingBokeh.defaultBlendMode == "screen")
        #expect(ProceduralType.lightLeaks.defaultBlendMode == "screen")
        #expect(ProceduralType.blackScreen.defaultBlendMode == "normal")
    }

    @Test("ProceduralConfiguration JSON roundtrip serialization")
    func testSerializationRoundtrip() throws {
        let original = ProceduralConfiguration(
            type: .retroGrid,
            speed: 1.5,
            intensity: 1.2,
            primaryColorHex: "#123456",
            secondaryColorHex: "#654321",
            blendMode: "normal",
            scale: 2.0,
            seed: 99,
            customParameters: ["gridRows": 24]
        )

        let json = try #require(original.encodeToJSON())
        let decoded = try #require(ProceduralConfiguration.decode(from: json))

        #expect(decoded.type == .retroGrid)
        #expect(decoded.speed == 1.5)
        #expect(decoded.intensity == 1.2)
        #expect(decoded.primaryColorHex == "#123456")
        #expect(decoded.secondaryColorHex == "#654321")
        #expect(decoded.blendMode == "normal")
        #expect(decoded.scale == 2.0)
        #expect(decoded.seed == 99)
        #expect(decoded.customParameters["gridRows"] == 24)
    }

    @Test("ProceduralConfiguration clamps invalid bounds")
    func testBoundClamping() {
        let config = ProceduralConfiguration(speed: -5.0, intensity: 10.0, scale: 0.0)
        #expect(config.speed == 0.1)
        #expect(config.intensity == 5.0)
        #expect(config.scale == 0.1)
    }
}
