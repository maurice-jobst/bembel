import Foundation

/// Real downtown coordinates, fabricated distances. The curated dataset
/// (BEM-E01) is what the live provider reads; these fixtures stay for previews.
///
/// One of each kind on purpose: a preview where every pin is a sampled city
/// fountain hides the two cases the UI has to get right — the historic one
/// nobody tests, and the Refill tap whose hours we do not know.
public struct SampleFountainProvider: FountainProviding {
    public static let fountains: [Fountain] = [
        Fountain(
            id: "rossmarkt", name: "Trinkbrunnen Rossmarkt", latitude: 50.1128, longitude: 8.6776,
            distanceLabel: "220 m", walkMinutes: 3, featured: true, kind: .stadt, tested: true),
        Fountain(
            id: "hauptwache", name: "Trinkbrunnen Hauptwache", latitude: 50.1136, longitude: 8.6797,
            distanceLabel: "350 m", walkMinutes: 5, kind: .mainova, tested: true),
        Fountain(
            id: "opernplatz", name: "Trinkbrunnen Opernplatz", latitude: 50.1157, longitude: 8.6717,
            distanceLabel: "600 m", walkMinutes: 8, kind: .stadt, tested: true),
        Fountain(
            id: "roemerberg", name: "Märchenbrunnen Römerberg", latitude: 50.1106, longitude: 8.6820,
            distanceLabel: "700 m", walkMinutes: 9, kind: .historisch, tested: false),
        Fountain(
            id: "mainkai", name: "Trinkbrunnen Mainkai", latitude: 50.1080, longitude: 8.6840, distanceLabel: "850 m",
            walkMinutes: 11, kind: .sonstige),
    ]

    public init() {}

    public func fountains() async throws -> [Fountain] {
        Self.fountains
    }
}
