import Foundation
import CoreGraphics
import CoreImage
import CoreMedia
#if os(macOS)
import AppKit
#endif
import Domain

/// Bộ đệm giải mã đồ họa Vector SVG, SF Symbol, ảnh tĩnh/động (PNG/GIF/APNG cục bộ & URL Supabase)
/// và bộ nhớ đệm Bitmap khung hình chữ tĩnh 60fps.
/// Tuân thủ AGENTS.md R2.1 (100% Apple SDK), R3.1 (File <= 300 dòng, Hàm <= 50 dòng), và R8.3 (Thread-safe).
public final class TextSVGAndAssetCache: @unchecked Sendable {
    public static let shared = TextSVGAndAssetCache()

    private let lock = NSLock()
    private var svgImageCache: [String: CGImage] = [:]
    private var animatedDecoderCache: [String: AnimatedStickerDecoder] = [:]
    private var staticTextCache: [Int: CIImage] = [:]
    private var inFlightURLs: Set<String> = []

    public init() {}

    /// Xóa toàn bộ bộ nhớ đệm khi cần giải phóng RAM
    public func clearCache() {
        lock.lock()
        svgImageCache.removeAll()
        animatedDecoderCache.removeAll()
        staticTextCache.removeAll()
        lock.unlock()
    }

    public func cachedTextImage(forKey key: Int) -> CIImage? {
        lock.lock()
        defer { lock.unlock() }
        return staticTextCache[key]
    }

    public func storeTextImage(_ image: CIImage, forKey key: Int) {
        lock.lock()
        if staticTextCache.count >= 64 {
            staticTextCache.removeAll(keepingCapacity: true)
        }
        staticTextCache[key] = image
        lock.unlock()
    }

    /// Áp dụng Opacity chuẩn cho ảnh Premultiplied Alpha (nhân đồng bộ cả R, G, B, A để không gây lóa trắng)
    public static func applyPremultipliedOpacity(_ opacity: Double, to image: CIImage) -> CIImage {
        let clamped = CGFloat(max(0.0, min(1.0, opacity)))
        guard clamped < 0.999 else { return image }
        let rVec = CIVector(x: clamped, y: 0, z: 0, w: 0)
        let gVec = CIVector(x: 0, y: clamped, z: 0, w: 0)
        let bVec = CIVector(x: 0, y: 0, z: clamped, w: 0)
        let aVec = CIVector(x: 0, y: 0, z: 0, w: clamped)
        guard let filter = CIFilter(name: "CIColorMatrix", parameters: [
            kCIInputImageKey: image,
            "inputRVector": rVec,
            "inputGVector": gVec,
            "inputBVector": bVec,
            "inputAVector": aVec
        ]) else {
            return image
        }
        return filter.outputImage ?? image
    }

    /// Giải mã chuỗi XML Vector SVG thành CGImage sắc nét ở đúng kích thước pixel mục tiêu
    public func rasterizeSVG(_ svgMarkup: String, targetSize: CGSize) -> CGImage? {
        let trimmed = svgMarkup.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let w = max(8, Int(ceil(targetSize.width)))
        let h = max(8, Int(ceil(targetSize.height)))
        let cacheKey = "\(trimmed.hashValue)_\(w)x\(h)"

        lock.lock()
        if let cached = svgImageCache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        #if os(macOS)
        guard let data = trimmed.data(using: .utf8),
              let nsImage = NSImage(data: data) else {
            return nil
        }

        let cgImage = renderNSImageToCGImage(nsImage, width: w, height: h)
        if let cgImage {
            lock.lock()
            if svgImageCache.count > 128 { svgImageCache.removeAll() }
            svgImageCache[cacheKey] = cgImage
            lock.unlock()
        }
        return cgImage
        #else
        return nil
        #endif
    }

    /// Giải mã biểu tượng SF Symbol có tô màu thành CGImage
    public func rasterizeSymbol(name: String, tintHex: String, targetSize: CGSize) -> CGImage? {
        guard !name.isEmpty else { return nil }
        let w = max(8, Int(ceil(targetSize.width)))
        let h = max(8, Int(ceil(targetSize.height)))
        let cacheKey = "sym_\(name)_\(tintHex)_\(w)x\(h)"

        lock.lock()
        if let cached = svgImageCache[cacheKey] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        #if os(macOS)
        guard let baseImg = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }
        let color = TextAdvancedStyleRenderer.parseHexColor(tintHex)
        let config = NSImage.SymbolConfiguration(pointSize: CGFloat(min(w, h)) * 0.75, weight: .bold)
        let configured = baseImg.withSymbolConfiguration(config) ?? baseImg

        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        color.set()
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        configured.draw(in: rect)
        ctx.setBlendMode(.sourceIn)
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
        NSGraphicsContext.restoreGraphicsState()

