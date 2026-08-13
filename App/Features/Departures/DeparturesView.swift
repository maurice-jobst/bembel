import BEMBELKit
import SwiftUI

/// Abfahrten: nearest stop resolved automatically, board with tabular
/// digits. Renders whatever the injected `DeparturesProviding` returns.
struct DeparturesView: View {
    @Environment(Router.self) private var router
    @Environment(\.dependencies) private var dependencies
    @State private var model = DeparturesModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BEMSpacing.m) {
                    if let station = model.selectedStation {
                        stationRow(station)
                    }
                    stationChips
                    if let board = model.board {
                        boardCard(board)
                        SourceLine(
                            systemImage: "arrow.trianglehead.2.clockwise",
                            text: Text("departures.source \(board.updatedLabel)")
                        )
                        .padding(.horizontal, BEMSpacing.xs)
                    }
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
        .task {
            await model.load(from: dependencies.departures)
        }
    }

    private func stationRow(_ station: Station) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(BEMColor.cobalt)
            Text(verbatim: station.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BEMColor.ink)
            if let distance = station.distanceLabel {
                Text(verbatim: distance)
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
        }
    }

    private var stationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BEMSpacing.s) {
                ForEach(model.stations) { station in
                    SelectionChip(title: Text(verbatim: station.name), isSelected: station == model.selectedStation) {
                        Task {
                            await model.select(station, from: dependencies.departures)
                        }
                    }
                }
            }
        }
    }

    private func boardCard(_ board: DepartureBoard) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(board.departures.enumerated()), id: \.element.id) { index, departure in
                DepartureRow(departure: departure)
                if index < board.departures.count - 1 {
                    Divider().overlay(BEMColor.glazeLine)
                }
            }
        }
        .background(BEMColor.saltGlazeElevated)
        .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))
    }
}

struct DepartureRow: View {
    let departure: Departure

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
