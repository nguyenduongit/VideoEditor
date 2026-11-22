import SwiftUI
import Domain
import DesignSystem

/// Bảng Inspector chuyên dụng cho clip Hiệu ứng thị giác (Effect Layer).
/// Tự động sinh các thanh trượt tùy chỉnh (`customParameters`) được định nghĩa trong Gói Sáng Tạo Mở.
/// Hỗ trợ lưu và ghi đè Effect Preset trên Supabase & bộ nhớ đệm.
/// Tuân thủ AGENTS.md (1 File = 1 Primary Type, Ubiquitous Language, Hàm <= 50 dòng, Body <= 40 dòng).
public struct EffectInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            headerSection
            EffectPresetActionSectionView(viewModel: viewModel, currentConfig: currentConfig)
            Divider().background(DSColors.blockBorder)
            slidersSection
            if !currentConfig.customParameters.isEmpty {
                Divider().background(DSColors.blockBorder)
                customParametersSection
            }
        }
        .padding(.vertical, DSSpacing.sm)
    }

    private var headerSection: some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                Circle()
                    .fill(DSColors.clipEffect.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: currentConfig.type.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DSColors.clipEffect)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.selectedClip?.name ?? currentConfig.type.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)

                Text(currentConfig.type.description)
                    .font(.system(size: 10.5))
                    .foregroundStyle(DSColors.textSecondary)
                    .lineLimit(2)
            }
        }
    }

    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "EFFECT PARAMETERS"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: String(localized: "Intensity"),
                value: Binding(
                    get: { viewModel.liveNumber(for: "intensity", default: currentConfig.intensity) },
                    set: { val in updateConfig(key: "intensity", value: val) { $0.intensity = val } }
                ),
                range: 0.0...1.0,
                step: 0.01,
                defaultValue: 1.0,
                unit: "%",
                trailingAccessory: effectKeyframeAccessory(for: "intensity", defaultVal: currentConfig.intensity),
                onEditingChanged: { editing in
                    if !editing { commitConfig() }
                }
            )

            DSSliderWithInput(
                title: String(localized: "Speed"),
                value: Binding(
                    get: { viewModel.liveNumber(for: "effectSpeed", default: currentConfig.speed) },
                    set: { val in updateConfig(key: "effectSpeed", value: val) { $0.speed = val } }
                ),
                range: 0.2...3.0,
                step: 0.05,
                defaultValue: 1.0,
                unit: "x",
                trailingAccessory: effectKeyframeAccessory(for: "effectSpeed", defaultVal: currentConfig.speed),
                onEditingChanged: { editing in
                    if !editing { commitConfig() }
                }
            )

            beatSyncControl

            if currentConfig.type == .cinematicBlur && currentConfig.customParameters.isEmpty {
                DSSliderWithInput(
                    title: String(localized: "Blur Radius"),
                    value: Binding(
                        get: { viewModel.liveNumber(for: "blurRadius", default: currentConfig.blurRadius) },
                        set: { val in updateConfig(key: "blurRadius", value: val) { $0.blurRadius = val } }
                    ),
                    range: 2.0...80.0,
                    step: 1.0,
                    defaultValue: 20.0,
                    unit: "px",
                    trailingAccessory: effectKeyframeAccessory(for: "blurRadius", defaultVal: currentConfig.blurRadius),
                    onEditingChanged: { editing in
                        if !editing { commitConfig() }
                    }
                )
            }
        }
    }

    private var beatSyncControl: some View {
        HStack(spacing: DSSpacing.sm) {
            ZStack {
                Circle()
                    .fill(currentConfig.isBeatSynced ? DSColors.toggleCyan.opacity(0.2) : DSColors.windowBackground)
                    .frame(width: 28, height: 28)
                Image(systemName: "music.note")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(currentConfig.isBeatSynced ? DSColors.toggleCyan : DSColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Beat Sync"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textPrimary)
                Text(String(localized: "Auto shake, bounce, or mini-zoom to audio beats"))
                    .font(.system(size: 9.5))
                    .foregroundStyle(DSColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { currentConfig.isBeatSynced },
                set: { val in
                    updateConfig(key: "isBeatSynced", value: val ? 1.0 : 0.0) { $0.isBeatSynced = val }
                    commitConfig()
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(DSSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .fill(DSColors.blockBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small)
                .stroke(currentConfig.isBeatSynced ? DSColors.toggleCyan.opacity(0.4) : DSColors.blockBorder, lineWidth: 1)
        )
    }

    private var customParametersSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "CREATIVE SHADER PARAMETERS"))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DSColors.textSecondary)

            ForEach(currentConfig.customParameters) { param in
                DSSliderWithInput(
                    title: param.title,
                    value: Binding(
                        get: { viewModel.liveNumber(for: param.id, default: currentConfig.value(forParameter: param.id)) },
                        set: { val in updateConfig(key: param.id, value: val) { $0.setValue(val, forParameter: param.id) } }
                    ),
                    range: param.minValue...param.maxValue,
                    step: param.step,
                    defaultValue: param.defaultValue,
                    unit: param.unit,
                    trailingAccessory: effectKeyframeAccessory(for: param.id, defaultVal: param.defaultValue),
                    onEditingChanged: { editing in
                        if !editing { commitConfig() }
                    }
                )
            }
        }
    }

    private func effectKeyframeAccessory(for key: String, defaultVal: Double) -> AnyView {
        let keys = [key]
        return AnyView(
            DSKeyframeControl(
                hasKeyframesOnTrack: viewModel.hasKeyframes(for: keys),
                isAtKeyframe: viewModel.hasKeyframeAtPlayhead(for: keys),
                canGoPrevious: viewModel.canJumpToPreviousKeyframe(for: keys),
                canGoNext: viewModel.canJumpToNextKeyframe(for: keys),
                selectedCurveID: viewModel.activeInterpolation(for: keys).rawValue,
                curveOptions: viewModel.keyframeCurveOptions,
                onToggleKeyframe: { viewModel.toggleKeyframe(for: keys, defaultValues: [key: defaultVal]) },
                onPreviousKeyframe: { viewModel.jumpToPreviousKeyframe(for: keys) },
                onNextKeyframe: { viewModel.jumpToNextKeyframe(for: keys) },
                onSelectCurve: { curveID in
                    if let interp = KeyframeInterpolation(rawValue: curveID) {
                        viewModel.setInterpolation(interp, for: keys)
                    }
                },
                onClearAllKeyframes: { viewModel.clearAllKeyframes(for: keys) }
            )
        )
    }

    private var currentConfig: EffectConfiguration {
        let str = viewModel.liveProperties["effectConfig"]?.asString
            ?? viewModel.selectedClip?.properties["effectConfig"]?.asString ?? ""
        return EffectConfiguration.decode(from: str) ?? EffectConfiguration()
    }

    private func updateConfig(key: String, value: Double, _ mutate: (inout EffectConfiguration) -> Void) {
        var cfg = currentConfig
        mutate(&cfg)
        if let json = cfg.encodeToJSON() {
            viewModel.updateLiveText(key: "effectConfig", text: json)
            viewModel.updateLiveValue(key: key, value: value)
        }
    }

    private func commitConfig() {
        if let json = currentConfig.encodeToJSON() {
            viewModel.commitTextProperty(key: "effectConfig", text: json)
        }
    }
}

