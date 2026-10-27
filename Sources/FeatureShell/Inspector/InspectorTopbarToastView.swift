import SwiftUI
import DesignSystem

/// Toast thông báo tinh gọn trên thanh Topbar (phía bên phải của tiêu đề/tabs).
/// Thay thế hoàn toàn toast ở dưới đáy để tận dụng khoảng trống và tiết kiệm không gian màn hình dọc.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng) và R3.4 (tách Subview).
public struct InspectorTopbarToastView: View {
    @Bindable var viewModel: ActionsPanelViewModel

    public init(viewModel: ActionsPanelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if let error = viewModel.errorMessage {
                errorPill(message: error)
            } else if let message = viewModel.statusMessage {
                statusPill(message: message)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.statusMessage != nil || viewModel.errorMessage != nil)
    }

    private func errorPill(message: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.red)

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.red)
                .lineLimit(1)

            Button {
                withAnimation { viewModel.errorMessage = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.red.opacity(0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(Color.red.opacity(0.14))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.red.opacity(0.3), lineWidth: 0.5))
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }

    private func statusPill(message: String) -> some View {
        let isExecuting = viewModel.isProcessing
        let tint = isExecuting ? DSColors.accent : Color.green

        return HStack(spacing: 5) {
            if isExecuting {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.green)
            }

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textPrimary)
                .lineLimit(1)

            if !isExecuting {
                Button {
                    withAnimation { viewModel.statusMessage = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DSColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(tint.opacity(0.14))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.3), lineWidth: 0.5))
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
        .task(id: viewModel.statusMessage) {
            guard viewModel.statusMessage != nil, !viewModel.isProcessing else { return }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation { viewModel.statusMessage = nil }
        }
    }
}
