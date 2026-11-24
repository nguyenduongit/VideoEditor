import Foundation

extension TransitionLibraryItem {
    /// 10 Mẫu Basic (Chuyển cảnh cơ bản) và 12 Mẫu Slide & Wipe (Trượt và quét).
    /// Mỗi preset chứa đầy đủ `parameterValues` điều khiển trực tiếp thuật toán Metal Compute Kernel.
    /// Tuân thủ AGENTS.md (Pure Domain, Sendable, File <= 300 dòng).
    public static let catalogBasic: [TransitionLibraryItem] = [
        // MARK: - 1. Basic (10 presets)
        TransitionLibraryItem(
            id: "trans_basic_fade", name: "Fade", description: "Cross fade",
            category: .basic, tags: ["basic", "fade"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "circle.lefthalf.filled",
            parameterValues: ["gammaCurve": 1.0, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_basic_fade_in", name: "Fade In", description: "Fade in smoothly",
            category: .basic, tags: ["basic", "fade in"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "sun.min.fill",
            parameterValues: ["gammaCurve": 1.0, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_basic_fade_out", name: "Fade Out", description: "Fade out smoothly",
            category: .basic, tags: ["basic", "fade out"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "moon.fill",
            parameterValues: ["gammaCurve": 1.0, "mode": 2.0]
        ),
        TransitionLibraryItem(
            id: "dissolve_default", name: "Dissolve", description: "Blend two scenes together",
            category: .basic, tags: ["basic", "dissolve", "trans_basic_dissolve"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "square.fill.and.line.vertical.and.square.fill",
            parameters: [
                CustomParameterDescriptor(id: "gammaCurve", title: "Gamma Smoothness", minValue: 0.5, maxValue: 2.2, defaultValue: 1.0, step: 0.05)
            ],
            parameterValues: ["gammaCurve": 1.0, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_basic_cross_dissolve", name: "Cross Dissolve", description: "Smooth cross dissolve blend",
            category: .basic, tags: ["basic", "cross dissolve"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "square.2.layers.3d",
            parameterValues: ["gammaCurve": 1.45, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_basic_mix", name: "Mix", description: "Mix two frames",
            category: .basic, tags: ["basic", "mix"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "slider.horizontal.2.square",
            parameterValues: ["gammaCurve": 0.75, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_basic_black_fade", name: "Black Fade", description: "Dip through black",
            category: .basic, tags: ["basic", "black fade"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "circle.fill",
            parameterValues: ["gammaCurve": 1.0, "mode": 3.0]
        ),
        TransitionLibraryItem(
            id: "trans_basic_white_fade", name: "White Fade", description: "Dip through white",
            category: .basic, tags: ["basic", "white fade"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "circle",
            parameterValues: ["gammaCurve": 1.0, "mode": 4.0]
        ),
        TransitionLibraryItem(
            id: "trans_basic_flash", name: "Flash", description: "Bright flash cut",
            category: .basic, tags: ["basic", "flash"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "bolt.fill",
            parameterValues: ["gammaCurve": 1.0, "mode": 5.0]
        ),
        TransitionLibraryItem(
            id: "trans_basic_white_flash", name: "White Flash", description: "Crisp white flash",
            category: .basic, tags: ["basic", "white flash"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "sparkles",
            parameterValues: ["gammaCurve": 1.0, "mode": 6.0]
        ),

        // MARK: - 2. Slide / Wipe (12 presets)
        TransitionLibraryItem(
            id: "trans_slide_left", name: "Slide Left", description: "Slide left",
            category: .slideWipe, tags: ["slide", "left"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.left.square.fill",
            parameterValues: ["dirX": -1.0, "dirY": 0.0, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_slide_right", name: "Slide Right", description: "Slide right",
            category: .slideWipe, tags: ["slide", "right"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.right.square.fill",
            parameterValues: ["dirX": 1.0, "dirY": 0.0, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_slide_up", name: "Slide Up", description: "Slide upward",
            category: .slideWipe, tags: ["slide", "up"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.up.square.fill",
            parameterValues: ["dirX": 0.0, "dirY": -1.0, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_slide_down", name: "Slide Down", description: "Slide downward",
            category: .slideWipe, tags: ["slide", "down"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.down.square.fill",
            parameterValues: ["dirX": 0.0, "dirY": 1.0, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_push_left", name: "Push Left", description: "Push left",
            category: .slideWipe, tags: ["push", "left"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.lefthalf.inset.filled.arrow.left",
            parameterValues: ["dirX": -1.0, "dirY": 0.0, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_push_right", name: "Push Right", description: "Push right",
            category: .slideWipe, tags: ["push", "right"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.righthalf.inset.filled.arrow.right",
            parameterValues: ["dirX": 1.0, "dirY": 0.0, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_push_up", name: "Push Up", description: "Push upward",
            category: .slideWipe, tags: ["push", "up"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.up.to.line",
            parameterValues: ["dirX": 0.0, "dirY": -1.0, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_push_down", name: "Push Down", description: "Push downward",
            category: .slideWipe, tags: ["push", "down"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.down.to.line",
            parameterValues: ["dirX": 0.0, "dirY": 1.0, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_wipe_left", name: "Wipe Left", description: "Wipe right to left",
            category: .slideWipe, tags: ["wipe", "left"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.lefthalf.filled",
            parameterValues: ["dirX": -1.0, "dirY": 0.0, "mode": 2.0]
        ),
        TransitionLibraryItem(
            id: "trans_wipe_right", name: "Wipe Right", description: "Wipe left to right",
            category: .slideWipe, tags: ["wipe", "right"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.righthalf.filled",
            parameterValues: ["dirX": 1.0, "dirY": 0.0, "mode": 2.0]
        ),
        TransitionLibraryItem(
            id: "trans_wipe_up", name: "Wipe Up", description: "Wipe bottom to top",
            category: .slideWipe, tags: ["wipe", "up"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.tophalf.filled",
            parameterValues: ["dirX": 0.0, "dirY": -1.0, "mode": 2.0]
        ),
        TransitionLibraryItem(
            id: "trans_wipe_down", name: "Wipe Down", description: "Wipe top to bottom",
            category: .slideWipe, tags: ["wipe", "down"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.bottomhalf.filled",
            parameterValues: ["dirX": 0.0, "dirY": 1.0, "mode": 2.0]
        )
    ]
}
