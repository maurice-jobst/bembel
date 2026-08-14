import CoreLocation
import Foundation

/// What the "nächster Kandidat" widget renders: the unverified entries nearest
/// a reference point, precomputed by the app.
///
/// The widget extension cannot read the app's Application Support directory
/// and has no location of its own, so the app publishes this digest into the
/// App Group whenever it holds both a snapshot and a map centre. A digest is a
/// photograph, not a live feed: it carries the point it was measured from and
/// the moment it was taken, and the widget labels it as such rather than
/// implying a distance it cannot recompute.
public struct CandidateDigest: Codable, Hashable, Sendable {
    public struct Item: Codable, Hashable, Sendable, Identifiable {
        public let id: String
        public let register: PlaceRegister
        public let name: String
        /// Stadtteil where the bundle knows one, else the city.
        public let area: String
        public let latitude: Double
        public let longitude: Double
        /// Metres from the digest's reference point, measured at build time.
        public let distance: CLLocationDistance

        public init(
            id: String,
            register: PlaceRegister,
            name: String,
            area: String,
            latitude: Double,
            longitude: Double,
            distance: CLLocationDistance
        ) {
            self.id = id
            self.register = register
            self.name = name
            self.area = area
            self.latitude = latitude
            self.longitude = longitude
            self.distance = distance
        }

        public var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        /// Deep link into the Orte tab, focused on this entry.
        public var url: URL? {
            DeepLink.url(register: register, entryID: id)
        }

        public var distanceLabel: String {
            Measurement(value: distance, unit: UnitLength.meters)
                .formatted(
                    .measurement(
                        width: .abbreviated,
                        usage: .road,
                        numberFormatStyle: .number.precision(.fractionLength(0...1))
                    )
                )
        }
    }

    public let items: [Item]
    public let referenceLatitude: Double
    public let referenceLongitude: Double
    public let updatedAt: Date

    public init(
        items: [Item],
        referenceLatitude: Double,
        referenceLongitude: Double,
        updatedAt: Date
    ) {
        self.items = items
        self.referenceLatitude = referenceLatitude
        self.referenceLongitude = referenceLongitude
        self.updatedAt = updatedAt
    }

    /// The nearest unverified entries — the coverage game's targets, which is
    /// exactly the inverse of `VisitMonitor.candidates` (that one watches
    /// *verified* places, because a stamp for a place that may not exist would
    /// be a lie).
    public static func make(
        from snapshot: RegisterSnapshot,
        near location: CLLocationCoordinate2D,
        limit: Int = 5,
        now: Date = .now
    ) -> CandidateDigest {
        let origin = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let measured: [(entry: RegisterEntry, distance: CLLocationDistance)] =
            snapshot.entries
            .filter(\.isCandidate)
            .map { entry in
                let place = CLLocation(latitude: entry.latitude, longitude: entry.longitude)
                return (entry, place.distance(from: origin))
            }
        // Ties broken by id so the digest is a pure function of its inputs — a
        // widget that reshuffles identical data on every write is noise.
        let nearest = measured.sorted { lhs, rhs in
            lhs.distance == rhs.distance ? lhs.entry.id < rhs.entry.id : lhs.distance < rhs.distance
        }
        let items = nearest.prefix(max(0, limit)).map { measurement in
            Item(
                id: measurement.entry.id,
                register: measurement.entry.register,
                name: measurement.entry.name,
                area: measurement.entry.area,
                latitude: measurement.entry.latitude,
                longitude: measurement.entry.longitude,
                distance: measurement.distance
            )
        }
        return CandidateDigest(
            items: items,
            referenceLatitude: location.latitude,
            referenceLongitude: location.longitude,
            updatedAt: now
        )
    }
}

/// The App Group handoff for `CandidateDigest`. Defaults rather than a file in
/// the container: the payload is a few hundred bytes, and `AppGroup.defaults`
/// already carries the "no container available" fallback that every unsigned
/// simulator build needs.
public enum CandidateDigestStore {
    public static let key = "widget.candidateDigest"

    /// Seconds-since-1970 dates: both sides ship in the same build, and a
    /// numeric stamp cannot drift on locale or formatter options the way an
    /// ISO string can.
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    /// Returns whether anything changed — the caller uses it to decide whether
    /// a widget reload is worth waking WidgetKit for.
    @discardableResult
    public static func save(
        _ digest: CandidateDigest,
        to defaults: UserDefaults = AppGroup.defaults
    ) -> Bool {
        guard let data = try? encoder.encode(digest) else { return false }
        // Compare on items only: a new reference point or timestamp with the
        // same candidates in the same order renders identically.
        if let existing = load(from: defaults), existing.items == digest.items {
            defaults.set(data, forKey: key)
            return false
        }
        defaults.set(data, forKey: key)
        return true
    }

    public static func load(from defaults: UserDefaults = AppGroup.defaults) -> CandidateDigest? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(CandidateDigest.self, from: data)
    }
}
