import CoreLocation
import Foundation

/// Plausible but fabricated values driving every feature screen until the
/// real providers land (RMV BEM-C01, DWD, PEGELONLINE, HLNUG). Nothing in
/// here is live; delete pieces as their tickets replace them.
enum SampleData {
    // MARK: Abfahrten

    struct Departure: Identifiable {
        let id = UUID()
        let line: String
        let kind: LineKind
        let destination: String
        let detail: String
        let minutes: Int
        let clock: String
        let delayed: Bool
    }

    static let station = "Willy-Brandt-Platz"
    static let stationDistance = "120 m"
    static let nearbyStations = ["Willy-Brandt-Platz", "Hauptwache", "Taunusanlage"]

    static let departures: [Departure] = [
        Departure(line: "S8", kind: .sBahn, destination: "Wiesbaden Hbf", detail: "Gleis 103 · tief", minutes: 3, clock: "10:50", delayed: false),
        Departure(line: "S9", kind: .sBahn, destination: "Hanau Hbf", detail: "Gleis 104 · +2 Min", minutes: 6, clock: "10:53", delayed: true),
        Departure(line: "U1", kind: .uBahn, destination: "Südbahnhof", detail: "Gleis A", minutes: 7, clock: "10:54", delayed: false),
        Departure(line: "U2", kind: .uBahn, destination: "Gonzenheim", detail: "Gleis B", minutes: 9, clock: "10:56", delayed: false),
        Departure(line: "11", kind: .surface, destination: "Fechenheim Schießhüttenstraße", detail: "Straßenbahn", minutes: 11, clock: "10:58", delayed: false),
        Departure(line: "46", kind: .surface, destination: "Ostbahnhof", detail: "Bus", minutes: 14, clock: "11:01", delayed: false),
        Departure(line: "S4", kind: .sBahn, destination: "Kronberg", detail: "Gleis 101 · tief", minutes: 16, clock: "11:03", delayed: false),
    ]

    static let departuresUpdated = "10:47"

    // MARK: Trinkwasser

    struct Fountain: Identifiable {
        let id = UUID()
        let name: String
        let coordinate: CLLocationCoordinate2D
        let distance: String
        let walkMinutes: Int
        let featured: Bool
    }

    static let fountains: [Fountain] = [
        Fountain(name: "Trinkbrunnen Rossmarkt", coordinate: .init(latitude: 50.1128, longitude: 8.6776), distance: "220 m", walkMinutes: 3, featured: true),
        Fountain(name: "Trinkbrunnen Hauptwache", coordinate: .init(latitude: 50.1136, longitude: 8.6797), distance: "350 m", walkMinutes: 5, featured: false),
        Fountain(name: "Trinkbrunnen Opernplatz", coordinate: .init(latitude: 50.1157, longitude: 8.6717), distance: "600 m", walkMinutes: 8, featured: false),
        Fountain(name: "Trinkbrunnen Römerberg", coordinate: .init(latitude: 50.1106, longitude: 8.6820), distance: "700 m", walkMinutes: 9, featured: false),
        Fountain(name: "Trinkbrunnen Mainkai", coordinate: .init(latitude: 50.1080, longitude: 8.6840), distance: "850 m", walkMinutes: 11, featured: false),
    ]

    // MARK: Regenradar

    static let radarHeadline = "Regen in 25 Min"
    static let radarDetail = "leicht, etwa 20 Minuten lang"
    static let radarClock = "10:47"
    static let radarStamp = "10:45"

    // MARK: Stadtzustand

    static let cityTemperature = "Frankfurt am Main · 24 °C"
    static let gaugeLevel = "3,42"
    static let gaugeTrend = "4 cm / 24 h"
    static let gaugeStation = "Osthafen"
    static let gaugeStamp = "10:45"
    static let gaugeHistory: [Double] = [20, 17, 22, 16, 12, 18, 26, 22, 28, 33, 30, 36]

    struct AirValue: Identifiable {
        let id = UUID()
        let name: String
        let reading: String
        let fraction: Double
        let elevated: Bool
    }

    static let airValues: [AirValue] = [
        AirValue(name: "NO₂", reading: "21 µg/m³", fraction: 0.26, elevated: false),
        AirValue(name: "PM₂,₅", reading: "8 µg/m³", fraction: 0.18, elevated: false),
        AirValue(name: "O₃", reading: "96 µg/m³", fraction: 0.62, elevated: true),
    ]

    static let airStamp = "HLNUG Station Frankfurt-Ost · 10:00"
    static let warningStamp = "NINA · 09:12"
}
