import Foundation

/// Real downtown coordinates for previews and tests. The live layer is
/// `FountainDatasetProvider` over `data/fountains.geojson` (BEM-E01).
///
/// One of each kind on purpose: fixtures made only of sampled city fountains
/// hide the cases the UI has to get right — the historic one nobody tests, the
/// Refill tap whose hours we do not know, and the one the city switched off.
public struct SampleFountainProvider: FountainProviding {
    public static let fountains: [Fountain] = [
        Fountain(
            id: "rossmarkt", name: "Trinkbrunnen Rossmarkt", latitude: 50.1128, longitude: 8.6776,
            kind: .stadt, tested: true, operational: true),
        Fountain(
            id: "hauptwache", name: "Trinkbrunnen Hauptwache", latitude: 50.1136, longitude: 8.6797,
            kind: .mainova, tested: true, operational: true),
        Fountain(
            id: "opernplatz", name: "Trinkbrunnen Opernplatz", latitude: 50.1157, longitude: 8.6717,
            kind: .stadt, tested: true, operational: false),
        Fountain(
            id: "roemerberg", name: "Märchenbrunnen Römerberg", latitude: 50.1106, longitude: 8.6820,
            kind: .historisch, tested: false),
        Fountain(
            id: "mainkai", name: "Refill-Station Mainkai", latitude: 50.1080, longitude: 8.6840,
            kind: .refill),
    ]

    public init() {}

    public func fountains() async throws -> [Fountain] {
        Self.fountains
    }
}
