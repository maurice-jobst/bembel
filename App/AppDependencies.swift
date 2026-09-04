import BEMBELKit
import SwiftUI

/// The app's provider wiring, injected through the environment. Sample
/// providers until the live ones land (epics C–G); previews and tests
/// override individual providers as needed.
struct AppDependencies {
    /// One instance for the whole app. The `@Entry` default expression is
    /// re-evaluated on environment reads, so it must hand out this shared
    /// value — otherwise every view gets its own provider actors and the
    /// register cache never hits across views.
    static let shared = AppDependencies()

    /// One store for every curated dataset. They share a directory and an
    /// `etags.json`, so they must share the actor that owns it — a store per
    /// provider means two caches and two writers over one file.
    /// `nil` when Application Support is unusable; the sample providers answer
    /// then, and the app still launches.
    private static let store = try? DatasetStore.makeDefault()

    /// Decoded once — 475 municipalities, read on every warnings poll.
    /// `nil` when rings.json is unreadable, which `NinaWarningProvider` turns
    /// into a visible failure rather than a fallback: unlike the register and
    /// the fountains, there is no honest stand-in for a civil-protection
    /// warning, and fabricated ones on that card would be worse than an empty
    /// one that says it is broken.
    private static let regionTable: RegionTable? = {
        #if DEBUG
            if let debug = DebugWarningRegion.table { return debug }
        #endif
        return try? RegionTable.bundled()
    }()

    var departures: any DeparturesProviding = SampleDeparturesProvider()
    var fountains: any FountainProviding = AppDependencies.liveFountains()
    var radar: any RadarProviding = AppDependencies.liveRadar()
    /// One property per Stadtzustand upstream, not one aggregate: they fail
    /// independently and the screen says which one did. All five are live —
    /// temperature (BEM-G06), the Main level (BEM-G01), the air (BEM-G02),
    /// the warnings (BEM-G03) and pollen (BEM-G04) — and each went live on
    /// its own ticket without touching the others, which is the whole point
    /// of the split.
    var temperature: any TemperatureProviding = DWDPoiTemperatureProvider()
    var gauge: any GaugeProviding = PegelOnlineProvider()
    var air: any AirQualityProviding = UBAAirQualityProvider()
    var cityWarnings: any CityWarningProviding = NinaWarningProvider(table: AppDependencies.regionTable)
    var pollen: any PollenProviding = AppDependencies.livePollen()
    var register: any RegisterProviding = AppDependencies.liveRegister()

    var citySources: CitySources {
        #if DEBUG
            let failing = DebugFailingSource.requested
            return CitySources(
                temperature: failing.contains("temperature") ? DebugFailingSource() : temperature,
                gauge: failing.contains("gauge") ? DebugFailingSource() : gauge,
                air: failing.contains("air") ? DebugFailingSource() : air,
                warnings: failing.contains("warnings") ? DebugFailingSource() : cityWarnings,
                pollen: failing.contains("pollen") ? DebugFailingSource() : pollen
            )
        #else
            return CitySources(
                temperature: temperature, gauge: gauge, air: air, warnings: cityWarnings, pollen: pollen
            )
        #endif
    }

    /// Rhein-Main by default. `DebugRadarRegion` can move the drawn box, which
    /// is the only way to look at the overlay on a dry day (BEM-F02).
    static func liveRadar() -> any RadarProviding {
        #if DEBUG
            if let bounds = DebugRadarRegion.bounds, let coordinate = DebugRadarRegion.coordinate {
                return RadolanRadarProvider(coordinate: coordinate, bounds: bounds)
            }
        #endif
        return RadolanRadarProvider()
    }

    /// `??` cannot bridge the two concrete types into `any RegisterProviding`,
    /// so this stays an explicit branch. Live by default, sample only if the
    /// store could not be built — a broken Application Support directory must
    /// not take the hero down.
    static func liveRegister() -> any RegisterProviding {
        guard let store else { return SampleRegisterProvider() }
        return BembelDataRegisterProvider(store: store)
    }

    /// Same branch, same reason: a broken Application Support directory must
    /// not cost the user the Trinkbrunnen layer, and the bundled dataset is
    /// already offline-complete.
    static func liveFountains() -> any FountainProviding {
        guard let store else { return SampleFountainProvider() }
        return FountainDatasetProvider(store: store)
    }

    /// Same branch, same reason (BEM-G04, #71): a broken Application Support
    /// directory must not cost the Stadtzustand screen its pollen row, and the
    /// bundled DWD snapshot is already offline-complete.
    static func livePollen() -> any PollenProviding {
        guard let store else { return SamplePollenProvider() }
        return PollenDatasetProvider(store: store)
    }
}

extension EnvironmentValues {
    @Entry var dependencies = AppDependencies.shared
}
