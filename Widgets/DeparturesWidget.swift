import BEMBELKit
import SwiftUI
import WidgetKit

/// Home-Screen departures: small (next departure large, two follow-ups) and
/// medium (three-row board). Entries come from the kit's sample fixtures
/// until BEM-C04 wires the shared RMV provider through the App Group.
struct DeparturesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "de.mauricejobst.bembel.departures",
            provider: DeparturesTimelineProvider()
        ) { entry in
            DeparturesWidgetView(entry: entry)
                .containerBackground(BEMColor.saltGlaze, for: .widget)
        }
        .configurationDisplayName("Abfahrten")
        .description("Die nächsten Abfahrten an deiner Haltestelle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DepartureEntry: TimelineEntry {
    let date: Date
    let station: Station
    let departures: [Departure]

    static var sample: DepartureEntry {
        DepartureEntry(
            date: .now,
            station: SampleDeparturesProvider.stations[0],
            departures: SampleDeparturesProvider.board.departures
        )
    }
}

struct DeparturesTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DepartureEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (DepartureEntry) -> Void) {
        completion(.sample)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DepartureEntry>) -> Void) {
        completion(Timeline(entries: [.sample], policy: .never))
    }
}

struct DeparturesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DepartureEntry

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 7) {
            header(showDistance: false)

            if let next = entry.departures.first {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    WidgetLineBadge(line: next.line, kind: next.kind)
                    Text(verbatim: "\(next.minutes)′")
                        .font(BEMFont.boardLarge)
                        .foregroundStyle(next.delayed ? BEMColor.caution : BEMColor.ink)
                }
                Text(verbatim: next.destination)
                    .font(.caption)
                    .foregroundStyle(BEMColor.inkSecondary)
                    .lineLimit(1)
                    .padding(.top, -4)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(entry.departures.dropFirst().prefix(2)) { departure in
                    HStack(spacing: 6) {
                        Text(verbatim: departure.line)
                            .frame(width: 26, alignment: .leading)
                        Text(verbatim: "\(departure.minutes)′")
                            .foregroundStyle(departure.delayed ? BEMColor.caution : BEMColor.inkSecondary)
                        Text(verbatim: departure.destination)
                            .lineLimit(1)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BEMColor.inkSecondary)
                }
            }
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                header(showDistance: true)
                Spacer()
                Text(entry.date, format: .dateTime.hour().minute())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(BEMColor.inkSecondary)
            }

            VStack(spacing: 0) {
                let rows = Array(entry.departures.prefix(3))
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, departure in
                    HStack(spacing: 9) {
                        WidgetLineBadge(line: departure.line, kind: departure.kind)
                        Text(verbatim: departure.destination)
                            .font(.footnote)
                            .foregroundStyle(BEMColor.ink)
                            .lineLimit(1)
                        Spacer()
                        Text(verbatim: "\(departure.minutes)′")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(departure.delayed ? BEMColor.caution : BEMColor.ink)
                    }
                    .padding(.vertical, 5)
                    if index < rows.count - 1 {
                        Divider().overlay(BEMColor.glazeLine)
                    }
                }
            }
        }
    }

    private func header(showDistance: Bool) -> some View {
        let title = [entry.station.name, showDistance ? entry.station.distanceLabel : nil]
            .compactMap { $0 }
            .joined(separator: " · ")
        return HStack(spacing: 5) {
            Image(systemName: "tram.fill")
                .font(.caption2)
                .foregroundStyle(BEMColor.cobalt)
            Text(verbatim: title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BEMColor.inkSecondary)
                .lineLimit(1)
        }
    }
}

/// Compact line badge, mirroring the app's styling: S fills cobaltDeep,
/// U outlines cobalt, surface lines outline grey.
struct WidgetLineBadge: View {
    let line: String
    let kind: LineKind

    var body: some View {
        Text(verbatim: line)
            .font(.system(.caption2, design: .rounded).weight(.bold).monospacedDigit())
            .foregroundStyle(foreground)
            .frame(minWidth: 34, minHeight: 20)
            .background {
                let shape = RoundedRectangle(cornerRadius: 5)
                switch kind {
                case .sBahn: shape.fill(BEMColor.cobaltDeep)
                case .uBahn: shape.stroke(BEMColor.cobalt, lineWidth: 1.5)
                case .surface: shape.stroke(BEMColor.glazeLine, lineWidth: 1)
                }
            }
    }

    private var foreground: Color {
        switch kind {
        case .sBahn: .white
        case .uBahn: BEMColor.cobalt
        case .surface: BEMColor.inkSecondary
        }
    }
}
