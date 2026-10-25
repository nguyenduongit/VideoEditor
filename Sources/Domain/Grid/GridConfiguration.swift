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
    public var rowDividers: [Double]
    public var colDividers: [Double]
    public var rowHeights: [Double]
    public var colWidths: [Double]
    public var rowOffsets: [Double]
    public var colOffsets: [Double]
    public var selectedTarget: GridTarget?
    public var isEnabled: Bool
    public var legStretchRatio: Double
    public var isDynamicLines: Bool

    public init(
        rows: Int = 3,
        columns: Int = 1,
        isEnabled: Bool = true,
        legStretchRatio: Double = 1.0,
        isDynamicLines: Bool = false
    ) {
        let safeRows = max(1, min(10, rows))
        let safeCols = max(1, min(10, columns))
        self.rows = safeRows
        self.columns = safeCols
        self.isEnabled = isEnabled
        self.legStretchRatio = max(0.9, min(1.3, legStretchRatio))
        self.isDynamicLines = isDynamicLines

        let defaultRowH = 1.0 / Double(safeRows)
        self.rowDividers = (1..<safeRows).map { Double($0) * defaultRowH }
        self.rowHeights = Array(repeating: defaultRowH, count: safeRows)
        self.rowOffsets = (0..<safeRows).map { Double($0) * defaultRowH }

        let defaultColW = 1.0 / Double(safeCols)
        self.colDividers = (1..<safeCols).map { Double($0) * defaultColW }
        self.colWidths = Array(repeating: defaultColW, count: safeCols)
        self.colOffsets = (0..<safeCols).map { Double($0) * defaultColW }

        self.selectedTarget = safeRows > 1 ? .row(1) : (safeCols > 1 ? .column(0) : .row(0))
    }

    public init(
        rows: Int,
        columns: Int,
        rowDividers: [Double]? = nil,
        colDividers: [Double]? = nil,
        rowHeights: [Double],
        colWidths: [Double],
        rowOffsets: [Double],
        colOffsets: [Double],
        selectedTarget: GridTarget? = nil,
        isEnabled: Bool = true,
        legStretchRatio: Double = 1.0,
        isDynamicLines: Bool = false
    ) {
        let safeRows = max(1, rows)
        let safeCols = max(1, columns)
        self.rows = safeRows
        self.columns = safeCols
        self.isEnabled = isEnabled
        self.legStretchRatio = max(0.9, min(1.3, legStretchRatio))
        self.isDynamicLines = isDynamicLines
        let defaultRowH = 1.0 / Double(safeRows)
        let defaultColW = 1.0 / Double(safeCols)
        self.rowDividers = rowDividers ?? ((1..<safeRows).map { Double($0) * defaultRowH })
        self.colDividers = colDividers ?? ((1..<safeCols).map { Double($0) * defaultColW })
        self.rowHeights = rowHeights
        self.colWidths = colWidths
        self.rowOffsets = rowOffsets
        self.colOffsets = colOffsets
        self.selectedTarget = selectedTarget
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let r = try container.decode(Int.self, forKey: .rows)
        let c = try container.decode(Int.self, forKey: .columns)
        self.rows = max(1, r)
        self.columns = max(1, c)
        self.isEnabled = (try? container.decode(Bool.self, forKey: .isEnabled)) ?? true
        let decodedRatio = (try? container.decode(Double.self, forKey: .legStretchRatio)) ?? 1.0
        self.legStretchRatio = max(0.9, min(1.3, decodedRatio))
        self.isDynamicLines = (try? container.decode(Bool.self, forKey: .isDynamicLines)) ?? false
        let defaultRowH = 1.0 / Double(self.rows)
        let defaultColW = 1.0 / Double(self.columns)
        self.rowDividers = (try? container.decode([Double].self, forKey: .rowDividers))
            ?? ((1..<self.rows).map { Double($0) * defaultRowH })
        self.colDividers = (try? container.decode([Double].self, forKey: .colDividers))
            ?? ((1..<self.columns).map { Double($0) * defaultColW })
        self.rowHeights = try container.decode([Double].self, forKey: .rowHeights)
        self.colWidths = try container.decode([Double].self, forKey: .colWidths)
        self.rowOffsets = try container.decode([Double].self, forKey: .rowOffsets)
        self.colOffsets = try container.decode([Double].self, forKey: .colOffsets)
        self.selectedTarget = try? container.decode(GridTarget.self, forKey: .selectedTarget)
    }

    public func rowBounds(for index: Int) -> (top: Double, bottom: Double) {
        guard index >= 0 && index < rows else { return (0.0, 1.0) }
        let top = (index == 0) ? 0.0 : (index - 1 < rowDividers.count ? rowDividers[index - 1] : 0.0)
        let bottom = (index == rows - 1) ? 1.0 : (index < rowDividers.count ? rowDividers[index] : 1.0)
        return (top, bottom)
    }

    public func colBounds(for index: Int) -> (left: Double, right: Double) {
        guard index >= 0 && index < columns else { return (0.0, 1.0) }
        let left = (index == 0) ? 0.0 : (index - 1 < colDividers.count ? colDividers[index - 1] : 0.0)
        let right = (index == columns - 1) ? 1.0 : (index < colDividers.count ? colDividers[index] : 1.0)
        return (left, right)
    }

    public var isDefault: Bool {
        guard isEnabled else { return true }
        if abs(legStretchRatio - 1.0) > 0.001 { return false }
        guard rowHeights.count == rows, colWidths.count == columns,
              rowOffsets.count == rows, colOffsets.count == columns,
              rowDividers.count == max(0, rows - 1),
              colDividers.count == max(0, columns - 1) else {
            return false
        }
        let expectedRowH = 1.0 / Double(rows)
        let expectedColW = 1.0 / Double(columns)
        for (idx, d) in rowDividers.enumerated() {
            if abs(d - Double(idx + 1) * expectedRowH) > 0.001 { return false }
        }
        for (idx, d) in colDividers.enumerated() {
            if abs(d - Double(idx + 1) * expectedColW) > 0.001 { return false }
        }
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
