import BEMBELKit
import CoreLocation
import SwiftUI
import WidgetKit

/// „Regnet's gleich?“ — the Radar tab's headline on the Home and Lock Screen
/// (BEM-F04). The extension downloads DWD's RV archive itself and reads one
/// point from it with `RadolanPointReader`; the map's reader would not fit in
/// a widget's memory (ADR 0011). One download fills an hour of entries.
struct RainWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.rain, provider: RainTimelineProvider()) { entry in
            RainWidgetView(entry: entry)
                .containerBackground(BEMColor.saltGlaze, for: .widget)
                .widgetURL(DeepLink.radarURL)
        }
        .configurationDisplayName("Regen")
        .description("Regnet es in Frankfurt in den nächsten zwei Stunden? Direkt aus dem Radar des DWD.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct RainEntry: TimelineEntry {
    let date: Date
    let state: RainWidgetState
    /// The next hour in five-minute steps, from this entry's own time. Empty
    /// when there is nothing current to draw.
    let bars: [Double?]

    static var sample: RainEntry {
        RainEntry(
            date: .now,
            state: .forecast(.rainStarting(inMinutes: 15, intensity: .moderate, lastingMinutes: 25), measuredAt: .now),
            bars: [0, 0, 0, 0.6, 1.2, 1.4, 0.9, 0.7, 0.3, 0, 0, 0]
        )
    }
}

/// WidgetKit's completion handler predates `Sendable`, and Swift 6 will not
/// let a `Task` capture it. WidgetKit calls it once per request, which is the
/// promise the unchecked conformance rests on.
private struct Reply<Value>: @unchecked Sendable {
    private let completion: (Value) -> Void
    init(_ completion: @escaping (Value) -> Void) { self.completion = completion }
    func callAsFunction(_ value: Value) { completion(value) }
}

struct RainTimelineProvider: TimelineProvider {
    /// The Radar tab's own point: the widget says what the tab says, and needs
    /// no location permission to say it.
    private static let frankfurt = CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)
    /// A widget has seconds, not a minute, before the system gives up on it.
    private static let timeout: TimeInterval = 20

    func placeholder(in context: Context) -> RainEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (RainEntry) -> Void) {
        guard !context.isPreview else {
            completion(.sample)
            return
        }
        let reply = Reply(completion)
        Task { reply(await Self.timeline(now: .now).entries.first ?? .sample) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RainEntry>) -> Void) {
        let reply = Reply(completion)
        Task { reply(await Self.timeline(now: .now)) }
    }

    private static func timeline(now: Date) async -> Timeline<RainEntry> {
        guard let nowcast = await fetch() else {
            return Timeline(
                entries: [RainEntry(date: now, state: .unavailable, bars: [])],
                policy: .after(now.addingTimeInterval(RainWidgetTimeline.retryInterval))
            )
        }
        let entries = RainWidgetTimeline.entries(for: nowcast, now: now).map { entry in
            RainEntry(
                date: entry.date,
                state: entry.state,
                bars: RainWidgetTimeline.remaining(nowcast, at: entry.date)?.prefix(12).map(\.millimetres) ?? []
            )
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(RainWidgetTimeline.reloadInterval)))
    }

    private static func fetch() async -> RadarNowcast? {
        var request = URLRequest(url: RadolanRadarProvider.latestURL)
        request.timeoutInterval = timeout
        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false
        else { return nil }
        return try? RadolanPointReader.nowcast(fromArchive: data, at: frankfurt)
    }
}

struct RainWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RainEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Label {
                Text(verbatim: headline)
            } icon: {
                Image(systemName: symbol)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Label {
                    Text(verbatim: headline)
                } icon: {
                    Image(systemName: symbol)
                }
                .font(.headline)
                .widgetAccentable()
                Text(verbatim: detail)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption)
                    .foregroundStyle(BEMColor.cobalt)
                Text(verbatim: "Regen · Frankfurt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BEMColor.inkSecondary)
                    .lineLimit(1)
            }
            Text(verbatim: headline)
                .font(.headline)
                .foregroundStyle(BEMColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(verbatim: detail)
                .font(.caption)
                .foregroundStyle(BEMColor.inkSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            if !entry.bars.isEmpty {
                RainBars(values: entry.bars)
                    .frame(height: 22)
                    .accessibilityHidden(true)
            }
            // GeoNutzV: the source is named wherever the data is shown.
            Text(verbatim: footer)
                .font(.caption2)
                .foregroundStyle(BEMColor.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Words

    // The same sentences as the Radar tab's `radar.outlook.*` and
    // `radar.detail.*` keys. The extension cannot read the app's String
    // Catalog, so, like the other widgets, it states them directly — #32's
    // audit is where the widgets get a catalog of their own.

    private var headline: String {
        switch entry.state {
        case .forecast(.rainingNow, _): "Regen jetzt"
        case .forecast(.rainStarting(let minutes, _, _), _): "Regen in \(minutes) Min"
        case .forecast(.dry, _): "Kein Regen"
        case .forecast(.noData, _): "Keine Radardaten"
        case .stale: "Radar veraltet"
        case .unavailable: "Radar nicht erreichbar"
        }
    }

    private var detail: String {
        switch entry.state {
        case .forecast(.rainingNow(let intensity, let remaining), _):
            if let remaining {
                "\(word(intensity)), noch etwa \(remaining) Minuten"
            } else {
                "\(word(intensity)), hält über die Vorhersage hinaus an"
            }
        case .forecast(.rainStarting(_, let intensity, let lasting), _):
            "\(word(intensity)), etwa \(lasting) Minuten lang"
        case .forecast(.dry(let horizon), _):
            "in den nächsten \(horizon) Minuten"
        case .forecast(.noData, _):
            "Das Radar sieht hier gerade nichts"
        case .stale:
            // A stale "trocken" is a wrong one; the footer says how old.
            "Zum Aktualisieren BEMBEL öffnen"
        case .unavailable:
            "Keine Verbindung zum DWD"
        }
    }

    private var footer: String {
        switch entry.state {
        case .forecast(_, let measuredAt), .stale(let measuredAt?):
            "DWD · Stand \(measuredAt.formatted(date: .omitted, time: .shortened))"
        case .stale(nil), .unavailable:
            "Deutscher Wetterdienst"
        }
    }

    private var symbol: String {
        switch entry.state {
        case .forecast(.rainingNow, _): "cloud.rain.fill"
        case .forecast(.rainStarting, _): "cloud.drizzle.fill"
        case .forecast(.dry, _): "sun.max.fill"
        case .forecast(.noData, _), .unavailable: "icloud.slash"
        case .stale: "clock.arrow.circlepath"
        }
    }

    private func word(_ intensity: RainIntensity) -> String {
        switch intensity {
        case .light: "leicht"
        case .moderate: "mäßig"
        case .heavy: "stark"
        }
    }
}

/// The next hour as twelve bars, on the Radar tab's scale: a dry step is a
/// hairline rather than nothing, so "dry" reads as measured, and no-data is a
/// gap, so it never reads as dry.
struct RainBars: View {
    let values: [Double?]
    /// 2 mm per five minutes is `RadarNowcastRules`' "heavy"; everything above
    /// fills the bar.
    private static let ceiling = 2.0

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(values.indices, id: \.self) { index in
                    let value = values[index]
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(value == nil ? Color.clear : BEMColor.cobalt)
                        .frame(height: height(value, in: proxy.size.height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func height(_ value: Double?, in available: CGFloat) -> CGFloat {
        guard let value else { return available }
        let share = min(value / Self.ceiling, 1)
        return max(2, available * share)
    }
}
