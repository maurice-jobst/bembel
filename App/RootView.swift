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
        case .departures: DeparturesView()
        case .shadow: ShadowView()
        case .water: WaterView()
        case .radar: RadarView()
        case .city: CityView()
        }
    }
}

extension BEMTab {
    var titleKey: LocalizedStringKey {
        switch self {
        case .departures: "tab.departures"
        case .shadow: "tab.shadow"
        case .water: "tab.water"
        case .radar: "tab.radar"
        case .city: "tab.city"
        }
    }

    var systemImage: String {
        switch self {
        case .departures: "tram.fill"
        case .shadow: "building.2.fill"
        case .water: "drop.fill"
        case .radar: "cloud.rain.fill"
        case .city: "gauge.with.dots.needle.50percent"
        }
    }
}
