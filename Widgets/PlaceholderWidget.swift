import SwiftUI
import WidgetKit

// Deleted at BEM-C04 when the departures widget lands; exists so the widget
// target compiles from BEM-A01 on.
struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "de.mauricejobst.bembel.placeholder",
            provider: PlaceholderProvider()
        ) { _ in
            VStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title2)
                Text(verbatim: "BEMBEL")
                    .font(.caption.weight(.semibold))
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("BEMBEL")
        .description("Platzhalter")
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}
