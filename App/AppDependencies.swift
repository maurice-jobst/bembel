import BEMBELKit
import SwiftUI

/// The app's provider wiring, injected through the environment. Sample
/// providers until the live ones land (epics C–G); previews and tests
/// override individual providers as needed.
struct AppDependencies {
    var departures: any DeparturesProviding = SampleDeparturesProvider()
    var fountains: any FountainProviding = SampleFountainProvider()
    var radar: any RadarProviding = SampleRadarProvider()
    var cityStatus: any CityStatusProviding = SampleCityStatusProvider()
    var register: any RegisterProviding = AppDependencies.liveRegister()

    /// `??` cannot bridge the two concrete types into `any RegisterProviding`,
    /// so this stays an explicit branch. Live by default, sample only if
    /// construction fails — a broken Application Support directory must not
    /// take the hero down.
    static func liveRegister() -> any RegisterProviding {
        if let live = try? BembelDataRegisterProvider.makeDefault() { return live }
        return SampleRegisterProvider()
    }
}

extension EnvironmentValues {
    @Entry var dependencies = AppDependencies()
}
