import Foundation

extension ClipPropertyRegistry {
    func autoPanGroupDescriptors(tab: String = "AI") -> [PropertyDescriptor] {
        [
            PropertyDescriptor(
                id: "autoPanEnabled",
                title: "Auto Pan",
                tab: tab,
                group: "Auto Pan",
                control: .toggle,
                defaultValue: .bool(false)
            ),
            PropertyDescriptor(
                id: "autoPanSmoothness",
                title: "Smoothness",
                tab: tab,
                group: "Auto Pan",
                control: .slider(min: 0.0, max: 1.0, step: 0.05, unit: "%"),
                defaultValue: .number(0.5)
            )
        ]
    }
}
