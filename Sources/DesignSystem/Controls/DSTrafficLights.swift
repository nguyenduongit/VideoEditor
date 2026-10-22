import SwiftUI

public struct DSTrafficLights: View {
    private let onClose: () -> Void
    private let onMinimize: () -> Void
    private let onZoom: () -> Void

    public init(
        onClose: @escaping () -> Void,
        onMinimize: @escaping () -> Void,
        onZoom: @escaping () -> Void
    ) {
        self.onClose = onClose
        self.onMinimize = onMinimize
        self.onZoom = onZoom
    }

    public var body: some View {
        HStack(spacing: DSSize.trafficLightSpacing) {
            trafficCircle(color: DSColors.trafficClose, action: onClose)
            trafficCircle(color: DSColors.trafficMinimize, action: onMinimize)
            trafficCircle(color: DSColors.trafficZoom, action: onZoom)
        }
    }

    private func trafficCircle(color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: DSSize.trafficLightSize, height: DSSize.trafficLightSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
