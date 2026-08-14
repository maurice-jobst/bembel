import CoreLocation
import Foundation

/// The `art` values `data/fountains.geojson` publishes. Open at the edges the
/// way `Merkmal` is: a bundle from a newer generator must not cost the user the
/// whole layer, so an unknown value decodes to `sonstige` rather than throwing.
public enum FountainKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    /// Sampled city fountain.
    case stadt
    /// Historic Laufbrunnen: drinking water, but the city does not sample it,
    /// and it runs only after Easter, 10:00–22:00.
    case historisch
    /// Sampled, operated by Mainova.
    case mainova
    /// Refill partner — a shop's tap, on shop hours.
    case refill
    /// Public fountain whose operator nobody has recorded.
    case sonstige

    public var id: String { rawValue }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FountainKind(rawValue: raw) ?? .sonstige
    }

    /// Refill stations answer to a shop, not to the season.
    public var isSeasonal: Bool { self != .refill }

    /// Only the historic fountains wait for Easter and keep daily hours.
    public var waitsForEaster: Bool { self == .historisch }
}

/// One drinking-water point.
///
/// Deliberately carries no distance and no "featured" flag: how far away a
/// fountain is depends on where the user stands, not on the fountain, and the
/// curated dataset has no way to know. Ranking is `FountainRanking`'s job.
public struct Fountain: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let kind: FountainKind
    /// Whether anyone tests this water. `nil` means the source does not say —
    /// which is not the same as "no", and must not render as either.
    ///
    /// Frankfurt's own metadata is why this field exists: the historic
    /// Erfrischungsbrunnen carry drinking water but are deliberately not called
    /// Trinkbrunnen, "da die Trinkwasserqualität der Brunnen nicht kontrolliert
    /// wird".
    public let tested: Bool?
    /// `false` only where the source says so; `nil` is "the source is silent",
    /// never "assume it works".
    public let operational: Bool?
    public let ags: String
    public let ring: Ring
    public let sources: [URL]

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        kind: FountainKind = .stadt,
        tested: Bool? = nil,
        operational: Bool? = nil,
        ags: String = "06412000",
        ring: Ring = .frankfurt,
        sources: [URL] = []
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.kind = kind
        self.tested = tested
        self.operational = operational
        self.ags = ags
        self.ring = ring
        self.sources = sources
    }

    public func state(at date: Date = .now, calendar: Calendar = .current) -> FountainState {
        // A fountain the city has switched off is off, whatever the calendar
        // says about the season.
        if operational == false { return .outOfService }
        return FountainSeason.state(of: kind, at: date, calendar: calendar)
    }
}

/// How far, and roughly how long on foot. Computed against the user's position,
/// so it lives beside the fountain rather than inside it.
public struct FountainDistance: Hashable, Sendable {
    /// Average walking pace, 4.8 km/h — the number Apple and OSM routers use
    /// for a flat urban walk.
    public static let metresPerMinute = 80.0

    public let metres: CLLocationDistance

    public init(metres: CLLocationDistance) {
        self.metres = metres
    }

    public var walkMinutes: Int {
        max(1, Int((metres / Self.metresPerMinute).rounded()))
    }

    public var label: String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .road,
                    numberFormatStyle: .number.precision(.fractionLength(0...1))
                )
            )
    }
}

/// A fountain as the list shows it: the facts, plus how far away it is right
/// now. `distance` is `nil` when the user has not granted location — the list
/// still has to be usable, so it falls back to a stable alphabetical order.
public struct RankedFountain: Identifiable, Hashable, Sendable {
    public let fountain: Fountain
    public let distance: FountainDistance?

    public var id: String { fountain.id }

    public init(fountain: Fountain, distance: FountainDistance?) {
        self.fountain = fountain
        self.distance = distance
    }
}

public enum FountainRanking {
    /// Nearest first when we know where the user is; otherwise alphabetical,
    /// which is at least predictable — a list that reshuffles itself around an
    /// unknown origin is worse than one that never claimed to be sorted.
    public static func ranked(
        _ fountains: [Fountain],
        from location: CLLocationCoordinate2D?
    ) -> [RankedFountain] {
        guard let location else {
            return
                fountains
                .sorted { lhs, rhs in
                    lhs.name == rhs.name ? lhs.id < rhs.id : lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
                .map { RankedFountain(fountain: $0, distance: nil) }
        }
        let origin = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let measured = fountains.map { fountain -> RankedFountain in
            let metres = CLLocation(latitude: fountain.latitude, longitude: fountain.longitude)
                .distance(from: origin)
            return RankedFountain(fountain: fountain, distance: FountainDistance(metres: metres))
        }
        // Ties break on id so the order is a pure function of its inputs.
        return measured.sorted { lhs, rhs in
            let a = lhs.distance?.metres ?? .greatestFiniteMagnitude
            let b = rhs.distance?.metres ?? .greatestFiniteMagnitude
            return a == b ? lhs.id < rhs.id : a < b
        }
    }
}
