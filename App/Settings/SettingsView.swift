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

                Section {
                    NavigationLink("settings.sources") {
                        DataSourcesView()
                    }
                } footer: {
                    Text("settings.privacy")
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

/// Every dataset the app touches, with provider and licence. Grows with the
/// feature tickets; the validator enforces the same rule for curated data.
struct DataSourcesView: View {
    private static let sources: [(name: String, licence: String)] = [
        ("RMV Open Data", "CC BY 4.0"),
        ("Hessen LoD2 (HVBG)", "Datenlizenz Deutschland 2.0"),
        ("Geoportal Frankfurt", "Datenlizenz Deutschland 2.0"),
        ("OpenStreetMap", "ODbL"),
        ("DWD RADOLAN", "GeoNutzV"),
        ("PEGELONLINE (WSV)", "Datenlizenz Deutschland 2.0"),
        ("HLNUG Luftmessnetz", "Datenlizenz Deutschland 2.0"),
        ("NINA (BBK)", "Datenlizenz Deutschland 2.0"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(Self.sources, id: \.name) { source in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: source.name)
                            .font(.body)
                        Text(verbatim: source.licence)
                            .font(.footnote)
                            .foregroundStyle(BEMColor.inkSecondary)
                    }
                }
            } footer: {
                Text("settings.sources.footer")
            }
        }
        .navigationTitle("settings.sources")
        .navigationBarTitleDisplayMode(.inline)
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
