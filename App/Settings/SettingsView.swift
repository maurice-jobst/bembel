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
/// applies to Settings exactly as it does to the feature tabs. The source
/// catalog itself needs no provider: it is bundled, not fetched, so it loads
/// synchronously from `DataSourceCatalog.load()` in `init` rather than through
/// `.task` — there is nothing to await and nothing that can go stale mid-session.
@MainActor
@Observable
final class DataSourcesModel {
    private(set) var snapshot: Loadable<RegisterSnapshot> = .idle
    private(set) var catalog: DataSourceCatalog?

    init(catalog: DataSourceCatalog? = try? DataSourceCatalog.load()) {
        self.catalog = catalog
    }

    func load(from provider: any RegisterProviding) async {
        guard !snapshot.hasLoaded else { return }
        snapshot = .loading
        snapshot = await .result { try await provider.snapshot() }
    }
}

/// Every dataset the app touches, read from `data/sources.json` +
/// `data/ATTRIBUTION.json` via the generated `datasources.json` bundle
/// (BEM-B06, #70) — no hand-typed array to drift out of sync with what the
/// app actually calls. A new registered source appears here once it carries
/// a `consumption` tag; nothing else needs to change.
struct DataSourcesView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var model = DataSourcesModel()

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

            if let catalog = model.catalog {
                sourceSection(catalog.live, header: "settings.sources.live", showsFooter: false)
                sourceSection(catalog.bundled, header: "settings.sources.bundled", showsFooter: true)
            } else {
                Section {
                    Text("settings.data.unavailable")
                        .foregroundStyle(BEMColor.inkSecondary)
                }
            }
        }
        .navigationTitle("settings.sources")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load(from: dependencies.register)
        }
    }

    @ViewBuilder
    private func sourceSection(_ entries: [DataSourceEntry], header: LocalizedStringKey, showsFooter: Bool) -> some View
    {
        Section {
            ForEach(entries) { source in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: source.name)
                        .font(.body)
                    Text(verbatim: source.license)
                        .font(.footnote)
                        .foregroundStyle(BEMColor.inkSecondary)
                }
            }
        } header: {
            Text(header)
        } footer: {
            if showsFooter {
                Text("settings.sources.footer")
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
