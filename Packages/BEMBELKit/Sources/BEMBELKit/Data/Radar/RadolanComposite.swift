import CoreLocation
import Foundation

/// One RADOLAN composite grid, parsed from DWD's binary format.
///
/// Layout (DWD "Beschreibung des Kompositformats"): an ASCII header terminated
/// by ETX, then one little-endian `UInt16` per grid cell, row 0 in the **south**.
/// The header declares its own geometry — `GP1200x1100` is rows × columns —
/// and its own scale, `PR E-02`, meaning the raw value is hundredths of a
/// millimetre. Nothing here is hardcoded that the header states.
public struct RadolanComposite: Sendable {
    /// Marks a cell outside radar coverage. DWD writes 0x29C4 there; in a real
    /// frame it is roughly half the grid, because the composite is a rectangle
    /// laid over a country-shaped radar network.
    static let noDataMarker: UInt16 = 0x29C4
    /// Flag bits sit in the top nibble; the reading is the low twelve.
    static let valueMask: UInt16 = 0x0FFF
    static let secondaryFlag: UInt16 = 0x2000

    public let product: String
    public let rows: Int
    public let columns: Int
    /// Minutes ahead of `measuredAt` this grid forecasts. 0 for an observation.
    public let forecastMinute: Int
    /// When the radar measured, in UTC — RADOLAN timestamps always are.
    public let measuredAt: Date?
    /// Millimetres of precipitation in the product's interval, or `nil` where
    /// the radar cannot see. Row-major, row 0 southernmost.
    public let values: [Double?]

    public enum Failure: Error, Equatable, Sendable {
        case noHeader
        case malformedHeader(String)
        case truncated(expected: Int, got: Int)
    }

    public init(data: Data) throws {
        guard let etx = data.firstIndex(of: 0x03) else { throw Failure.noHeader }
        let headerData = data[data.startIndex..<etx]
        guard let header = String(data: Data(headerData), encoding: .isoLatin1) else {
            throw Failure.noHeader
        }

        product = String(header.prefix(2))

        guard let geometry = Self.field(header, "GP"), let size = Self.geometry(geometry) else {
            throw Failure.malformedHeader("GP")
        }
        rows = size.rows
        columns = size.columns

        // `PR E-02` → ×0.01. Reading the exponent rather than assuming it means
        // a product published at another scale cannot silently be off by 100.
        let scale: Double
        if let precision = Self.field(header, "PR"), let exponent = Self.exponent(precision) {
            scale = pow(10.0, Double(exponent))
        } else {
            scale = 0.01
        }

        forecastMinute = Self.field(header, "VV").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
        measuredAt = Self.timestamp(header)

        let body = data[data.index(after: etx)...]
        let expected = rows * columns * 2
        guard body.count >= expected else {
            throw Failure.truncated(expected: expected, got: body.count)
        }

        let count = rows * columns
        values = body.withUnsafeBytes { raw -> [Double?] in
            var readings = [Double?](repeating: nil, count: count)
            for index in 0..<count {
                let low = UInt16(raw[index * 2])
                let high = UInt16(raw[index * 2 + 1])
                let word = low | (high << 8)
                guard word != Self.noDataMarker, word & Self.secondaryFlag == 0 else { continue }
                readings[index] = Double(word & Self.valueMask) * scale
            }
            return readings
        }
    }

    public func value(row: Int, column: Int) -> Double? {
        guard (0..<rows).contains(row), (0..<columns).contains(column) else { return nil }
        return values[row * columns + column]
    }

    /// The heaviest reading within `radius` cells — one kilometre per cell.
    ///
    /// A single pixel is a 1 km² claim about a shower's edge; "will I get wet
    /// walking there" is a question about the neighbourhood, and taking the
    /// maximum errs toward warning rather than toward a dry promise.
    public func peak(row: Int, column: Int, radius: Int = 1) -> Double? {
        var peak: Double?
        for dr in -radius...radius {
            for dc in -radius...radius {
                guard let reading = value(row: row + dr, column: column + dc) else { continue }
                peak = max(peak ?? 0, reading)
            }
        }
        return peak
    }

    // MARK: - Header fields

    /// Header fields are `KEY` followed by a fixed-width value, run together
    /// with no separators — so a field ends where the next known key begins.
    private static let keys = ["BY", "VS", "SW", "PR", "INT", "GP", "VV", "MF", "MS", "ST", "CS"]

    static func field(_ header: String, _ key: String) -> String? {
        guard let range = header.range(of: key) else { return nil }
        let rest = header[range.upperBound...]
        var end = rest.endIndex
        for other in keys where other != key {
            if let next = rest.range(of: other), next.lowerBound < end {
                end = next.lowerBound
            }
        }
        return String(rest[rest.startIndex..<end])
    }

    private static func geometry(_ raw: String) -> (rows: Int, columns: Int)? {
        let parts = raw.split(separator: "x").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let rows = Int(parts[0]), let columns = Int(parts[1]) else { return nil }
        return (rows, columns)
    }

    private static func exponent(_ raw: String) -> Int? {
        guard let e = raw.firstIndex(where: { $0 == "E" || $0 == "e" }) else { return nil }
        return Int(raw[raw.index(after: e)...].trimmingCharacters(in: .whitespaces))
    }

    /// `RVddhhmmwwwwwMMyy` — day, hour, minute, then WMO station and month/year.
    /// The year is two digits, which is DWD's problem and now ours: 2000-based
    /// is right until 2100 and wrong in a way nobody will be around to see.
    private static func timestamp(_ header: String) -> Date? {
        let digits = Array(header.dropFirst(2))
        guard digits.count >= 15 else { return nil }
        func number(_ range: Range<Int>) -> Int? { Int(String(digits[range])) }
        guard
            let day = number(0..<2), let hour = number(2..<4), let minute = number(4..<6),
            let month = number(11..<13), let year = number(13..<15)
        else { return nil }
        var components = DateComponents()
        components.year = 2000 + year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar.date(from: components)
    }
}
