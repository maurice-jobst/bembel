import BEMBELKit
import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            ForEach(BEMTab.allCases) { tab in
                NavigationStack {
                    FeaturePlaceholderView(tab: tab)
                        .navigationTitle(tab.titleKey)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("settings.title", systemImage: "gear") {
                                    router.isPresentingSettings = true
                                }
                            }
                        }
                }
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

struct FeaturePlaceholderView: View {
    let tab: BEMTab

    var body: some View {
        ContentUnavailableView {
            Label("placeholder.title", systemImage: tab.systemImage)
        } description: {
            Text("placeholder.message")
        }
        .background(BEMColor.saltGlaze)
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
