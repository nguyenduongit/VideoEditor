import Foundation

extension ClipPropertyRegistry {
    func registerBuiltInDescriptors() {
        register(descriptors: videoDescriptors, for: .video, tabs: ["Video", "Mask", "Adjustment", "AI"])
        register(descriptors: imageDescriptors, for: .image, tabs: ["Image", "Mask", "Adjustment"])
        register(descriptors: audioDescriptors, for: .audio)
        register(descriptors: textDescriptors, for: .text, tabs: ["Text", "Appearance", "Background", "Animation"])
        register(descriptors: effectDescriptors(), for: .effect, tabs: ["Effect"])
        register(descriptors: adjustmentDescriptors, for: .adjustment, tabs: ["Basic", "HSL", "Wheels", "Curves", "Effects"])
        register(descriptors: stickerDescriptors, for: .sticker, tabs: ["Sticker", "Animation"])
    }

    var stickerDescriptors: [PropertyDescriptor] {
        transformDescriptors(tab: "Sticker", subtab: "Sticker", includeUniform: true)
            + blendDescriptors(tab: "Sticker", subtab: "Sticker") + [
            PropertyDescriptor(id: "speed", title: "Tốc độ", tab: "Sticker", group: "Sticker",
                               control: .slider(min: 0.25, max: 4.0, step: 0.05, unit: "x"), defaultValue: .number(1.0))
        ]
    }

    var videoDescriptors: [PropertyDescriptor] {
        transformDescriptors(tab: "Video", subtab: "Basic", includeUniform: true)
            + blendDescriptors(tab: "Video", subtab: "Basic")
            + speedGroupDescriptors(tab: "Video", subtab: "Speed")
            + audioGroupDescriptors(tab: "Video", subtab: "Audio")
            + adjustmentDescriptors(tab: "Adjustment")
            + maskGroupDescriptors(tab: "Mask")
            + autoPanGroupDescriptors(tab: "AI")
    }

    var imageDescriptors: [PropertyDescriptor] {
        transformDescriptors(tab: "Image", subtab: "Basic", includeUniform: true)
            + blendDescriptors(tab: "Image", subtab: "Basic")
            + adjustmentDescriptors(tab: "Adjustment")
            + maskGroupDescriptors(tab: "Mask")
    }

    var audioDescriptors: [PropertyDescriptor] {
        audioGroupDescriptors(tab: "Audio", subtab: "Audio") + [
            PropertyDescriptor(
                id: "pan",
                title: "Balance",
                tab: "Audio",
                group: "Audio",
                control: .slider(min: -1.0, max: 1.0, step: 0.01, unit: "%"),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "isBeatCounter",
                title: "Beat Counter",
                tab: "Audio",
                group: "Audio",
                control: .toggle,
                defaultValue: .bool(false)
            )
        ] + speedGroupDescriptors(tab: "Audio", subtab: "Speed")
    }

    var textDescriptors: [PropertyDescriptor] {
        [
            PropertyDescriptor(
                id: "textConfig",
                title: "Configuration",
                tab: "Text",
                group: "Text",
                control: .textField,
                defaultValue: .string(TextConfiguration().encodeToJSON() ?? "")
            ),
            PropertyDescriptor(
                id: "textContent",
                title: "Text",
                tab: "Text",
                group: "Text",
                control: .textField,
                defaultValue: .string("Text")
            ),
            PropertyDescriptor(
                id: "fontSize",
                title: "Font Size",
                tab: "Text",
                group: "Text",
                control: .slider(min: 12.0, max: 160.0, step: 1.0, unit: "pt"),
                defaultValue: .number(48.0)
            )
        ] + transformDescriptors(tab: "Text", subtab: "Text", includeUniform: false)
    }

    func blendDescriptors(tab: String, subtab: String = "Basic") -> [PropertyDescriptor] {
        let blendOptions = [
            PickerOption(id: "normal", title: "Normal"),
            PickerOption(id: "multiply", title: "Multiply"),
            PickerOption(id: "screen", title: "Screen"),
            PickerOption(id: "overlay", title: "Overlay"),
            PickerOption(id: "add", title: "Add (Glow)")
        ]
        return [
            PropertyDescriptor(
                id: "blendMode",
                title: "Mode",
                tab: tab,
                subtab: subtab,
                group: "Blend",
                control: .dropdown(options: blendOptions),
                defaultValue: .string("normal")
            ),
            PropertyDescriptor(
                id: "opacity",
                title: "Opacity",
                tab: tab,
                subtab: subtab,
                group: "Blend",
                control: .slider(min: 0.0, max: 1.0, step: 0.01, unit: "%"),
                defaultValue: .number(1.0)
            )
        ]
    }

