import Foundation

/// Cấu trúc Uniform chuẩn C-layout truyền trực tiếp vào `[[buffer(0)]]` của Metal Compute Kernel.
/// Đồng bộ byte-alignment tuyệt đối giữa Swift và Metal Shading Language (MSL).
public struct MetalEffectUniforms: Sendable, Equatable {
    public var time: Float
    public var progress: Float
    public var intensity: Float
    public var speed: Float
    public var width: Float
    public var height: Float
    public var p0: Float
    public var p1: Float
    public var p2: Float
    public var p3: Float
    public var p4: Float
    public var p5: Float
    public var p6: Float
    public var p7: Float
    public var reserved0: Float = 0
    public var reserved1: Float = 0

    public init(
        time: Float = 0, progress: Float = 0, intensity: Float = 1, speed: Float = 1,
        width: Float = 1920, height: Float = 1080,
        p0: Float = 0, p1: Float = 0, p2: Float = 0, p3: Float = 0,
        p4: Float = 0, p5: Float = 0, p6: Float = 0, p7: Float = 0
    ) {
        self.time = time; self.progress = progress; self.intensity = intensity; self.speed = speed
        self.width = width; self.height = height
        self.p0 = p0; self.p1 = p1; self.p2 = p2; self.p3 = p3
        self.p4 = p4; self.p5 = p5; self.p6 = p6; self.p7 = p7
    }
}

/// Kho mã nguồn Metal Shading Language (MSL) tích hợp sẵn cho Lõi Metal Compute Pipeline (6 Effect + 8 Dual-Texture Transition).
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng).
public enum BuiltInMetalShaders {
    public static let allKernelNames: [String] = [
        "metal_cyber_glitch", "metal_vhs_retro", "metal_thermal_vision",
        "metal_pixel_arcade", "metal_halftone_dots", "metal_shockwave_ripple",
        "metal_transition_dissolve", "metal_transition_push",
        "metal_transition_whip_pan", "metal_transition_zoom_blur",
        "metal_transition_cross_warp", "metal_transition_glitch_slice",
        "metal_transition_light_leak", "metal_transition_geometric_wipe",
        "metal_grading_hsl", "metal_grading_wheels",
        "metal_grading_rgb_curves", "metal_grading_film_grain"
    ]

    public static var librarySource: String {
        effectLibrarySource + "\n" + transitionLibrarySource + "\n" + gradingLibrarySource
    }

