import Foundation

/// Mở rộng `BuiltInMetalShaders` chứa nhóm 4 họ Dual-Texture Metal Compute Kernels (T1..T4):
/// Dissolve/Basic, Push/Slide/Wipe, WhipPan/Blur/Camera, và Zoom/Radial/Spin.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng).
extension BuiltInMetalShaders {
    public static var transitionLibrarySource: String {
        transitionBasicAndMotionSource + "\n" + transitionEffectsAnd3DSource
    }

    public static let transitionBasicAndMotionSource: String = """
    // T1. Dual-Texture Transition: Dissolve & Basic (p0 = gammaCurve, p2 = mode 0..6)
    // mode: 0=Dissolve/Fade/Mix, 1=FadeIn, 2=FadeOut, 3=BlackFade, 4=WhiteFade, 5=Flash, 6=WhiteFlash
    kernel void metal_transition_dissolve(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        int mode = int(rint(clamp(u.p2, 0.0, 6.0)));
        float gamma = (u.p0 > 0.1) ? clamp(u.p0, 0.4, 2.5) : 1.0;
        float4 cFrom = fromTex.read(gid);
        float4 cTo = toTex.read(gid);

        if (mode == 1) {
            float fade = smoothstep(0.0, 1.0, p);
            float3 col = mix(cFrom.rgb * (1.0 - p * 0.7), cTo.rgb, fade);
            outTex.write(float4(clamp(col, 0.0, 1.0), mix(cFrom.a, cTo.a, p)), gid);
            return;
        }
        if (mode == 2) {
            float fadeOut = 1.0 - smoothstep(0.0, 0.78, p);
            float fadeIn = smoothstep(0.55, 1.0, p);
            float3 col = cFrom.rgb * fadeOut + cTo.rgb * fadeIn;
            outTex.write(float4(clamp(col, 0.0, 1.0), mix(cFrom.a, cTo.a, p)), gid);
            return;
        }
        if (mode == 3) {
            float3 col = (p < 0.5)
                ? mix(cFrom.rgb, float3(0.0), p * 2.0)
                : mix(float3(0.0), cTo.rgb, (p - 0.5) * 2.0);
            outTex.write(float4(clamp(col, 0.0, 1.0), 1.0), gid);
            return;
        }
        if (mode == 4) {
            float3 col = (p < 0.5)
                ? mix(cFrom.rgb, float3(1.0), p * 2.0)
                : mix(float3(1.0), cTo.rgb, (p - 0.5) * 2.0);
            outTex.write(float4(clamp(col, 0.0, 1.0), 1.0), gid);
            return;
        }
        if (mode == 5) {
            float3 base = mix(cFrom.rgb, cTo.rgb, smoothstep(0.2, 0.8, p));
            float env = pow(sin(p * 3.14159265), 1.8);
            float3 col = base + float3(1.0, 0.98, 0.94) * env * 1.25;
            outTex.write(float4(clamp(col, 0.0, 1.0), mix(cFrom.a, cTo.a, p)), gid);
            return;
        }
        if (mode == 6) {
            float3 base = mix(cFrom.rgb, cTo.rgb, smoothstep(0.25, 0.75, p));
            float whiteEnv = pow(sin(p * 3.14159265), 1.4);
            float3 col = mix(base, float3(1.0, 1.0, 1.0), whiteEnv);
            outTex.write(float4(clamp(col, 0.0, 1.0), 1.0), gid);
            return;
        }

        float3 linFrom = pow(max(cFrom.rgb, float3(0.0)), float3(gamma));
        float3 linTo = pow(max(cTo.rgb, float3(0.0)), float3(gamma));
        float3 blended = pow(max(mix(linFrom, linTo, p), float3(0.0)), float3(1.0 / gamma));
        outTex.write(float4(clamp(blended, 0.0, 1.0), mix(cFrom.a, cTo.a, p)), gid);
    }

    // T2. Dual-Texture Transition: Push / Slide / Wipe (p0 = dirX, p1 = dirY, p2 = mode 0:Push 1:Slide 2:Wipe)
    kernel void metal_transition_push(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        float dx = (abs(u.p0) < 0.01 && abs(u.p1) < 0.01) ? -1.0 : clamp(u.p0, -1.0, 1.0);
        float dy = clamp(u.p1, -1.0, 1.0);
        int mode = int(rint(clamp(u.p2, 0.0, 2.0)));
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 uv = float2(gid) / size;

        if (mode == 2) {
            float coord = (abs(dx) >= abs(dy))
                ? ((dx > 0.0) ? uv.x : (1.0 - uv.x))
                : ((dy > 0.0) ? uv.y : (1.0 - uv.y));
            float feather = 0.025;
            float edge = p * (1.0 + feather * 2.0) - feather;
            float mask = 1.0 - smoothstep(edge - feather, edge + feather, coord);
            outTex.write(mix(fromTex.read(gid), toTex.read(gid), mask), gid);
            return;
        }
        if (mode == 1) {
            float2 toUV = uv - float2(dx, dy) * (p - 1.0);
            if (toUV.x >= 0.0 && toUV.x <= 1.0 && toUV.y >= 0.0 && toUV.y <= 1.0) {
                outTex.write(readClamped(toTex, toUV * size), gid);
            } else {
                float2 fromUV = uv - float2(dx, dy) * p * 0.25;
                float4 cFrom = readClamped(fromTex, fromUV * size);
                outTex.write(float4(cFrom.rgb * (1.0 - p * 0.35), cFrom.a), gid);
            }
            return;
        }

        float2 shifted = uv - float2(dx, dy) * p;
        if (shifted.x >= 0.0 && shifted.x <= 1.0 && shifted.y >= 0.0 && shifted.y <= 1.0) {
            outTex.write(readClamped(fromTex, shifted * size), gid);
        } else {
            float2 toUV = fract(shifted + float2(2.0, 2.0));
            outTex.write(readClamped(toTex, toUV * size), gid);
        }
    }

    // T3. Dual-Texture Transition: Whip Pan, Blur & Camera Motion (p0 = dir, p1 = blurStrength, p2 = mode 0..7, p3 = subParam)
    kernel void metal_transition_whip_pan(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        float dir = (u.p0 >= 0.0) ? 1.0 : -1.0;
        float strength = (u.p1 > 0.05) ? u.p1 : 1.0;
        int mode = int(rint(clamp(u.p2, 0.0, 7.0)));
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 pos = float2(gid);
        float env = sin(p * 3.14159265);
        float smoothP = p * p * (3.0 - 2.0 * p);

        if (mode == 1) {
            float rad = strength * env * 0.045 * max(size.x, size.y);
            float4 acc = float4(0.0);
            for (int y = -2; y <= 2; ++y) {
                for (int x = -2; x <= 2; ++x) {
                    float2 off = float2(float(x), float(y)) * (rad * 0.5);
                    acc += mix(readClamped(fromTex, pos + off), readClamped(toTex, pos + off), smoothP);
                }
            }
            outTex.write(acc / 25.0, gid);
            return;
        }
        if (mode == 2 || mode == 3) {
            float angle = (mode == 3) ? 1.5707963 : u.p3;
            float2 blurDir = float2(cos(angle), sin(angle)) * strength * env * 0.075 * max(size.x, size.y);
            float4 acc = float4(0.0);
            for (int i = -4; i <= 4; ++i) {
                float2 off = blurDir * (float(i) / 4.0);
                acc += mix(readClamped(fromTex, pos + off), readClamped(toTex, pos + off), smoothP);
            }
            outTex.write(acc / 9.0, gid);
            return;
        }
        if (mode == 4 || mode == 7) {
            float freq = (mode == 4) ? 38.0 : 14.0;
            float amp = ((mode == 4) ? 0.065 : 0.035) * strength * env * size.x;
            float2 shake = float2(sin(p * freq), cos(p * freq * 0.77)) * amp;
            float2 center = size * 0.5;
            float2 zoomedPos = center + (pos - center) * (1.0 - 0.14 * env) + shake;
            outTex.write(mix(readClamped(fromTex, zoomedPos), readClamped(toTex, zoomedPos), smoothP), gid);
            return;
        }
        if (mode == 5 || mode == 6) {
            float2 center = size * 0.5;
            float maxAngle = (mode == 6) ? (sin(p * 6.2831853) * 0.55) : ((u.p3 > 0.7 ? 6.2831853 : 3.14159265) * smoothP * dir);
            float s = sin(maxAngle);
            float c = cos(maxAngle);
            float scale = 1.0 - 0.28 * env;
            float2 rel = (pos - center) * scale;
            float2 rotRel = float2(rel.x * c - rel.y * s, rel.x * s + rel.y * c);
            outTex.write(mix(readClamped(fromTex, center + rotRel), readClamped(toTex, center + rotRel), smoothP), gid);
            return;
        }

        float blurAmp = strength * env * 0.085 * size.x;
        float4 accum = float4(0.0);
        for (int i = -3; i <= 3; ++i) {
            float tapOffset = (float(i) / 3.0) * blurAmp;
            float sampleX = (pos.x + tapOffset) / size.x - dir * p;
            float wrappedX = fract(sampleX + 4.0);
            bool useTo = (dir > 0.0) ? (sampleX < 0.0) : (sampleX > 1.0);
            float2 sampleCoord = float2(wrappedX * size.x, pos.y);
            accum += useTo ? readClamped(toTex, sampleCoord) : readClamped(fromTex, sampleCoord);
        }
        outTex.write(accum / 7.0, gid);
    }

    // T4. Dual-Texture Transition: Zoom & Radial/Spin Blur (p0 = zoomStrength, p2 = mode 0..10)
    kernel void metal_transition_zoom_blur(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        int mode = int(rint(clamp(u.p2, 0.0, 10.0)));
        float env = sin(p * 3.14159265);
        float strength = ((u.p0 > 0.005) ? u.p0 : 0.38) * env;
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 center = size * 0.5;
        float2 rel = float2(gid) - center;
        float smoothP = p * p * (3.0 - 2.0 * p);

        if (mode == 9) {
            float4 acc = float4(0.0);
            for (int i = -3; i <= 3; ++i) {
                float ang = (float(i) / 3.0) * strength * 0.85;
                float s = sin(ang); float c = cos(ang);
                float2 rRel = float2(rel.x * c - rel.y * s, rel.x * s + rel.y * c);
                acc += mix(readClamped(fromTex, center + rRel), readClamped(toTex, center + rRel), smoothP);
            }
            outTex.write(acc / 7.0, gid);
            return;
        }
        if (mode == 10) {
            float4 acc = float4(0.0);
            for (int i = 0; i < 7; ++i) {
                float sc = 1.0 - (float(i) / 6.0) * strength * 0.65;
                acc += mix(readClamped(fromTex, center + rel * sc), readClamped(toTex, center + rel * sc), smoothP);
            }
            outTex.write(acc / 7.0, gid);
            return;
        }

        bool isZoomOut = (mode == 2 || mode == 3 || mode == 6);
        float2 shakeOff = (mode == 7) ? float2(sin(p * 36.0), cos(p * 29.0)) * env * 0.04 * size.x : float2(0.0);
        float4 accFrom = float4(0.0);
        float4 accTo = float4(0.0);
        for (int i = 0; i < 7; ++i) {
            float f = float(i) / 6.0;
            float scaleFrom = isZoomOut
                ? (1.0 + p * 0.85 + f * strength)
                : max(0.22, 1.0 - p * 0.45 - f * strength);
            float scaleTo = isZoomOut
                ? max(0.25, 0.45 + p * 0.55 - f * strength * 0.5)
                : (1.0 + (1.0 - p) * 0.55 + f * strength * 0.8);
            accFrom += readClamped(fromTex, center + rel * scaleFrom + shakeOff);
            accTo += readClamped(toTex, center + rel * scaleTo + shakeOff);
        }
        float4 col = mix(accFrom / 7.0, accTo / 7.0, smoothP);
        if (mode == 8) {
            float2 cell = fract(float2(gid) / 18.0) - 0.5;
            float star = max(0.0, 1.0 - (abs(cell.x) * 8.0 + abs(cell.y) * 8.0)) * env;
            col.rgb = clamp(col.rgb + float3(1.0, 0.96, 0.8) * star * 0.75, 0.0, 1.0);
        }
        outTex.write(col, gid);
    }
    """
}
