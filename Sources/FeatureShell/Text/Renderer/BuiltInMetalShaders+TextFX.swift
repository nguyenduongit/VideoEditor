import Foundation

/// Metal Compute Kernels for pure-motion Typography VFX (`liquid_morph`, `prism_sweep`, `cyber_glitch`).
/// Uses premultiplied RGBA8 alpha-safe sampling while preserving 100% of Appearance colors.
extension BuiltInMetalShaders {
    public static let textFXKernelNames: [String] = [
        "metal_text_liquid_morph",
        "metal_text_prism_sweep",
        "metal_text_cyber_glitch",
        "metal_text_hdr_bloom",
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

    // T2. Neutral Luminance Sweep (progress = 0..1, p0 = halfWidthRatio, p1 = angleRad) preserving Appearance hue
    kernel void metal_text_prism_sweep(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 uv = float2(gid) / size;
        float4 src = inTex.read(gid);

        float ang = (abs(u.p1) > 0.01) ? u.p1 : 0.42;
        float proj = uv.x * cos(ang) + (1.0 - uv.y) * sin(ang);
        float center = mix(-0.28, 1.38, clamp(u.progress, 0.0, 1.0));
        float bandW = max(0.04, u.p0 > 0.01 ? u.p0 : 0.14);
        float d = (proj - center) / bandW;

        float core = exp(-d * d * 2.2);
        float strength = clamp(u.intensity, 0.1, 2.0);
        float boost = 1.0 + core * strength * 0.45;
        outTex.write(float4(clamp(src.rgb * boost, 0.0, src.a), src.a), gid);
    }

    // T3. Pure Geometric Scanline + Block Offset (no RGB channel color tinting)
    kernel void metal_text_cyber_glitch(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float qTime = floor(u.time * 16.0);
        float inten = clamp(u.intensity, 0.0, 2.0);

        float band = floor(pos.y / 14.0);
        float bandRnd = hash12(float2(band, qTime));
        float bandShift = (bandRnd > 0.72) ? ((bandRnd - 0.85) * 4.5 * u.p1 * inten) : 0.0;

        float2 block = floor(pos / 22.0);
        float blockRnd = hash12(block + float2(qTime * 1.7, qTime * 3.1));
        float2 blockShift = (blockRnd > 0.88) ? float2((blockRnd - 0.94) * 38.0 * inten, (fract(blockRnd * 13.0) - 0.5) * 14.0 * inten) : float2(0.0);

        float2 basePos = pos + float2(bandShift, 0.0) + blockShift;
        float4 col = sampleTransparentBilinear(inTex, basePos);
        outTex.write(col, gid);
    }
    """
}
