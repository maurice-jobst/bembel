import CoreLocation
import Foundation
import Testing

@testable import BEMBELKit

/// Real Umweltbundesamt responses captured 2026-08-19.
///
/// `uba-stations-hessen.json` is the live `stations/json` body with its rows
/// subset to the 35 Hessen stations plus two elsewhere — the wire shape,
/// column order and cell types are untouched, only the row count is, because
/// the full body is 92 KB of Germany to test a nearest-of lookup with.
private func ubaFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private func ubaDecoded<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
    try JSONDecoder().decode(T.self, from: ubaFixture(name))
}

private let frankfurtCentre = CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)

@Suite("UBA wire format")
struct UBAWireTests {
    @Test("Positional rows decode against their own column names")
    func stations() throws {
        let stations = UBARules.stations(from: try ubaDecoded(UBATable.self, "uba-stations-hessen"))
        let ost = try #require(stations.first { $0.code == "DEHE008" })
        #expect(ost.id == "636")
        #expect(ost.name == "Frankfurt Ost")
        #expect(ost.networkName == "Hessen")
        #expect(ost.typeName == "Hintergrund")
        // The pinned fallback must stay the station the API actually serves.
        #expect(UBAStation.frankfurtOst.id == ost.id)
        #expect(UBAStation.frankfurtOst.code == ost.code)
        #expect(UBAStation.frankfurtOst.latitude == ost.latitude)
        #expect(UBAStation.frankfurtOst.longitude == ost.longitude)
    }

    @Test("A cell is a string here and a number there, and both must read")
    func mixedCellTypes() throws {
        // `station latitude` arrives as a quoted string; the component values
        // inside an airquality row arrive as bare numbers. One decoder, both.
        #expect(UBAField.string("50.0996").double == 50.0996)
        #expect(UBAField.number(636).text == "636")
        #expect(UBAField.string("636").int == 636)
        #expect(UBAField.null.double == nil)
        #expect(UBAField.null.text == nil)
    }

    @Test("The pollutant vocabulary comes from the API, not from a table here")
    func components() throws {
        let vocabulary = UBARules.components(from: try ubaDecoded(UBAFlatTable.self, "uba-components"))
        #expect(vocabulary["5"]?.symbol == "NO₂")
        #expect(vocabulary["5"]?.unit == "µg/m³")
        #expect(vocabulary["9"]?.symbol == "PM₂,₅")
        #expect(vocabulary["3"]?.symbol == "O₃")
        #expect(vocabulary.count == 12)
    }
}

@Suite("UBA rules")
struct UBARulesTests {
    @Test("Nearest station beats the default, and no fix keeps the default")
    func nearest() throws {
        let stations = UBARules.stations(from: try ubaDecoded(UBATable.self, "uba-stations-hessen"))
        // 1.7 km from the centre; Frankfurt Ost is 4.9 km away.
        #expect(UBARules.nearest(stations, to: frankfurtCentre)?.code == "DEHE041")
        // Sachsenhausen-Süd is nearer to Schwanheim than to the kerbside one.
        let schwanheim = CLLocationCoordinate2D(latitude: 50.0800, longitude: 8.5900)
        #expect(UBARules.nearest(stations, to: schwanheim)?.code == "DEHE135")
        #expect(UBARules.nearest(stations, to: nil) == nil)
        #expect(UBARules.nearest([], to: frankfurtCentre) == nil)
    }

    @Test("The band, not just the position inside it, decides the bar")
    func fraction() {
        // 38 µg/m³ of ozone is 0.63 of "sehr gut"; 121 is 0.67 of "mäßig".
        // Drawn from `y` alone those bars are the same length.
        let veryGood = UBARules.fraction(band: 0, y: 0.633)
        let moderate = UBARules.fraction(band: 2, y: 0.67)
        #expect(veryGood < moderate)
        #expect(abs(veryGood - 0.1266) < 0.001)
        #expect(abs(moderate - 0.534) < 0.001)
        // The top band is open-ended, so y can exceed 1.
        #expect(UBARules.fraction(band: 4, y: 3.2) == 1)
        // No y: the middle of the band, not its edge.
        #expect(UBARules.fraction(band: 1, y: nil) == 0.3)
        // No band is no bar, not a full one.
        #expect(UBARules.fraction(band: nil, y: 0.9) == 0)
    }

    @Test("The newest hour wins, and the keys sort without being parsed")
    func newestHour() {
        let hours = [
            "2026-08-19 09:00:00": [UBAField.string("nine")],
            "2026-08-19 13:00:00": [UBAField.string("thirteen")],
            "2026-08-18 23:00:00": [UBAField.string("yesterday")],
        ]
        #expect(UBARules.newestHour(hours)?.key == "2026-08-19 13:00:00")
        #expect(UBARules.newestHour([:]) == nil)
    }

