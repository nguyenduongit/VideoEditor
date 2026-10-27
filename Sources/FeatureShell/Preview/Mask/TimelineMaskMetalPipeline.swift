import Foundation
import CoreImage
import Metal

public struct MaskShaderUniforms {
    var shape: UInt32
    var invert: UInt32
    var feather: Float
    var rotation: Float
    var centerX: Float
    var centerY: Float
    var radiusX: Float
    var radiusY: Float
    var sizeWidth: Float
    var sizeHeight: Float
    var cornerRadius: Float
    var filmHeight: Float
}

/// GPU Metal compute pipeline for high-performance mask synthesis.
/// Eliminates CPU NSBitmapImageRep allocations and executes in VRAM (< 0.1ms/frame).
/// Bọc các đối tượng Metal (MTLDevice, MTLCommandQueue, MTLComputePipelineState); toàn bộ là immutable 'let' constants và thread-safe theo Apple Metal framework (R8.3).
public final class TimelineMaskMetalPipeline: @unchecked Sendable {
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let pipelineState: MTLComputePipelineState?

    public init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            self.device = nil
            self.commandQueue = nil
            self.pipelineState = nil
            return
        }

        self.device = device
        self.commandQueue = commandQueue

        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct MaskUniforms {
            uint shape;
            uint invert;
            float feather;
            float rotation;
            float centerX;
            float centerY;
            float radiusX;
            float radiusY;
            float sizeWidth;
            float sizeHeight;
            float cornerRadius;
            float filmHeight;
        };

        inline float approx_erf(float x) {
            float a = 0.147;
            float x2 = x * x;
            float ax2 = a * x2;
            float inner = exp(-x2 * (4.0 / 3.14159265 + ax2) / (1.0 + ax2));
            float s = x < 0.0 ? -1.0 : 1.0;
            return s * sqrt(max(0.0, 1.0 - inner));
        }

        kernel void mask_render(
            texture2d<float, access::write> outTexture [[texture(0)]],
            constant MaskUniforms &uniforms [[buffer(0)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
                return;
            }
            float2 pt = float2(float(gid.x) + 0.5, float(gid.y) + 0.5) - float2(uniforms.centerX, uniforms.centerY);
            float cosA = cos(-uniforms.rotation);
            float sinA = sin(-uniforms.rotation);
            float2 p = float2(pt.x * cosA - pt.y * sinA, pt.x * sinA + pt.y * cosA);

            float alpha = 0.0;

            if (uniforms.shape == 1) { // Split
                float fw = uniforms.feather * 800.0;
                if (fw <= 0.0) {
                    alpha = p.x >= 0.0 ? 1.0 : 0.0;
                } else if (p.x <= -fw * 0.5) {
                    alpha = 0.0;
                } else if (p.x >= fw * 0.5) {
                    alpha = 1.0;
                } else {
                    float t = (p.x + fw * 0.5) / fw;
                    float u = (t - 0.5) * 6.0;
                    float c = 0.5 * (1.0 + approx_erf(u / 1.41421356));
                    float c0 = 0.5 * (1.0 + approx_erf(-3.0 / 1.41421356));
                    float c1 = 0.5 * (1.0 + approx_erf(3.0 / 1.41421356));
                    alpha = clamp((c - c0) / (c1 - c0), 0.0, 1.0);
                }
            } else if (uniforms.shape == 2) { // Circle
                float rx = max(1.0, uniforms.radiusX);
                float ry = max(1.0, uniforms.radiusY);
                float d = length(p / float2(rx, ry)) - 1.0;
                float distPx = d * min(rx, ry);
                float blurR = uniforms.feather * 150.0;
                if (blurR <= 0.0) {
                    alpha = distPx <= 0.0 ? 1.0 : 0.0;
                } else {
                    float u = -distPx / (blurR * 0.7071);
                    alpha = clamp(0.5 * (1.0 + approx_erf(u)), 0.0, 1.0);
                }
            } else if (uniforms.shape == 3) { // Rectangle
                float w = max(1.0, uniforms.sizeWidth);
                float h = max(1.0, uniforms.sizeHeight);
                float cr = max(0.0, min(uniforms.cornerRadius, min(w, h) * 0.5));
                float2 q = abs(p) - float2(w * 0.5 - cr, h * 0.5 - cr);
                float distPx = length(max(q, float2(0.0))) + min(max(q.x, q.y), 0.0) - cr;
                float blurR = uniforms.feather * 150.0;
                if (blurR <= 0.0) {
                    alpha = distPx <= 0.0 ? 1.0 : 0.0;
                } else {
                    float u = -distPx / (blurR * 0.7071);
                    alpha = clamp(0.5 * (1.0 + approx_erf(u)), 0.0, 1.0);
                }
            } else if (uniforms.shape == 4) { // Filmstrip
                float filmH = max(1.0, uniforms.filmHeight);
                float fw = uniforms.feather * 800.0;
                float distFromCenter = abs(p.y);
                if (fw <= 0.0) {
                    alpha = distFromCenter <= filmH * 0.5 ? 1.0 : 0.0;
                } else {
                    float innerSolid = max(0.0, filmH * 0.5 - fw * 0.5);
                    float outerBound = filmH * 0.5 + fw * 0.5;
                    if (distFromCenter <= innerSolid) {
                        alpha = 1.0;
                    } else if (distFromCenter >= outerBound) {
                        alpha = 0.0;
                    } else {
                        float t = (distFromCenter - innerSolid) / max(1.0, outerBound - innerSolid);
                        float u = (1.0 - t - 0.5) * 6.0;
                        float c = 0.5 * (1.0 + approx_erf(u / 1.41421356));
                        float c0 = 0.5 * (1.0 + approx_erf(-3.0 / 1.41421356));
                        float c1 = 0.5 * (1.0 + approx_erf(3.0 / 1.41421356));
                        alpha = clamp((c - c0) / (c1 - c0), 0.0, 1.0);
                    }
                }
            }

            if (uniforms.invert != 0) {
                alpha = 1.0 - alpha;
            }

            outTexture.write(float4(alpha, alpha, alpha, alpha), gid);
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let function = library.makeFunction(name: "mask_render") else {
                self.pipelineState = nil
                return
            }
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            self.pipelineState = nil
        }
    }

    public var isAvailable: Bool {
        pipelineState != nil && commandQueue != nil && device != nil
    }

    public func generateMask(
        params: TimelineMaskParameters,
        canvasSize: CGSize
    ) -> CIImage? {
        guard let device,
              let commandQueue,
              let pipelineState else {
            return nil
        }

        let width = max(1, Int(canvasSize.width))
        let height = max(1, Int(canvasSize.height))

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderWrite, .shaderRead]
        guard let texture = device.makeTexture(descriptor: desc) else {
            return nil
        }

        let shapeCode: UInt32
        switch params.shape {
        case .none: shapeCode = 0
        case .split: shapeCode = 1
        case .circle: shapeCode = 2
        case .rectangle: shapeCode = 3
        case .filmstrip: shapeCode = 4
        }

        let cx: Float
        let cy: Float
        let rot: Float

        if params.shape == .filmstrip {
            cx = Float(canvasSize.width / 2.0)
            cy = Float(canvasSize.height / 2.0 + CGFloat(params.offsetY))
            rot = 0.0
        } else {
            cx = Float(canvasSize.width / 2.0 + CGFloat(params.positionX))
            cy = Float(canvasSize.height / 2.0 + CGFloat(params.positionY))
            rot = Float(-params.rotation * .pi / 180.0)
        }

        var uniforms = MaskShaderUniforms(
            shape: shapeCode,
            invert: params.invert ? 1 : 0,
            feather: Float(params.feather),
            rotation: rot,
            centerX: cx,
            centerY: cy,
            radiusX: Float(params.radiusX),
            radiusY: Float(params.radiusY),
            sizeWidth: Float(params.width),
            sizeHeight: Float(params.height),
            cornerRadius: Float(params.cornerRadius),
            filmHeight: Float(params.filmHeight)
        )

        guard let cmdBuffer = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&uniforms, length: MemoryLayout<MaskShaderUniforms>.stride, index: 0)

        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerGroup = MTLSize(width: w, height: h, depth: 1)
        let numGroups = MTLSize(
            width: (width + w - 1) / w,
            height: (height + h - 1) / h,
            depth: 1
        )
        encoder.dispatchThreadgroups(numGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        cmdBuffer.commit()
        cmdBuffer.waitUntilCompleted()

        return CIImage(mtlTexture: texture, options: nil)
    }
}
