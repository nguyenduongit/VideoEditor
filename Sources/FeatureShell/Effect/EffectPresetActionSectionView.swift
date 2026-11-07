import SwiftUI
import Domain
import DesignSystem

/// Khu vực nút đóng góp Preset mới / ghi đè Preset cho tab Effects trong Inspector.
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct EffectPresetActionSectionView: View {
    @Bindable private var viewModel: InspectorViewModel
    private let currentConfig: EffectConfiguration

    @State private var isSaveModalPresented: Bool = false
    @State private var isOverwriteAlertPresented: Bool = false
    @State private var isOverwriting: Bool = false
    @State private var saveSuccessMessage: String?

    public init(viewModel: InspectorViewModel, currentConfig: EffectConfiguration) {
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

    private var canOverwriteOrigin: Bool {
        guard let originID = originPresetID else { return false }
        let all = viewModel.dependencies.effectTemplates.loadAllTemplates()
        guard let existing = all.first(where: { $0.id == originID }) else { return false }
        return existing.canBeModified(by: CommunityIdentity.currentAuthorID)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            if let originID = originPresetID, let originName = originPresetName, canOverwriteOrigin {
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
                kind: .effect(config: currentConfig),
                originPresetID: originPresetID,
                originPresetName: originPresetName,
                dependencies: viewModel.dependencies,
                onSaveCompleted: { newID, newName in
                    viewModel.commitTextProperty(key: "originPresetId", text: newID)
                    viewModel.commitTextProperty(key: "originPresetName", text: newName)
                    saveSuccessMessage = "Đã đóng góp preset \"\(newName)\" lên Thư viện!"
                },
                onDismiss: { isSaveModalPresented = false }
            )
        }
        .alert("Xác nhận ghi đè Preset", isPresented: $isOverwriteAlertPresented) {
            Button(String(localized: "Ghi đè"), role: .destructive) {
                overwriteCurrentPreset()
            }
            Button(String(localized: "Hủy"), role: .cancel) {}
        } message: {
            Text(String(localized: "Cập nhật thông số hiệu ứng mới vào preset \"\(originPresetName ?? "")\" trên kho cộng đồng?"))
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
                    Text(String(localized: "Ghi đè \"\(originName)\""))
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
            .help(String(localized: "Lưu thành một Preset mới trên Thư viện Cộng đồng"))
        }
    }

    private var newPresetButton: some View {
        Button(action: { isSaveModalPresented = true }) {
            HStack(spacing: 5) {
                Image(systemName: "globe.asia.australia.fill")
                Text(String(localized: "Đóng góp thành Preset"))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DSColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func overwriteCurrentPreset() {
        guard let originID = originPresetID, let originName = originPresetName else { return }
        isOverwriting = true
        saveSuccessMessage = nil

        let allPresets = viewModel.dependencies.effectTemplates.loadAllTemplates()
        let existing = allPresets.first(where: { $0.id == originID })

        let updatedPreset = EffectPreset(
            id: originID,
            name: originName,
            description: existing?.description ?? "",
            category: existing?.category ?? .lightTransition,
            tags: existing?.tags ?? [originName.lowercased()],
            config: currentConfig,
            isSystem: false,
            community: existing?.community ?? CommunityMetadata(
                authorID: CommunityIdentity.currentAuthorID,
                authorName: CommunityIdentity.currentAuthorName
            )
        )

        Task {
            do {
                viewModel.dependencies.effectTemplates.updateInMemoryPreset(updatedPreset)
                try await viewModel.dependencies.presetRepositories.effectRepository?.savePreset(updatedPreset)
                await MainActor.run {
                    isOverwriting = false
                    saveSuccessMessage = "Đã cập nhật \"\(originName)\" thành công!"
                }
            } catch {
                await MainActor.run {
                    isOverwriting = false
                    saveSuccessMessage = "Lỗi cập nhật: \(error.localizedDescription)"
                }
            }
        }
    }
}

