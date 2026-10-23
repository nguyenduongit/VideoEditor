import Foundation

/// Selection target within a video grid (a specific row or column).
public enum GridTarget: Codable, Sendable, Equatable, Hashable {
    case row(Int)
    case column(Int)

    public var title: String {
        switch self {
        case .row(let index):
            return "Row \(index + 1)"
        case .column(let index):
            return "Column \(index + 1)"
        }
    }
}

/// Normalized configuration of a video grid slice layout.
/// Complies with R2.3, R3.1, and R4.3 of AGENTS.md.
public struct GridConfiguration: Codable, Sendable, Equatable {
    public var rows: Int
    public var columns: Int
    public var rowHeights: [Double]
    public var colWidths: [Double]
    public var rowOffsets: [Double]
    public var colOffsets: [Double]
    public var selectedTarget: GridTarget?

    public init(rows: Int = 3, columns: Int = 1) {
        let safeRows = max(1, min(10, rows))
        let safeCols = max(1, min(10, columns))
        self.rows = safeRows
        self.columns = safeCols

        let defaultRowH = 1.0 / Double(safeRows)
        self.rowHeights = Array(repeating: defaultRowH, count: safeRows)
        self.rowOffsets = (0..<safeRows).map { Double($0) * defaultRowH }

        let defaultColW = 1.0 / Double(safeCols)
        self.colWidths = Array(repeating: defaultColW, count: safeCols)
        self.colOffsets = (0..<safeCols).map { Double($0) * defaultColW }

        self.selectedTarget = safeRows > 1 ? .row(1) : (safeCols > 1 ? .column(0) : .row(0))
    }

    public init(
        rows: Int,
        columns: Int,
        rowHeights: [Double],
        colWidths: [Double],
        rowOffsets: [Double],
        colOffsets: [Double],
        selectedTarget: GridTarget? = nil
    ) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
        self.rowHeights = rowHeights
        self.colWidths = colWidths
        self.rowOffsets = rowOffsets
        self.colOffsets = colOffsets
        self.selectedTarget = selectedTarget
    }

    public var isDefault: Bool {
        guard rowHeights.count == rows, colWidths.count == columns,
              rowOffsets.count == rows, colOffsets.count == columns else {
            return false
        }
        let expectedRowH = 1.0 / Double(rows)
        let expectedColW = 1.0 / Double(columns)
        for (idx, h) in rowHeights.enumerated() {
            if abs(h - expectedRowH) > 0.001 || abs(rowOffsets[idx] - Double(idx) * expectedRowH) > 0.001 {
                return false
            }
        }
        for (idx, w) in colWidths.enumerated() {
            if abs(w - expectedColW) > 0.001 || abs(colOffsets[idx] - Double(idx) * expectedColW) > 0.001 {
                return false
            }
        }
        return true
    }

    public func encodeToString() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decode(from json: String) -> GridConfiguration? {
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(GridConfiguration.self, from: data)
    }
}
