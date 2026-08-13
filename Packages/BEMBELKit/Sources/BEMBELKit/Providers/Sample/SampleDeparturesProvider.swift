import Foundation

/// Plausible but fabricated departures until BEM-C01/C02 wire RMV. The
/// static fixtures also feed widget timelines and previews.
public struct SampleDeparturesProvider: DeparturesProviding {
    public static let stations: [Station] = [
        Station(name: "Willy-Brandt-Platz", distanceLabel: "120 m"),
        Station(name: "Hauptwache"),
        Station(name: "Taunusanlage"),
    ]

    public static let board = DepartureBoard(
        departures: [
            Departure(line: "S8", kind: .sBahn, destination: "Wiesbaden Hbf", detail: "Gleis 103 · tief", minutes: 3, clock: "10:50", delayed: false),
            Departure(line: "S9", kind: .sBahn, destination: "Hanau Hbf", detail: "Gleis 104 · +2 Min", minutes: 6, clock: "10:53", delayed: true),
            Departure(line: "U1", kind: .uBahn, destination: "Südbahnhof", detail: "Gleis A", minutes: 7, clock: "10:54", delayed: false),
            Departure(line: "U2", kind: .uBahn, destination: "Gonzenheim", detail: "Gleis B", minutes: 9, clock: "10:56", delayed: false),
            Departure(line: "11", kind: .surface, destination: "Fechenheim Schießhüttenstraße", detail: "Straßenbahn", minutes: 11, clock: "10:58", delayed: false),
            Departure(line: "46", kind: .surface, destination: "Ostbahnhof", detail: "Bus", minutes: 14, clock: "11:01", delayed: false),
            Departure(line: "S4", kind: .sBahn, destination: "Kronberg", detail: "Gleis 101 · tief", minutes: 16, clock: "11:03", delayed: false),
        ],
        updatedLabel: "10:47"
    )

    public init() {}

    public func stations() async throws -> [Station] {
        Self.stations
    }

    public func board(for station: Station) async throws -> DepartureBoard {
        Self.board
    }
}
