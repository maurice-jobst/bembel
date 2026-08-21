import BEMBELKit
import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router
    @AppStorage(OnboardingState.completedKey, store: AppGroup.defaults)
    private var onboardingCompleted = false

    var body: some View {
        @Bindable var router = router
        if !onboardingCompleted {
            OnboardingView()
        } else {
            TabView(selection: $router.selectedTab) {
                ForEach(BEMTab.allCases) { tab in
                    screen(for: tab)
                        .tabItem {
                            Label(tab.titleKey, systemImage: tab.systemImage)
                        }
                        .tag(tab)
                }
            }
            .tint(BEMColor.cobalt)
            .sheet(isPresented: $router.isPresentingSettings) {
                SettingsView()
            }
        }
    }

    @ViewBuilder
    private func screen(for tab: BEMTab) -> some View {
        switch tab {
        case .places: PlacesView()
        case .departures: DeparturesView()
        case .sun: SunView()
        case .radar: RadarView()
        case .city: CityView()
        }
    }
}

extension BEMTab {
    var titleKey: LocalizedStringKey {
        switch self {
        case .places: "tab.places"
        case .departures: "tab.departures"
        case .sun: "tab.sun"
        case .radar: "tab.radar"
        case .city: "tab.city"
        }
    }

    var systemImage: String {
        switch self {
        case .places: "mappin.and.ellipse"
        case .departures: "tram.fill"
        // Verified in SF Symbols (available since 2019), not assembled from a
        // base name — see the two invented `*.slash` names that shipped as
        // blank icons in the Stadtzustand work.
        case .sun: "sun.max.fill"
        case .radar: "cloud.rain.fill"
        case .city: "gauge.with.dots.needle.50percent"
        }
    }
}
