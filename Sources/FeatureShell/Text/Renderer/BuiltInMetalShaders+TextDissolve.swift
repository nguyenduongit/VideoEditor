import Foundation

/// Additional Metal Compute Kernels for Typography (`hdr_bloom`, `particle_dissolve`, `directional_blur`).
extension BuiltInMetalShaders {
    public static let textDissolveSource: String = """
    // T5. Dense 7x7 Gaussian HDR Bloom over Transparent Canvas (p0 = radiusPx, p1/p2/p3 = rgb, p4 = hasCustomColor)
    kernel void metal_text_hdr_bloom(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float4 src = inTex.read(gid);
        float stepPx = clamp(u.p0 > 0.5 ? u.p0 * 0.22 : 2.2, 0.8, 3.0);
        float strength = clamp(u.intensity, 0.0, 2.5);
        if (strength <= 0.005) {
            outTex.write(src, gid);
            return;
        }

        float3 glowAccum = float3(0.0);
        float alphaAccum = 0.0;
        float weightSum = 0.0;

        for (int dy = -3; dy <= 3; dy++) {
            for (int dx = -3; dx <= 3; dx++) {
                float d2 = float(dx * dx + dy * dy);
                float w = exp(-d2 * 0.22);
                float4 s = sampleTransparentBilinear(inTex, pos + float2(float(dx), float(dy)) * stepPx);
                glowAccum += s.rgb * w;
                alphaAccum += s.a * w;
                weightSum += w;
            }
        }

        float haloA = clamp((alphaAccum / max(1.0, weightSum)) * strength * 1.15, 0.0, 1.0);
        float3 customTint = (alphaAccum > 0.01) ? clamp(glowAccum / alphaAccum, 0.0, 1.0) : float3(1.0);
        float4 halo = float4(customTint * haloA, haloA);

        float4 comp = src + halo * (1.0 - src.a);
        float coreBoost = 1.0 + min(0.35, strength * 0.16) * src.a;
        comp.rgb = clamp(comp.rgb * coreBoost, 0.0, comp.a);
        outTex.write(comp, gid);
    }

    // T6. Self-Colored Particle Dissolve Driven by Text Alpha Mask (progress = 0..1, p0 = driftAngleRad, p1 = travelPx)
    kernel void metal_text_particle_dissolve(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 pos = float2(gid);
        float2 uv = pos / size;
        float prog = clamp(u.progress, 0.0, 1.0);
        float4 src = inTex.read(gid);

        if (prog <= 0.002) {
            outTex.write(src, gid);
            return;
        }

        float n = textFbm2D(uv * 18.0 + float2(0.0, uv.x * 2.5));
        float sweptThreshold = clamp(prog * 1.25 - uv.x * 0.22, 0.0, 1.0);
        float keepMask = smoothstep(sweptThreshold - 0.06, sweptThreshold + 0.06, n);
        float burnRim = smoothstep(0.14, 0.0, abs(n - sweptThreshold)) * (1.0 - step(0.99, prog));

        float4 eroded = src * keepMask;
        float3 baseCol = (src.a > 0.01) ? clamp(src.rgb / src.a, 0.0, 1.0) : float3(1.0);
        eroded.rgb = clamp(eroded.rgb + baseCol * burnRim * src.a * 0.45, 0.0, eroded.a);

        // Drifting particles preserving exact Appearance glyph colors
        float ang = u.p0;
        float2 driftDir = float2(cos(ang), sin(ang));
        float maxTravel = (u.p1 > 1.0 ? u.p1 : 95.0);
        float4 sparkAccum = float4(0.0);

        for (int layer = 1; layer <= 4; layer++) {
            float lf = float(layer) / 4.0;
            float travel = prog * maxTravel * lf;
            float curl = sin(prog * 6.2831 + float(layer) * 2.1 + pos.y * 0.04) * 14.0 * lf;
            float2 perp = float2(-driftDir.y, driftDir.x);
            float2 emitPos = pos - driftDir * travel - perp * curl;
            float2 cell = floor(emitPos / 4.0);
            float rnd = hash12(cell + float2(float(layer) * 19.0, 3.7));
            if (rnd > 0.68) {
                float4 sEmit = readTransparent(inTex, cell * 4.0 + 2.0);
                if (sEmit.a > 0.25) {
                    float2 emitUv = (cell * 4.0 + 2.0) / size;
                    float nEmit = textFbm2D(emitUv * 18.0 + float2(0.0, emitUv.x * 2.5));
                    float emitThresh = clamp(prog * 1.25 - emitUv.x * 0.22, 0.0, 1.0);
                    if (nEmit < emitThresh && nEmit > emitThresh - 0.52) {
                        float2 jitter = (float2(rnd, fract(rnd * 17.0)) - 0.5) * 1.8;
                        float2 cellCenter = cell * 4.0 + float2(2.0) + jitter;
                        float dist = length(emitPos - cellCenter);
                        float dotA = smoothstep(2.0, 0.25, dist) * (1.0 - lf * 0.65) * (1.0 - prog * 0.35);
                        float3 sCol = clamp(sEmit.rgb / max(0.01, sEmit.a), 0.0, 1.0);
                        sparkAccum += float4(sCol * dotA, dotA) * (1.0 - sparkAccum.a);
                    }
                }
            }
        }

        float4 finalOut = eroded + sparkAccum * (1.0 - eroded.a);
        outTex.write(clamp(finalOut, 0.0, 1.0), gid);
    }

    // T7. Premultiplied-Safe Directional Motion Blur (p0 = radiusPx, p1 = angleRad)
    kernel void metal_text_directional_blur(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float radius = clamp(u.p0, 0.0, 45.0);
        if (radius <= 0.4) {
            outTex.write(inTex.read(gid), gid);
            return;
        }
        float2 pos = float2(gid);
        float2 dir = float2(cos(u.p1), sin(u.p1));
        float4 acc = float4(0.0);
        float wSum = 0.0;
        for (int i = -5; i <= 5; i++) {
            float frac = float(i) / 5.0;
            float w = exp(-frac * frac * 2.2);
            acc += sampleTransparentBilinear(inTex, pos + dir * (frac * radius)) * w;
            wSum += w;
        }
        outTex.write(acc / max(0.001, wSum), gid);
    }
    """
}
