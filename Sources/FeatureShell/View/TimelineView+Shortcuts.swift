import SwiftUI
import AppKit
import CoreMedia
import Domain
import DesignSystem

extension TimelineView {
    func buildContextActions() -> TimelineClipContextActions {
        TimelineClipContextActions(
            playheadTime: playheadState.currentTime,
            canPasteClip: !viewModel.clipboardClips.isEmpty,
            canPasteAttributes: viewModel.attributeClipboardClip != nil,
            onCut: { viewModel.cutClips(targetClipID: $0) },
            onCopy: { viewModel.copyClips(targetClipID: $0) },
            onPaste: { viewModel.pasteClips(at: playheadState.currentTime) },
            onDuplicate: { viewModel.duplicateClips(targetClipID: $0) },
            onDelete: { viewModel.deleteClip(id: $0) },
            onSplitAtPlayhead: { id in
                viewModel.selectClip(id)
                _ = viewModel.splitClips(at: playheadState.currentTime)
            },
            onCopyAttributes: { viewModel.copyAttributes(from: $0) },
            onPasteAttributes: { viewModel.openPasteAttributesModal(for: $0) },
            onResetAttributes: { viewModel.resetClipAttributes(clipID: $0) },
            onToggleMuteClipAudio: { viewModel.toggleClipAudioMute(clipID: $0) },
            onSetSpeed: { viewModel.setClipSpeedPreset(clipID: $0, speed: $1) },
            onFlip: { viewModel.toggleClipFlip(clipID: $0, horizontal: $1) },
            onResetTransform: { viewModel.resetClipTransform(clipID: $0) },
            onSetDuration: { viewModel.setClipDurationPreset(clipID: $0, seconds: $1) },
            onMatchDurationBelow: { viewModel.matchClipDurationToBelowOrTimeline(clipID: $0) },
            onApplyTextStyleToTrack: { viewModel.applyTextStyleToAllInTrack(clipID: $0) },
            onAutoMarkBeats: { id, mode in
                viewModel.selectClip(id)
                viewModel.autoMarkBeats(mode: mode)
            },
            onToggleBeatAtPlayhead: { id in
                viewModel.selectClip(id)
                _ = viewModel.toggleBeatMarkerAtPlayhead(at: playheadState.currentTime)
            },
            onClearBeats: { id in
                viewModel.selectClip(id)
                viewModel.clearSelectedBeatMarkers()
            },
            onSetAudioFade: { viewModel.setAudioFadePreset(clipID: $0, seconds: $1) },
            canOverwriteOriginPreset: { canOverwriteOriginPreset(for: $0) },
            onOverwritePreset: { viewModel.presetOverwriteTargetClip = $0 }
        )
    }

    func handleTimelineKeyPress(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .delete || press.key == KeyEquivalent("\u{7f}") {
            viewModel.deleteSelectedClips()
            return .handled
        }
        if handleCommandOrOptionKey(press) {
            return .handled
        }
        if press.modifiers.isEmpty {
            return handleBareTimelineKey(press.key)
        }
        return .ignored
    }

    private func handleBareTimelineKey(_ key: KeyEquivalent) -> KeyPress.Result {
        switch key {
        case KeyEquivalent("s"):
            _ = viewModel.splitClips(at: playheadState.currentTime)
            return .handled
        case KeyEquivalent("m"):
            _ = viewModel.toggleBeatMarkerAtPlayhead(at: playheadState.currentTime)
            return .handled
        case .leftArrow:
            playheadState.stepFrame(by: -1)
            return .handled
        case .rightArrow:
            playheadState.stepFrame(by: 1)
            return .handled
        default:
            return .ignored
        }
    }

    private func handleCommandOrOptionKey(_ press: KeyPress) -> Bool {
        let char = press.characters.lowercased()
        let mods = press.modifiers
        if mods == .command {
            return dispatchCommandShortcut(char)
        }
        if mods == [.command, .shift] {
            return dispatchCommandShiftShortcut(char)
        }
        if mods == [.command, .option] {
            if char == "c" { viewModel.copyAttributes(); return true }
            if char == "v" { viewModel.openPasteAttributesModal(); return true }
        }
        if mods == .option {
            if char == "[" { viewModel.trimSelectedClipsToPlayhead(at: playheadState.currentTime, isStart: true); return true }
            if char == "]" { viewModel.trimSelectedClipsToPlayhead(at: playheadState.currentTime, isStart: false); return true }
        }
        return false
    }

