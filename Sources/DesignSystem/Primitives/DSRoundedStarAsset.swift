import AppKit
import SwiftUI

/// Asset provider for the custom chubby rounded star icon requested for Left Sidebar Favorites.
/// Decoded from high-resolution vector-rendered PNG data matching the exact design asset.
/// Complies with AGENTS.md R3.1 (File <= 300 lines).
public enum DSRoundedStarAsset {
    private static let base64Data = "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"

    @MainActor
    public static let image: NSImage? = {
        guard let data = Data(base64Encoded: base64Data) else { return nil }
        let img = NSImage(data: data)
        img?.isTemplate = false
        return img
    }()
}

public struct DSRoundedStarView: View {
    private let isFavorite: Bool
    private let size: CGFloat

    public init(isFavorite: Bool = true, size: CGFloat = 20) {
        self.isFavorite = isFavorite
        self.size = size
    }

    public var body: some View {
        if let img = DSRoundedStarAsset.image {
            Image(nsImage: img)
                .resizable()
                .renderingMode(isFavorite ? .original : .template)
                .foregroundStyle(isFavorite ? DSColors.favoriteStar : Color.white.opacity(0.85))
                .shadow(color: Color.black.opacity(0.45), radius: 1.5, x: 0, y: 1)
                .frame(width: size, height: size)
        } else {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: size * 0.8, weight: .bold))
                .foregroundStyle(isFavorite ? DSColors.favoriteStar : Color.white.opacity(0.85))
                .frame(width: size, height: size)
        }
    }
}
