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

/// Live fountains: the bundled layer, cached and conditionally refreshed by
/// `CachedDatasetProvider`. All this type adds is the freshness window and the
/// payload → domain mapping.
public struct FountainDatasetProvider: FountainProviding {
    /// A day. This layer changes a few times a season — the city adds a
    /// fountain, or the sampling status of one flips — so anything shorter is
    /// a request that reliably answers 304.
    private static let maxAge: TimeInterval = 24 * 60 * 60

    private let base: CachedDatasetProvider<FountainsDataset, [Fountain]>

    public init(store: DatasetStore, defaults: UserDefaults = AppGroup.defaults) {
        base = CachedDatasetProvider(
            FountainsDataset.self,
            store: store,
            maxAge: Self.maxAge,
            clock: RefreshClock(id: FountainsDataset.id, defaults: defaults)
        ) { $0.fountains() }
    }

    public func fountains() async throws -> [Fountain] {
        try await base.value()
    }

    public func invalidate() async {
        await base.invalidate()
    }
}