    public static let effectLibrarySource: String = """
    #include <metal_stdlib>
    using namespace metal;

    struct MetalEffectUniforms {
        float time; float progress; float intensity; float speed;
        float width; float height;
        float p0; float p1; float p2; float p3;
        float p4; float p5; float p6; float p7;
        float reserved0; float reserved1;
    };

    inline float hash12(float2 p) {
        float3 p3 = fract(float3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }

    inline float4 readClamped(texture2d<float, access::read> tex, float2 coord) {
        int w = int(tex.get_width());
        int h = int(tex.get_height());
        int cx = clamp(int(rint(coord.x)), 0, max(0, w - 1));
        int cy = clamp(int(rint(coord.y)), 0, max(0, h - 1));
        return tex.read(uint2(cx, cy));
    }

    // 1. Cyber RGB Glitch (p0 = rgbOffset px, p1 = pulseFreq Hz)
    kernel void metal_cyber_glitch(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float freq = max(0.5, u.p1);
        float wave = 0.65 + 0.35 * abs(sin(u.time * freq * 3.14159265));
        float band = floor(pos.y / 24.0);
        float sliceNoise = hash12(float2(band, floor(u.time * freq * 2.0)));
        float sliceJitter = (sliceNoise > 0.78) ? (sliceNoise - 0.85) * u.p0 * 2.8 : 0.0;
        float shift = u.p0 * wave + sliceJitter;

        float4 base = inTex.read(gid);
        float4 rSample = readClamped(inTex, float2(pos.x + shift, pos.y));
        float4 bSample = readClamped(inTex, float2(pos.x - shift * 0.75, pos.y));
        float scan = 0.96 + 0.04 * sin(pos.y * 1.570796);
        float3 col = float3(rSample.r, base.g, bSample.b) * scan;
        outTex.write(float4(clamp(col, 0.0, 1.0), base.a), gid);
    }

    // 2. VHS Retro Tape (p0 = scanlineStrength, p1 = colorBleed px)
    kernel void metal_vhs_retro(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float strength = clamp(u.p0, 0.0, 1.5);
        float bleed = max(0.0, u.p1);
        float trackWave = sin(pos.y * 0.03 + u.time * 8.0) * (strength * 3.5);

        float4 cCenter = readClamped(inTex, float2(pos.x + trackWave, pos.y));
        float4 cRed = readClamped(inTex, float2(pos.x + trackWave + bleed, pos.y));
        float4 cBlue = readClamped(inTex, float2(pos.x + trackWave - bleed * 0.7, pos.y));

        float3 rgb = float3(cRed.r, cCenter.g, cBlue.b);
        float luma = dot(rgb, float3(0.299, 0.587, 0.114));
        rgb = mix(float3(luma), rgb, 0.80);
        float scanline = 1.0 - strength * 0.22 * (0.5 + 0.5 * sin(pos.y * 3.14159));
        float grain = (hash12(pos + float2(u.time * 60.0, u.time * 17.0)) - 0.5) * 0.08 * strength;
        outTex.write(float4(clamp(rgb * scanline + grain, 0.0, 1.0), cCenter.a), gid);
    }

    // 3. Thermal Vision (p0 = thermalSensitivity)
    kernel void metal_thermal_vision(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float4 src = inTex.read(gid);
        float sens = clamp(u.p0, 0.3, 3.0);
        float lum = dot(src.rgb, float3(0.299, 0.587, 0.114));
        float t = clamp(pow(lum, 1.0 / sens), 0.0, 1.0);

        float3 c0 = float3(0.05, 0.02, 0.35);
        float3 c1 = float3(0.15, 0.10, 0.78);
        float3 c2 = float3(0.82, 0.12, 0.48);
        float3 c3 = float3(0.98, 0.58, 0.08);
        float3 c4 = float3(1.00, 0.96, 0.75);

        float3 heat;
        if (t < 0.25) heat = mix(c0, c1, t * 4.0);
        else if (t < 0.50) heat = mix(c1, c2, (t - 0.25) * 4.0);
        else if (t < 0.75) heat = mix(c2, c3, (t - 0.50) * 4.0);
        else heat = mix(c3, c4, (t - 0.75) * 4.0);

        outTex.write(float4(heat, src.a), gid);
    }

    // 4. Pixel Retro Arcade 8-Bit (p0 = pixelScale, p1 = colorLevels)
    kernel void metal_pixel_arcade(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float scale = max(1.0, u.p0);
        float levels = max(2.0, u.p1);
        float2 center = float2(u.width * 0.5, u.height * 0.5);
        float2 rel = float2(gid) - center;
        float2 snapped = floor(rel / scale) * scale + scale * 0.5 + center;

        float4 src = readClamped(inTex, snapped);
        float3 quant = floor(src.rgb * levels) / max(1.0, levels - 1.0);
        outTex.write(float4(clamp(quant, 0.0, 1.0), src.a), gid);
    }

    // 5. Comic Halftone Dots (p0 = comicBlend)
    kernel void metal_halftone_dots(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float4 src = inTex.read(gid);
        float blend = clamp(u.p0, 0.0, 1.0);
        float2 pos = float2(gid);

        float4 right = readClamped(inTex, pos + float2(1.5, 0.0));
        float4 down = readClamped(inTex, pos + float2(0.0, 1.5));
        float edge = length(src.rgb - right.rgb) + length(src.rgb - down.rgb);
        float ink = edge > 0.24 ? 0.08 : 1.0;

        float angle = 0.785398;
        float2 rot = float2(pos.x * cos(angle) - pos.y * sin(angle), pos.x * sin(angle) + pos.y * cos(angle));
        float2 cell = fract(rot / 7.0) - 0.5;
        float luma = dot(src.rgb, float3(0.299, 0.587, 0.114));
        float dotMask = length(cell) < (1.0 - luma) * 0.62 ? 0.68 : 1.05;
        float3 poster = floor(src.rgb * 5.0) / 4.0;
        float3 comic = clamp(poster * dotMask * ink, 0.0, 1.0);

        outTex.write(float4(mix(src.rgb, comic, blend), src.a), gid);
    }

    // 6. Shockwave Ripple (p0 = amplitude px, p1 = bandWidth)
    kernel void metal_shockwave_ripple(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float2 center = float2(u.width * 0.5, u.height * 0.5);
        float maxR = length(center);
        float2 dir = pos - center;
        float dist = length(dir);
        float normDist = dist / max(1.0, maxR);

        float radius = fract(max(0.05, u.progress) * max(0.5, u.speed));
        float band = max(0.03, u.p1);
        float diff = normDist - radius;
        float4 src = inTex.read(gid);

        if (abs(diff) < band && dist > 0.001) {
            float normDiff = diff / band;
            float profile = (1.0 - normDiff * normDiff) * sin(normDiff * 3.14159265);
            float2 unitDir = dir / dist;
            float2 offset = unitDir * profile * u.p0;
            float4 rCol = readClamped(inTex, pos + offset * 1.15);
            float4 gCol = readClamped(inTex, pos + offset);
            float4 bCol = readClamped(inTex, pos + offset * 0.85);
            outTex.write(float4(rCol.r, gCol.g, bCol.b, src.a), gid);
        } else {
            outTex.write(src, gid);
        }
    }
    """
}
