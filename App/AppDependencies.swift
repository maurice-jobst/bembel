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
    var radar: any RadarProviding = RadolanRadarProvider()
    /// One property per Stadtzustand upstream, not one aggregate: they fail
    /// independently and the screen says which one did. The Main level
    /// (BEM-G01), the air (BEM-G02) and the warnings (BEM-G03) are live;
    /// temperature is still sample and becomes live on its own ticket
    /// without touching the others.
    var temperature: any TemperatureProviding = SampleTemperatureProvider()
    var gauge: any GaugeProviding = PegelOnlineProvider()
    var air: any AirQualityProviding = UBAAirQualityProvider()
    var cityWarnings: any CityWarningProviding = NinaWarningProvider(table: AppDependencies.regionTable)
    var register: any RegisterProviding = AppDependencies.liveRegister()

    var citySources: CitySources {
        #if DEBUG
            let failing = DebugFailingSource.requested
            return CitySources(
                temperature: failing.contains("temperature") ? DebugFailingSource() : temperature,
                gauge: failing.contains("gauge") ? DebugFailingSource() : gauge,
                air: failing.contains("air") ? DebugFailingSource() : air,
                warnings: failing.contains("warnings") ? DebugFailingSource() : cityWarnings
            )
        #else
            return CitySources(temperature: temperature, gauge: gauge, air: air, warnings: cityWarnings)
        #endif
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
}

extension EnvironmentValues {
    @Entry var dependencies = AppDependencies.shared
}
