import Foundation

/// Pure-geometric GPU Mesh Warp Metal Compute Kernel (`bend`, `twist`, `waveRibbon`, `lensBulge`)
/// preserving 100% of Appearance fill, stroke, and gradient colors.
extension BuiltInMetalShaders {
    public static let textMeshWarpKernelNames: [String] = [
        "metal_text_mesh_warp"
    ]

    public static let textMeshWarpSource: String = """
    // M1. Pure-Geometry Mesh Warp (p0 = mode [1..4], p1 = amount, p2 = frequency, time = phase)
    kernel void metal_text_mesh_warp(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 pos = float2(gid);
        float2 uv = (pos + 0.5) / size;
        float2 c = uv - 0.5;

        int mode = int(rint(u.p0));
        float amount = clamp(u.p1, -2.0, 2.0);
        float freq = max(0.2, u.p2);
        float phase = u.time;

        float2 samplePos = pos;
        if (abs(amount) > 0.002) {
            if (mode == 1) {
                // Bend: dynamic parabolic arc across glyph width with subtle perspective pinch
                float arcY = amount * (c.x * c.x - 0.08) * size.y * 0.48;
                float pinchX = -abs(amount) * 0.05 * c.x * c.y * size.x;
                samplePos = pos + float2(pinchX, arcY);
            } else if (mode == 2) {
                // Twist: ribbon torsion around horizontal center axis
                float theta = c.x * amount * 3.1415926 + sin(phase) * 0.15;
                float cosT = max(0.18, abs(cos(theta)));
                float warpedY = (0.5 + c.y / cosT) * size.y;
                float skewX = sin(theta) * c.y * size.y * 0.16;
                samplePos = float2(pos.x + skewX, warpedY);
            } else if (mode == 3) {
                // WaveRibbon: traveling continuous cloth wave along X axis
                float angle = c.x * freq * 6.2831853 - phase;
                float dispY = sin(angle) * amount * size.y * 0.18;
                float dispX = cos(angle) * amount * size.x * 0.025 * (c.y * 2.0);
                samplePos = pos + float2(dispX, dispY);
            } else if (mode == 4) {
                // LensBulge: radial elastic spherical bulge or pinch
                float r2 = dot(c * 2.0, c * 2.0);
                float falloff = max(0.0, 1.0 - r2 * 0.85);
                float scaleFactor = max(0.35, 1.0 - amount * 0.42 * falloff);
                samplePos = (0.5 + c * scaleFactor) * size - 0.5;
            }
        }

        float4 col = sampleTransparentBilinear(inTex, samplePos);
        outTex.write(clamp(col, 0.0, 1.0), gid);
    }
    """
}
