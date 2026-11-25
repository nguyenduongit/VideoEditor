import Foundation

/// SDF-accelerated pure-motion Metal Compute Kernels for Typography:
/// Color-Preserving 3D Bevel Extrusion and Contour-Normal GPU Particle Scatter.
extension BuiltInMetalShaders {
    public static let textSuperFXKernelNames: [String] = [
        "metal_text_sdf_bevel_pbr",
        "metal_text_gpu_particle_scatter"
    ]

    public static let textSuperFXSource: String = """
    // Samples cached glyph SDF texture even when filter pass runs inside a symmetrically padded bounds box.
    inline float4 readAlignedSDF(
        texture2d<float, access::read> sdfTex,
        uint2 inSize,
        int2 pos
    ) {
        int sw = int(sdfTex.get_width());
        int sh = int(sdfTex.get_height());
        if (sw <= 1 || sh <= 1) return float4(128.0, 0.0, 0.0, 0.0);
        int2 offset = int2((int(inSize.x) - sw) / 2, (int(inSize.y) - sh) / 2);
        int2 sc = pos - offset;
        if (sc.x < 0 || sc.x >= sw || sc.y < 0 || sc.y >= sh) {
            return float4(128.0, 0.0, 0.0, 0.0);
        }
        return sdfTex.read(uint2(sc));
    }

    // Smooth bilinear SDF lookup for anti-aliased liquid mercury, bevel extrusion, and subpixel contours.
    inline float4 sampleAlignedSDFBilinear(
        texture2d<float, access::read> sdfTex,
        uint2 inSize,
        float2 pos
    ) {
        float2 f = floor(pos);
        float2 t = pos - f;
        int2 b = int2(f);
        float4 s00 = readAlignedSDF(sdfTex, inSize, b);
        float4 s10 = readAlignedSDF(sdfTex, inSize, b + int2(1, 0));
        float4 s01 = readAlignedSDF(sdfTex, inSize, b + int2(0, 1));
        float4 s11 = readAlignedSDF(sdfTex, inSize, b + int2(1, 1));
        return mix(mix(s00, s10, t.x), mix(s01, s11, t.x), t.y);
    }

    // S1. True 3D Bevel Extrusion & Metallic PBR Specular Glint using cached JFA SDF normals.
    // u.p0 = lightAngleRad, u.p1 = bevelDepthPx, u.p2 = metallic (0..1), u.p3 = extrudePx
    kernel void metal_text_sdf_bevel_pbr(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        texture2d<float, access::read> sdfTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        uint2 outSize = uint2(outTex.get_width(), outTex.get_height());
        if (gid.x >= outSize.x || gid.y >= outSize.y) return;

        float4 src = inTex.read(gid);
        float4 sdf = readAlignedSDF(sdfTex, outSize, int2(gid));
        float inten = clamp(u.intensity, 0.0, 2.0);
        float angle = u.p0;
        float2 light2D = float2(cos(angle), sin(angle));
        float3 L = normalize(float3(light2D.x, light2D.y, 0.68));
        float3 V = float3(0.0, 0.0, 1.0);
        float3 H = normalize(L + V);

        float extrudePx = max(0.0, u.p3) * min(1.5, inten);
        float4 extrudeCol = float4(0.0);
        if (src.a < 0.98 && extrudePx > 0.35) {
            for (int step = 1; step <= 8; step++) {
                float frac = float(step) / 8.0;
                float2 tapPos = float2(gid) + light2D * (frac * extrudePx);
                float4 tapSdf = sampleAlignedSDFBilinear(sdfTex, outSize, tapPos);
                if (tapSdf.a > 0.08) {
                    float edgeSmooth = smoothstep(0.08, 0.72, tapSdf.a);
                    float shade = mix(0.28, 0.55, 1.0 - frac);
                    float4 tapCol = sampleTransparentBilinear(inTex, tapPos);
                    float3 wallRGB = (tapCol.a > 0.02) ? clamp(tapCol.rgb / tapCol.a, 0.0, 1.0) : float3(0.25);
                    float a = edgeSmooth * (1.0 - frac * 0.28) * min(1.0, inten);
                    extrudeCol = float4(wallRGB * shade * a, a);
                    break;
                }
            }
        }

        if (src.a <= 0.005) {
            outTex.write(extrudeCol, gid);
            return;
        }

        float bevelW = max(1.5, u.p1);
        float rimT = clamp(1.0 - max(0.0, -sdf.r) / bevelW, 0.0, 1.0);
        float bevelSlope = pow(rimT, 0.72) * 1.45;
        float3 N = normalize(float3(sdf.g * bevelSlope, -sdf.b * bevelSlope, 0.85));

        float ndotl = max(0.18, dot(N, L));
        float spec = pow(max(0.0, dot(N, H)), 24.0) * 0.38;
        float fresnel = pow(clamp(1.0 - max(0.0, N.z), 0.0, 1.0), 2.2) * 0.28;

        float3 baseCol = clamp(src.rgb / src.a, 0.0, 1.0);
        float3 shaded = baseCol * mix(1.0, 0.72 + 0.42 * ndotl, min(1.0, inten))
            + baseCol * (spec + fresnel * rimT) * inten;

        float4 face = float4(clamp(shaded, 0.0, 1.0) * src.a, src.a);
        float4 comp = face + extrudeCol * (1.0 - face.a);
        outTex.write(clamp(comp, 0.0, 1.0), gid);
    }

    // S2. GPU Contour-Normal Particle Scatter preserving 100% Appearance RGB.
    // u.progress = 0..1, u.p0 = driftAngleRad, u.p1 = travelPx, u.p2 = curlAmp
    kernel void metal_text_gpu_particle_scatter(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        texture2d<float, access::read> sdfTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        uint2 outSize = uint2(outTex.get_width(), outTex.get_height());
        if (gid.x >= outSize.x || gid.y >= outSize.y) return;

        float prog = clamp(u.progress, 0.0, 1.0);
        float4 src = inTex.read(gid);
        if (prog <= 0.002) {
            outTex.write(src, gid);
            return;
        }

        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 pos = float2(gid);
        float2 uv = pos / size;
        float4 sdf = readAlignedSDF(sdfTex, outSize, int2(gid));

        float n = textFbm2D(uv * 22.0 + float2(u.time * 0.2, 1.7));
        float contourBias = clamp((-sdf.r) * 0.08, 0.0, 0.55);
        float threshold = clamp(prog * 1.32 - contourBias * 0.55, 0.0, 1.05);
        float keepMask = smoothstep(threshold - 0.07, threshold + 0.07, n);
        float burnEdge = smoothstep(0.15, 0.0, abs(n - threshold)) * (1.0 - step(0.99, prog));

        float3 selfRGB = (src.a > 0.01) ? clamp(src.rgb / src.a, 0.0, 1.0) : float3(1.0);
        float4 eroded = src * keepMask;
        eroded.rgb = clamp(eroded.rgb + selfRGB * burnEdge * src.a * 0.45, 0.0, eroded.a);

        float2 drift = float2(cos(u.p0), sin(u.p0));
        float maxTravel = max(24.0, u.p1);
        float curlAmp = max(6.0, u.p2);
        float4 sparks = float4(0.0);

        for (int layer = 1; layer <= 6; layer++) {
            float lf = float(layer) / 6.0;
            float2 perp = float2(-drift.y, drift.x);
            float curl = sin(prog * 7.5 + float(layer) * 1.7 + pos.y * 0.05) * curlAmp * lf;
            float2 backOffset = drift * (prog * maxTravel * lf) + perp * curl;
            float2 emitPos = pos - backOffset;
            float2 cell = floor(emitPos / 3.5);
            float rnd = hash12(cell + float2(float(layer) * 23.0, 9.1));
            if (rnd > 0.64) {
                int2 cPos = int2(cell * 3.5 + 1.75);
                float4 emitSrc = readTransparent(inTex, float2(cPos));
                if (emitSrc.a > 0.2) {
                    float2 eSdf = readAlignedSDF(sdfTex, outSize, cPos).gb;
                    float2 normalBurst = eSdf * (prog * 18.0 * lf);
                    float2 pCenter = cell * 3.5 + float2(1.75) + normalBurst + (float2(rnd, fract(rnd * 13.0)) - 0.5) * 1.6;
                    float dist = length(emitPos - pCenter);
                    float dotA = smoothstep(1.9, 0.2, dist) * (1.0 - lf * 0.58) * (1.0 - prog * 0.28);
                    float3 pCol = clamp(emitSrc.rgb / max(0.01, emitSrc.a), 0.0, 1.0);
                    sparks += float4(pCol * dotA, dotA) * (1.0 - sparks.a);
                }
            }
        }
        float4 outCol = eroded + sparks * (1.0 - eroded.a);
        outTex.write(clamp(outCol, 0.0, 1.0), gid);
    }
    """
}
