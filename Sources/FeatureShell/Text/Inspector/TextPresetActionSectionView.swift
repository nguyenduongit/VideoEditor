import SwiftUI
import Domain
import DesignSystem

/// Khu vực nút lưu Preset / ghi đè Preset cho tab Text
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct TextPresetActionSectionView: View {
    @Bindable private var viewModel: InspectorViewModel
    private let currentConfig: TextConfiguration

    @State private var isSaveModalPresented: Bool = false
    @State private var isOverwriteAlertPresented: Bool = false
    @State private var isOverwriting: Bool = false
    @State private var saveSuccessMessage: String?

    public init(viewModel: InspectorViewModel, currentConfig: TextConfiguration) {
        self.viewModel = viewModel
        self.currentConfig = currentConfig
    }

    private var originPresetID: String? {
        viewModel.liveProperties["originPresetId"]?.asString
            ?? viewModel.selectedClip?.properties["originPresetId"]?.asString
    }

    private var originPresetName: String? {
        viewModel.liveProperties["originPresetName"]?.asString
            ?? viewModel.selectedClip?.properties["originPresetName"]?.asString
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if let originID = originPresetID, let originName = originPresetName {
                existingPresetButtons(originID: originID, originName: originName)
            } else {
                newPresetButton
            }

            if let saveSuccessMessage {
                Text(saveSuccessMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.green)
            }
        }
        .popover(isPresented: $isSaveModalPresented) {
            SavePresetModalView(
                kind: .text(config: currentConfig),
                originPresetID: originPresetID,
                originPresetName: originPresetName,
                dependencies: viewModel.dependencies,
                onSaveCompleted: { newID, newName in
                    viewModel.commitTextProperty(key: "originPresetId", text: newID)
                    viewModel.commitTextProperty(key: "originPresetName", text: newName)
                    saveSuccessMessage = "Đã lưu preset \"\(newName)\" thành công!"
                },
                onDismiss: { isSaveModalPresented = false }
            )
        }
        .alert("Xác nhận ghi đè Preset", isPresented: $isOverwriteAlertPresented) {
            Button("Ghi đè", role: .destructive) {
                overwriteCurrentPreset()
            }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn cập nhật toàn bộ định dạng và hiệu ứng mới vào preset \"\(originPresetName ?? "")\" trên Supabase không?")
        }
    }

    private func existingPresetButtons(originID: String, originName: String) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Button(action: { isOverwriteAlertPresented = true }) {
                HStack(spacing: 5) {
                    if isOverwriting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("Ghi đè \"\(originName)\"")
                        .lineLimit(1)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(DSColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(isOverwriting)

            Button(action: { isSaveModalPresented = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DSColors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Lưu thành bản sao preset mới...")
        }
    }

    private var newPresetButton: some View {
        Button(action: { isSaveModalPresented = true }) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down")
                Text("Lưu thành Preset...")
                Spacer()
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundStyle(DSColors.textSecondary)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(DSColors.textPrimary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func overwriteCurrentPreset() {
        guard let originID = originPresetID, let originName = originPresetName else { return }
        isOverwriting = true
        let existing = viewModel.dependencies.textTemplates.loadAllTemplates().first(where: { $0.id == originID })
        let updatedPreset = TextPreset(
            id: originID,
            name: originName,
            description: existing?.description ?? "Cập nhật từ timeline",
            category: existing?.category ?? .trending,
            tags: existing?.tags ?? [originName.lowercased()],
            defaultDuration: existing?.defaultDuration ?? 4.0,
            previewBadge: existing?.previewBadge,
            previewBackgroundHex: existing?.previewBackgroundHex ?? "#18181B",
            fallbackFontName: existing?.fallbackFontName,
            remoteFontURL: existing?.remoteFontURL,
            config: currentConfig,
            subLayers: existing?.subLayers ?? [],
            isSystem: false
        )
        Task {
            _ = viewModel.dependencies.textTemplates.saveTemplateToUserCache(updatedPreset)
            try? await viewModel.dependencies.presetRepositories.textRepository?.savePreset(updatedPreset)
            await MainActor.run {
                isOverwriting = false
                saveSuccessMessage = "Đã ghi đè \"\(originName)\" thành công!"
            }
        }
    }
}
