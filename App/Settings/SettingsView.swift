import BEMBELKit
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RegionSettings.selectedRingKey, store: AppGroup.defaults)
    private var selectedRingRaw = RegionSettings.defaultRing.rawValue
    @AppStorage(StickerState.loginKey, store: AppGroup.defaults) private var githubLogin = ""
    @AppStorage(StickerState.visitDetectionKey, store: AppGroup.defaults) private var visitDetection = false

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
                    TextField("settings.github.field", text: $githubLogin)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("settings.github.header")
                } footer: {
                    Text("settings.github.footer")
                }

                Section {
                    Toggle("settings.visits.toggle", isOn: $visitDetection)
                } footer: {
                    Text("settings.visits.footer")
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

/// Data-state rows read view-model state, not a provider — the ADR 0007 seam
/// applies to Settings exactly as it does to the feature tabs.
@MainActor
@Observable
final class DataSourcesModel {
    private(set) var snapshot: Loadable<RegisterSnapshot> = .idle

    func load(from provider: any RegisterProviding) async {
        guard !snapshot.hasLoaded else { return }
        snapshot = .loading
        snapshot = await .result { try await provider.snapshot() }
    }
}

/// Every dataset the app touches, with provider and licence. Grows with the
/// feature tickets; the validator enforces the same rule for curated data.
struct DataSourcesView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var model = DataSourcesModel()

    private static let sources: [(name: String, licence: String)] = [
        ("bembel-data (Community)", "ODbL"),
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
                if let snapshot = model.snapshot.value, snapshot.schemaVersion > 0 {
                    LabeledContent("settings.data.version") {
                        Text(verbatim: String(snapshot.schemaVersion))
                    }
                    if let generatedAt = snapshot.generatedAt {
                        LabeledContent("settings.data.generated") {
                            Text(generatedAt, format: .dateTime.day().month(.abbreviated).year())
                        }
                    }
                    LabeledContent("settings.data.entries") {
                        Text(verbatim: String(snapshot.entries.count))
                    }
                } else {
                    Text("settings.data.unavailable")
                        .foregroundStyle(BEMColor.inkSecondary)
                }
            } header: {
                Text("settings.data.header")
            }

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
        .task {
            await model.load(from: dependencies.register)
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
