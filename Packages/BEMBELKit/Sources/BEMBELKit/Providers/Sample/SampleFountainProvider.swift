import Foundation

/// Real downtown coordinates, fabricated distances. The curated dataset
/// replaces this (BEM-E01).
public struct SampleFountainProvider: FountainProviding {
    public static let fountains: [Fountain] = [
        Fountain(
            id: "rossmarkt", name: "Trinkbrunnen Rossmarkt", latitude: 50.1128, longitude: 8.6776,
            distanceLabel: "220 m", walkMinutes: 3, featured: true),
        Fountain(
            id: "hauptwache", name: "Trinkbrunnen Hauptwache", latitude: 50.1136, longitude: 8.6797,
            distanceLabel: "350 m", walkMinutes: 5),
        Fountain(
            id: "opernplatz", name: "Trinkbrunnen Opernplatz", latitude: 50.1157, longitude: 8.6717,
            distanceLabel: "600 m", walkMinutes: 8),
        Fountain(
            id: "roemerberg", name: "Trinkbrunnen Römerberg", latitude: 50.1106, longitude: 8.6820,
            distanceLabel: "700 m", walkMinutes: 9),
        Fountain(
            id: "mainkai", name: "Trinkbrunnen Mainkai", latitude: 50.1080, longitude: 8.6840, distanceLabel: "850 m",
            walkMinutes: 11),
    ]

    public init() {}

    public func fountains() async throws -> [Fountain] {
        Self.fountains
    }
}
