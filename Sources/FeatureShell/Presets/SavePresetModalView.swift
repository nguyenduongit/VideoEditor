import SwiftUI
import Domain
import DesignSystem

/// Hộp thoại popover/sheet đóng góp Preset mới lên Kho Thư viện Cộng đồng Mở (Text, Adjustment, Effect).
/// Tuân thủ quy tắc R3.1 (File <= 300 dòng, View body <= 80 dòng) của AGENTS.md.
public struct SavePresetModalView: View {
    public enum PresetKind {
        case adjustment(config: AdjustmentConfiguration)
        case text(config: TextConfiguration)
        case effect(config: EffectConfiguration)
    }

    public let kind: PresetKind
    public let originPresetID: String?
    public let originPresetName: String?
    public let onSaveCompleted: (String, String) -> Void
    public let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var authorName: String = CommunityIdentity.currentAuthorName
    @State private var tagsInput: String = ""
    @State private var description: String = ""
    @State private var selectedAdjustmentCategory: AdjustmentTemplateCategory = .cinematic
    @State private var selectedTextCategory: TextTemplateCategory = .trending
    @State private var selectedEffectCategory: EffectTemplateCategory = .lightTransition
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private let dependencies: EditorDependencies

    public init(
        kind: PresetKind,
        originPresetID: String? = nil,
        originPresetName: String? = nil,
        dependencies: EditorDependencies = EditorDependencies(),
        onSaveCompleted: @escaping (String, String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.kind = kind
        self.originPresetID = originPresetID
        self.originPresetName = originPresetName
        self.dependencies = dependencies
        self.onSaveCompleted = onSaveCompleted
        self.onDismiss = onDismiss
        _name = State(initialValue: originPresetName ?? "Preset của tôi")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            headerView
            inputFormView
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.red)
            }
            actionButtonsView
        }
        .padding(DSSpacing.md)
        .frame(width: 340)
        .background(DSColors.windowBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "globe.asia.australia.fill")
                .foregroundStyle(DSColors.accent)
            Text(originPresetID != nil ? String(localized: "Đóng góp Bản Remix Mới") : String(localized: "Đóng góp lên Kho Cộng đồng"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSColors.textPrimary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DSColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var inputFormView: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            labeledTextField(title: "Tên Preset", placeholder: "Nhập tên preset...", text: $name)
            HStack(spacing: DSSpacing.sm) {
                labeledTextField(title: "Tác giả đóng góp", placeholder: "Tên của bạn...", text: $authorName)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Danh mục"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DSColors.textSecondary)
                    categoryPicker
                }
            }
            labeledTextField(title: "Từ khóa (cách nhau dấu phẩy)", placeholder: "vlog, cinematic, neon...", text: $tagsInput)
            labeledTextField(title: "Ghi chú / Mô tả (tùy chọn)", placeholder: "Mô tả ngắn phong cách...", text: $description)
        }
    }

    private func labeledTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: String.LocalizationValue(title)))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
            TextField(String(localized: String.LocalizationValue(placeholder)), text: text)
                .textFieldStyle(.plain)
                .padding(6)
                .background(DSColors.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    @ViewBuilder
    private var categoryPicker: some View {
        switch kind {
        case .adjustment:
            DSDropdown(
                selectedTitle: selectedAdjustmentCategory.rawValue,
                options: AdjustmentTemplateCategory.allCases.filter { $0 != .all }.map {
                    DSDropdownOption(id: $0.rawValue, title: $0.rawValue)
                },
                onSelect: { val in
                    if let cat = AdjustmentTemplateCategory(rawValue: val) {
                        selectedAdjustmentCategory = cat
                    }
                }
            )
        case .text:
            DSDropdown(
                selectedTitle: selectedTextCategory.rawValue,
                options: TextTemplateCategory.assignableCases.map {
                    DSDropdownOption(id: $0.rawValue, title: $0.rawValue)
                },
                onSelect: { val in
                    if let cat = TextTemplateCategory(rawValue: val) {
                        selectedTextCategory = cat
                    }
                }
            )
        case .effect:
            DSDropdown(
                selectedTitle: selectedEffectCategory.rawValue,
                options: EffectTemplateCategory.assignableCases.map {
                    DSDropdownOption(id: $0.rawValue, title: $0.rawValue)
                },
                onSelect: { val in
                    if let cat = EffectTemplateCategory(rawValue: val) {
                        selectedEffectCategory = cat
                    }
                }
            )
        }
    }

    private var actionButtonsView: some View {
        HStack(spacing: DSSpacing.sm) {
            Button(String(localized: "Hủy"), action: onDismiss)
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Spacer()

            Button(action: savePresetAction) {
                HStack(spacing: 4) {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                    }
                    Text(String(localized: "Chia sẻ lên Thư viện"))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : DSColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func parsedTags(trimmedName: String) -> [String] {
        let userTags = tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        return Array(Set([trimmedName.lowercased()] + userTags)).sorted()
    }

    private func savePresetAction() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        isSaving = true
        errorMessage = nil
        CommunityIdentity.currentAuthorName = authorName
        let newID = UUID().uuidString
        let tags = parsedTags(trimmedName: trimmedName)
        let communityMeta = CommunityMetadata(
            authorID: CommunityIdentity.currentAuthorID,
            authorName: CommunityIdentity.currentAuthorName,
            downloadsCount: 1,
            createdAtTimestamp: Date().timeIntervalSince1970
        )

        Task {
            do {
                switch kind {
                case .adjustment(let config):
                    let preset = AdjustmentPreset(
                        id: newID, name: trimmedName, description: description,
                        category: selectedAdjustmentCategory, tags: tags,
                        config: config, isSystem: false, community: communityMeta
                    )
                    _ = dependencies.adjustmentTemplates.saveTemplateToUserCache(preset)
                    try await dependencies.presetRepositories.adjustmentRepository?.savePreset(preset)
                case .text(let config):
                    let preset = TextPreset(
                        id: newID, name: trimmedName, description: description,
                        category: selectedTextCategory, tags: tags,
                        config: config, isSystem: false, community: communityMeta
                    )
                    _ = dependencies.textTemplates.saveTemplateToUserCache(preset)
                    try await dependencies.presetRepositories.textRepository?.savePreset(preset)
                case .effect(let config):
                    let preset = EffectPreset(
                        id: newID, name: trimmedName, description: description,
                        category: selectedEffectCategory, tags: tags,
                        config: config, isSystem: false, community: communityMeta
                    )
                    dependencies.effectTemplates.updateInMemoryPreset(preset)
                    try await dependencies.presetRepositories.effectRepository?.savePreset(preset)
                }
                await MainActor.run {
                    isSaving = false
                    onSaveCompleted(newID, trimmedName)
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Lỗi lưu Supabase: \(error.localizedDescription)"
                }
            }
        }
    }
}
