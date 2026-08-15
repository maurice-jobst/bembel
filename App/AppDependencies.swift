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

    var departures: any DeparturesProviding = SampleDeparturesProvider()
    var fountains: any FountainProviding = AppDependencies.liveFountains()
    var radar: any RadarProviding = RadolanRadarProvider()
    var cityStatus: any CityStatusProviding = SampleCityStatusProvider()
    var register: any RegisterProviding = AppDependencies.liveRegister()

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
