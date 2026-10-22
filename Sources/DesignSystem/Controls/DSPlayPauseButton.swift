import SwiftUI

public struct DSPlayPauseButton: View {
    private let isPlaying: Bool
    private let action: () -> Void

    public init(
        isPlaying: Bool,
        action: @escaping () -> Void
    ) {
        self.isPlaying = isPlaying
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 14))
                .foregroundStyle(DSColors.textPrimary)
                .frame(width: DSSize.iconButtonSize, height: DSSize.iconButtonSize)
                .background(DSColors.activeTabBackground)
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
