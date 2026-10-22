import SwiftUI
import Domain
import DesignSystem

public struct TimelineTrackHeaderView: View {
    private let layer: TimelineLayer
    private let height: CGFloat
    private let onToggleLock: () -> Void
    private let onToggleHide: () -> Void
    private let onToggleMute: () -> Void

    public init(
        layer: TimelineLayer,
        height: CGFloat,
        onToggleLock: @escaping () -> Void,
        onToggleHide: @escaping () -> Void,
        onToggleMute: @escaping () -> Void
    ) {
        self.layer = layer
        self.height = height
        self.onToggleLock = onToggleLock
        self.onToggleHide = onToggleHide
        self.onToggleMute = onToggleMute
    }

    public var body: some View {
        HStack(spacing: DSSpacing.none) {
            lockColumn
            hideColumn
            muteColumn
        }
        .frame(width: DSSize.layerHeaderWidth, height: height)
        .background(DSColors.layerHeaderBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(DSColors.blockBorder),
            alignment: .bottom
        )
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(DSColors.blockBorder),
            alignment: .trailing
        )
    }

    private var lockColumn: some View {
        headerIconButton(
            systemName: layer.isLocked ? "lock.fill" : "lock.open",
            isActive: layer.isLocked,
            action: onToggleLock
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var hideColumn: some View {
        Group {
            if layer.kind != .audio {
                headerIconButton(
                    systemName: layer.isHidden ? "eye.slash.fill" : "eye.fill",
                    isActive: layer.isHidden,
                    action: onToggleHide
                )
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var muteColumn: some View {
        Group {
            if layer.kind == .video || layer.kind == .audio {
                headerIconButton(
                    systemName: layer.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    isActive: layer.isMuted,
                    action: onToggleMute
                )
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func headerIconButton(
        systemName: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isActive ? DSColors.accent : DSColors.textSecondary)
                .frame(width: 22, height: 20)
                .background(isActive ? DSColors.activeTabBackground : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
