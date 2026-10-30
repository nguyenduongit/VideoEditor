import Foundation

extension ClipPropertyRegistry {
    func effectDescriptors(tab: String = "Effect") -> [PropertyDescriptor] {
        [
            PropertyDescriptor(
                id: "effectConfig",
                title: "Configuration",
                tab: tab,
                group: "Effect",
                control: .textField,
                defaultValue: .string(EffectConfiguration().encodeToJSON() ?? "")
            ),
            PropertyDescriptor(
                id: "effectType",
                title: "Effect Type",
                tab: tab,
                group: "Effect",
                control: .textField,
                defaultValue: .string(EffectType.fadeIn.rawValue)
            ),
            PropertyDescriptor(
                id: "intensity",
                title: "Intensity",
                tab: tab,
                group: "Effect",
                control: .slider(min: 0.0, max: 1.0, step: 0.01, unit: "%"),
                defaultValue: .number(1.0)
            ),
            PropertyDescriptor(
                id: "speed",
                title: "Speed",
                tab: tab,
                group: "Effect",
                control: .slider(min: 0.1, max: 3.0, step: 0.05, unit: "x"),
                defaultValue: .number(1.0)
            )
        ]
    }
}
