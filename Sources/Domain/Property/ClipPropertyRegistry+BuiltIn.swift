import Foundation

extension ClipPropertyRegistry {
    func registerBuiltInDescriptors() {
        register(descriptors: videoDescriptors, for: .video, tabs: ["Video", "Mask", "Adjustment", "AI"])
        register(descriptors: imageDescriptors, for: .image)
        register(descriptors: audioDescriptors, for: .audio)
        register(descriptors: textDescriptors, for: .text, tabs: ["Text", "Style", "Animation"])
        register(descriptors: effectDescriptors(), for: .effect, tabs: ["Effect"])
        register(descriptors: adjustmentDescriptors, for: .adjustment, tabs: ["Basic", "HSL", "Wheels", "Curves", "Effects"])
    }

    var videoDescriptors: [PropertyDescriptor] {
        transformDescriptors(tab: "Video", includeUniform: true)
            + speedGroupDescriptors(tab: "Video")
            + audioGroupDescriptors(tab: "Video")
            + adjustmentDescriptors(tab: "Adjustment")
            + maskGroupDescriptors(tab: "Mask")
            + autoPanGroupDescriptors(tab: "AI")
    }

    var imageDescriptors: [PropertyDescriptor] {
        transformDescriptors(tab: "Image", includeUniform: true) + [
            PropertyDescriptor(
                id: "speed",
                title: "Speed",
                tab: "Speed",
                group: "Speed",
                control: .slider(min: 0.1, max: 10.0, step: 0.05, unit: "x"),
                defaultValue: .number(1.0)
            )
        ]
    }

