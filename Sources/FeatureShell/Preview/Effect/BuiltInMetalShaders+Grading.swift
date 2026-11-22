import Foundation

/// Các Metal Compute Kernel chuyên biệt cho Color Grading (8-Band HSL, Lift/Gamma/Gain Wheels,
/// Independent R/G/B Curves và Organic Film Grain), thay thế hoàn toàn `CIColorKernel(source:)`
/// đã bị Apple deprecate và bảo toàn tuyệt đối Premultiplied Alpha.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng).
extension BuiltInMetalShaders {
    public static let gradingLibrarySource: String = """
    inline float evalCurve5(float v, float y0, float y1, float y2, float y3, float y4) {
        float x = clamp(v, 0.0, 1.0) * 4.0;
        int seg = min(3, max(0, int(floor(x))));
        float t = x - float(seg);
        float p[5] = { y0, y1, y2, y3, y4 };
        float p0 = p[max(0, seg - 1)];
        float p1 = p[seg];
        float p2 = p[min(4, seg + 1)];
        float p3 = p[min(4, seg + 2)];
        float t2 = t * t;
        float t3 = t2 * t;
        float outY = 0.5 * ((2.0 * p1)
            + (-p0 + p2) * t
            + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
            + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3);
        return clamp(outY, 0.0, 1.0);
    }

    inline float hueChannelToRGB(float p, float q, float tc) {
        float t = tc;
        if (t < 0.0) t += 1.0;
        else if (t > 1.0) t -= 1.0;
        if (t < 0.16666667) return p + (q - p) * 6.0 * t;
        if (t < 0.5) return q;
        if (t < 0.66666667) return p + (q - p) * (0.66666667 - t) * 6.0;
        return p;
    }

    // 15. 8-Band HSL Selective Color (params[0..7]=dH, params[8..15]=dS, params[16..23]=dL)
    kernel void metal_grading_hsl(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant float *params [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float4 s = inTex.read(gid);
        if (s.a < 0.0001) { outTex.write(s, gid); return; }
        float3 rgb = clamp(s.rgb / s.a, 0.0, 1.0);

        float maxC = max(rgb.r, max(rgb.g, rgb.b));
        float minC = min(rgb.r, min(rgb.g, rgb.b));
        float delta = maxC - minC;
        float lum = (maxC + minC) * 0.5;
        if (delta < 0.001 || lum < 0.003 || lum > 0.997) { outTex.write(s, gid); return; }
        float sat = lum > 0.5 ? delta / max(0.0001, 2.0 - maxC - minC) : delta / max(0.0001, maxC + minC);
        if (sat < 0.015) { outTex.write(s, gid); return; }

        float hue = 0.0;
        if (rgb.r == maxC) {
            hue = (rgb.g - rgb.b) / delta;
            if (hue < 0.0) hue += 6.0;
        } else if (rgb.g == maxC) {
            hue = 2.0 + (rgb.b - rgb.r) / delta;
        } else {
            hue = 4.0 + (rgb.r - rgb.g) / delta;
        }
        hue /= 6.0;

        // 8 dải màu phủ kín 360° không có vùng chết (Red, Orange, Yellow, Green, Cyan, Blue, Purple, Magenta)
        const float centers[8] = { 0.0, 0.0833, 0.1667, 0.3333, 0.5000, 0.6667, 0.7917, 0.9028 };
        const float widths[8]  = { 0.115, 0.095, 0.125, 0.170, 0.170, 0.155, 0.135, 0.125 };

        float totalH = 0.0, totalS = 0.0, totalL = 0.0, totalW = 0.0;
        for (int i = 0; i < 8; i++) {
            float d = abs(hue - centers[i]);
            if (d > 0.5) d = 1.0 - d;
            if (d < widths[i]) {
                float u = d / widths[i];
                float w = (1.0 - u * u) * (1.0 - u * u);
                totalH += params[i] * w;
                totalS += params[8 + i] * w;
                totalL += params[16 + i] * w;
                totalW += w;
            }
        }
        if (totalW < 0.001) { outTex.write(s, gid); return; }

        float normFactor = 1.0 / max(1.0, totalW);
        totalH *= normFactor;
        totalS *= normFactor;
        totalL *= normFactor;

        float satRoll = smoothstep(0.015, 0.10, sat);
        hue = fract(hue + totalH * satRoll * 0.34);
        if (hue < 0.0) hue += 1.0;

        float dSat = totalS * satRoll;
        sat = dSat >= 0.0
            ? clamp(sat + dSat * (1.0 - sat * 0.30) * 0.85, 0.0, 1.0)
            : clamp(sat * (1.0 + dSat), 0.0, 1.0);

        float dLum = totalL * satRoll;
        lum = dLum >= 0.0
            ? clamp(lum + dLum * (1.0 - lum * 0.25) * 0.68, 0.0, 1.0)
            : clamp(lum * (1.0 + dLum * 0.78), 0.0, 1.0);

        float q = lum < 0.5 ? lum * (1.0 + sat) : lum + sat - lum * sat;
        float p = 2.0 * lum - q;
        float3 outRGB = float3(
            hueChannelToRGB(p, q, hue + 0.33333333),
            hueChannelToRGB(p, q, hue),
            hueChannelToRGB(p, q, hue - 0.33333333)
        );
        outTex.write(float4(clamp(outRGB, 0.0, 1.0) * s.a, s.a), gid);
    }

    // 16. Lift / Gamma / Gain Color Wheels (params[0..3]=lift, params[4..7]=gamma, params[8..11]=gain)
    kernel void metal_grading_wheels(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant float *params [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float4 s = inTex.read(gid);
        if (s.a < 0.0001) { outTex.write(s, gid); return; }
        float3 rgb = clamp(s.rgb / s.a, 0.0, 1.0);
        float luma = dot(rgb, float3(0.2126, 0.7152, 0.0722));

        float3 liftVec  = float3(params[0], params[1], params[2]) + float3(params[3]);
        float3 gammaVec = float3(params[4], params[5], params[6]) + float3(params[7]);
        float3 gainVec  = float3(params[8], params[9], params[10]) + float3(params[11]);

        // ASC-CDL & DaVinci Resolve hybrid Lift (Shadows) / Gamma (Midtones) / Gain (Highlights)
        float invLuma = clamp(1.0 - luma, 0.0, 1.0);
        float wLift = invLuma * (0.35 + 0.65 * invLuma);
        float wGamma = 0.25 + 0.75 * sin(clamp(luma, 0.0, 1.0) * 3.14159265359);
        float wGain = luma * (0.35 + 0.65 * luma);

        rgb += liftVec * wLift;
        rgb = rgb * max(float3(0.05), float3(1.0) + gainVec * 0.85) + gainVec * 0.45 * wGain;
        rgb += gammaVec * wGamma;

        outTex.write(float4(clamp(rgb, 0.0, 1.0) * s.a, s.a), gid);
    }

    // 17. Independent R / G / B Curves (params[0..4]=R, params[5..9]=G, params[10..14]=B)
    kernel void metal_grading_rgb_curves(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant float *params [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float4 s = inTex.read(gid);
        if (s.a < 0.0001) { outTex.write(s, gid); return; }
        float3 rgb = clamp(s.rgb / s.a, 0.0, 1.0);
        float rOut = evalCurve5(rgb.r, params[0], params[1], params[2], params[3], params[4]);
        float gOut = evalCurve5(rgb.g, params[5], params[6], params[7], params[8], params[9]);
        float bOut = evalCurve5(rgb.b, params[10], params[11], params[12], params[13], params[14]);
        outTex.write(float4(float3(rOut, gOut, bOut) * s.a, s.a), gid);
    }

    // 18. Organic Monochromatic Film Grain (params[0]=strength 0..1, params[1]=cellSize px >= 1.0)
    kernel void metal_grading_film_grain(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant float *params [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float4 s = inTex.read(gid);
        if (s.a < 0.0001) { outTex.write(s, gid); return; }
        float3 rgb = clamp(s.rgb / s.a, 0.0, 1.0);
        float strength = clamp(params[0], 0.0, 1.0);
        float cell = max(1.0, params[1]);

        float2 samplePos = floor(float2(gid) / cell);
        float n = hash12(samplePos + float2(19.37, 73.91)) - 0.5;
        float luma = dot(rgb, float3(0.2126, 0.7152, 0.0722));
        float filmMask = 1.0 - 0.40 * luma * luma;
        rgb = clamp(rgb + float3(n * strength * 0.55 * filmMask), 0.0, 1.0);
        outTex.write(float4(rgb * s.a, s.a), gid);
    }
    """
}
