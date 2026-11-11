import Foundation

extension TransitionPreset {
    /// 9 Mẫu Zoom, 9 Mẫu Blur và 10 Mẫu Camera & Motion.
    /// Mỗi preset chứa đầy đủ `parameterValues` điều khiển trực tiếp thuật toán Metal Compute Kernel.
    /// Tuân thủ AGENTS.md (Pure Domain, Sendable, File <= 300 dòng).
    public static let catalogMotion: [TransitionPreset] = [
        // MARK: - 3. Zoom (9 mẫu)
        TransitionPreset(
            id: "trans_zoom_in", name: "Zoom In", description: "Phóng to",
            category: .zoom, tags: ["zoom", "in", "phong to"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "plus.magnifyingglass",
            parameterValues: ["zoomStrength": 0.02, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_zoom_out", name: "Zoom Out", description: "Thu nhỏ",
            category: .zoom, tags: ["zoom", "out", "thu nho"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "minus.magnifyingglass",
            parameterValues: ["zoomStrength": 0.02, "mode": 2.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_zoom_in_blur", name: "Zoom In Blur", description: "Phóng to kèm nhòe",
            category: .zoom, tags: ["zoom", "in", "blur", "nhoe"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "arrow.up.left.and.arrow.down.right",
            parameterValues: ["zoomStrength": 0.45, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_zoom_out_blur", name: "Zoom Out Blur", description: "Thu nhỏ kèm nhòe",
            category: .zoom, tags: ["zoom", "out", "blur", "nhoe"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "arrow.down.right.and.arrow.up.left",
            parameterValues: ["zoomStrength": 0.45, "mode": 3.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_zoom_camera", name: "Camera Zoom", description: "Zoom kiểu máy quay",
            category: .zoom, tags: ["zoom", "camera", "may quay"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "video.fill",
            parameterValues: ["zoomStrength": 0.25, "mode": 4.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_zoom_pull_in", name: "Pull In", description: "Kéo vào",
            category: .zoom, tags: ["zoom", "pull in", "keo vao"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "arrow.down.forward.and.arrow.up.backward",
            parameterValues: ["zoomStrength": 0.18, "mode": 5.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_zoom_pull_out", name: "Pull Out", description: "Kéo ra",
            category: .zoom, tags: ["zoom", "pull out", "keo ra"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "arrow.up.backward.and.arrow.down.forward",
            parameterValues: ["zoomStrength": 0.18, "mode": 6.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_zoom_shake", name: "Zoom Shake", description: "Zoom rung",
            category: .zoom, tags: ["zoom", "shake", "rung"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "waveform.path",
            parameterValues: ["zoomStrength": 0.28, "mode": 7.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_zoom_twinkle", name: "Twinkle Zoom", description: "Zoom lấp lánh",
            category: .zoom, tags: ["zoom", "twinkle", "lap lanh"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "sparkles",
            parameterValues: ["zoomStrength": 0.22, "mode": 8.0], isSystem: true
        ),

        // MARK: - 4. Blur (9 mẫu)
        TransitionPreset(
            id: "trans_blur_basic", name: "Blur", description: "Làm mờ",
            category: .blur, tags: ["blur", "lam mo"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "drop.fill",
            parameterValues: ["blurStrength": 1.0, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_blur_motion", name: "Motion Blur", description: "Nhòe chuyển động",
            category: .blur, tags: ["blur", "motion", "chuyen dong"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "wind",
            parameterValues: ["blurStrength": 1.35, "mode": 2.0, "subParam": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_blur_radial", name: "Radial Blur", description: "Nhòe xuyên tâm",
            category: .blur, tags: ["blur", "radial", "xuyen tam"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "target",
            parameterValues: ["zoomStrength": 0.48, "mode": 10.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_blur_horizontal", name: "Horizontal Blur", description: "Nhòe ngang",
            category: .blur, tags: ["blur", "horizontal", "ngang"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "arrow.left.and.right",
            parameterValues: ["blurStrength": 1.45, "mode": 2.0, "subParam": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_blur_vertical", name: "Vertical Blur", description: "Nhòe dọc",
            category: .blur, tags: ["blur", "vertical", "doc"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "arrow.up.and.down",
            parameterValues: ["blurStrength": 1.45, "mode": 3.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_blur_spin", name: "Spin Blur", description: "Nhòe xoay",
            category: .blur, tags: ["blur", "spin", "xoay"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "tornado",
            parameterValues: ["zoomStrength": 0.45, "mode": 9.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_blur_directional", name: "Directional Blur", description: "Nhòe theo hướng",
            category: .blur, tags: ["blur", "directional", "huong"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "location.north.line.fill",
            parameterValues: ["blurStrength": 1.4, "mode": 2.0, "subParam": 0.785], isSystem: true
        ),
        TransitionPreset(
            id: "trans_blur_zoom", name: "Zoom Blur", description: "Nhòe phóng to",
            category: .blur, tags: ["blur", "zoom", "phong to"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "sparkle.magnifyingglass",
            parameterValues: ["zoomStrength": 0.55, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_blur_gaussian", name: "Gaussian Blur", description: "Nhòe Gaussian",
            category: .blur, tags: ["blur", "gaussian"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "aqi.medium",
            parameterValues: ["blurStrength": 1.65, "mode": 1.0], isSystem: true
        ),

        // MARK: - 5. Camera / Movement (10 mẫu)
        TransitionPreset(
            id: "trans_cam_whip_pan", name: "Whip Pan", description: "Lia máy cực nhanh",
            category: .camera, tags: ["camera", "whip pan", "lia may"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "arrow.left.to.line.compact",
            parameterValues: ["blurStrength": 1.25, "mode": 0.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_cam_camera_shake", name: "Camera Shake", description: "Rung máy quay",
            category: .camera, tags: ["camera", "shake", "rung may"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "camera.metering.matrix",
            parameterValues: ["blurStrength": 1.25, "mode": 4.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_cam_shake", name: "Shake", description: "Rung",
            category: .camera, tags: ["camera", "shake", "rung"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "waveform",
            parameterValues: ["blurStrength": 0.85, "mode": 4.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_cam_spin", name: "Spin", description: "Xoay",
            category: .camera, tags: ["camera", "spin", "xoay"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "arrow.clockwise",
            parameterValues: ["blurStrength": 1.0, "mode": 5.0, "subParam": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_cam_rotate", name: "Rotate", description: "Xoay khung hình",
            category: .camera, tags: ["camera", "rotate", "xoay khung"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "rotate.right.fill",
            parameterValues: ["blurStrength": 1.0, "mode": 5.0, "subParam": 0.5], isSystem: true
        ),
        TransitionPreset(
            id: "trans_cam_flip", name: "Flip", description: "Lật khung hình",
            category: .camera, tags: ["camera", "flip", "lat"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "flip.horizontal.fill",
            parameterValues: ["shapeMode": 0.0, "feather": 0.02, "mode": 11.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_cam_swirl", name: "Swirl", description: "Xoáy",
            category: .camera, tags: ["camera", "swirl", "xoay nuoc"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "hurricane",
            parameterValues: ["warpStrength": 56.0, "mode": 1.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_cam_swing", name: "Swing", description: "Đung đưa",
            category: .camera, tags: ["camera", "swing", "dung dua"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "metronome.fill",
            parameterValues: ["blurStrength": 1.0, "mode": 6.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_cam_handheld", name: "Handheld", description: "Rung máy cầm tay",
            category: .camera, tags: ["camera", "handheld", "cam tay"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "hand.raised.fill",
            parameterValues: ["blurStrength": 0.9, "mode": 7.0], isSystem: true
        ),
        TransitionPreset(
            id: "trans_cam_motion", name: "Motion", description: "Chuyển động",
            category: .camera, tags: ["camera", "motion", "chuyen dong"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "figure.run",
            parameterValues: ["blurStrength": 1.15, "mode": 0.0], isSystem: true
        )
    ]
}
