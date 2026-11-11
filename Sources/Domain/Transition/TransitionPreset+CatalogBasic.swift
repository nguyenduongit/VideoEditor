import Foundation

extension TransitionPreset {
    /// 10 Mẫu Basic (Chuyển cảnh cơ bản) và 12 Mẫu Slide & Wipe (Trượt và quét).
    /// Mỗi preset chứa đầy đủ `parameterValues` điều khiển trực tiếp thuật toán Metal Compute Kernel.
    /// Tuân thủ AGENTS.md (Pure Domain, Sendable, File <= 300 dòng).
    public static let catalogBasic: [TransitionPreset] = [
        // MARK: - 1. Basic (10 mẫu)
        TransitionPreset(
            id: "trans_basic_fade", name: "Fade", description: "Mờ dần",
            category: .basic, tags: ["basic", "fade", "mo dan"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "circle.lefthalf.filled",
            parameterValues: ["gammaCurve": 1.0, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_basic_fade_in", name: "Fade In", description: "Hiện dần",
            category: .basic, tags: ["basic", "fade in", "hien dan"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "sun.min.fill",
            parameterValues: ["gammaCurve": 1.0, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_basic_fade_out", name: "Fade Out", description: "Biến mất dần",
            category: .basic, tags: ["basic", "fade out", "bien mat"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "moon.fill",
            parameterValues: ["gammaCurve": 1.0, "mode": 2.0], isSystem: true
        ),
        TransitionPreset(
            id: "dissolve_default", name: "Dissolve", description: "Hòa tan hai cảnh",
            category: .basic, tags: ["basic", "dissolve", "hoa tan", "trans_basic_dissolve"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "square.fill.and.line.vertical.and.square.fill",
            parameters: [
                CustomParameterDescriptor(id: "gammaCurve", title: "Độ mượt Gamma", minValue: 0.5, maxValue: 2.2, defaultValue: 1.0, step: 0.05)
            ],
            parameterValues: ["gammaCurve": 1.0, "mode": 0.0],
            isSystem: true
        ),
        TransitionPreset(
            id: "trans_basic_cross_dissolve", name: "Cross Dissolve", description: "Hai cảnh hòa trộn",
            category: .basic, tags: ["basic", "cross dissolve", "hoa tron"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "square.2.layers.3d",
            parameterValues: ["gammaCurve": 1.45, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_basic_mix", name: "Mix", description: "Trộn hai khung hình",
            category: .basic, tags: ["basic", "mix", "tron"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "slider.horizontal.2.square",
            parameterValues: ["gammaCurve": 0.75, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_basic_black_fade", name: "Black Fade", description: "Chuyển qua màn hình đen",
            category: .basic, tags: ["basic", "black fade", "man den"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "circle.fill",
            parameterValues: ["gammaCurve": 1.0, "mode": 3.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_basic_white_fade", name: "White Fade", description: "Chuyển qua màn hình trắng",
            category: .basic, tags: ["basic", "white fade", "man trang"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "circle",
            parameterValues: ["gammaCurve": 1.0, "mode": 4.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_basic_flash", name: "Flash", description: "Chớp sáng",
            category: .basic, tags: ["basic", "flash", "chop sang"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "bolt.fill",
            parameterValues: ["gammaCurve": 1.0, "mode": 5.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_basic_white_flash", name: "White Flash", description: "Chớp trắng",
            category: .basic, tags: ["basic", "white flash", "chop trang"], defaultDuration: 2.0,
            shaderType: .dissolve, iconName: "sparkles",
            parameterValues: ["gammaCurve": 1.0, "mode": 6.0], isSystem: true
        ),

        // MARK: - 2. Slide / Wipe (12 mẫu)
        TransitionPreset(
            id: "trans_slide_left", name: "Slide Left", description: "Trượt sang trái",
            category: .slideWipe, tags: ["slide", "left", "truot trai"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.left.square.fill",
            parameterValues: ["dirX": -1.0, "dirY": 0.0, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_slide_right", name: "Slide Right", description: "Trượt sang phải",
            category: .slideWipe, tags: ["slide", "right", "truot phai"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.right.square.fill",
            parameterValues: ["dirX": 1.0, "dirY": 0.0, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_slide_up", name: "Slide Up", description: "Trượt lên",
            category: .slideWipe, tags: ["slide", "up", "truot len"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.up.square.fill",
            parameterValues: ["dirX": 0.0, "dirY": -1.0, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_slide_down", name: "Slide Down", description: "Trượt xuống",
            category: .slideWipe, tags: ["slide", "down", "truot xuong"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.down.square.fill",
            parameterValues: ["dirX": 0.0, "dirY": 1.0, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_push_left", name: "Push Left", description: "Đẩy sang trái",
            category: .slideWipe, tags: ["push", "left", "day trai"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.lefthalf.inset.filled.arrow.left",
            parameterValues: ["dirX": -1.0, "dirY": 0.0, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_push_right", name: "Push Right", description: "Đẩy sang phải",
            category: .slideWipe, tags: ["push", "right", "day phai"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.righthalf.inset.filled.arrow.right",
            parameterValues: ["dirX": 1.0, "dirY": 0.0, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_push_up", name: "Push Up", description: "Đẩy lên",
            category: .slideWipe, tags: ["push", "up", "day len"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.up.to.line",
            parameterValues: ["dirX": 0.0, "dirY": -1.0, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_push_down", name: "Push Down", description: "Đẩy xuống",
            category: .slideWipe, tags: ["push", "down", "day xuong"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "arrow.down.to.line",
            parameterValues: ["dirX": 0.0, "dirY": 1.0, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_wipe_left", name: "Wipe Left", description: "Quét từ phải sang trái",
            category: .slideWipe, tags: ["wipe", "left", "quet trai"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.lefthalf.filled",
            parameterValues: ["dirX": -1.0, "dirY": 0.0, "mode": 2.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_wipe_right", name: "Wipe Right", description: "Quét từ trái sang phải",
            category: .slideWipe, tags: ["wipe", "right", "quet phai"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.righthalf.filled",
            parameterValues: ["dirX": 1.0, "dirY": 0.0, "mode": 2.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_wipe_up", name: "Wipe Up", description: "Quét từ dưới lên",
            category: .slideWipe, tags: ["wipe", "up", "quet len"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.tophalf.filled",
            parameterValues: ["dirX": 0.0, "dirY": -1.0, "mode": 2.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_wipe_down", name: "Wipe Down", description: "Quét từ trên xuống",
            category: .slideWipe, tags: ["wipe", "down", "quet xuong"], defaultDuration: 2.0,
            shaderType: .directionalPush, iconName: "rectangle.bottomhalf.filled",
            parameterValues: ["dirX": 0.0, "dirY": 1.0, "mode": 2.0], isSystem: true
        )
    ]
}