    private func audioGroupDescriptors(tab: String = "Audio", subtab: String = "Audio") -> [PropertyDescriptor] {
        [
            PropertyDescriptor(
                id: "volume",
                title: "Volume",
                tab: tab,
                subtab: subtab,
                group: "Audio",
                control: .slider(min: 0.0, max: 2.0, step: 0.01, unit: "%"),
                defaultValue: .number(1.0)
            ),
            PropertyDescriptor(
                id: "fadeIn",
                title: "Fade in",
                tab: tab,
                subtab: subtab,
                group: "Audio",
                control: .slider(min: 0.0, max: 10.0, step: 0.1, unit: "s"),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "fadeOut",
                title: "Fade out",
                tab: tab,
                subtab: subtab,
                group: "Audio",
                control: .slider(min: 0.0, max: 10.0, step: 0.1, unit: "s"),
                defaultValue: .number(0.0)
            )
        ]
    }

    private func speedGroupDescriptors(tab: String = "Speed", subtab: String = "Speed") -> [PropertyDescriptor] {
        [
            PropertyDescriptor(
                id: "speed",
                title: "Speed",
                tab: tab,
                subtab: subtab,
                group: "Speed",
                control: .slider(min: 0.1, max: 10.0, step: 0.05, unit: "x"),
                defaultValue: .number(1.0)
            ),
            PropertyDescriptor(
                id: "duration",
                title: "Duration",
                tab: tab,
                subtab: subtab,
                group: "Speed",
                control: .numberField(min: 0.1, max: 36000.0, step: 0.1, unit: "s"),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "pitchPreservation",
                title: "Keep pitch",
                tab: tab,
                subtab: subtab,
                group: "Speed",
                control: .toggle,
                defaultValue: .bool(true)
            )
        ]
    }

    private func transformDescriptors(tab: String, subtab: String = "Basic", includeUniform: Bool) -> [PropertyDescriptor] {
        var list: [PropertyDescriptor] = [
            PropertyDescriptor(
                id: "position", title: "Position", tab: tab, subtab: subtab, group: "Transform",
                control: .position2D(xID: "positionX", yID: "positionY", step: 1.0),
                defaultValue: .number(0.0)
            )
        ]
        if includeUniform {
            list.append(contentsOf: [
                PropertyDescriptor(
                    id: "scale", title: "Scale", tab: tab, subtab: subtab, group: "Transform",
                    control: .slider(min: 0.01, max: 5.0, step: 0.01, unit: "%"),
                    defaultValue: .number(1.0),
                    condition: PropertyCondition(key: "uniformScale", matchesOneOf: [.bool(true)])
                ),
                PropertyDescriptor(
                    id: "scaleWidth", title: "Scale Width", tab: tab, subtab: subtab, group: "Transform",
                    control: .slider(min: 0.01, max: 5.0, step: 0.01, unit: "%"),
                    defaultValue: .number(1.0),
                    condition: PropertyCondition(key: "uniformScale", matchesOneOf: [.bool(false)])
                ),
                PropertyDescriptor(
                    id: "scaleHeight", title: "Scale Height", tab: tab, subtab: subtab, group: "Transform",
                    control: .slider(min: 0.01, max: 5.0, step: 0.01, unit: "%"),
                    defaultValue: .number(1.0),
                    condition: PropertyCondition(key: "uniformScale", matchesOneOf: [.bool(false)])
                ),
                PropertyDescriptor(
                    id: "uniformScale", title: "Uniform scale", tab: tab, subtab: subtab, group: "Transform",
                    control: .toggle, defaultValue: .bool(true)
                )
            ])
        } else {
            list.append(
                PropertyDescriptor(
                    id: "scale", title: "Scale", tab: tab, subtab: subtab, group: "Transform",
                    control: .slider(min: 0.01, max: 5.0, step: 0.01, unit: "%"),
                    defaultValue: .number(1.0)
                )
            )
        }
        list.append(contentsOf: [
            PropertyDescriptor(
                id: "rotation", title: "Rotate", tab: tab, subtab: subtab, group: "Transform",
                control: .rotation(min: -360.0, max: 360.0, step: 0.1),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "skewX", title: "Skew X", tab: tab, subtab: subtab, group: "Transform",
                control: .slider(min: -60.0, max: 60.0, step: 0.1, unit: "°"),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "skewY", title: "Skew Y", tab: tab, subtab: subtab, group: "Transform",
                control: .slider(min: -60.0, max: 60.0, step: 0.1, unit: "°"),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "perspectiveX", title: "Perspective X", tab: tab, subtab: subtab, group: "Transform",
                control: .slider(min: -1.0, max: 1.0, step: 0.01, unit: "%"),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "perspectiveY", title: "Perspective Y", tab: tab, subtab: subtab, group: "Transform",
                control: .slider(min: -1.0, max: 1.0, step: 0.01, unit: "%"),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "flip", title: "Flip", tab: tab, subtab: subtab, group: "Transform",
                control: .flip(horizontalID: "flipHorizontal", verticalID: "flipVertical"),
                defaultValue: .bool(false)
            )
        ])
        return list
    }
}
