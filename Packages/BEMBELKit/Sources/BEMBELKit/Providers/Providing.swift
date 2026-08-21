import CoreLocation
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

// The Stadtzustand screen reads four unrelated upstreams: Bright Sky for the
// temperature, PEGELONLINE for the Main level (BEM-G01), HLNUG for air quality
// (BEM-G02) and NINA for warnings (BEM-G03). One protocol per upstream, because
// they fail independently and the screen has to keep saying so.
//
// It used to be a single `CityStatusProviding` returning one aggregate value,
// which meant a PEGELONLINE outage blanked the whole screen — the warning card
// included, the one that matters most in an emergency. Rejoining these into an
// aggregate would bring that back.

public protocol TemperatureProviding: Sendable {
    func temperature() async throws -> TemperatureReading
}

public protocol GaugeProviding: Sendable {
    func reading() async throws -> GaugeReading
}

public protocol AirQualityProviding: Sendable {
    /// `coordinate` picks the station: air quality is measured at points, and
    /// the nearest one is a different answer from the city's default one.
    /// `nil` — no fix, or permission withheld — is a supported answer and
    /// falls back to the Frankfurt station, the same contract
    /// `FountainRanking` already keeps for the Orte list.
    func airQuality(near coordinate: CLLocationCoordinate2D?) async throws -> AirQuality
}

public protocol CityWarningProviding: Sendable {
    /// Empty is an answer: no warning is in force. It is not the same as a
    /// failed fetch, and the screen renders the two differently.
    func warnings() async throws -> [CityWarning]
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
