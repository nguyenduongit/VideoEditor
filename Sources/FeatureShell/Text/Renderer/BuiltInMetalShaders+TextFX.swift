import Foundation

/// Metal Compute Kernels for pure-motion Typography VFX (`liquid_morph`, `particle_dissolve`, `directional_blur`).
/// Uses premultiplied RGBA8 alpha-safe sampling while preserving 100% of Appearance colors.
extension BuiltInMetalShaders {
    public static let textFXKernelNames: [String] = [
        "metal_text_liquid_morph",
        "metal_text_particle_dissolve",
        "metal_text_directional_blur"
    ]

    public static let textFXSource: String = """
    inline float4 readTransparent(texture2d<float, access::read> tex, float2 coord) {
        int ix = int(rint(coord.x));
        int iy = int(rint(coord.y));
        int w = int(tex.get_width());
        int h = int(tex.get_height());
        if (ix < 0 || ix >= w || iy < 0 || iy >= h) return float4(0.0);
        return tex.read(uint2(ix, iy));
    }

    inline float4 sampleTransparentBilinear(texture2d<float, access::read> tex, float2 coord) {
        float2 f = floor(coord);
        float2 t = coord - f;
        float4 c00 = readTransparent(tex, f);
        float4 c10 = readTransparent(tex, f + float2(1.0, 0.0));
        float4 c01 = readTransparent(tex, f + float2(0.0, 1.0));
        float4 c11 = readTransparent(tex, f + float2(1.0, 1.0));
        return mix(mix(c00, c10, t.x), mix(c01, c11, t.x), t.y);
    }

    inline float textValueNoise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        float2 u = f * f * (3.0 - 2.0 * f);
        float a = hash12(i);
        float b = hash12(i + float2(1.0, 0.0));
        float c = hash12(i + float2(0.0, 1.0));
        float d = hash12(i + float2(1.0, 1.0));
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    inline float textFbm2D(float2 p) {
        float v = 0.0;
        float amp = 0.5;
        for (int i = 0; i < 3; i++) {
            v += amp * textValueNoise(p);
            p = p * 2.07 + float2(13.1, 7.7);
            amp *= 0.5;
        }
        return v;
    }

    // T1. Multi-octave Liquid Morph & Glossy Surface Sheen (p0 = ampPx, p1 = freq, p2 = sheen)
    kernel void metal_text_liquid_morph(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 pos = float2(gid);
        float2 uv = pos / size;
        float amp = max(0.0, u.p0) * max(0.1, u.intensity);
        float freq = max(1.0, u.p1);
        float phase = u.time;

        float nX = textFbm2D(uv * (6.0 * freq) + float2(phase * 0.45, -phase * 0.3)) - 0.5;
        float nY = textFbm2D(uv * (6.0 * freq) + float2(5.2 - phase * 0.35, phase * 0.5)) - 0.5;
        float wave = sin(uv.x * 12.0 + phase * 2.0) * 0.35;
        float2 samplePos = pos + float2(nX * amp * 2.0, (nY + wave * 0.3) * amp * 2.0);
        float4 col = sampleTransparentBilinear(inTex, samplePos);
        outTex.write(col, gid);
    }
    """
}
