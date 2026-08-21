import BEMBELKit
import CoreLocation
import Foundation
import Observation

/// Stadtzustand reads four unrelated upstreams, so it keeps four states — the
/// same split `PlacesModel` made for its two registers.
///
/// This used to be one `Loadable<CityStatus>`. A PEGELONLINE timeout then took
/// the whole screen down, warning card included, which is the worst possible
/// thing for the card that matters in an emergency to do. Nothing here may be
/// merged back into a single state.
@MainActor
@Observable
final class CityModel {
    private(set) var temperatureState: Loadable<TemperatureReading> = .idle
    private(set) var gaugeState: Loadable<GaugeReading> = .idle
    private(set) var airState: Loadable<AirQuality> = .idle
    private(set) var warningState: Loadable<[CityWarning]> = .idle

    /// One *successful* load of each source per screen lifetime. A failure
    /// stays retryable, and an empty warning list is a success — the screen
    /// must not keep asking NINA whether it is still quiet.
    private var hasLoaded: Bool {
        temperatureState.hasLoaded && gaugeState.hasLoaded && airState.hasLoaded && warningState.hasLoaded
    }

    /// True while nothing has been settled yet, which is the only moment the
    /// screen has nothing at all to show.
    var isInitialLoad: Bool {
        !temperatureState.hasLoaded && !gaugeState.hasLoaded && !airState.hasLoaded && !warningState.hasLoaded
    }

    func load(from sources: CitySources, near coordinate: CLLocationCoordinate2D? = nil) async {
        guard !hasLoaded else { return }
        await loadAll(from: sources, near: coordinate)
    }

    /// Pull-to-refresh: the user is telling us the cached readings are wrong
    /// for this moment. Everything goes back to the source, including the ones
    /// that succeeded — a screen that refreshes only its broken half would
    /// leave the good cards stamped with an older clock than the bad ones.
    func refresh(from sources: CitySources, near coordinate: CLLocationCoordinate2D? = nil) async {
        temperatureState = .idle
        gaugeState = .idle
        airState = .idle
        warningState = .idle
        await loadAll(from: sources, near: coordinate)
    }

    /// All four in flight at once. Sequentially, a PEGELONLINE request sitting
    /// on its timeout would hold the warning card back by exactly that long —
    /// which is the coupling this split exists to remove, reintroduced as
    /// latency instead of as failure.
    private func loadAll(from sources: CitySources, near coordinate: CLLocationCoordinate2D?) async {
        if !temperatureState.hasLoaded { temperatureState = .loading }
        if !gaugeState.hasLoaded { gaugeState = .loading }
        if !airState.hasLoaded { airState = .loading }
        if !warningState.hasLoaded { warningState = .loading }

        async let temperature = Loadable<TemperatureReading>.result {
            try await sources.temperature.temperature()
        }
        async let gauge = Loadable<GaugeReading>.result { try await sources.gauge.reading() }
        async let air = Loadable<AirQuality>.result { try await sources.air.airQuality(near: coordinate) }
        async let warnings = Loadable<[CityWarning]>.result { try await sources.warnings.warnings() }

        temperatureState = await temperature
        gaugeState = await gauge
        airState = await air
        warningState = await warnings
    }

    /// Retry one card without disturbing the other three.
    func retryGauge(from sources: CitySources) async {
        gaugeState = .loading
        gaugeState = await .result { try await sources.gauge.reading() }
    }

    func retryAir(from sources: CitySources, near coordinate: CLLocationCoordinate2D? = nil) async {
        airState = .loading
        airState = await .result { try await sources.air.airQuality(near: coordinate) }
    }

    func retryWarnings(from sources: CitySources) async {
        warningState = .loading
        warningState = await .result { try await sources.warnings.warnings() }
    }
}

/// The four Stadtzustand upstreams, bundled for passing into the model.
///
/// A plain struct rather than four parameters on every call: the set travels
/// together, and a fifth source (Pollen, #71) should be one field here rather
/// than a fifth argument at six call sites.
struct CitySources {
    let temperature: any TemperatureProviding
    let gauge: any GaugeProviding
    let air: any AirQualityProviding
    let warnings: any CityWarningProviding
}
