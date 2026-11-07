import Foundation

/// Mở rộng `BuiltInMetalShaders` chứa đủ 8 họ Dual-Texture Metal Compute Kernels chuyển cảnh thời gian thực.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng).
extension BuiltInMetalShaders {
    public static let transitionLibrarySource: String = """
    // T1. Dual-Texture Transition: Dissolve (p0 = gammaCurve, default 1.0)
    kernel void metal_transition_dissolve(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        float gamma = (u.p0 > 0.1) ? clamp(u.p0, 0.4, 2.5) : 1.0;
        float4 cFrom = fromTex.read(gid);
        float4 cTo = toTex.read(gid);
        float3 linFrom = pow(max(cFrom.rgb, float3(0.0)), float3(gamma));
        float3 linTo = pow(max(cTo.rgb, float3(0.0)), float3(gamma));
        float3 blended = pow(max(mix(linFrom, linTo, p), float3(0.0)), float3(1.0 / gamma));
        outTex.write(float4(clamp(blended, 0.0, 1.0), mix(cFrom.a, cTo.a, p)), gid);
    }

    // T2. Dual-Texture Transition: Directional Push / Slide (p0 = dirX, p1 = dirY)
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
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 uv = float2(gid) / size;
        float2 shifted = uv - float2(dx, dy) * p;

        if (shifted.x >= 0.0 && shifted.x <= 1.0 && shifted.y >= 0.0 && shifted.y <= 1.0) {
            outTex.write(readClamped(fromTex, shifted * size), gid);
        } else {
            float2 toUV = fract(shifted + float2(2.0, 2.0));
            outTex.write(readClamped(toTex, toUV * size), gid);
        }
    }

    // T3. Dual-Texture Transition: Whip Pan (p0 = direction -1/+1, p1 = blurStrength)
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
        float blurAmp = ((u.p1 > 0.05) ? u.p1 : 1.0) * sin(p * 3.14159265) * 0.085 * u.width;
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 pos = float2(gid);

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

    // T4. Dual-Texture Transition: Zoom Blur (p0 = zoomStrength)
    kernel void metal_transition_zoom_blur(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        float strength = ((u.p0 > 0.01) ? u.p0 : 0.38) * sin(p * 3.14159265);
        float2 center = float2(u.width * 0.5, u.height * 0.5);
        float2 rel = float2(gid) - center;

        float4 accFrom = float4(0.0);
        float4 accTo = float4(0.0);
        for (int i = 0; i < 7; ++i) {
            float f = float(i) / 6.0;
            float scaleFrom = max(0.25, 1.0 - p * 0.35 - f * strength);
            float scaleTo = 1.0 + (1.0 - p) * 0.45 + f * strength * 0.8;
            accFrom += readClamped(fromTex, center + rel * scaleFrom);
            accTo += readClamped(toTex, center + rel * scaleTo);
        }
        float smoothP = p * p * (3.0 - 2.0 * p);
        outTex.write(mix(accFrom / 7.0, accTo / 7.0, smoothP), gid);
    }

    // T5. Dual-Texture Transition: Cross Warp (p0 = warpStrength)
    kernel void metal_transition_cross_warp(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        float smoothP = p * p * (3.0 - 2.0 * p);
        float2 pos = float2(gid);
        float warp = (u.p0 > 0.0 ? u.p0 : 48.0) * sin(p * 3.14159265);
        float wave = sin((pos.y / max(1.0, u.height)) * 6.283185 + p * 3.14159);

        float4 cFrom = readClamped(fromTex, pos + float2(warp * p * wave, 0.0));
        float4 cTo = readClamped(toTex, pos - float2(warp * (1.0 - p) * wave, 0.0));
        outTex.write(mix(cFrom, cTo, smoothP), gid);
    }

    // T6. Dual-Texture Transition: Glitch Slice (p0 = sliceIntensity px)
    kernel void metal_transition_glitch_slice(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        float2 pos = float2(gid);
        float slice = floor(pos.y / 28.0);
        float rnd = hash12(float2(slice, floor(p * 12.0)));
        float envelope = sin(p * 3.14159265);
        float amp = (u.p0 > 1.0) ? u.p0 : 90.0;
        float offset = (rnd - 0.5) * amp * envelope;
        float rgbShift = amp * 0.14 * envelope;

        bool showTo = (rnd * 0.4 + p * 0.8) > 0.5;
        texture2d<float, access::read> activeTex = showTo ? toTex : fromTex;
        float signDir = showTo ? 1.0 : -1.0;
        float4 cG = readClamped(activeTex, float2(pos.x + signDir * offset, pos.y));
        float4 cR = readClamped(activeTex, float2(pos.x + signDir * offset + rgbShift, pos.y));
        float4 cB = readClamped(activeTex, float2(pos.x + signDir * offset - rgbShift, pos.y));
        outTex.write(float4(cR.r, cG.g, cB.b, cG.a), gid);
    }

    // T7. Dual-Texture Transition: Light Leak (p0 = flareIntensity, p1 = warmth)
    kernel void metal_transition_light_leak(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        float flareAmp = (u.p0 > 0.05) ? u.p0 : 1.0;
        float warmth = clamp((u.p1 > 0.01) ? u.p1 : 0.85, 0.0, 1.0);
        float2 uv = float2(gid) / float2(max(1.0, u.width), max(1.0, u.height));

        float sweepX = mix(-0.2, 1.2, p);
        float d1 = length(uv - float2(sweepX, 0.45));
        float d2 = length(uv - float2(1.0 - sweepX * 0.7, 0.62));
        float envelope = sin(p * 3.14159265);
        float leak = (exp(-d1 * 3.4) + 0.65 * exp(-d2 * 4.2)) * envelope * flareAmp;

        float4 base = mix(fromTex.read(gid), toTex.read(gid), smoothstep(0.18, 0.82, p));
        float3 warmTint = mix(float3(0.95, 0.75, 1.0), float3(1.0, 0.56, 0.16), warmth);
        float3 screenCol = 1.0 - (1.0 - base.rgb) * (1.0 - clamp(warmTint * leak, 0.0, 1.0));
        outTex.write(float4(clamp(screenCol, 0.0, 1.0), base.a), gid);
    }

    // T8. Dual-Texture Transition: Geometric Wipe (p0 = shapeMode 0:Circle 1:Diagonal 2:Blinds, p1 = feather)
    kernel void metal_transition_geometric_wipe(
        texture2d<float, access::read> fromTex [[texture(0)]],
        texture2d<float, access::read> toTex [[texture(1)]],
        texture2d<float, access::write> outTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float p = clamp(u.progress, 0.0, 1.0);
        int mode = int(rint(clamp(u.p0, 0.0, 2.0)));
        float feather = clamp((u.p1 > 0.001) ? u.p1 : 0.06, 0.005, 0.35);
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 uv = float2(gid) / size;

        float mask = p;
        if (mode == 0) {
            float aspect = size.x / size.y;
            float2 rel = float2((uv.x - 0.5) * aspect, uv.y - 0.5);
            float maxR = length(float2(0.5 * aspect, 0.5)) + feather;
            float dist = length(rel);
            mask = 1.0 - smoothstep(p * maxR - feather, p * maxR + feather, dist);
        } else if (mode == 1) {
            float diag = (uv.x + uv.y) * 0.5;
            float edge = p * (1.0 + feather * 2.0) - feather;
            mask = 1.0 - smoothstep(edge - feather, edge + feather, diag);
        } else {
            float cell = fract(uv.x * 10.0);
            float edge = p * (1.0 + feather * 2.0) - feather;
            mask = 1.0 - smoothstep(edge - feather, edge + feather, cell);
        }

        float4 cFrom = fromTex.read(gid);
        float4 cTo = toTex.read(gid);
        outTex.write(mix(cFrom, cTo, clamp(mask, 0.0, 1.0)), gid);
    }
    """
}
