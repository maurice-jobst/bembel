import Foundation

/// Ring membership lookup, loaded from the generated rings.json — membership
/// lives in data, never in Swift code.
public struct RegionTable: Sendable {
    public struct Municipality: Codable, Hashable, Sendable {
        public let ags: AGS
        public let name: String
        public let ring: Ring

        public init(ags: AGS, name: String, ring: Ring) {
            self.ags = ags
            self.name = name
            self.ring = ring
        }
    }

    struct File: Codable {
        let version: Int
        let municipalities: [Municipality]
    }

    public let municipalities: [Municipality]
    private let byAGS: [AGS: Municipality]

    public init(municipalities: [Municipality]) {
        self.municipalities = municipalities
        self.byAGS = Dictionary(
            municipalities.map { ($0.ags, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    public static func bundled() throws -> RegionTable {
        guard let url = Bundle.module.url(forResource: "rings", withExtension: "json") else {
            throw RegionTableError.missingBundledTable
        }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        return RegionTable(municipalities: file.municipalities)
    }

    public func ring(for ags: AGS) -> Ring? {
        byAGS[ags]?.ring
    }

    /// The distinct Kreis prefixes — the first five AGS digits — of every
    /// municipality inside `selection`, sorted.
    ///
    /// For APIs that can only be keyed at Kreis level. NINA is the one that
    /// forced this: its region key is a Regionalschlüssel, which below Kreis
    /// level is laid out differently from the AGS and so cannot be derived
    /// from one. It also keeps the widest ring at 26 requests rather than 475.
    public func kreisKeys(in selection: Ring) -> [String] {
        let keys = municipalities.lazy
            .filter { $0.ring <= selection }
            .map { String($0.ags.rawValue.prefix(5)) }
        return Set(keys).sorted()
    }

    /// Whether a POI in `ags` is visible under the user's ring `selection`.
    /// Unknown municipalities are excluded — a hole in the table must surface
    /// as missing data, not silently widen the region.
    public func isIncluded(_ ags: AGS, in selection: Ring) -> Bool {
        guard let ring = ring(for: ags) else { return false }
        return ring <= selection
    }
}

public enum RegionTableError: Error {
    case missingBundledTable
}