// MARK: - Subview nội bộ: Thao tác Lưu & Ghi đè Preset (Private Cohesion)

public struct EffectPresetActionSectionView: View {
    @Bindable var viewModel: InspectorViewModel
    let currentConfig: EffectConfiguration

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
                    saveSuccessMessage = "Saved preset \"\(newName)\" successfully!"
                },
                onDismiss: { isSaveModalPresented = false }
            )
        }
        .alert("Confirm Preset Overwrite", isPresented: $isOverwriteAlertPresented) {
            Button(String(localized: "Overwrite"), role: .destructive) {
                overwriteCurrentPreset()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Are you sure you want to update all new effect parameters to preset \"\(originPresetName ?? "")\" on Supabase?"))
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
                    Text(String(localized: "Overwrite \"\(originName)\""))
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
            .help(String(localized: "Save as a new preset copy..."))
        }
    }

    private var newPresetButton: some View {
        Button(action: { isSaveModalPresented = true }) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down")
                Text(String(localized: "Save as Preset..."))
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
            community: existing?.community
        )

        Task {
            do {
                viewModel.dependencies.effectTemplates.updateInMemoryPreset(updatedPreset)
                try await viewModel.dependencies.presetRepositories.effectRepository?.savePreset(updatedPreset)
                await MainActor.run {
                    isOverwriting = false
                    saveSuccessMessage = "Updated \"\(originName)\" successfully!"
                }
            } catch {
                await MainActor.run {
                    isOverwriting = false
                    saveSuccessMessage = "Update error: \(error.localizedDescription)"
                }
            }
        }
    }
}
