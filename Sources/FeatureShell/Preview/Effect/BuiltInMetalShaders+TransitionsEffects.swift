import Foundation

/// Mở rộng `BuiltInMetalShaders` chứa nhóm 4 họ Dual-Texture Metal Compute Kernels (T5..T8):
/// CrossWarp/Swirl/Ripple, Glitch/RGB/Static/Pixel, LightLeak/WhiteFlash/Flare/FilmBurn, và 3D/Mask/Wipe.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng).
extension BuiltInMetalShaders {
    public static let transitionEffectsAnd3DSource: String = """
    // T5. Dual-Texture Transition: Cross Warp, Swirl, Ripple & Wave (p0 = warpStrength, p2 = mode 0..5)
    kernel void metal_transition_cross_warp(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        int mode = int(rint(clamp(u.p2, 0.0, 5.0)));
        float smoothP = p * p * (3.0 - 2.0 * p);
        float env = sin(p * 3.14159265);
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 pos = float2(gid);
        float2 center = size * 0.5;
        float warp = (u.p0 > 0.0 ? u.p0 : 48.0) * env;

        if (mode == 1) {
            float2 rel = pos - center;
            float maxR = length(center);
            float factor = max(0.0, 1.0 - length(rel) / max(1.0, maxR));
            float ang = factor * factor * env * 3.8;
            float s = sin(ang); float c = cos(ang);
            float2 rot = center + float2(rel.x * c - rel.y * s, rel.x * s + rel.y * c);
            outTex.write(mix(readClamped(fromTex, rot), readClamped(toTex, rot), smoothP), gid);
            return;
        }
        if (mode == 3) {
            float stretch = 1.0 + env * 1.4;
            float2 sFrom = center + float2((pos.x - center.x) / stretch, pos.y - center.y);
            float2 sTo = center + float2((pos.x - center.x) * stretch, pos.y - center.y);
            outTex.write(mix(readClamped(fromTex, sFrom), readClamped(toTex, sTo), smoothP), gid);
            return;
        }
        if (mode == 4) {
            float2 rel = pos - center;
            float dist = length(rel);
            float2 dir = (dist > 0.001) ? (rel / dist) : float2(0.0);
            float ripple = sin(dist * 0.12 - p * 16.0) * warp * 0.45;
            outTex.write(mix(readClamped(fromTex, pos + dir * ripple), readClamped(toTex, pos - dir * ripple), smoothP), gid);
            return;
        }

        float freq = (mode == 5) ? 14.0 : ((mode == 2) ? 22.0 : 6.283185);
        float waveX = sin((pos.y / size.y) * freq + p * 6.283185);
        float waveY = (mode == 2 || mode == 5) ? cos((pos.x / size.x) * freq + p * 6.283185) * 0.6 : 0.0;
        float2 disp = float2(waveX, waveY) * warp;
        float4 cFrom = readClamped(fromTex, pos + disp * p);
        float4 cTo = readClamped(toTex, pos - disp * (1.0 - p));
        outTex.write(mix(cFrom, cTo, smoothP), gid);
    }

    // T6. Dual-Texture Transition: Glitch, RGB, TV Static, Pixel & Chromatic (p0 = sliceIntensity, p2 = mode 0..5)
    kernel void metal_transition_glitch_slice(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        int mode = int(rint(clamp(u.p2, 0.0, 5.0)));
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 pos = float2(gid);
        float env = sin(p * 3.14159265);
        float smoothP = p * p * (3.0 - 2.0 * p);
        float amp = (u.p0 > 1.0) ? u.p0 : 90.0;

        if (mode == 3) {
            float noise = hash12(pos + float2(p * 137.0, p * 293.0));
            float4 base = mix(fromTex.read(gid), toTex.read(gid), smoothP);
            float3 snow = float3(noise);
            float bar = smoothstep(0.12, 0.0, abs(fract(pos.y / size.y - p * 3.0) - 0.5));
            float3 col = mix(base.rgb, snow, env * 0.72) + bar * env * 0.25;
            outTex.write(float4(clamp(col, 0.0, 1.0), base.a), gid);
            return;
        }
        if (mode == 4) {
            float block = max(1.0, floor(1.0 + env * 0.14 * max(size.x, size.y)));
            float2 snapped = floor(pos / block) * block + block * 0.5;
            outTex.write(mix(readClamped(fromTex, snapped), readClamped(toTex, snapped), smoothP), gid);
            return;
        }
        if (mode == 5) {
            float2 center = size * 0.5;
            float2 rel = pos - center;
            float disp = 0.12 * env;
            float4 r = mix(readClamped(fromTex, center + rel * (1.0 - disp)), readClamped(toTex, center + rel * (1.0 - disp)), smoothP);
            float4 g = mix(fromTex.read(gid), toTex.read(gid), smoothP);
            float4 b = mix(readClamped(fromTex, center + rel * (1.0 + disp)), readClamped(toTex, center + rel * (1.0 + disp)), smoothP);
            outTex.write(float4(r.r, g.g, b.b, g.a), gid);
            return;
        }

        float bandH = (mode == 2) ? 16.0 : 28.0;
        float slice = floor(pos.y / bandH);
        float cellX = (mode == 2) ? floor(pos.x / 24.0) : 0.0;
        float rnd = hash12(float2(slice + cellX * 7.0, floor(p * 12.0)));
        float offset = (rnd - 0.5) * amp * env;
        float rgbShift = amp * ((mode == 1) ? 0.26 : 0.14) * env;

        bool showTo = (rnd * 0.4 + p * 0.8) > 0.5;
        texture2d<float, access::read> activeTex = showTo ? toTex : fromTex;
        float signDir = showTo ? 1.0 : -1.0;
        float4 cG = readClamped(activeTex, float2(pos.x + signDir * offset, pos.y));
        float4 cR = readClamped(activeTex, float2(pos.x + signDir * offset + rgbShift, pos.y));
        float4 cB = readClamped(activeTex, float2(pos.x + signDir * offset - rgbShift, pos.y));
        outTex.write(float4(cR.r, cG.g, cB.b, cG.a), gid);
    }

    // T7. Dual-Texture Transition: Light Effects (p0 = flareIntensity, p1 = warmth, p2 = mode 0..9)
    kernel void metal_transition_light_leak(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        int mode = int(rint(clamp(u.p2, 0.0, 9.0)));
        float flareAmp = (u.p0 > 0.05) ? u.p0 : 1.0;
        float warmth = clamp(u.p1, 0.0, 1.0);
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 uv = float2(gid) / size;
        float env = sin(p * 3.14159265);
        float4 base = mix(fromTex.read(gid), toTex.read(gid), smoothstep(0.18, 0.82, p));

        if (mode == 1) {
            float whiteFlash = pow(env, 1.35);
            float3 col = mix(base.rgb, float3(1.0, 1.0, 1.0), clamp(whiteFlash, 0.0, 1.0));
            outTex.write(float4(col, 1.0), gid);
            return;
        }
        if (mode == 2) {
            float d = length(uv - float2(0.5, 0.5));
            float burst = exp(-d * 1.4) * pow(env, 1.5) * flareAmp * 1.25;
            outTex.write(float4(clamp(base.rgb + float3(1.0, 0.99, 0.95) * burst, 0.0, 1.0), base.a), gid);
            return;
        }
        if (mode == 7) {
            float strobe = step(0.55, fract(p * 7.0)) * env;
            float3 col = mix(base.rgb, float3(1.0, 1.0, 1.0), strobe * 0.92);
            outTex.write(float4(col, 1.0), gid);
            return;
        }
        if (mode == 3) {
            float2 flarePos = float2(mix(0.2, 0.8, p), 0.45);
            float d = length(uv - flarePos);
            float streak = exp(-abs(uv.y - flarePos.y) * 18.0) * exp(-abs(uv.x - flarePos.x) * 2.5);
            float ring = smoothstep(0.04, 0.0, abs(d - 0.24)) * 0.5;
            float3 lensCol = float3(0.55, 0.85, 1.0) * (streak + ring) + float3(1.0, 0.95, 0.85) * exp(-d * 5.0);
            outTex.write(float4(clamp(base.rgb + lensCol * env * flareAmp, 0.0, 1.0), base.a), gid);
            return;
        }
        if (mode == 4 || mode == 5) {
            float2 rel = uv - float2(0.5, 0.2);
            float rays = (mode == 5) ? (0.6 + 0.4 * sin(atan2(rel.y, rel.x) * 14.0 + p * 6.0)) : 1.0;
            float glow = exp(-length(uv - float2(0.5, 0.5)) * 1.6) * rays * env * flareAmp;
            outTex.write(float4(clamp(base.rgb + float3(1.0, 0.95, 0.82) * glow * 0.85, 0.0, 1.0), base.a), gid);
            return;
        }
        if (mode == 8 || mode == 9) {
            float grid = (mode == 8) ? 14.0 : 20.0;
            float2 cell = fract(uv * grid + float2(0.0, p * 0.5)) - 0.5;
            float2 id = floor(uv * grid);
            float rnd = hash12(id);
            float sp = max(0.0, 1.0 - (abs(cell.x) + abs(cell.y)) * 6.5) * sin(p * 3.14159 + rnd * 6.28);
            float3 spCol = (mode == 8) ? float3(1.0, 0.98, 0.88) : float3(0.85, 0.95, 1.0);
            outTex.write(float4(clamp(base.rgb + spCol * max(0.0, sp) * env * 1.3, 0.0, 1.0), base.a), gid);
            return;
        }

        float sweepX = mix(-0.2, 1.2, p);
        float d1 = length(uv - float2(sweepX, 0.45));
        float d2 = length(uv - float2(1.0 - sweepX * 0.7, 0.62));
        float leak = (exp(-d1 * 3.4) + 0.65 * exp(-d2 * 4.2)) * env * flareAmp;
        float3 warmTint = (mode == 6)
            ? float3(1.0, 0.35, 0.05)
            : mix(float3(0.95, 0.75, 1.0), float3(1.0, 0.56, 0.16), warmth);
        float3 screenCol = 1.0 - (1.0 - base.rgb) * (1.0 - clamp(warmTint * leak, 0.0, 1.0));
        outTex.write(float4(clamp(screenCol, 0.0, 1.0), base.a), gid);
    }

    // T8. Dual-Texture Transition: 3D, Split & Geometric Mask (p0 = shapeMode, p1 = feather, p2 = mode 0..11)
    kernel void metal_transition_geometric_wipe(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        int mode = int(rint(clamp(u.p2, 0.0, 11.0)));
        int legacyShape = int(rint(clamp(u.p0, 0.0, 2.0)));
        float feather = clamp((u.p1 > 0.001) ? u.p1 : 0.05, 0.005, 0.35);
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 uv = float2(gid) / size;

        if (mode == 1) {
            float sc = max(0.05, p * 2.4);
            float2 q = float2((uv.x - 0.5) * 2.2 / sc, (0.55 - uv.y) * 2.2 / sc);
            float a = q.x * q.x + q.y * q.y - 1.0;
            float heart = a * a * a - q.x * q.x * q.y * q.y * q.y;
            float mask = 1.0 - smoothstep(-0.15, 0.15, heart);
            outTex.write(mix(fromTex.read(gid), toTex.read(gid), mask), gid);
            return;
        }
        if (mode == 4) {
            float distMid = abs(uv.y - 0.5);
            if (distMid < p * 0.5) {
                outTex.write(toTex.read(gid), gid);
            } else {
                float shiftY = (uv.y < 0.5) ? (uv.y + p * 0.5) : (uv.y - p * 0.5);
                outTex.write(readClamped(fromTex, float2(uv.x, shiftY) * size), gid);
            }
            return;
        }
        if (mode == 5 || mode == 6) {
            float grid = (mode == 6) ? 2.0 : 1.0;
            float2 cellUV = fract(uv * float2(2.0, grid));
            float2 shifted = cellUV - float2(0.0, 1.0 - p);
            float4 col = (shifted.y >= 0.0 && shifted.y <= 1.0) ? readClamped(toTex, float2(cellUV.x, shifted.y) * size) : fromTex.read(gid);
            outTex.write(col, gid);
            return;
        }
        if (mode == 7 || mode == 8 || mode == 10) {
            float coord = (mode == 8) ? uv.y : uv.x;
            float boundary = 1.0 - p;
            bool inFrom = (coord < boundary);
            float local = inFrom ? (coord / max(0.001, boundary)) : ((coord - boundary) / max(0.001, p));
            float shade = inFrom ? (1.0 - p * 0.45) : (0.55 + p * 0.45);
            float2 sUV = (mode == 8) ? float2(uv.x, local) : float2(local, uv.y);
            float4 c = inFrom ? readClamped(fromTex, sUV * size) : readClamped(toTex, sUV * size);
            outTex.write(float4(c.rgb * shade, c.a), gid);
            return;
        }
        if (mode == 9) {
            float diag = (uv.x + uv.y) * 0.5;
            float line = 1.0 - p;
            if (diag > line) {
                float shadow = smoothstep(line, line + 0.08, diag);
                float4 cTo = toTex.read(gid);
                outTex.write(float4(cTo.rgb * (0.65 + 0.35 * shadow), cTo.a), gid);
            } else {
                float curl = smoothstep(line - 0.06, line, diag);
                float4 cFrom = fromTex.read(gid);
                outTex.write(float4(mix(cFrom.rgb, float3(0.92), curl * 0.55), cFrom.a), gid);
            }
            return;
        }
        if (mode == 11) {
            float c = cos(p * 3.14159265);
            float absC = max(0.04, abs(c));
            float localX = (uv.x - 0.5) / absC + 0.5;
            if (localX < 0.0 || localX > 1.0) {
                outTex.write(float4(0.06, 0.06, 0.08, 1.0), gid);
            } else {
                texture2d<float, access::read> activeTex = (p < 0.5) ? fromTex : toTex;
                float4 col = readClamped(activeTex, float2(localX, uv.y) * size);
                outTex.write(float4(col.rgb * (0.4 + 0.6 * absC), col.a), gid);
            }
            return;
        }

        int shape = (mode == 2) ? 1 : ((mode == 3) ? 2 : legacyShape);
        float mask = p;
        if (shape == 0) {
            float aspect = size.x / size.y;
            float2 rel = float2((uv.x - 0.5) * aspect, uv.y - 0.5);
            float maxR = length(float2(0.5 * aspect, 0.5)) + feather;
            mask = 1.0 - smoothstep(p * maxR - feather, p * maxR + feather, length(rel));
        } else if (shape == 1) {
            float diag = (mode == 2) ? (abs(uv.x - 0.5) + abs(uv.y - 0.5)) : ((uv.x + uv.y) * 0.5);
            float edge = p * (1.0 + feather * 2.0) - feather;
            mask = 1.0 - smoothstep(edge - feather, edge + feather, diag);
        } else {
            float cell = fract(uv.x * 10.0);
            float edge = p * (1.0 + feather * 2.0) - feather;
            mask = 1.0 - smoothstep(edge - feather, edge + feather, cell);
        }
        outTex.write(mix(fromTex.read(gid), toTex.read(gid), clamp(mask, 0.0, 1.0)), gid);
    }
    """
}
