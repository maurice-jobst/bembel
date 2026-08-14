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

    /// Same contract as `RegisterProviding.invalidate()` — pull-to-refresh
    /// tells us the staleness window is wrong for this moment.
    func invalidate() async
}

extension FountainProviding {
    /// A provider that answers from fixtures has nothing to invalidate.
    public func invalidate() async {}
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

    /// Drop whatever is cached so the next `snapshot()` goes back to the
    /// source. Pull-to-refresh is the only caller: a user who pulls is telling
    /// us the staleness window is wrong for this moment.
    func invalidate() async
}

extension RegisterProviding {
    /// A provider that answers from fixtures has nothing to invalidate.
    public func invalidate() async {}
}
