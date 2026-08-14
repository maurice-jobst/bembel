import BEMBELKit
import SwiftUI

/// The coverage game: how much of the city is actually verified, per
/// Stadtteil. Degrades honestly — a bundle without coverage counts shows the
/// empty state instead of a fake zero.
struct CoverageView: View {
    let model: PlacesModel
    @Environment(\.dismiss) private var dismiss

    private var totals: (verified: Int, total: Int) {
        model.coverage.reduce(into: (0, 0)) { sum, area in
            sum.0 += area.verified
            sum.1 += area.total
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if model.coverage.isEmpty {
                    Text("coverage.empty")
                        .font(.subheadline)
                        .foregroundStyle(BEMColor.inkSecondary)
                } else {
                    Section {
                        ForEach(model.coverage) { area in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(verbatim: area.district)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("coverage.progress \(area.verified) \(area.total)")
                                        .font(BEMFont.dataLabel)
                                        .foregroundStyle(BEMColor.inkSecondary)
                                }
                                ProgressView(value: area.fraction)
                                    .tint(BEMColor.cobalt)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("coverage.progress \(totals.verified) \(totals.total)")
                    } footer: {
                        Text("coverage.footer")
                    }
                }

                if let report = RatingFunnel.report(register: model.selectedRegister, name: nil) {
                    Section {
                        Link(destination: report) {
                            Label("coverage.report", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("coverage.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
        }
    }
}