    private func dispatchCommandShortcut(_ char: String) -> Bool {
        switch char {
        case "b": _ = viewModel.splitClips(at: playheadState.currentTime); return true
        case "e": _ = viewModel.extractAudio(); return true
        case "c": viewModel.copyClips(); return true
        case "x": viewModel.cutClips(); return true
        case "v": viewModel.pasteClips(at: playheadState.currentTime); return true
        case "d": viewModel.duplicateClips(); return true
        case "a": viewModel.selectAllClips(); return true
        case "z": _ = viewModel.undo(); return true
        default: return false
        }
    }

    private func dispatchCommandShiftShortcut(_ char: String) -> Bool {
        switch char {
        case "z": _ = viewModel.redo(); return true
        case "a": viewModel.clearSelection(); return true
        default: return false
        }
    }

    func handleBridgeShortcut(chars: String?, keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        let key = chars?.lowercased() ?? ""
        let mods = flags.intersection([.command, .shift, .option, .control])
        if mods == .command {
            return dispatchCommandShortcut(key)
        }
        if mods == [.command, .shift] && key == "a" {
            viewModel.clearSelection()
            return true
        }
        if mods == [.command, .option] {
            if key == "c" || keyCode == 8 { viewModel.copyAttributes(); return true }
            if key == "v" || keyCode == 9 { viewModel.openPasteAttributesModal(); return true }
        }
        if mods == .option {
            if key == "[" || keyCode == 33 {
                viewModel.trimSelectedClipsToPlayhead(at: playheadState.currentTime, isStart: true)
                return true
            }
            if key == "]" || keyCode == 30 {
                viewModel.trimSelectedClipsToPlayhead(at: playheadState.currentTime, isStart: false)
                return true
            }
        }
        return false
    }

    @ViewBuilder
    func makeSavePresetSheet(for clip: TimelineClip) -> some View {
        if let presetKind = savePresetKind(for: clip) {
            SavePresetModalView(
                kind: presetKind,
                originPresetID: clip.properties["originPresetId"]?.asString,
                originPresetName: clip.properties["originPresetName"]?.asString,
                dependencies: viewModel.dependencies,
                onSaveCompleted: { newID, newName in
                    viewModel.commitClipProperties(clipID: clip.id, properties: [
                        "originPresetId": .string(newID),
                        "originPresetName": .string(newName)
                    ])
                    viewModel.presetSaveTargetClip = nil
                },
                onDismiss: { viewModel.presetSaveTargetClip = nil }
            )
        }
    }

    func makePasteAttributesSheet() -> some View {
        PasteAttributesModalView(
            sourceClipName: viewModel.attributeClipboardClip?.name ?? "Clip",
            targetCount: max(1, viewModel.pasteAttributesTargetClipIDs.count),
            availableCategories: viewModel.pasteAttributesCategories,
            selectedCategories: Binding(
                get: { viewModel.selectedAttributeCategories },
                set: { viewModel.selectedAttributeCategories = $0 }
            ),
            onConfirm: { viewModel.confirmPasteAttributes() },
            onCancel: { viewModel.isPasteAttributesPresented = false }
        )
    }

    func savePresetKind(for clip: TimelineClip) -> SavePresetModalView.PresetKind? {
        switch clip.kind {
        case .text:
            let cfg = TextConfiguration.decode(from: clip.properties["textConfig"]?.asString ?? "")
                ?? TextConfiguration(content: clip.name)
            return .text(config: cfg)
        case .adjustment:
            let cfg = AdjustmentConfiguration.decode(from: clip.properties["adjustmentConfig"]?.asString ?? "")
                ?? AdjustmentConfiguration()
            return .adjustment(config: cfg)
        default:
            return nil
        }
    }

    func canOverwriteOriginPreset(for clip: TimelineClip) -> Bool {
        guard let originID = clip.properties["originPresetId"]?.asString,
              let originName = clip.properties["originPresetName"]?.asString,
              !originID.isEmpty, !originName.isEmpty else {
            return false
        }
        let authorID = CommunityIdentity.currentAuthorID
        switch clip.kind {
        case .adjustment:
            guard let existing = viewModel.dependencies.adjustmentTemplates.loadAllTemplates()
                .first(where: { $0.id == originID }) else { return true }
            return existing.canBeModified(by: authorID)
        case .text:
            guard let existing = viewModel.dependencies.textTemplates.loadAllTemplates()
                .first(where: { $0.id == originID }) else { return true }
            return existing.canBeModified(by: authorID)
        default:
            return false
        }
    }

