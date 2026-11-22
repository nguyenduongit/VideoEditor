import SwiftUI
import WebKit
import DesignSystem

/// Component hiển thị Vector SVG (hỗ trợ cả Vector tĩnh sắc nét và SVG động có CSS @keyframes/SMIL).
/// Sử dụng 100% Apple SDK (WebKit / AppKit NSImage), không dùng thư viện ngoài (AGENTS.md).
public struct SVGStickerThumbnailView: View {
    public let svgMarkup: String
    public let fallbackSymbol: String
    public let size: CGFloat?

    public init(svgMarkup: String, fallbackSymbol: String = "sparkles", size: CGFloat? = nil) {
        self.svgMarkup = svgMarkup
        self.fallbackSymbol = fallbackSymbol
        self.size = size
    }

    public var body: some View {
        Group {
            if isAnimatedSVG {
                AnimatedSVGWebViewRepresentable(svgMarkup: svgMarkup)
                    .modifier(ThumbnailFrameModifier(size: size))
                    .allowsHitTesting(false)
            } else if let cgImg = TextSVGAndAssetCache.shared.rasterizeSVG(
                svgMarkup,
                targetSize: CGSize(width: (size ?? 128) * 2, height: (size ?? 128) * 2)
            ) {
                Image(decorative: cgImg, scale: 2.0)
                    .resizable()
                    .scaledToFit()
                    .modifier(ThumbnailFrameModifier(size: size))
                    .allowsHitTesting(false)
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: (size ?? 56) * 0.55))
                    .foregroundStyle(DSColors.toggleCyan)
            }
        }
    }

    private var isAnimatedSVG: Bool {
        svgMarkup.contains("@keyframes") ||
        svgMarkup.contains("<animate") ||
        svgMarkup.contains("<animateTransform")
    }
}

private struct ThumbnailFrameModifier: ViewModifier {
    let size: CGFloat?

    func body(content: Content) -> some View {
        if let size {
            content.frame(width: size, height: size)
        } else {
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - WKWebView Representable for Animated SVG (macOS Native)

#if os(macOS)
private struct AnimatedSVGWebViewRepresentable: NSViewRepresentable {
    let svgMarkup: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { background: transparent; overflow: hidden; display: flex; align-items: center; justify-content: center; width: 100vw; height: 100vh; }
        svg { max-width: 100%; max-height: 100%; width: auto; height: auto; }
        </style>
        </head>
        <body>
        \(svgMarkup)
        </body>
        </html>
        """
        nsView.loadHTMLString(html, baseURL: nil)
    }
}
#endif

