import Foundation

extension TransitionLibraryItem {
    /// 9 Mẫu Zoom, 9 Mẫu Blur và 10 Mẫu Camera & Motion.
    /// Mỗi preset chứa đầy đủ `parameterValues` điều khiển trực tiếp thuật toán Metal Compute Kernel.
    /// Tuân thủ AGENTS.md (Pure Domain, Sendable, File <= 300 dòng).
    public static let catalogMotion: [TransitionLibraryItem] = [
        // MARK: - 3. Zoom (9 presets)
        TransitionLibraryItem(
            id: "trans_zoom_in", name: "Zoom In", description: "Zoom in",
            category: .zoom, tags: ["zoom", "in"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "plus.magnifyingglass",
            parameterValues: ["zoomStrength": 0.02, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_zoom_out", name: "Zoom Out", description: "Zoom out",
            category: .zoom, tags: ["zoom", "out"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "minus.magnifyingglass",
            parameterValues: ["zoomStrength": 0.02, "mode": 2.0]
        ),
        TransitionLibraryItem(
            id: "trans_zoom_in_blur", name: "Zoom In Blur", description: "Zoom in with blur",
            category: .zoom, tags: ["zoom", "in", "blur"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "arrow.up.left.and.arrow.down.right",
            parameterValues: ["zoomStrength": 0.45, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_zoom_out_blur", name: "Zoom Out Blur", description: "Zoom out with blur",
            category: .zoom, tags: ["zoom", "out", "blur"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "arrow.down.right.and.arrow.up.left",
            parameterValues: ["zoomStrength": 0.45, "mode": 3.0]
        ),
        TransitionLibraryItem(
            id: "trans_zoom_camera", name: "Camera Zoom", description: "Optical camera zoom",
            category: .zoom, tags: ["zoom", "camera"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "video.fill",
            parameterValues: ["zoomStrength": 0.25, "mode": 4.0]
        ),
        TransitionLibraryItem(
            id: "trans_zoom_pull_in", name: "Pull In", description: "Dynamic pull in",
            category: .zoom, tags: ["zoom", "pull in"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "arrow.down.forward.and.arrow.up.backward",
            parameterValues: ["zoomStrength": 0.18, "mode": 5.0]
        ),
        TransitionLibraryItem(
            id: "trans_zoom_pull_out", name: "Pull Out", description: "Dynamic pull out",
            category: .zoom, tags: ["zoom", "pull out"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "arrow.up.backward.and.arrow.down.forward",
            parameterValues: ["zoomStrength": 0.18, "mode": 6.0]
        ),
        TransitionLibraryItem(
            id: "trans_zoom_shake", name: "Zoom Shake", description: "Zoom punch with shake",
            category: .zoom, tags: ["zoom", "shake"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "waveform.path",
            parameterValues: ["zoomStrength": 0.28, "mode": 7.0]
        ),
        TransitionLibraryItem(
            id: "trans_zoom_twinkle", name: "Twinkle Zoom", description: "Zoom with sparkling highlights",
            category: .zoom, tags: ["zoom", "twinkle"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "sparkles",
            parameterValues: ["zoomStrength": 0.22, "mode": 8.0]
        ),

        // MARK: - 4. Blur (9 presets)
        TransitionLibraryItem(
            id: "trans_blur_basic", name: "Blur", description: "Soft blur",
            category: .blur, tags: ["blur"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "drop.fill",
            parameterValues: ["blurStrength": 1.0, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_blur_motion", name: "Motion Blur", description: "Directional motion blur",
            category: .blur, tags: ["blur", "motion"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "wind",
            parameterValues: ["blurStrength": 1.35, "mode": 2.0, "subParam": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_blur_radial", name: "Radial Blur", description: "Radial blur burst",
            category: .blur, tags: ["blur", "radial"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "target",
            parameterValues: ["zoomStrength": 0.48, "mode": 10.0]
        ),
        TransitionLibraryItem(
            id: "trans_blur_horizontal", name: "Horizontal Blur", description: "Horizontal streak blur",
            category: .blur, tags: ["blur", "horizontal"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "arrow.left.and.right",
            parameterValues: ["blurStrength": 1.45, "mode": 2.0, "subParam": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_blur_vertical", name: "Vertical Blur", description: "Vertical streak blur",
            category: .blur, tags: ["blur", "vertical"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "arrow.up.and.down",
            parameterValues: ["blurStrength": 1.45, "mode": 3.0]
        ),
        TransitionLibraryItem(
            id: "trans_blur_spin", name: "Spin Blur", description: "Rotational spin blur",
            category: .blur, tags: ["blur", "spin"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "tornado",
            parameterValues: ["zoomStrength": 0.45, "mode": 9.0]
        ),
        TransitionLibraryItem(
            id: "trans_blur_directional", name: "Directional Blur", description: "Angled directional blur",
            category: .blur, tags: ["blur", "directional"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "location.north.line.fill",
            parameterValues: ["blurStrength": 1.4, "mode": 2.0, "subParam": 0.785]
        ),
        TransitionLibraryItem(
            id: "trans_blur_zoom", name: "Zoom Blur", description: "Zoom blur transition",
            category: .blur, tags: ["blur", "zoom"], defaultDuration: 2.0,
            shaderType: .zoomBlur, iconName: "sparkle.magnifyingglass",
            parameterValues: ["zoomStrength": 0.55, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_blur_gaussian", name: "Gaussian Blur", description: "Smooth Gaussian blur",
            category: .blur, tags: ["blur", "gaussian"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "aqi.medium",
            parameterValues: ["blurStrength": 1.65, "mode": 1.0]
        ),

        // MARK: - 5. Camera / Movement (10 presets)
        TransitionLibraryItem(
            id: "trans_cam_whip_pan", name: "Whip Pan", description: "Ultra-fast camera whip pan",
            category: .camera, tags: ["camera", "whip pan"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "arrow.left.to.line.compact",
            parameterValues: ["blurStrength": 1.25, "mode": 0.0]
        ),
        TransitionLibraryItem(
            id: "trans_cam_camera_shake", name: "Camera Shake", description: "Dynamic camera shake",
            category: .camera, tags: ["camera", "shake"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "camera.metering.matrix",
            parameterValues: ["blurStrength": 1.25, "mode": 4.0]
        ),
        TransitionLibraryItem(
            id: "trans_cam_shake", name: "Shake", description: "Quick energy shake",
            category: .camera, tags: ["camera", "shake"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "waveform",
            parameterValues: ["blurStrength": 0.85, "mode": 4.0]
        ),
        TransitionLibraryItem(
            id: "trans_cam_spin", name: "Spin", description: "Fast spin rotation",
            category: .camera, tags: ["camera", "spin"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "arrow.clockwise",
            parameterValues: ["blurStrength": 1.0, "mode": 5.0, "subParam": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_cam_rotate", name: "Rotate", description: "Frame rotation whip",
            category: .camera, tags: ["camera", "rotate"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "rotate.right.fill",
            parameterValues: ["blurStrength": 1.0, "mode": 5.0, "subParam": 0.5]
        ),
        TransitionLibraryItem(
            id: "trans_cam_flip", name: "Flip", description: "Frame flip turn",
            category: .camera, tags: ["camera", "flip"], defaultDuration: 2.0,
            shaderType: .geometricWipe, iconName: "flip.horizontal.fill",
            parameterValues: ["shapeMode": 0.0, "feather": 0.02, "mode": 11.0]
        ),
        TransitionLibraryItem(
            id: "trans_cam_swirl", name: "Swirl", description: "Vortex swirl warp",
            category: .camera, tags: ["camera", "swirl"], defaultDuration: 2.0,
            shaderType: .crossWarp, iconName: "hurricane",
            parameterValues: ["warpStrength": 56.0, "mode": 1.0]
        ),
        TransitionLibraryItem(
            id: "trans_cam_swing", name: "Swing", description: "Pendulum swing motion",
            category: .camera, tags: ["camera", "swing"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "metronome.fill",
            parameterValues: ["blurStrength": 1.0, "mode": 6.0]
        ),
        TransitionLibraryItem(
            id: "trans_cam_handheld", name: "Handheld", description: "Handheld camera shake",
            category: .camera, tags: ["camera", "handheld"], defaultDuration: 2.0,
            shaderType: .whipPanLeft, iconName: "hand.raised.fill",
            parameterValues: ["blurStrength": 0.9, "mode": 7.0]
        ),
        TransitionLibraryItem(
            id: "trans_cam_motion", name: "Motion", description: "Smooth kinetic pan",
            category: .camera, tags: ["camera", "motion"], defaultDuration: 2.0,
            shaderType: .whipPanRight, iconName: "figure.run",
            parameterValues: ["blurStrength": 1.15, "mode": 0.0]
        )
    ]
}
