import Foundation

// The seam between the app shell (frontend lane) and data sources (backend
// lane). Views only ever see these protocols; live implementations replace
// the Sample… ones ticket by ticket (epics C–G) without touching App/.

public protocol DeparturesProviding: Sendable {
    /// Stops near the user, nearest first.
    func stations() async throws -> [Station]
    func board(for station: Station) async throws -> DepartureBoard
}

public protocol FountainProviding: Sendable {
    func fountains() async throws -> [Fountain]
}

public protocol RadarProviding: Sendable {
    func nowcast() async throws -> RadarNowcast
}

public protocol CityStatusProviding: Sendable {
    func status() async throws -> CityStatus
}

public protocol RegisterProviding: Sendable {
    /// The whole published bundle. Registers are small (hundreds of entries)
    /// and the UI slices them by register and Merkmal locally — paging here
    /// would be speculative generality.
    func snapshot() async throws -> RegisterSnapshot
}
