import Foundation

/// How a line is drawn on the board: S-Bahn filled, U-Bahn outlined cobalt,
/// surface (tram/bus) outlined grey.
public enum LineKind: Sendable, Hashable {
    case sBahn
    case uBahn
    case surface
}

/// A stop the user can pin the board to. Identity is the name until RMV
/// station IDs land (BEM-C01/C02).
public struct Station: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    /// Preformatted distance from the user ("120 m"); nil when unknown.
    public let distanceLabel: String?

    public init(name: String, distanceLabel: String? = nil) {
        self.name = name
        self.distanceLabel = distanceLabel
    }
}

public struct Departure: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let line: String
    public let kind: LineKind
    public let destination: String
    public let detail: String
    public let minutes: Int
    public let clock: String
    public let delayed: Bool

    public init(
        id: UUID = UUID(),
        line: String,
        kind: LineKind,
        destination: String,
        detail: String,
        minutes: Int,
        clock: String,
        delayed: Bool
    ) {
        self.id = id
        self.line = line
        self.kind = kind
        self.destination = destination
        self.detail = detail
        self.minutes = minutes
        self.clock = clock
        self.delayed = delayed
    }
}

/// One rendered board: the departures for a station plus its data stamp.
public struct DepartureBoard: Sendable {
    public let departures: [Departure]
    /// Clock label of the last refresh ("10:47").
    public let updatedLabel: String

    public init(departures: [Departure], updatedLabel: String) {
        self.departures = departures
        self.updatedLabel = updatedLabel
    }
}
