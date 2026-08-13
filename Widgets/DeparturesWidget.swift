import BEMBELKit
import SwiftUI
import WidgetKit

/// Home-Screen departures: small (next departure large, two follow-ups) and
/// medium (three-row board). Entries are sample fixtures until BEM-C04 wires
/// the shared RMV provider through the App Group.
struct DeparturesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "de.mauricejobst.bembel.departures",
            provider: DeparturesProvider()
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
    struct Row {
        let line: String
        let sBahn: Bool
        let uBahn: Bool
        let destination: String
        let minutes: Int
        let delayed: Bool
    }

    let date: Date
    let station: String
    let distance: String
    let rows: [Row]

    static let sample = DepartureEntry(
        date: .now,
        station: "Willy-Brandt-Platz",
        distance: "120 m",
        rows: [
            Row(line: "S8", sBahn: true, uBahn: false, destination: "Wiesbaden Hbf", minutes: 3, delayed: false),
            Row(line: "S9", sBahn: true, uBahn: false, destination: "Hanau Hbf", minutes: 6, delayed: true),
            Row(line: "U1", sBahn: false, uBahn: true, destination: "Südbahnhof", minutes: 7, delayed: false),
        ]
    )
}

struct DeparturesProvider: TimelineProvider {
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

            if let next = entry.rows.first {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    WidgetLineBadge(row: next)
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
                ForEach(entry.rows.dropFirst().prefix(2), id: \.line) { row in
                    HStack(spacing: 6) {
                        Text(verbatim: row.line)
                            .frame(width: 26, alignment: .leading)
                        Text(verbatim: "\(row.minutes)′")
                            .foregroundStyle(row.delayed ? BEMColor.caution : BEMColor.inkSecondary)
                        Text(verbatim: row.destination)
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
                ForEach(Array(entry.rows.prefix(3).enumerated()), id: \.element.line) { index, row in
                    HStack(spacing: 9) {
                        WidgetLineBadge(row: row)
                        Text(verbatim: row.destination)
                            .font(.footnote)
                            .foregroundStyle(BEMColor.ink)
                            .lineLimit(1)
                        Spacer()
                        Text(verbatim: "\(row.minutes)′")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(row.delayed ? BEMColor.caution : BEMColor.ink)
                    }
                    .padding(.vertical, 5)
                    if index < min(entry.rows.count, 3) - 1 {
                        Divider().overlay(BEMColor.glazeLine)
                    }
                }
            }
        }
    }

    private func header(showDistance: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "tram.fill")
                .font(.caption2)
                .foregroundStyle(BEMColor.cobalt)
            Text(verbatim: showDistance ? "\(entry.station) · \(entry.distance)" : entry.station)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BEMColor.inkSecondary)
                .lineLimit(1)
        }
    }
}

/// Compact line badge, mirroring the app's styling: S fills cobaltDeep,
/// U outlines cobalt, surface lines outline grey.
struct WidgetLineBadge: View {
    let row: DepartureEntry.Row

    var body: some View {
        Text(verbatim: row.line)
            .font(.system(.caption2, design: .rounded).weight(.bold).monospacedDigit())
            .foregroundStyle(row.sBahn ? .white : (row.uBahn ? BEMColor.cobalt : BEMColor.inkSecondary))
            .frame(minWidth: 34, minHeight: 20)
            .background {
                let shape = RoundedRectangle(cornerRadius: 5)
                if row.sBahn {
                    shape.fill(BEMColor.cobaltDeep)
                } else if row.uBahn {
                    shape.stroke(BEMColor.cobalt, lineWidth: 1.5)
                } else {
                    shape.stroke(BEMColor.glazeLine, lineWidth: 1)
                }
            }
    }
}
