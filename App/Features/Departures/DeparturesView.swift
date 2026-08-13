import BEMBELKit
import SwiftUI

/// Abfahrten: nearest stop resolved automatically, board with tabular
/// digits. Sample data until BEM-C01 wires RMV.
struct DeparturesView: View {
    @Environment(Router.self) private var router
    @State private var selectedStation = SampleData.station

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BEMSpacing.m) {
                    stationRow
                    stationChips
                    board
                    SourceLine(
                        systemImage: "arrow.trianglehead.2.clockwise",
                        text: Text("departures.source \(SampleData.departuresUpdated)")
                    )
                    .padding(.horizontal, BEMSpacing.xs)
                }
                .padding(.horizontal, BEMSpacing.l)
            }
            .background(BEMColor.saltGlaze)
            .navigationTitle("tab.departures")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.title", systemImage: "gear") {
                        router.isPresentingSettings = true
                    }
                }
            }
        }
    }

    private var stationRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(BEMColor.cobalt)
            Text(verbatim: selectedStation)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BEMColor.ink)
            Text(verbatim: SampleData.stationDistance)
                .font(BEMFont.dataLabel)
                .foregroundStyle(BEMColor.inkSecondary)
        }
    }

    private var stationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BEMSpacing.s) {
                ForEach(SampleData.nearbyStations, id: \.self) { station in
                    SelectionChip(title: Text(verbatim: station), isSelected: station == selectedStation) {
                        selectedStation = station
                    }
                }
            }
        }
    }

    private var board: some View {
        VStack(spacing: 0) {
            ForEach(Array(SampleData.departures.enumerated()), id: \.element.id) { index, departure in
                DepartureRow(departure: departure)
                if index < SampleData.departures.count - 1 {
                    Divider().overlay(BEMColor.glazeLine)
                }
            }
        }
        .background(BEMColor.saltGlazeElevated)
        .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))
    }
}

struct DepartureRow: View {
    let departure: SampleData.Departure

    var body: some View {
        HStack(spacing: BEMSpacing.m) {
            LineBadge(line: departure.line, kind: departure.kind)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: departure.destination)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BEMColor.ink)
                    .lineLimit(1)
                Text(verbatim: departure.detail)
                    .font(.caption)
                    .foregroundStyle(departure.delayed ? BEMColor.caution : BEMColor.inkSecondary)
            }
            Spacer(minLength: BEMSpacing.s)
            VStack(alignment: .trailing, spacing: 2) {
                Text("departures.minutes \(departure.minutes)")
                    .font(BEMFont.board)
                    .foregroundStyle(departure.delayed ? BEMColor.caution : BEMColor.ink)
                Text(verbatim: departure.clock)
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, BEMSpacing.m)
        .accessibilityElement(children: .combine)
    }
}
