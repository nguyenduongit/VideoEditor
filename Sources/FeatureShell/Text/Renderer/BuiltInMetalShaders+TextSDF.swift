import Foundation

/// GPU Signed Distance Field (Jump Flooding) & Vector Mask Compute Kernels for the Text Atlas Engine.
extension BuiltInMetalShaders {
    public static let textSDFKernelNames: [String] = [
        "metal_text_sdf_seed",
        "metal_text_sdf_jfa_step",
        "metal_text_sdf_finalize",
        "metal_text_mask_shape"
    ]

    public static let textSDFSource: String = """
    // SDF-1. Initialize Jump Flooding interior/exterior relative coordinate seeds from glyph alpha.
    kernel void metal_text_sdf_seed(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outSeed [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outSeed.get_width() || gid.y >= outSeed.get_height()) return;
        float a = inTex.read(gid).a;
        bool inside = (a >= 0.45);
        float4 seed = inside
            ? float4(0.0, 0.0, 10000.0, 10000.0)
            : float4(10000.0, 10000.0, 0.0, 0.0);
        outSeed.write(seed, gid);
    }

    // SDF-2. 3x3 neighborhood Jump Flooding step at stride u.p0 (ping-ponged on rgba16Float textures).
    kernel void metal_text_sdf_jfa_step(
        texture2d<float, access::read> inSeed [[texture(0)]],
        texture2d<float, access::write> outSeed [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        int w = int(outSeed.get_width());
        int h = int(outSeed.get_height());
        if (int(gid.x) >= w || int(gid.y) >= h) return;

        int stepPx = max(1, int(rint(u.p0)));
        float4 best = inSeed.read(gid);
        float bestInD2 = dot(best.xy, best.xy);
        float bestOutD2 = dot(best.zw, best.zw);

        for (int oy = -1; oy <= 1; oy++) {
            for (int ox = -1; ox <= 1; ox++) {
                if (ox == 0 && oy == 0) continue;
                int nx = int(gid.x) + ox * stepPx;
                int ny = int(gid.y) + oy * stepPx;
                if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
                float4 n = inSeed.read(uint2(nx, ny));
                float2 delta = float2(float(ox * stepPx), float(oy * stepPx));

                float2 candIn = n.xy + delta;
                float dIn2 = dot(candIn, candIn);
                if (dIn2 < bestInD2) {
                    bestInD2 = dIn2;
                    best.xy = candIn;
                }

                float2 candOut = n.zw + delta;
                float dOut2 = dot(candOut, candOut);
                if (dOut2 < bestOutD2) {
                    bestOutD2 = dOut2;
                    best.zw = candOut;
                }
            }
        }
        outSeed.write(best, gid);
    }

    // SDF-3. Finalizes signed distance + smooth outward surface normal:
    // (.r = signedDistancePx [negative inside], .g/.b = outward normal xy, .a = glyphAlpha).
    kernel void metal_text_sdf_finalize(
        texture2d<float, access::read> finalSeed [[texture(0)]],
        texture2d<float, access::write> outSDF [[texture(1)]],
        texture2d<float, access::read> colorTex [[texture(2)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outSDF.get_width() || gid.y >= outSDF.get_height()) return;
        float4 s = finalSeed.read(gid);
        float srcA = colorTex.read(gid).a;

        bool hasIn = abs(s.x) < 5000.0 && abs(s.y) < 5000.0;
        bool hasOut = abs(s.z) < 5000.0 && abs(s.w) < 5000.0;
        float distOut = hasIn ? length(s.xy) : 128.0;
        float distIn = hasOut ? length(s.zw) : 128.0;

        bool isInside = (srcA >= 0.45);
        float signedDist = isInside ? -(distIn - 0.5) : (distOut - 0.5);
        if (distOut < 1.5 && distIn < 1.5) {
            signedDist = mix(signedDist, 0.5 - srcA, 0.65);
        }
        signedDist = clamp(signedDist, -128.0, 128.0);

        float2 rawDir = isInside ? s.zw : -s.xy;
        float dirLen = length(rawDir);
        float2 normal = (dirLen > 0.001) ? (rawDir / dirLen) : float2(0.0, 0.0);
        outSDF.write(float4(signedDist, normal.x, normal.y, srcA), gid);
    }

    // MASK-1. GPU geometric reveal mask (p0 = clipRevealX, p1 = clipRevealY, p2 = mode [0..4]).
    kernel void metal_text_mask_shape(
        texture2d<float, access::read> inTex [[texture(0)]],
        texture2d<float, access::write> outTex [[texture(1)]],
        constant MetalEffectUniforms &u [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTex.get_width() || gid.y >= outTex.get_height()) return;
        float2 size = float2(max(1.0, u.width), max(1.0, u.height));
        float2 uv = float2(gid) / size;
        float rx = clamp(u.p0, 0.0, 1.0);
        float ry = clamp(u.p1, 0.0, 1.0);
        int mode = int(rint(u.p2));
        float4 src = inTex.read(gid);

        float mask = 1.0;
        float p = min(rx, ry);
        float edgeFeather = 1.4 / max(4.0, min(size.x, size.y));
        if (mode == 0) {
            float mx = (rx >= 0.999) ? 1.0 : smoothstep(rx + edgeFeather, rx - edgeFeather, uv.x);
            float my = (ry >= 0.999) ? 1.0 : smoothstep(ry + edgeFeather, ry - edgeFeather, 1.0 - uv.y);
            mask = mx * my;
        } else if (mode == 1 || mode == 2) {
            float mx = (rx >= 0.999) ? 1.0 : smoothstep(rx * 0.5 + edgeFeather, rx * 0.5 - edgeFeather, abs(uv.x - 0.5));
            float my = (ry >= 0.999) ? 1.0 : smoothstep(ry * 0.5 + edgeFeather, ry * 0.5 - edgeFeather, abs(uv.y - 0.5));
            mask = mx * my;
        } else if (mode == 3) {
            float slant = size.y * 0.38;
            float span = size.x + slant;
            float rightEdge = (-slant * 0.5) + span * p;
            float edgeX = rightEdge + slant * (1.0 - uv.y);
            mask = smoothstep(edgeX + 1.25, edgeX - 1.25, float(gid.x));
        } else {
            float2 d = (uv - 0.5) * size;
            float r = max(0.5, length(size * 0.5) * 1.05 * p);
            mask = smoothstep(r + 1.25, r - 1.25, length(d));
        }
        outTex.write(src * mask, gid);
    }
    """
}