        guard let cgImage = ctx.makeImage() else { return nil }
        lock.lock()
        svgImageCache[cacheKey] = cgImage
        lock.unlock()
        return cgImage
        #else
        return nil
        #endif
    }

    /// Trích xuất khung hình từ đường dẫn file cục bộ hoặc URL HTTPS Supabase tại thời điểm `localTime`
    public func frameForAsset(
        path: String,
        localTime: Double,
        loop: Bool = true,
        speed: Double = 1.0,
        targetSize: CGSize = CGSize(width: 512, height: 512)
    ) -> CGImage? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return frameForRemoteURL(trimmed, localTime: localTime, loop: loop, speed: speed, targetSize: targetSize)
        }

        let localPath = trimmed.hasPrefix("file://")
            ? (URL(string: trimmed)?.path ?? trimmed)
            : trimmed
        if localPath.lowercased().hasSuffix(".svg"),
           let svgStr = try? String(contentsOfFile: localPath, encoding: .utf8) {
            return rasterizeSVG(svgStr, targetSize: targetSize)
        }

        let decoder = resolveLocalDecoder(key: trimmed, fileURL: URL(fileURLWithPath: localPath))
        let time = CMTime(seconds: max(0.0, localTime), preferredTimescale: 600)
        return decoder?.frame(at: time, loopMode: loop ? .loop : .playOnce, speed: speed)
    }

    private func frameForRemoteURL(
        _ urlString: String,
        localTime: Double,
        loop: Bool,
        speed: Double,
        targetSize: CGSize
    ) -> CGImage? {
        let diskURL = remoteCacheFileURL(for: urlString)
        if FileManager.default.fileExists(atPath: diskURL.path) {
            if urlString.lowercased().hasSuffix(".svg"),
               let svgStr = try? String(contentsOf: diskURL, encoding: .utf8) {
                return rasterizeSVG(svgStr, targetSize: targetSize)
            }
            let decoder = resolveLocalDecoder(key: urlString, fileURL: diskURL)
            let time = CMTime(seconds: max(0.0, localTime), preferredTimescale: 600)
            return decoder?.frame(at: time, loopMode: loop ? .loop : .playOnce, speed: speed)
        }
        prefetchRemoteAssetIfNeeded(urlString: urlString, destination: diskURL)
        return nil
    }

    private func resolveLocalDecoder(key: String, fileURL: URL) -> AnimatedStickerDecoder? {
        lock.lock()
        if let existing = animatedDecoderCache[key] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let loaded = AnimatedStickerDecoder(url: fileURL)
        guard !loaded.isEmpty else { return nil }
        lock.lock()
        if animatedDecoderCache.count > 48 { animatedDecoderCache.removeAll() }
        animatedDecoderCache[key] = loaded
        lock.unlock()
        return loaded
    }

    private func remoteCacheFileURL(for urlString: String) -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("VideoEditorRemoteAssets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = URL(string: urlString)?.pathExtension ?? "dat"
        let safeExt = ext.isEmpty ? "dat" : ext
        return dir.appendingPathComponent("\(abs(urlString.hashValue)).\(safeExt)")
    }

    private func prefetchRemoteAssetIfNeeded(urlString: String, destination: URL) {
        guard let remoteURL = URL(string: urlString) else { return }
        lock.lock()
        let alreadyInFlight = inFlightURLs.contains(urlString)
        if !alreadyInFlight { inFlightURLs.insert(urlString) }
        lock.unlock()
        guard !alreadyInFlight else { return }

        let task = URLSession.shared.dataTask(with: remoteURL) { [weak self] data, response, _ in
            defer {
                self?.lock.lock()
                self?.inFlightURLs.remove(urlString)
                self?.lock.unlock()
            }
            guard let data, !data.isEmpty,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return }
            try? data.write(to: destination, options: .atomic)
        }
        task.resume()
    }

    #if os(macOS)
    private func renderNSImageToCGImage(_ image: NSImage, width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }
    #endif
}
