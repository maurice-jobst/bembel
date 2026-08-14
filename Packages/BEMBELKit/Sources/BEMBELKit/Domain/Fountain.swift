import CoreLocation
import Foundation

/// The `art` values `data/fountains.geojson` publishes. Open at the edges the
/// way `Merkmal` is: a bundle from a newer generator must not cost the user the
/// whole layer, so an unknown value decodes to `sonstige` rather than throwing.
public enum FountainKind: String, Codable, CaseIterable, Hashable, Sendable {
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

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FountainKind(rawValue: raw) ?? .sonstige
    }

    /// Refill stations answer to a shop, not to the season.
    public var isSeasonal: Bool { self != .refill }

    /// Only the historic fountains wait for Easter and keep daily hours.
    public var waitsForEaster: Bool { self == .historisch }
}

public struct Fountain: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    /// Preformatted distance from the user ("220 m").
    public let distanceLabel: String
    public let walkMinutes: Int
    /// The highlighted nearest fountain gets the big cobalt pin.
    public let featured: Bool
    public let kind: FountainKind
    /// Whether anyone tests this water. `nil` means the source does not say —
    /// which is not the same as "no", and must not render as either.
    ///
    /// Frankfurt's own metadata is why this field exists: the historic
    /// Erfrischungsbrunnen carry drinking water but are deliberately not called
    /// Trinkbrunnen, "da die Trinkwasserqualität der Brunnen nicht kontrolliert
    /// wird". Rendering them like sampled fountains would be a promise the data
    /// does not make (BEM-E03 owns showing it).
    public let tested: Bool?

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        distanceLabel: String,
        walkMinutes: Int,
        featured: Bool = false,
        kind: FountainKind = .stadt,
        tested: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.distanceLabel = distanceLabel
        self.walkMinutes = walkMinutes
        self.featured = featured
        self.kind = kind
        self.tested = tested
    }

    public func state(at date: Date = .now, calendar: Calendar = .current) -> FountainState {
        FountainSeason.state(of: kind, at: date, calendar: calendar)
    }
}
