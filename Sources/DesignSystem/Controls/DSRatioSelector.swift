import SwiftUI

/// A dropdown menu control for selecting options (such as aspect ratio).
/// Conforms to R2.4 & R8.1 of AGENTS.md: receives only primitives and closures, uses tokens.
public struct DSRatioSelector: View {
    private let selectedTitle: String
    private let options: [String]
    private let onSelect: (String) -> Void
    @State private var isHovered = false

    public init(
        selectedTitle: String,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) {
        self.selectedTitle = selectedTitle
        self.options = options
        self.onSelect = onSelect
    }

    public var body: some View {
        DSDropdown(
            selectedTitle: selectedTitle,
            leadingIcon: "aspectratio",
            options: options.map { DSDropdownOption(id: $0, title: $0) },
            onSelect: onSelect
        )
    }
}
