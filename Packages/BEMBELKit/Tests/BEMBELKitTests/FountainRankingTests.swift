import CoreLocation
import Foundation
import Testing

@testable import BEMBELKit

@Suite("Fountain ranking and dataset")
struct FountainRankingTests {
    private let hauptwache = CLLocationCoordinate2D(latitude: 50.1136, longitude: 8.6797)

    private func fountain(
        _ id: String,
        _ name: String,
        lat: Double,
        lon: Double,
        kind: FountainKind = .stadt,
        ring: Ring = .frankfurt
    ) -> Fountain {
        Fountain(id: id, name: name, latitude: lat, longitude: lon, kind: kind, ring: ring)
    }

    @Test("With a fix, nearest wins")
    func nearestFirst() {
        let ranked = FountainRanking.ranked(
            [
                fountain("weit", "Weit", lat: 50.2000, lon: 8.9000),
                fountain("nah", "Nah", lat: 50.1137, lon: 8.6798),
                fountain("mittel", "Mittel", lat: 50.1200, lon: 8.6900),
            ],
            from: hauptwache
        )
        #expect(ranked.map(\.id) == ["nah", "mittel", "weit"])
        #expect(ranked.allSatisfy { $0.distance != nil })
    }

    @Test("Without a fix the list is alphabetical and carries no distance")
    func alphabeticalFallback() {
        let ranked = FountainRanking.ranked(
            [
                fountain("c", "Zeil", lat: 50.11, lon: 8.68),
                fountain("a", "Äppelallee", lat: 50.12, lon: 8.69),
                fountain("b", "Mainkai", lat: 50.10, lon: 8.67),
            ],
            from: nil
        )
        // Locale-aware: Ä sorts with A in German, not after Z.
        #expect(ranked.map(\.id) == ["a", "b", "c"])
        #expect(ranked.allSatisfy { $0.distance == nil })
    }

    @Test("Same distance, same order every time")
    func deterministicTies() {
        let pair = [
            fountain("zzz", "Zwei", lat: 50.1200, lon: 8.6900),
            fountain("aaa", "Eins", lat: 50.1200, lon: 8.6900),
        ]
        #expect(FountainRanking.ranked(pair, from: hauptwache).map(\.id) == ["aaa", "zzz"])
        #expect(FountainRanking.ranked(pair.reversed(), from: hauptwache).map(\.id) == ["aaa", "zzz"])
    }

    @Test("Walk minutes never round down to zero")
    func walkMinutesFloor() {
        #expect(FountainDistance(metres: 0).walkMinutes == 1)
        #expect(FountainDistance(metres: 5).walkMinutes == 1)
        #expect(FountainDistance(metres: 800).walkMinutes == 10)
    }

    @Test("An out-of-service fountain is off whatever the season says")
    func outOfServiceBeatsSeason() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let midsummer = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12))!
        let broken = Fountain(
            id: "kaputt", name: "Kaputt", latitude: 50.11, longitude: 8.68,
            kind: .stadt, tested: true, operational: false)
        #expect(broken.state(at: midsummer, calendar: calendar) == .outOfService)

        let working = Fountain(
            id: "heil", name: "Heil", latitude: 50.11, longitude: 8.68,
            kind: .stadt, tested: true, operational: true)
        #expect(working.state(at: midsummer, calendar: calendar) == .running)
    }

    // --- the wire format ------------------------------------------------------

    private func collection(_ featuresJSON: String) throws -> FountainCollection {
        let json = """
            {"version": 1, "id": "fountains", "type": "FeatureCollection", "features": [\(featuresJSON)]}
            """
        return try JSONDecoder().decode(FountainCollection.self, from: Data(json.utf8))
    }

    private let goodFeature = """
        {"type":"Feature","id":"ffm-tb-8","geometry":{"type":"Point","coordinates":[8.686,50.1117]},
         "properties":{"name":"Löwenbrunnen","ags":"06412000","ring":"frankfurt",
         "sources":["https://example.test/x"],"art":"stadt","geprueft":true,"inBetrieb":true}}
        """

    @Test("A published feature maps into the domain")
    func decodesFeature() throws {
        let fountains = try collection(goodFeature).fountains()
        let one = try #require(fountains.first)
        #expect(one.id == "ffm-tb-8")
        #expect(one.name == "Löwenbrunnen")
        // GeoJSON is [lon, lat]; getting this backwards is the classic bug.
        #expect(one.longitude == 8.686)
        #expect(one.latitude == 50.1117)
        #expect(one.kind == .stadt)
        #expect(one.tested == true)
        #expect(one.ring == .frankfurt)
        #expect(one.sources.map(\.absoluteString) == ["https://example.test/x"])
    }

    @Test("An unusable feature is dropped, not thrown — one bad row never costs the layer")
    func dropsUnusableFeatures() throws {
        let broken = """
            {"type":"Feature","id":"linie","geometry":{"type":"LineString","coordinates":[8.6,50.1]},
             "properties":{"name":"Linie","ags":"06412000","ring":"frankfurt","sources":[]}},
            {"type":"Feature","id":"fremder-ring","geometry":{"type":"Point","coordinates":[8.6,50.1]},
             "properties":{"name":"Woanders","ags":"06412000","ring":"wetterau","sources":[]}},
            \(goodFeature)
            """
        #expect(try collection(broken).fountains().map(\.id) == ["ffm-tb-8"])
    }

    @Test("An art this build has never heard of degrades to sonstige")
    func unknownArtDegrades() throws {
        let exotic = """
            {"type":"Feature","id":"neu","geometry":{"type":"Point","coordinates":[8.6,50.1]},
             "properties":{"name":"Neu","ags":"06412000","ring":"frankfurt","sources":[],"art":"zapfsaeule"}}
            """
        let one = try #require(try collection(exotic).fountains().first)
        #expect(one.kind == .sonstige)
        #expect(one.tested == nil)
        #expect(one.operational == nil)
    }

    @Test("The bundled layer decodes and is not empty")
    func bundledLayerLoads() throws {
        let url = try #require(Bundle.kitResources.url(forResource: "fountains", withExtension: "geojson"))
        let collection = try JSONDecoder().decode(FountainCollection.self, from: Data(contentsOf: url))
        let fountains = collection.fountains()
        #expect(fountains.count == collection.features.count, "the shipped layer should lose no feature")
        #expect(fountains.count > 50)
        // The distinction the whole ticket hangs on has to survive the decoder.
        #expect(fountains.contains { $0.tested == false && $0.kind == .historisch })
        #expect(fountains.contains { $0.tested == true })
    }
}
