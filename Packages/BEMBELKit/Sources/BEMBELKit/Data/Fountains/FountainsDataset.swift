import Foundation

/// `data/fountains.geojson` exactly as it is on the wire, and its mapping into
/// the domain. Contract: `data/schema/geojson-dataset.schema.json`, built by
/// `scripts/generate_fountains.py` (BEM-E01).
struct FountainCollection: Decodable, Sendable {
    struct Feature: Decodable, Sendable {
        struct Geometry: Decodable, Sendable {
            let type: String
            let coordinates: [Double]
        }

        struct Properties: Decodable, Sendable {
            let name: String
            let ags: String
            let ring: String
            let sources: [String]
            let art: FountainKind?
            let geprueft: Bool?
            let inBetrieb: Bool?
        }

        let id: String
        let geometry: Geometry
        let properties: Properties
    }

    let version: Int
    let features: [Feature]
}

enum FountainsDataset: CuratedDataset {
    typealias Payload = FountainCollection
    static let id = "fountains"
    static let fileExtension = "geojson"
}

extension FountainCollection {
    /// Wire → domain, total by construction: a feature this build cannot make
    /// sense of is dropped, never thrown. One malformed row must not cost the
    /// user the whole layer — same rule as the bembel-data decoder.
    func fountains() -> [Fountain] {
        features.compactMap { feature in
            guard
                feature.geometry.type == "Point",
                feature.geometry.coordinates.count == 2,
                let ring = Ring(rawValue: feature.properties.ring),
                !feature.id.isEmpty
            else { return nil }
            let longitude = feature.geometry.coordinates[0]
            let latitude = feature.geometry.coordinates[1]
            return Fountain(
                id: feature.id,
                name: feature.properties.name,
                latitude: latitude,
                longitude: longitude,
                // An `art` the schema allows but this build has not heard of
                // decodes to `sonstige`; an absent one means the same thing.
                kind: feature.properties.art ?? .sonstige,
                tested: feature.properties.geprueft,
                operational: feature.properties.inBetrieb,
                ags: feature.properties.ags,
                ring: ring,
                sources: feature.properties.sources.compactMap(URL.init(string:))
            )
        }
    }
}

/// Live fountains: the bundled layer, refreshed by conditional GET when the
/// cached copy ages out. Like the register provider, a failed refresh is never
/// an error the UI sees — the read path always answers from the last good copy.
public actor FountainDatasetProvider: FountainProviding {
    private static let staleness = Staleness(maxAge: 24 * 60 * 60)
    private static let lastRefreshKey = "fountains.lastRefreshedAt"

    private let store: DatasetStore
    private let defaults: UserDefaults
    private var cached: [Fountain]?

    public init(store: DatasetStore, defaults: UserDefaults = AppGroup.defaults) {
        self.store = store
        self.defaults = defaults
    }

    public func fountains() async throws -> [Fountain] {
        if let cached { return cached }
        if shouldRefresh {
            // Outcome ignored on purpose: the read below falls back to the last
            // good data anyway, and any completed attempt resets the clock
            // rather than hammering the host once per view appearance. A day is
            // the right window — this layer changes a few times a season.
            await store.refresh(FountainsDataset.self)
            defaults.set(Date().timeIntervalSince1970, forKey: Self.lastRefreshKey)
        }
        let fountains = try await store.payload(for: FountainsDataset.self).fountains()
        cached = fountains
        return fountains
    }

    public func invalidate() {
        cached = nil
        defaults.removeObject(forKey: Self.lastRefreshKey)
    }

    private var shouldRefresh: Bool {
        let stamp = defaults.double(forKey: Self.lastRefreshKey)
        guard stamp > 0 else { return true }
        return Self.staleness.isStale(fetchedAt: Date(timeIntervalSince1970: stamp))
    }
}
