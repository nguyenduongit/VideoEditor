import Foundation
extension BuiltInMetalShaders {
    public static let natureParticlesKernelNames: [String] = [
        "metal_effect_falling_leaves",
        "metal_effect_petals",
        "metal_effect_floating_dust",
        "metal_effect_fireflies",
        "metal_effect_embers_sparks",
        "metal_effect_floating_bubbles"
    ]
    public static let natureParticlesSource: String = """
    kernel void metal_effect_falling_leaves(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float4 base = inTex.read(gid);
        float speed = max(0.2, (u.p1 > 0.0 ? u.p1 : 1.0) * u.speed);
        float t = u.time * speed;
        float density = clamp(u.p0 > 0.0 ? u.p0 : 1.0, 0.2, 3.0) * u.intensity;
        float cellSize = 55.0;
        float yFall = (u.height - pos.y) + t * 140.0;
        float xSway = pos.x + sin((u.height - pos.y) * 0.015 + t * 2.2) * 35.0;
        float2 samplePos = float2(xSway, yFall);
        float2 cell = floor(samplePos / cellSize);
        float rnd = hash12(cell);
        float leafAlpha = 0.0;
        float3 leafCol = float3(0.9, 0.5, 0.1);
        if (rnd > (1.0 - 0.25 * density)) {
            float2 cellCenter = cell * cellSize + float2(fract(rnd * 13.0) * 35.0 + 10.0, fract(rnd * 29.0) * 35.0 + 10.0);
            float2 delta = samplePos - cellCenter;
            float angle = sin(t * 2.5 + rnd * 6.28) * 0.9 + rnd * 3.14;
            float cosA = cos(angle);
            float sinA = sin(angle);
            float2 rot = float2(delta.x * cosA - delta.y * sinA, delta.x * sinA + delta.y * cosA);
            float tumble = 0.35 + 0.65 * abs(cos(t * 3.2 + rnd * 6.28));
            float leafLength = 14.0 * (0.8 + 0.4 * fract(rnd * 7.0));
            float leafWidth = 7.5 * tumble * (0.8 + 0.4 * fract(rnd * 7.0));
            float nx = rot.x / leafLength;
            float ny = rot.y / max(1.0, leafWidth);
            float taper = max(0.1, 1.0 - 0.45 * (nx * nx));
            float shapeDist = (nx * nx) + (ny * ny) / taper;
            if (shapeDist < 1.0) {
                leafAlpha = smoothstep(1.0, 0.75, shapeDist);
                float colPick = fract(rnd * 19.0);
                if (colPick < 0.33) {
                    leafCol = mix(float3(0.95, 0.68, 0.12), float3(0.85, 0.38, 0.08), abs(nx));
                } else if (colPick < 0.66) {
                    leafCol = mix(float3(0.82, 0.22, 0.10), float3(0.55, 0.12, 0.05), abs(nx));
                } else {
                    leafCol = mix(float3(0.72, 0.45, 0.15), float3(0.48, 0.28, 0.10), abs(nx));
                }
                if (abs(rot.y) < 0.8 && abs(nx) < 0.85) {
                    leafCol *= 0.75;
                }
            }
        }
        float3 outRgb = mix(base.rgb, leafCol, clamp(leafAlpha * 0.92, 0.0, 1.0));
        outTex.write(float4(clamp(outRgb, 0.0, 1.0), base.a), gid);
    }
    kernel void metal_effect_petals(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float4 base = inTex.read(gid);
        float speed = max(0.2, (u.p1 > 0.0 ? u.p1 : 1.0) * u.speed);
        float t = u.time * speed;
        float density = clamp(u.p0 > 0.0 ? u.p0 : 1.0, 0.2, 3.0) * u.intensity;
        float cellSize = 48.0;
        float yFall = (u.height - pos.y) + t * 95.0;
        float xDrift = pos.x + sin((u.height - pos.y) * 0.012 + t * 1.6) * 45.0 + cos(t * 0.8) * 15.0;
        float2 samplePos = float2(xDrift, yFall);
        float2 cell = floor(samplePos / cellSize);
        float rnd = hash12(cell);
        float petalAlpha = 0.0;
        float3 petalCol = float3(1.0, 0.76, 0.84);
        if (rnd > (1.0 - 0.22 * density)) {
            float2 cellCenter = cell * cellSize + float2(fract(rnd * 11.0) * 30.0 + 8.0, fract(rnd * 23.0) * 30.0 + 8.0);
            float2 delta = samplePos - cellCenter;
            float angle = sin(t * 1.8 + rnd * 6.28) * 0.8 + rnd * 3.14;
            float cosA = cos(angle);
            float sinA = sin(angle);
            float2 rot = float2(delta.x * cosA - delta.y * sinA, delta.x * sinA + delta.y * cosA);
            float tumble = 0.4 + 0.6 * abs(cos(t * 2.4 + rnd * 6.28));
            float pRadius = 11.0 * (0.85 + 0.3 * fract(rnd * 5.0));
            float nx = rot.x / max(1.0, pRadius * tumble);
            float ny = rot.y / pRadius;
            float notch = (ny > 0.0) ? (0.35 * exp(-8.0 * nx * nx) * ny) : 0.0;
            float dist = (nx * nx) + (ny * ny) + notch;
            if (dist < 1.0) {
                petalAlpha = smoothstep(1.0, 0.7, dist);
                float rad = length(float2(nx, ny));
                petalCol = mix(float3(1.0, 0.88, 0.92), float3(0.96, 0.65, 0.78), rad * 0.8);
            }
        }
        float3 outRgb = mix(base.rgb, petalCol, clamp(petalAlpha * 0.86, 0.0, 1.0));
        outTex.write(float4(clamp(outRgb, 0.0, 1.0), base.a), gid);
    }
    kernel void metal_effect_floating_dust(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float4 base = inTex.read(gid);
        float speed = max(0.1, (u.p1 > 0.0 ? u.p1 : 1.0) * u.speed);
        float t = u.time * speed;
        float density = clamp(u.p0 > 0.0 ? u.p0 : 1.0, 0.2, 3.0) * u.intensity;
        float cellSize = 38.0;
        float2 wander = float2(sin(t * 0.4 + pos.y * 0.01) * 20.0, cos(t * 0.35 + pos.x * 0.01) * 18.0 - t * 15.0);
        float2 samplePos = pos + wander;
        float2 cell = floor(samplePos / cellSize);
        float rnd = hash12(cell);
        float dustLight = 0.0;
        if (rnd > (1.0 - 0.28 * density)) {
            float2 moteCenter = cell * cellSize + float2(fract(rnd * 17.0) * 26.0 + 6.0, fract(rnd * 31.0) * 26.0 + 6.0);
            float dist = length(samplePos - moteCenter);
            float moteRadius = 3.5 + fract(rnd * 13.0) * 5.0;
            float shimmer = 0.7 + 0.3 * sin(t * 3.0 + rnd * 20.0);
            dustLight = exp(-(dist * dist) / (2.0 * moteRadius * moteRadius)) * shimmer;
        }
        float3 dustCol = float3(1.0, 0.92, 0.75) * dustLight * 0.75;
        float3 outRgb = base.rgb + dustCol;
        outTex.write(float4(clamp(outRgb, 0.0, 1.0), base.a), gid);
    }
    kernel void metal_effect_fireflies(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float4 base = inTex.read(gid);
        float speed = max(0.1, (u.p1 > 0.0 ? u.p1 : 1.0) * u.speed);
        float t = u.time * speed;
        float density = clamp(u.p0 > 0.0 ? u.p0 : 1.0, 0.2, 3.0) * u.intensity;
        float cellSize = 65.0;
        float2 cell = floor(pos / cellSize);
        float rnd = hash12(cell);
        float3 fireflyGlow = float3(0.0);
        if (rnd > (1.0 - 0.22 * density)) {
            float2 wander = float2(
                sin(t * 1.2 + rnd * 6.28) * 22.0 + cos(t * 0.5) * 10.0,
                cos(t * 0.9 + rnd * 3.14) * 20.0 + sin(t * 0.4) * 8.0
            );
            float2 flyCenter = cell * cellSize + float2(cellSize * 0.5, cellSize * 0.5) + wander;
            float dist = length(pos - flyCenter);
            float blink = max(0.0, sin(t * 2.2 + rnd * 12.56));
            float pulse = blink * blink * blink;
            if (dist < 28.0 && pulse > 0.01) {
                float core = max(0.0, 1.0 - dist / 2.8);
                float halo = 1.0 / (1.0 + dist * 0.35);
                float totalGlow = (core * 2.0 + halo * 0.8) * pulse;
                fireflyGlow = float3(0.75, 1.0, 0.25) * totalGlow;
            }
        }
        float3 outRgb = base.rgb + fireflyGlow * 0.85;
        outTex.write(float4(clamp(outRgb, 0.0, 1.0), base.a), gid);
    }
    kernel void metal_effect_embers_sparks(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float4 base = inTex.read(gid);
        float speed = max(0.2, (u.p1 > 0.0 ? u.p1 : 1.0) * u.speed);
        float t = u.time * speed;
        float density = clamp(u.p0 > 0.0 ? u.p0 : 1.0, 0.2, 3.0) * u.intensity;
        float cellSize = 36.0;
        float yRise = pos.y - t * 180.0;
        float xJitter = pos.x + sin(pos.y * 0.03 + t * 4.5) * 18.0;
        float2 samplePos = float2(xJitter, yRise);
        float2 cell = floor(samplePos / cellSize);
        float rnd = hash12(cell);
        float3 emberGlow = float3(0.0);
        if (rnd > (1.0 - 0.26 * density)) {
            float2 cellCenter = cell * cellSize + float2(fract(rnd * 13.0) * 24.0 + 6.0, fract(rnd * 27.0) * 24.0 + 6.0);
            float dist = length(samplePos - cellCenter);
            float radius = 3.2 + fract(rnd * 7.0) * 3.0;
            float heightRatio = clamp((u.height - pos.y) / max(1.0, u.height), 0.0, 1.0);
            float flicker = 0.7 + 0.3 * sin(t * 14.0 + rnd * 50.0);
            float heat = (1.0 - heightRatio * 0.65) * flicker;
            if (dist < radius * 3.5) {
                float core = max(0.0, 1.0 - dist / radius);
                float halo = 1.0 / (1.0 + dist * 0.5);
                float intensity = (core * 2.5 + halo * 0.7) * heat;
                float3 col = mix(float3(1.0, 0.35, 0.05), float3(1.0, 0.95, 0.45), core);
                emberGlow = col * intensity;
            }
        }
        float3 outRgb = base.rgb + emberGlow * 0.9;
        outTex.write(float4(clamp(outRgb, 0.0, 1.0), base.a), gid);
    }
    kernel void metal_effect_floating_bubbles(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float4 base = inTex.read(gid);
        float speed = max(0.2, (u.p1 > 0.0 ? u.p1 : 1.0) * u.speed);
        float t = u.time * speed;
        float density = clamp(u.p0 > 0.0 ? u.p0 : 1.0, 0.2, 3.0) * u.intensity;
        float cellSize = 62.0;
        float yRise = pos.y - t * 90.0;
        float xSway = pos.x + sin(pos.y * 0.02 + t * 2.0) * 14.0;
        float2 samplePos = float2(xSway, yRise);
        float2 cell = floor(samplePos / cellSize);
        float rnd = hash12(cell);
        float bubbleRim = 0.0;
        float bubbleGlint = 0.0;
        if (rnd > (1.0 - 0.20 * density)) {
            float2 cellCenter = cell * cellSize + float2(fract(rnd * 17.0) * 36.0 + 12.0, fract(rnd * 29.0) * 36.0 + 12.0);
            float2 delta = samplePos - cellCenter;
            float dist = length(delta);
            float radius = 10.0 + fract(rnd * 11.0) * 14.0;
            float rimThickness = 1.6;
            float rimDist = abs(dist - radius);
            if (rimDist < rimThickness) {
                bubbleRim = smoothstep(rimThickness, 0.0, rimDist);
            }
            float2 glintDir = normalize(float2(-0.707, -0.707));
            float align = dot(normalize(delta), glintDir);
            if (align > 0.55 && rimDist < 2.5) {
                bubbleGlint = pow((align - 0.55) / 0.45, 2.0) * smoothstep(2.5, 0.0, rimDist) * 1.5;
            }
        }
        float3 sheenCol = float3(0.85, 0.95, 1.0) * bubbleRim * 0.75 + float3(1.0) * bubbleGlint;
        float3 outRgb = base.rgb + sheenCol;
        outTex.write(float4(clamp(outRgb, 0.0, 1.0), base.a), gid);
    }
    """
}