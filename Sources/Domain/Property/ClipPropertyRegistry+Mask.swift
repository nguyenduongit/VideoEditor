import Foundation

extension ClipPropertyRegistry {
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
