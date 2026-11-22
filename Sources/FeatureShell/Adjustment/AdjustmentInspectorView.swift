import SwiftUI
import Domain
import DesignSystem

/// Bảng điều khiển Inspector chuyên dụng cho Adjustment Layer.
/// Hiển thị trực tiếp 5 tab con: Basic, HSL, Wheels, Curves, Effects, cùng thanh công cụ Preset (Lưu/Ghi đè).
/// Tuân thủ AGENTS.md (1 File = 1 Primary Type, Ubiquitous Language, Hàm <= 50 dòng, Body <= 40 dòng).
public struct AdjustmentInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            presetActionsBlock

            switch viewModel.effectiveTab {
            case "Basic":
                AdjustmentBasicSectionView(viewModel: viewModel)
            case "HSL":
                AdjustmentHSLSectionView(viewModel: viewModel)
            case "Wheels":
                AdjustmentWheelsSectionView(viewModel: viewModel)
            case "Curves":
                curvesSection
            case "Effects":
                AdjustmentEffectsSectionView(viewModel: viewModel)
            default:
                AdjustmentBasicSectionView(viewModel: viewModel)
            }
        }
        .padding(.vertical, DSSpacing.sm)
    }

    @ViewBuilder
    private var presetActionsBlock: some View {
        if viewModel.effectiveTab == "Basic" {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                if viewModel.selectedClip?.originPresetID != nil {
                    presetMixSection
                }
                AdjustmentPresetActionSectionView(viewModel: viewModel, currentConfig: currentConfig)
            }
        }
    }

    private var presetMixSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(String(localized: "CORE COLOR PROPERTIES"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            let intensityBinding = Binding<Double>(
                get: { viewModel.liveNumber(for: "intensity", default: 1.0) },
                set: { viewModel.updateLiveValue(key: "intensity", value: $0) }
            )
            DSSliderWithInput(
                title: "Preset Intensity (Mix)",
                value: intensityBinding,
                range: 0.0...1.0,
                step: 0.01,
                defaultValue: 1.0,
                unit: "%",
                onEditingChanged: { editing in
                    viewModel.onSliderEditingChanged(key: "intensity", isEditing: editing)
                }
            )

            let opacityBinding = Binding<Double>(
                get: { viewModel.liveNumber(for: "opacity", default: 1.0) },
                set: { viewModel.updateLiveValue(key: "opacity", value: $0) }
            )
            DSSliderWithInput(
                title: "Opacity",
                value: opacityBinding,
                range: 0.0...1.0,
                step: 0.01,
                defaultValue: 1.0,
                unit: "%",
                onEditingChanged: { editing in
                    viewModel.onSliderEditingChanged(key: "opacity", isEditing: editing)
                }
            )
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private var curvesSection: some View {
        let curvesBinding = Binding<ColorCurvesAdjustments>(
            get: { currentConfig.curves },
            set: { newValue in
                var cfg = currentConfig
                cfg.curves = newValue
                if let json = cfg.encodeToJSON() {
                    viewModel.updateLiveText(key: "adjustmentConfig", text: json)
                }
            }
        )
        return ColorCurvesControlView(
            curves: curvesBinding,
            onEditingChanged: { editing in
                if !editing, let json = currentConfig.encodeToJSON() {
                    viewModel.commitTextProperty(key: "adjustmentConfig", text: json)
                }
            }
        )
    }

    private var currentConfig: AdjustmentConfiguration {
        let str = viewModel.liveProperties["adjustmentConfig"]?.asString
            ?? viewModel.selectedClip?.properties["adjustmentConfig"]?.asString ?? ""
        return AdjustmentConfiguration.decode(from: str) ?? AdjustmentConfiguration()
    }
}

// MARK: - Subview cục bộ: Thao tác Lưu & Ghi đè Preset (Private Cohesion)

private struct AdjustmentPresetActionSectionView: View {
    @Bindable var viewModel: InspectorViewModel
    let currentConfig: AdjustmentConfiguration

    @State private var isSaveModalPresented: Bool = false
    @State private var isOverwriteAlertPresented: Bool = false
    @State private var isOverwriting: Bool = false
    @State private var saveSuccessMessage: String?

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
        guard let existing = viewModel.dependencies.adjustmentTemplates.loadAllTemplates().first(where: { $0.id == originID }) else {
            return true
        }
        return existing.canBeModified(by: CommunityIdentity.currentAuthorID)
    }

    var body: some View {
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
                kind: .adjustment(config: currentConfig),
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
            Text(String(localized: "Are you sure you want to update all new parameters to preset \"\(originPresetName ?? "")\" on Supabase?"))
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
        let existing = viewModel.dependencies.adjustmentTemplates.loadAllTemplates().first(where: { $0.id == originID })
        let updatedPreset = AdjustmentPreset(
            id: originID,
            name: originName,
            description: existing?.description ?? "Updated from timeline",
            category: existing?.category ?? .cinematic,
            tags: existing?.tags ?? [originName.lowercased()],
            previewBadge: existing?.previewBadge,
            previewColorsHex: existing?.previewColorsHex ?? ["#27272A", "#52525B"],
            config: currentConfig,
            isSystem: false,
            community: existing?.community
        )
        Task {
            _ = viewModel.dependencies.adjustmentTemplates.saveTemplateToUserCache(updatedPreset)
            do {
                try await viewModel.dependencies.presetRepositories.adjustmentRepository?.savePreset(updatedPreset)
                await MainActor.run {
                    isOverwriting = false
                    saveSuccessMessage = "Overwrote \"\(originName)\" successfully!"
                }
            } catch {
                await MainActor.run {
                    isOverwriting = false
                    saveSuccessMessage = "Failed to save preset: \(error.localizedDescription)"
                }
            }
        }
    }
}
