import Foundation

/// Mở rộng `BuiltInMetalShaders` chứa nhóm 6 Metal Compute Kernels bổ sung cho 11 danh mục Effects:
/// Rain/Snow, Film Dust & Scratch, HUD/Scanlines, Light Leak, Duotone/Color, và Camera Shake & Mini-Zoom.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng).
extension BuiltInMetalShaders {
    public static let creativeEffectsKernelNames: [String] = [
        "metal_effect_rain_snow",
        "metal_effect_film_dust_scratch",
        "metal_effect_hud_grid_scanlines",
        "metal_effect_light_leak_flare",
        "metal_effect_duotone",
        "metal_effect_camera_shake"
    ]

    public static let creativeEffectsSource: String = """
    // 7. Particle / Nature: Rain & Snow (p0 = mode 0:Rain 1:Snow, p1 = density, p2 = speed)
    kernel void metal_effect_rain_snow(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 pos = float2(gid);
        float4 base = inTex.read(gid);
        float isSnow = (u.p0 > 0.5) ? 1.0 : 0.0;
        float speed = max(0.2, (u.p2 > 0.0 ? u.p2 : 1.0) * u.speed);
        float t = u.time * speed;
        float density = clamp(u.p1 > 0.0 ? u.p1 : 1.0, 0.1, 3.0) * u.intensity;

        float particle = 0.0;
        if (isSnow > 0.5) {
            float2 sPos = pos + float2(sin(pos.y * 0.02 + t * 2.0) * 12.0, t * 75.0);
            float2 cell = floor(sPos / 28.0);
            float rnd = hash12(cell);
            if (rnd > (1.0 - 0.22 * density)) {
                float2 cOrigin = cell * 28.0 + float2(rnd * 20.0, fract(rnd * 7.0) * 20.0);
                float dist = length(sPos - cOrigin);
                particle = max(0.0, 1.0 - dist / 3.5);
            }
        } else {
            float slant = (pos.x + (u.height - pos.y) * 0.15);
            float fall = (u.height - pos.y) + t * 900.0;
            float col = floor(slant / 6.0);
            float dropRnd = hash12(float2(col, floor(fall / 80.0)));
            if (dropRnd > (1.0 - 0.15 * density)) {
                float streakPhase = fract(fall / 80.0);
                if (streakPhase < 0.25) {
                    particle = (1.0 - streakPhase / 0.25) * 0.75;
                }
            }
        }
        float3 col = mix(base.rgb, float3(0.92, 0.95, 1.0), particle * 0.85);
        outTex.write(float4(clamp(col, 0.0, 1.0), base.a), gid);
    }

    // 8. Retro / Film: Film Dust, Scratch & Gate Jitter (p0 = scratchIntensity, p1 = dustDensity, p2 = jitterAmp)
    kernel void metal_effect_film_dust_scratch(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float jitterAmp = (u.p2 > 0.0 ? u.p2 : 2.5) * u.intensity;
        float frameJitter = (hash12(float2(floor(u.time * 18.0), 1.0)) - 0.5) * jitterAmp;
        float2 readPos = float2(gid.x, float(gid.y) + frameJitter);
        float4 base = readClamped(inTex, readPos);

        float scratchInt = (u.p0 > 0.0 ? u.p0 : 1.0) * u.intensity;
        float tFrame = floor(u.time * 24.0);
        float scratchX = floor(hash12(float2(tFrame, 3.0)) * u.width);
        float scratch = 0.0;
        if (abs(float(gid.x) - scratchX) < 1.2) {
            scratch = scratchInt * 0.65;
        }

        float dustDense = (u.p1 > 0.0 ? u.p1 : 1.0) * u.intensity;
        float dustNoise = hash12(float2(gid) * 0.15 + float2(tFrame * 17.0, tFrame * 43.0));
        float dust = (dustNoise > (1.0 - 0.003 * dustDense)) ? 0.85 : 0.0;

        float3 col = base.rgb + float3(scratch + dust);
        col = clamp(col, 0.0, 1.0);
        outTex.write(float4(col, base.a), gid);
    }

    // 9. Text / Overlay: HUD Grid & Scanlines (p0 = scanlineStrength, p1 = gridSpacing, p2 = crosshair)
    kernel void metal_effect_hud_grid_scanlines(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float4 base = inTex.read(gid);
        float2 pos = float2(gid);
        float strength = clamp(u.p0 > 0.0 ? u.p0 : 0.45, 0.0, 1.0) * u.intensity;
        float scanline = 1.0 - strength * 0.20 * (0.5 + 0.5 * sin(pos.y * 3.14159));

        float gridSpacing = max(16.0, u.p1 > 0.0 ? u.p1 : 48.0);
        float onGridX = (fract(pos.x / gridSpacing) < (1.2 / gridSpacing)) ? 1.0 : 0.0;
        float onGridY = (fract(pos.y / gridSpacing) < (1.2 / gridSpacing)) ? 1.0 : 0.0;
        float grid = max(onGridX, onGridY) * 0.18 * strength;

        float2 center = float2(u.width * 0.5, u.height * 0.5);
        float distToCenter = length(pos - center);
        float crosshair = 0.0;
        if (u.p2 > 0.5 && distToCenter < 60.0 && distToCenter > 15.0) {
            if (abs(pos.x - center.x) < 1.0 || abs(pos.y - center.y) < 1.0) {
                crosshair = 0.45 * strength;
            }
        }

        float3 hudCol = float3(0.15, 0.95, 0.85); // Cyan HUD
        float3 col = base.rgb * scanline + hudCol * (grid + crosshair);
        outTex.write(float4(clamp(col, 0.0, 1.0), base.a), gid);
    }

    // 10. Light Effects: Volumetric Light Leak & Lens Flare (p0 = flareIntensity, p1 = warmth, p2 = posX)
    kernel void metal_effect_light_leak_flare(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float4 base = inTex.read(gid);
        float2 pos = float2(gid);
        float t = u.time * max(0.2, u.speed);
        float flareIntensity = clamp(u.p0 > 0.0 ? u.p0 : 1.0, 0.0, 3.0) * u.intensity;

        float2 flareCenter = float2(
            u.width * (0.25 + 0.5 * sin(t * 0.8)),
            u.height * (0.80 + 0.15 * cos(t * 0.6))
        );
        float d = length(pos - flareCenter) / max(1.0, u.width * 0.65);
        float glow = exp(-d * 2.2) * flareIntensity;

        float3 warmColor = mix(float3(1.0, 0.55, 0.2), float3(1.0, 0.2, 0.6), sin(t * 0.5) * 0.5 + 0.5);
        float3 leak = warmColor * glow * 0.75;
        float3 col = base.rgb + leak;
        outTex.write(float4(clamp(col, 0.0, 1.0), base.a), gid);
    }

    // 11. Color Effects: Duotone, Sepia & Negative (p0 = mode 0..4, p1 = blend, p2 = toneA, p3 = toneB)
    kernel void metal_effect_duotone(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float4 base = inTex.read(gid);
        float lum = dot(base.rgb, float3(0.299, 0.587, 0.114));
        int mode = int(rint(u.p0));
        float blend = clamp(u.p1 > 0.0 ? u.p1 : 1.0, 0.0, 1.0) * u.intensity;

        float3 transformed = base.rgb;
        if (mode == 0) { // B&W / Grayscale
            transformed = float3(lum);
        } else if (mode == 1) { // Sepia Vintage
            transformed = float3(lum * 1.15, lum * 0.90, lum * 0.68);
        } else if (mode == 2) { // Cyber Duotone (Dark blue to Bright orange)
            float3 darkTone = float3(0.08, 0.12, 0.45);
            float3 lightTone = float3(1.0, 0.65, 0.25);
            transformed = mix(darkTone, lightTone, lum);
        } else if (mode == 3) { // Negative / Invert
            transformed = float3(1.0) - base.rgb;
        } else if (mode == 4) { // Solarize
            transformed = lum < 0.5 ? base.rgb : (float3(1.0) - base.rgb);
        }
        float3 finalCol = mix(base.rgb, transformed, blend);
        outTex.write(float4(clamp(finalCol, 0.0, 1.0), base.a), gid);
    }

    // 12. Camera / Motion: Camera Shake & Beat Pulse Mini-Zoom (p0 = shakeIntensity, p1 = frequency, p2 = beatPulse)
    kernel void metal_effect_camera_shake(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float intensity = clamp(u.p0 > 0.0 ? u.p0 : 1.0, 0.0, 3.0) * u.intensity;
        float freq = max(1.0, (u.p1 > 0.0 ? u.p1 : 16.0) * u.speed);
        float beatPulse = clamp(u.p2, 0.0, 1.0); // Mini-zoom pulse from beat sync

        float totalZoom = 1.04 + 0.12 * beatPulse * intensity;
        float2 center = float2(u.width * 0.5, u.height * 0.5);
        float2 pos = float2(gid);

        float dx = sin(u.time * freq * 1.15) * 16.0 * intensity;
        float dy = cos(u.time * freq * 0.92) * 12.0 * intensity;
        float ang = sin(u.time * freq * 0.73) * 0.02 * intensity;

        float2 rel = (pos - center) / totalZoom;
        float s = sin(ang); float c = cos(ang);
        float2 rot = float2(rel.x * c - rel.y * s, rel.x * s + rel.y * c);
        float2 sampleCoord = center + rot + float2(dx, dy);

        float4 sampled = readClamped(inTex, sampleCoord);
        outTex.write(sampled, gid);
    }
    """
}