    @Test("UBA's 0…4 maps to the bands; anything else is no assessment")
    func indexMapping() {
        #expect(AirIndex(uba: 0) == .veryGood)
        #expect(AirIndex(uba: 4) == .veryPoor)
        #expect(AirIndex(uba: -1) == .unassessed)
        #expect(AirIndex(uba: 9) == .unassessed)
        #expect(AirIndex(uba: nil) == .unassessed)
        // "No assessment" must not read as reassurance, and must not read as
        // alarm either — it is neither.
        #expect(!AirIndex.unassessed.isElevated)
        #expect(AirIndex.unassessed.band == nil)
        #expect(!AirIndex.good.isElevated)
        #expect(AirIndex.moderate.isElevated)
        #expect(AirIndex.veryPoor.isElevated)
    }
}

@Suite("UBA air quality")
struct UBAAirQualityTests {
    private func quality(_ fixture: String, station: UBAStation) throws -> AirQuality {
        let table = try ubaDecoded(UBAAirQualityTable.self, fixture)
        let hours = try #require(table.data[station.id])
        let newest = try #require(UBARules.newestHour(hours))
        return UBAAirQualityProvider.quality(
            station: station,
            hourKey: newest.key,
            row: newest.row,
            vocabulary: UBARules.components(from: try ubaDecoded(UBAFlatTable.self, "uba-components"))
        )
    }

    @Test("A background station becomes four named bars and one verdict")
    func frankfurtOst() throws {
        let air = try quality("uba-airquality-frankfurt-ost", station: .frankfurtOst)
        #expect(air.index == .veryGood)
        #expect(air.stationName == "Frankfurt Ost")
        // HLNUG runs it; UBA only publishes it. The card credits the network.
        #expect(air.stampLabel == "HLNUG · Frankfurt Ost (Hintergrund) · 13:00")
        #expect(air.values.map(\.name) == ["O₃", "NO₂", "PM₁₀", "PM₂,₅"])
        let ozone = try #require(air.values.first)
        #expect(ozone.readingLabel == "38 µg/m³")
        #expect(ozone.index == .veryGood)
    }

    @Test("An incomplete row is a station that measures less, not a broken one")
    func kerbsideStationWithoutOzone() throws {
        // Friedberger Landstraße is a Verkehr station and reports no ozone, so
        // every one of its rows carries data_incomplete = 1. Treating that as
        // "bad data" would leave the nearest station to the city centre
        // permanently blank.
        let friedberger = UBAStation(
            id: "669", code: "DEHE041", name: "Frankfurt Friedberger Landstraße",
            latitude: 50.1257, longitude: 8.6919, networkName: "Hessen", typeName: "Verkehr"
        )
        let air = try quality("uba-airquality-friedberger", station: friedberger)
        #expect(air.values.count == 3)
        #expect(!air.values.contains { $0.name == "O₃" })
        #expect(air.stampLabel.contains("(Verkehr)"))
        #expect(air.index == .veryGood)
    }

    @Test("An unknown component id degrades to its number, not to nothing")
    func unknownComponent() {
        let row: [UBAField] = [
            .string("2026-08-19 14:00:00"), .number(1), .number(0),
            .list([.number(99), .number(7), .number(1), .string("0.5")]),
        ]
        let air = UBAAirQualityProvider.quality(
            station: .frankfurtOst, hourKey: "2026-08-19 13:00:00", row: row, vocabulary: [:]
        )
        #expect(air.values.first?.name == "99")
        #expect(air.values.first?.readingLabel == "7")
        #expect(air.index == .good)
    }

    @Test("Both days are asked for, so the card does not blank out after midnight")
    func urlSpansTwoDays() throws {
        let justAfterMidnight = try #require(
            ISO8601DateFormatter.internetDateTime.date(from: "2026-08-19T00:20:00+02:00")
        )
        let url = UBAAirQualityProvider.airQualityURL(station: "636", now: justAfterMidnight)
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        var values = [String: String]()
        for item in query where values[item.name] == nil { values[item.name] = item.value ?? "" }
        #expect(values["date_from"] == "2026-08-18")
        #expect(values["date_to"] == "2026-08-19")
        // Never omit it: airquality/json without a station does not answer at
        // all — 40 s and zero bytes.
        #expect(values["station"] == "636")
        #expect(url.host() == "luftdaten.umweltbundesamt.de")
        #expect(url.path().hasPrefix("/api/air-data/v3/"))
    }

    @Test("A remembered station survives a round trip and nothing else does")
    func stationStore() throws {
        let defaults = try #require(UserDefaults(suiteName: "uba-station-store-test"))
        defaults.removePersistentDomain(forName: "uba-station-store-test")
        let store = StationStore(defaults: defaults)
        #expect(store.station == nil)

        store.station = .frankfurtOst
        let restored = try #require(store.station)
        #expect(restored == UBAStation.frankfurtOst)

        store.station = nil
        #expect(store.station == nil)
        defaults.removePersistentDomain(forName: "uba-station-store-test")
    }
}