    func overwriteOriginPreset(for clip: TimelineClip) {
        guard canOverwriteOriginPreset(for: clip),
              let originID = clip.properties["originPresetId"]?.asString,
              let originName = clip.properties["originPresetName"]?.asString,
              let presetKind = savePresetKind(for: clip) else { return }

        let deps = viewModel.dependencies
        Task { @MainActor in
            do {
                switch presetKind {
                case .adjustment(let cfg):
                    try await overwriteAdjustmentPreset(id: originID, name: originName, config: cfg, deps: deps)
                case .text(let cfg):
                    try await overwriteTextPreset(id: originID, name: originName, config: cfg, deps: deps)
                }
            } catch {
                presetOverwriteErrorMessage = "Failed to overwrite \"\(originName)\": \(error.localizedDescription)"
            }
        }
    }

    private func overwriteAdjustmentPreset(
        id: String,
        name: String,
        config: AdjustmentConfiguration,
        deps: EditorDependencies
    ) async throws {
        let existing = deps.adjustmentTemplates.loadAllTemplates().first(where: { $0.id == id })
        let updated = AdjustmentPreset(
            id: id,
            name: name,
            description: existing?.description ?? "Updated from timeline",
            category: existing?.category ?? .cinematic,
            tags: existing?.tags ?? [name.lowercased()],
            previewBadge: existing?.previewBadge,
            previewColorsHex: existing?.previewColorsHex ?? ["#27272A", "#52525B"],
            config: config,
            isSystem: false,
            community: existing?.community
        )
        _ = deps.adjustmentTemplates.saveTemplateToUserCache(updated)
        try await deps.presetRepositories.adjustmentRepository?.savePreset(updated)
    }

    private func overwriteTextPreset(
        id: String,
        name: String,
        config: TextConfiguration,
        deps: EditorDependencies
    ) async throws {
        let existing = deps.textTemplates.loadAllTemplates().first(where: { $0.id == id })
        let updated = TextPreset(
            id: id,
            name: name,
            description: existing?.description ?? "Updated from timeline",
            category: existing?.category ?? .trending,
            tags: existing?.tags ?? [name.lowercased()],
            defaultDuration: existing?.defaultDuration ?? 4.0,
            previewBadge: existing?.previewBadge,
            previewBackgroundHex: existing?.previewBackgroundHex ?? "#18181B",
            fallbackFontName: existing?.fallbackFontName,
            remoteFontURL: existing?.remoteFontURL,
            config: config,
            isSystem: false,
            community: existing?.community
        )
        _ = deps.textTemplates.saveTemplateToUserCache(updated)
        try await deps.presetRepositories.textRepository?.savePreset(updated)
    }
    var presetOverwriteAlertsView: some View {
        Color.clear
            .alert(
                String(localized: "Confirm Preset Overwrite"),
                isPresented: Binding(get: { viewModel.presetOverwriteTargetClip != nil }, set: { if !$0 { viewModel.presetOverwriteTargetClip = nil } }),
                presenting: viewModel.presetOverwriteTargetClip
            ) { clip in
                Button(String(localized: "Overwrite"), role: .destructive) {
                    overwriteOriginPreset(for: clip)
                    viewModel.presetOverwriteTargetClip = nil
                }
                Button(String(localized: "Cancel"), role: .cancel) {
                    viewModel.presetOverwriteTargetClip = nil
                }
            } message: { clip in
                let originName = clip.properties["originPresetName"]?.asString ?? clip.name
                Text(String(localized: "Are you sure you want to update all new parameters to preset \"\(originName)\" on Supabase?"))
            }
            .alert(
                String(localized: "Preset Overwrite Failed"),
                isPresented: Binding(get: { presetOverwriteErrorMessage != nil }, set: { if !$0 { presetOverwriteErrorMessage = nil } })
            ) {
                Button(String(localized: "OK"), role: .cancel) { presetOverwriteErrorMessage = nil }
            } message: {
                Text(presetOverwriteErrorMessage ?? "")
            }
    }
}
