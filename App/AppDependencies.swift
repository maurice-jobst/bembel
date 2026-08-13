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
}

extension EnvironmentValues {
    @Entry var dependencies = AppDependencies()
}
