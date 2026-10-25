import SwiftUI
import Domain
import DesignSystem

/// Khung Chat AI Dựng phim đa lượt (Multi-turn Gemini Copilot) hiển thị ở Sidebar phải khi chưa chọn đối tượng nào.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, Hàm <= 50 dòng, View body <= 80 dòng) và R5.1 (DesignSystem tokens).
public struct AIChatPanelView: View {
    @Bindable private var viewModel: AIChatPanelViewModel

    private let quickSuggestions: [String] = [
        "Thêm video vào timeline và phủ màu Điện ảnh",
        "Chèn tiêu đề Neon ở giây thứ 1",
        "Đổi tỷ lệ khung hình sang 9:16"
    ]

    public init(viewModel: AIChatPanelViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: DSSpacing.none) {
            chatHeaderToolbar
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.sm)
            Divider().background(DSColors.blockBorder)
            if !viewModel.hasAPIKey || viewModel.isEditingAPIKey {
                apiKeyConfigurationBox.padding(DSSpacing.md)
                Divider().background(DSColors.blockBorder)
            }
            messagesScrollView
            Divider().background(DSColors.blockBorder)
            inputComposerBar.padding(DSSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.blockBackground)
    }

    private var chatHeaderToolbar: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSColors.toggleCyan)
            Menu {
                ForEach(AIChatPanelViewModel.availableModels, id: \.id) { item in
                    Button(action: { viewModel.selectedModel = item.id }) {
                        HStack {
                            Text(item.label)
                            if viewModel.selectedModel == item.id { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(viewModel.selectedModel == "gemini-2.5-pro" ? "Gemini 2.5 Pro" : "Gemini 2.5 Flash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DSColors.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(DSColors.textSecondary)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Button(action: { viewModel.inputText = AIChatPanelViewModel.standardQuickWorkflowPrompt }) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.toggleCyan)
            }
            .buttonStyle(.plain)
            .help("Điền Yêu cầu nhanh (MV 5 bước) vào ô chat")

            Button(action: { viewModel.undoLastChange() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Hoàn tác chỉnh sửa gần nhất (Undo)")

            Button(action: {
                viewModel.draftAPIKey = viewModel.apiKey
                viewModel.isEditingAPIKey.toggle()
            }) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(viewModel.hasAPIKey ? DSColors.trafficZoom : DSColors.trafficMinimize)
            }
            .buttonStyle(.plain)
            .help("Cài đặt Gemini API Key")

            Button(action: { viewModel.clearConversation() }) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Xóa lịch sử hội thoại")
        }
    }

    private var apiKeyConfigurationBox: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("Cấu hình Gemini API Key")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)
            HStack(spacing: DSSpacing.xs) {
                SecureField("Nhập API Key (AIza...)", text: $viewModel.draftAPIKey)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(DSColors.textPrimary)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, 5)
                    .background(DSColors.windowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.small).stroke(DSColors.blockBorder, lineWidth: 1))
                    .onSubmit { viewModel.saveAPIKey() }

                Button(action: { viewModel.saveAPIKey() }) {
                    Text("Lưu")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, DSSpacing.md)
                        .padding(.vertical, 5)
                        .background(DSColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            DSVerticalScrollView(backgroundColor: DSColors.blockBackground) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    ForEach(viewModel.messages) { msg in
                        messageBubble(msg).id(msg.id)
                    }
                    if viewModel.messages.count <= 1 { suggestionChipsSection }
                    if viewModel.isProcessing { processingIndicator.id("ai_processing_indicator") }
                }
                .padding(DSSpacing.md)
            }
            .onChange(of: viewModel.messages.count) {
                if let lastID = viewModel.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.isProcessing) {
                if viewModel.isProcessing {
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("ai_processing_indicator", anchor: .bottom) }
                }
            }
        }
    }

    private func messageBubble(_ msg: AIChatMessage) -> some View {
        let isUser = msg.role == .user
        return HStack {
            if isUser { Spacer(minLength: 24) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if !msg.toolBadges.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.system(size: 8)).foregroundStyle(DSColors.toggleCyan)
                        Text(msg.toolBadges.joined(separator: " • "))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(DSColors.toggleCyan)
                            .lineLimit(1)
                    }
                }
                Text(msg.text)
                    .font(.system(size: 11.5))
                    .foregroundStyle(isUser ? Color.white : (msg.isError ? DSColors.trafficClose : DSColors.textPrimary))
                    .textSelection(.enabled)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .background(isUser ? DSColors.accent : DSColors.windowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(isUser ? Color.clear : DSColors.blockBorder, lineWidth: 1))
            }
            if !isUser { Spacer(minLength: 16) }
        }
    }

    private var suggestionChipsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("Yêu cầu nhanh cho AI:")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)
            standardWorkflowCard
            ForEach(quickSuggestions, id: \.self) { suggestion in
                Button(action: { viewModel.sendPrompt(suggestion) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars").font(.system(size: 10)).foregroundStyle(DSColors.toggleCyan)
                        Text(suggestion).font(.system(size: 11)).foregroundStyle(DSColors.textPrimary).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, 6)
                    .background(DSColors.windowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                    .overlay(RoundedRectangle(cornerRadius: DSRadius.small).stroke(DSColors.blockBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, DSSpacing.xs)
    }

    private var standardWorkflowCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles.tv").font(.system(size: 11, weight: .semibold)).foregroundStyle(DSColors.toggleCyan)
                Text("Dựng trọn gói MV (5 bước chuẩn)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: { viewModel.inputText = AIChatPanelViewModel.standardQuickWorkflowPrompt }) {
                    Image(systemName: "square.and.pencil").font(.system(size: 11, weight: .medium)).foregroundStyle(DSColors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Điền vào ô chat để tùy chỉnh nội dung trước khi gửi")
            }
            Text(AIChatPanelViewModel.standardQuickWorkflowPrompt)
                .font(.system(size: 10.5))
                .foregroundStyle(DSColors.textSecondary)
                .lineSpacing(2)
            Button(action: { viewModel.sendPrompt(AIChatPanelViewModel.standardQuickWorkflowPrompt) }) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill").font(.system(size: 9))
                    Text("Chạy yêu cầu nhanh này").font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(DSColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
            }
            .buttonStyle(.plain)
        }
        .padding(DSSpacing.sm)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.toggleCyan.opacity(0.45), lineWidth: 1))
    }

    private var processingIndicator: some View {
        HStack(spacing: DSSpacing.xs) {
            ProgressView().controlSize(.small)
            Text("AI đang phân tích & chỉnh sửa Timeline...")
                .font(.system(size: 11))
                .foregroundStyle(DSColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, 6)
    }

    private var inputComposerBar: some View {
        HStack(alignment: .bottom, spacing: DSSpacing.xs) {
            TextField("Nhập yêu cầu dựng phim hoặc chỉnh tiếp...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(DSColors.textPrimary)
                .lineLimit(1...4)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, 7)
                .background(DSColors.windowBackground)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
                .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
                .onSubmit { viewModel.sendPrompt() }

            Button(action: { viewModel.sendPrompt() }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing
                        ? DSColors.textSecondary.opacity(0.4)
                        : DSColors.accent
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isProcessing)
            .help("Gửi yêu cầu cho AI")
        }
    }
}
