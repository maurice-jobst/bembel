import BEMBELKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RegionSettings.selectedRingKey, store: AppGroup.defaults)
    private var selectedRingRaw = RegionSettings.defaultRing.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("settings.region.picker", selection: $selectedRingRaw) {
                        ForEach(Ring.allCases) { ring in
                            Text(ring.titleKey).tag(ring.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("settings.region.header")
                } footer: {
                    Text("settings.region.footer")
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
        }
    }
}

extension Ring {
    var titleKey: LocalizedStringKey {
        switch self {
        case .frankfurt: "ring.frankfurt"
        case .kernraum: "ring.kernraum"
        case .rheinmain: "ring.rheinmain"
        }
    }
}