    var audioDescriptors: [PropertyDescriptor] {
        audioGroupDescriptors(tab: "Audio") + [
            PropertyDescriptor(
                id: "pan",
                title: "Balance",
                tab: "Audio",
                group: "Audio",
                control: .slider(min: -1.0, max: 1.0, step: 0.01, unit: "%"),
                defaultValue: .number(0.0)
            )
        ] + speedGroupDescriptors()
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
                defaultValue: .string("Văn bản")
            ),
            PropertyDescriptor(
                id: "fontSize",
                title: "Font Size",
                tab: "Text",
                group: "Text",
                control: .slider(min: 12.0, max: 160.0, step: 1.0, unit: "pt"),
                defaultValue: .number(48.0)
            )
        ] + transformDescriptors(tab: "Style", includeUniform: false)
    }

    private func audioGroupDescriptors(tab: String = "Audio") -> [PropertyDescriptor] {
        [
            PropertyDescriptor(
                id: "volume",
                title: "Volume",
                tab: tab,
                group: "Audio",
                control: .slider(min: 0.0, max: 2.0, step: 0.01, unit: "%"),
                defaultValue: .number(1.0)
            ),
            PropertyDescriptor(
                id: "fadeIn",
                title: "Fade in",
                tab: tab,
                group: "Audio",
                control: .slider(min: 0.0, max: 10.0, step: 0.1, unit: "s"),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "fadeOut",
                title: "Fade out",
                tab: tab,
                group: "Audio",
                control: .slider(min: 0.0, max: 10.0, step: 0.1, unit: "s"),
                defaultValue: .number(0.0)
            )
        ]
    }

    private func speedGroupDescriptors(tab: String = "Speed") -> [PropertyDescriptor] {
        [
            PropertyDescriptor(
                id: "speed",
                title: "Speed",
                tab: tab,
                group: "Speed",
                control: .slider(min: 0.1, max: 10.0, step: 0.05, unit: "x"),
                defaultValue: .number(1.0)
            ),
            PropertyDescriptor(
                id: "duration",
                title: "Duration",
                tab: tab,
                group: "Speed",
                control: .numberField(min: 0.1, max: 36000.0, step: 0.1, unit: "s"),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "pitchPreservation",
                title: "Keep pitch",
                tab: tab,
                group: "Speed",
                control: .toggle,
                defaultValue: .bool(true)
            )
        ]
    }

    private func transformDescriptors(tab: String, includeUniform: Bool) -> [PropertyDescriptor] {
        var list: [PropertyDescriptor] = [
            PropertyDescriptor(
                id: "scale",
                title: "Scale",
                tab: tab,
                group: "Transform",
                control: .slider(min: 0.0, max: 5.0, step: 0.01, unit: "%"),
                defaultValue: .number(1.0)
            )
        ]
        if includeUniform {
            list.append(
                PropertyDescriptor(
                    id: "uniformScale",
                    title: "Uniform scale",
                    tab: tab,
                    group: "Transform",
                    control: .toggle,
                    defaultValue: .bool(true)
                )
            )
        }
        list.append(contentsOf: [
            PropertyDescriptor(
                id: "position",
                title: "Position",
                tab: tab,
                group: "Transform",
                control: .position2D(xID: "positionX", yID: "positionY", step: 1.0),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "rotation",
                title: "Rotate",
                tab: tab,
                group: "Transform",
                control: .rotation(min: -360.0, max: 360.0, step: 0.1),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "opacity",
                title: "Opacity",
                tab: tab,
                group: "Transform",
                control: .slider(min: 0.0, max: 1.0, step: 0.01, unit: "%"),
                defaultValue: .number(1.0)
            )
        ])
        return list
    }

    func maskGroupDescriptors(tab: String = "Mask") -> [PropertyDescriptor] {
        maskShapeDescriptors(tab: tab) + maskParameterDescriptors(tab: tab)
    }

    private func maskShapeDescriptors(tab: String) -> [PropertyDescriptor] {
        let options = [
            PickerOption(id: "none", title: "None", iconName: "circle.slash"),
            PickerOption(id: "split", title: "Split", iconName: "rectangle.split.2x1"),
            PickerOption(id: "filmstrip", title: "Filmstrip", iconName: "film"),
            PickerOption(id: "circle", title: "Circle", iconName: "circle"),
            PickerOption(id: "rectangle", title: "Rectangle", iconName: "square")
        ]
        let anyMask = PropertyCondition(
            key: "maskType",
            matchesOneOf: [.string("split"), .string("filmstrip"), .string("circle"), .string("rectangle")]
        )
        return [
            PropertyDescriptor(
                id: "maskType",
                title: "Shape",
                tab: tab,
                group: "Mask",
                control: .picker(options: options),
                defaultValue: .string("none")
            ),
            PropertyDescriptor(
                id: "maskInvert",
                title: "Invert",
                tab: tab,
                group: "Mask",
                control: .toggle,
                defaultValue: .bool(false),
                condition: anyMask
            ),
            PropertyDescriptor(
                id: "maskFeather",
                title: "Feather",
                tab: tab,
                group: "Mask",
                control: .slider(min: 0.0, max: 1.0, step: 0.01, unit: "%"),
                defaultValue: .number(0.0),
                condition: anyMask
            )
        ]
    }

    private func maskParameterDescriptors(tab: String) -> [PropertyDescriptor] {
        let filmstripCond = PropertyCondition(key: "maskType", matchesOneOf: [.string("filmstrip")])
        let circleCond = PropertyCondition(key: "maskType", matchesOneOf: [.string("circle")])
        let rectCond = PropertyCondition(key: "maskType", matchesOneOf: [.string("rectangle")])
        let posCond = PropertyCondition(key: "maskType", matchesOneOf: [.string("split"), .string("circle"), .string("rectangle")])
        let rotCond = PropertyCondition(key: "maskType", matchesOneOf: [.string("split"), .string("circle"), .string("rectangle")])

        return [
            PropertyDescriptor(id: "maskPosition", title: "Position", tab: tab, group: "Mask",
                               control: .position2D(xID: "maskPositionX", yID: "maskPositionY", step: 1.0),
                               defaultValue: .number(0.0), condition: posCond),
            PropertyDescriptor(id: "maskOffsetY", title: "Offset Y", tab: tab, group: "Mask",
                               control: .slider(min: -500.0, max: 500.0, step: 1.0, unit: "px"),
                               defaultValue: .number(0.0), condition: filmstripCond),
            PropertyDescriptor(id: "maskRotation", title: "Rotate", tab: tab, group: "Mask",
                               control: .rotation(min: -360.0, max: 360.0, step: 0.1),
                               defaultValue: .number(0.0), condition: rotCond),
            PropertyDescriptor(id: "maskRadiusX", title: "Radius X", tab: tab, group: "Mask",
                               control: .slider(min: 10.0, max: 1000.0, step: 1.0, unit: "px"),
                               defaultValue: .number(200.0), condition: circleCond),
            PropertyDescriptor(id: "maskRadiusY", title: "Radius Y", tab: tab, group: "Mask",
                               control: .slider(min: 10.0, max: 1000.0, step: 1.0, unit: "px"),
                               defaultValue: .number(200.0), condition: circleCond),
            PropertyDescriptor(id: "maskWidth", title: "Width", tab: tab, group: "Mask",
                               control: .slider(min: 10.0, max: 2000.0, step: 1.0, unit: "px"),
                               defaultValue: .number(400.0), condition: rectCond),
            PropertyDescriptor(id: "maskHeight", title: "Height", tab: tab, group: "Mask",
                               control: .slider(min: 10.0, max: 2000.0, step: 1.0, unit: "px"),
                               defaultValue: .number(300.0), condition: rectCond),
            PropertyDescriptor(id: "maskCornerRadius", title: "Roundness", tab: tab, group: "Mask",
                               control: .slider(min: 0.0, max: 200.0, step: 1.0, unit: "px"),
                               defaultValue: .number(0.0), condition: rectCond),
            PropertyDescriptor(id: "maskFilmHeight", title: "Height", tab: tab, group: "Mask",
                               control: .slider(min: 50.0, max: 1080.0, step: 1.0, unit: "px"),
                               defaultValue: .number(500.0), condition: filmstripCond)
        ]
    }
}
