import Foundation

extension ClipPropertyRegistry {
    func adjustmentDescriptors(tab: String = "Adjustment") -> [PropertyDescriptor] {
        [
            PropertyDescriptor(
                id: "opacity",
                title: "Intensity",
                tab: tab,
                group: "Color",
                control: .slider(min: 0.0, max: 1.0, step: 0.01, unit: "%"),
                defaultValue: .number(1.0)
            ),
            PropertyDescriptor(
                id: "adjustmentConfig",
                title: "Configuration",
                tab: tab,
                group: "Color",
                control: .textField,
                defaultValue: .string(AdjustmentConfiguration().encodeToJSON() ?? "")
            ),
            PropertyDescriptor(
                id: "brightness",
                title: "Brightness",
                tab: tab,
                group: "Color",
                control: .slider(min: -1.0, max: 1.0, step: 0.05),
                defaultValue: .number(0.0)
            ),
            PropertyDescriptor(
                id: "contrast",
                title: "Contrast",
                tab: tab,
                group: "Color",
                control: .slider(min: 0.0, max: 2.0, step: 0.05),
                defaultValue: .number(1.0)
            )
        ]
    }

    var adjustmentDescriptors: [PropertyDescriptor] {
        adjustmentDescriptors(tab: "Basic")
    }
}
