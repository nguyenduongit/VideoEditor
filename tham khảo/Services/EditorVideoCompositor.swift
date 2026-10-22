import AVFoundation
import CoreImage

final class EditorVideoInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let trackID: CMPersistentTrackID
    let orientation: CGImagePropertyOrientation
    let process: (CIImage, Double) -> CIImage
    init(duration: Double, trackID: CMPersistentTrackID, orientation: CGImagePropertyOrientation, process: @escaping (CIImage, Double) -> CIImage) {
        timeRange = CMTimeRange(start: .zero, duration: EditorCompositionService.time(duration))
        self.trackID = trackID; requiredSourceTrackIDs = [NSNumber(value: trackID)]
        self.orientation = orientation; self.process = process
    }
}
/// A tweening compositor is required: a CI filter composition may cache a stretched source frame,
/// skipping changes in opacity during a freeze. This compositor renders every output timestamp.
final class EditorVideoCompositor: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String: Any & Sendable]? { [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA]] }
    var requiredPixelBufferAttributesForRenderContext: [String: Any & Sendable] { [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferMetalCompatibilityKey as String: true] }
    private let queue = DispatchQueue(label: "editor.video.compositor")
    private let context = CIContext()
    private var renderContext: AVVideoCompositionRenderContext?
    private let requestLock = NSLock()
    private var pendingRequests: [AVAsynchronousVideoCompositionRequest] = []

    private func containsPending(_ request: AVAsynchronousVideoCompositionRequest) -> Bool {
        requestLock.withLock { pendingRequests.contains { $0 === request } }
    }

    private func takePending(_ request: AVAsynchronousVideoCompositionRequest) -> Bool {
        requestLock.withLock {
            guard let index = pendingRequests.firstIndex(where: { $0 === request }) else { return false }
            pendingRequests.remove(at: index)
            return true
        }
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) { queue.sync { renderContext = newRenderContext } }
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        requestLock.lock()
        pendingRequests.append(request)
        requestLock.unlock()

        queue.async { [self] in
            autoreleasepool {
                guard containsPending(request) else { return }

                guard let instruction = request.videoCompositionInstruction as? EditorVideoInstruction,
                      let source = request.sourceFrame(byTrackID: instruction.trackID),
                      let destination = renderContext?.newPixelBuffer() else {
                    guard takePending(request) else { return }
                    request.finishCancelledRequest()
                    return
                }
                let input = CIImage(cvPixelBuffer: source).oriented(instruction.orientation)
                let result = instruction.process(input, request.compositionTime.seconds)
                guard containsPending(request) else { return }
                context.render(result, to: destination, bounds: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(destination), height: CVPixelBufferGetHeight(destination)), colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
                guard takePending(request) else { return }
                request.finish(withComposedVideoFrame: destination)
            }
        }
    }
    func cancelAllPendingVideoCompositionRequests() {
        requestLock.lock()
        let toCancel = pendingRequests
        pendingRequests.removeAll()
        requestLock.unlock()

        for req in toCancel {
            req.finishCancelledRequest()
        }
    }
}
