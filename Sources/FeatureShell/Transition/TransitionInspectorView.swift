import SwiftUI
import Domain
import DesignSystem

/// Bảng Inspector chuyên dụng cho hiệu ứng Chuyển cảnh (`CutTransition`) giữa 2 clip kề nhau:
/// Chọn họ GPU Shader 2-texture, Thời lượng, Căn chỉnh vết cắt, Đường cong Easing, Crossfade Âm thanh,
/// các Thanh trượt tham số động và Lưu mẫu lên Supabase.
/// Tuân thủ AGENTS.md R3.1 (File <= 300 dòng, View body <= 80 dòng).
public struct TransitionInspectorView: View {
    @Bindable private var viewModel: InspectorViewModel
    @State private var customPresetName: String = ""

    public init(viewModel: InspectorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            if let transition = viewModel.selectedTransition {
                headerAndKernelSection(transition)
                durationAndAudioSection(transition)
                alignmentAndEasingSection(transition)
                dynamicParametersSection(transition)
                savePresetAndDeleteSection(transition)
            } else {
                emptyView
            }
        }
        .padding(.vertical, DSSpacing.sm)
    }

    private func headerAndKernelSection(_ transition: CutTransition) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.md) {
                ZStack {
                    Circle()
                        .fill(DSColors.accent.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DSColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(transition.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DSColors.textPrimary)
                    Text("A/B Dual-Texture GPU · Không dịch nhịp cắt")
                        .font(.system(size: 10))
                        .foregroundStyle(DSColors.textSecondary)
                }
                Spacer()
            }

            HStack {
                Text("Thuật toán GPU")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { transition.shaderType },
                    set: { viewModel.updateTransitionShaderType($0) }
                )) {
                    ForEach(TransitionShaderType.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(width: 175)
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func durationAndAudioSection(_ transition: CutTransition) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("THỜI LƯỢNG & ÂM THANH")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            DSSliderWithInput(
                title: "Thời gian",
                value: Binding(
                    get: { transition.duration.seconds },
                    set: { viewModel.updateTransitionDuration($0, commit: false) }
                ),
                range: 0.1...3.0,
                step: 0.05,
                defaultValue: 0.5,
                unit: "s",
                onEditingChanged: { editing in
                    viewModel.onTransitionSliderEditingChanged(editing)
                }
            )

            Toggle(isOn: Binding(
                get: { transition.crossfadeAudio },
                set: { viewModel.updateTransitionCrossfadeAudio($0) }
            )) {
                Text("Hòa trộn âm thanh tự động (Audio Crossfade)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(DSColors.textPrimary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    private func alignmentAndEasingSection(_ transition: CutTransition) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("CĂN VẾT CẮT & GIA TỐC EASING")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSColors.textSecondary)

            HStack(spacing: DSSpacing.sm) {
                ForEach(TransitionAlignment.allCases, id: \.self) { align in
                    let isSelected = transition.alignment == align
                    Button(action: { viewModel.updateTransitionAlignment(align) }) {
                        Text(align.displayName)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.white : DSColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(isSelected ? DSColors.accent : DSColors.windowBackground)
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                            .overlay(RoundedRectangle(cornerRadius: DSRadius.small).stroke(DSColors.blockBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Đường cong nhịp")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSColors.textSecondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { transition.easing },
                    set: { viewModel.updateTransitionEasing($0) }
                )) {
                    ForEach(TransitionEasing.allCases) { curve in
                        Text(curve.displayName).tag(curve)
                    }
                }
                .labelsHidden()
                .frame(width: 175)
            }
        }
        .padding(DSSpacing.md)
        .background(DSColors.blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func dynamicParametersSection(_ transition: CutTransition) -> some View {
        let descriptors = viewModel.activeTransitionParameterDescriptors
        if !descriptors.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text("THÔNG SỐ KỸ XẢO ĐỘNG")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DSColors.textSecondary)

                ForEach(descriptors) { desc in
                    DSSliderWithInput(
                        title: desc.title,
                        value: Binding(
                            get: { viewModel.transitionParameterValue(for: desc) },
                            set: { viewModel.updateTransitionParameter(id: desc.id, value: $0, commit: false) }
                        ),
                        range: desc.minValue...desc.maxValue,
                        step: desc.step,
                        defaultValue: desc.defaultValue,
                        unit: desc.unit.isEmpty ? nil : desc.unit,
                        onEditingChanged: { editing in
                            viewModel.onTransitionSliderEditingChanged(editing)
                        }
                    )
                }
            }
            .padding(DSSpacing.md)
            .background(DSColors.blockBackground)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.block))
            .overlay(RoundedRectangle(cornerRadius: DSRadius.block).stroke(DSColors.blockBorder, lineWidth: 1))
        }
    }

    private func savePresetAndDeleteSection(_ transition: CutTransition) -> some View {
        VStack(spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.xs) {
                TextField("Tên mẫu mới...", text: $customPresetName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                Button(action: {
                    let fallback = customPresetName.isEmpty ? "\(transition.name) Custom" : customPresetName
                    viewModel.saveSelectedTransitionAsPreset(name: fallback)
                    customPresetName = ""
                }) {
                    Label("Lưu mẫu", systemImage: "icloud.and.arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button(role: .destructive, action: { viewModel.deleteSelectedTransition() }) {
                HStack {
                    Spacer()
                    Image(systemName: "trash").font(.system(size: 12))
                    Text("Xóa chuyển cảnh").font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(Color.red)
                .frame(height: 30)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small))
                .overlay(RoundedRectangle(cornerRadius: DSRadius.small).stroke(Color.red.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyView: some View {
        VStack(spacing: DSSpacing.sm) {
            Spacer(minLength: 40)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 26))
                .foregroundStyle(DSColors.textSecondary.opacity(0.45))
            Text("Chọn một điểm nối chuyển cảnh trên Timeline")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DSColors.textSecondary)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
    }
}
