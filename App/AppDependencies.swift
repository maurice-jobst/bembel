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

    var departures: any DeparturesProviding = SampleDeparturesProvider()
    var fountains: any FountainProviding = AppDependencies.liveFountains()
    var radar: any RadarProviding = RadolanRadarProvider()
    /// Live Main level (BEM-G01); air and warnings are still sample inside it
    /// until BEM-G02/G03.
    var cityStatus: any CityStatusProviding = LiveCityStatusProvider()
    var register: any RegisterProviding = AppDependencies.liveRegister()

    /// `??` cannot bridge the two concrete types into `any RegisterProviding`,
    /// so this stays an explicit branch. Live by default, sample only if
    /// construction fails — a broken Application Support directory must not
    /// take the hero down.
    static func liveRegister() -> any RegisterProviding {
        if let live = try? BembelDataRegisterProvider.makeDefault() { return live }
        return SampleRegisterProvider()
    }

    /// Same branch, same reason: a broken Application Support directory must
    /// not cost the user the Trinkbrunnen layer, and the bundled dataset is
    /// already offline-complete.
    static func liveFountains() -> any FountainProviding {
        if let live = try? FountainDatasetProvider.makeDefault() { return live }
        return SampleFountainProvider()
    }
}

extension EnvironmentValues {
    @Entry var dependencies = AppDependencies.shared
}
