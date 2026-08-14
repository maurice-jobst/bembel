import BEMBELKit
import SwiftUI
import WidgetKit

/// "Nächster Kandidat": the unverified entry nearest the last place the user
/// looked at the map, one tap from its detail card. The coverage game on the
/// Home Screen — the whole point is that verifying is a two-minute detour on a
/// walk you were taking anyway.
///
/// The extension holds no location and cannot reach the app's refreshed data;
/// it renders `CandidateDigest`, which the app publishes into the App Group.
struct NearestCandidateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKind.nearestCandidate,
            provider: CandidateTimelineProvider()
        ) { entry in
            NearestCandidateWidgetView(entry: entry)
                .containerBackground(BEMColor.saltGlaze, for: .widget)
        }
        .configurationDisplayName("Nächster Kandidat")
        .description("Der nächste unbestätigte Ort in deiner Nähe — einer, den du verifizieren könntest.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CandidateEntry: TimelineEntry {
    let date: Date
    /// `nil` means the digest is missing or empty — two different sentences to
    /// the user, told apart by `hasDigest`.
    let item: CandidateDigest.Item?
    let hasDigest: Bool
    /// When the app last measured the distances shown here.
    let measuredAt: Date?
    /// Further candidates behind this one, for the "und N weitere" line.
    let others: Int

    static var sample: CandidateEntry {
        CandidateEntry(
            date: .now,
            item: CandidateDigest.Item(
                id: "yok-yok",
                register: .wasserhaeuschen,
                name: "Yok-Yok",
                area: "Bahnhofsviertel",
                latitude: 50.1075,
                longitude: 8.6665,
                distance: 640
            ),
            hasDigest: true,
            measuredAt: .now,
            others: 3
        )
    }

    static func empty(hasDigest: Bool, measuredAt: Date? = nil) -> CandidateEntry {
        CandidateEntry(date: .now, item: nil, hasDigest: hasDigest, measuredAt: measuredAt, others: 0)
    }
}

struct CandidateTimelineProvider: TimelineProvider {
    /// One candidate per hour, so a widget nobody taps still cycles through the
    /// neighbourhood instead of nagging about the same place all day.
    private static let step: TimeInterval = 60 * 60

    func placeholder(in context: Context) -> CandidateEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (CandidateEntry) -> Void) {
        completion(context.isPreview ? .sample : (timeline().first ?? .empty(hasDigest: false)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CandidateEntry>) -> Void) {
        let entries = timeline()
        guard !entries.isEmpty else {
            // Nothing to rotate through: re-ask in an hour rather than never,
            // because the app may publish a digest at any point.
            completion(
                Timeline(
                    entries: [.empty(hasDigest: CandidateDigestStore.load() != nil)],
                    policy: .after(.now.addingTimeInterval(Self.step))
                )
            )
            return
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func timeline() -> [CandidateEntry] {
        guard let digest = CandidateDigestStore.load(), !digest.items.isEmpty else { return [] }
        return digest.items.enumerated().map { index, item in
            CandidateEntry(
                date: .now.addingTimeInterval(Double(index) * Self.step),
                item: item,
                hasDigest: true,
                measuredAt: digest.updatedAt,
                others: digest.items.count - index - 1
            )
        }
    }
}

struct NearestCandidateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CandidateEntry

    var body: some View {
        Group {
            if let item = entry.item {
                switch family {
                case .systemMedium: medium(item)
                default: small(item)
                }
            } else {
                emptyState
            }
        }
        .widgetURL(entry.item?.url)
    }

    private func small(_ item: CandidateDigest.Item) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            header
            Spacer(minLength: 0)
            Text(verbatim: item.name)
                .font(.headline)
                .foregroundStyle(BEMColor.ink)
                .lineLimit(2)
            Text(verbatim: item.area)
                .font(.caption)
                .foregroundStyle(BEMColor.inkSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            distanceLine(item)
        }
    }

    private func medium(_ item: CandidateDigest.Item) -> some View {
        let measuredAt = entry.measuredAt
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                header
                Spacer()
                // A digest measured seconds ago has no age worth printing, and
                // the numeric style renders that as "in 0 Sekunden" — future
                // tense for something that already happened.
                if let measuredAt, entry.date.timeIntervalSince(measuredAt) >= 60 {
                    Text(measuredAt, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(BEMColor.inkSecondary)
                        .lineLimit(1)
                }
            }

            HStack(alignment: .top, spacing: 11) {
                CandidatePinBadge()
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: item.name)
                        .font(.headline)
                        .foregroundStyle(BEMColor.ink)
                        .lineLimit(1)
                    Text(verbatim: "\(item.area) · \(item.distanceLabel)")
                        .font(.caption)
                        .foregroundStyle(BEMColor.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Text(verbatim: entry.others > 0 ? "Noch \(entry.others) weitere in der Nähe" : "Tippen, um zu verifizieren")
                .font(.caption2)
                .foregroundStyle(BEMColor.inkSecondary)
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal")
                .font(.caption2)
                .foregroundStyle(BEMColor.cobalt)
            Text(verbatim: "Unbestätigt")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BEMColor.inkSecondary)
                .lineLimit(1)
        }
    }

    private func distanceLine(_ item: CandidateDigest.Item) -> some View {
        Text(verbatim: item.distanceLabel)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(BEMColor.cobalt)
    }

    /// Two different silences: no digest at all means the app has never had
    /// both data and a map on screen; an empty one means this corner of the
    /// city is actually done. Saying "keine Kandidaten" in the first case
    /// would be a claim we have not earned.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            Text(verbatim: entry.hasDigest ? "Hier ist alles bestätigt." : "BEMBEL öffnen, um die Karte zu laden.")
                .font(.subheadline)
                .foregroundStyle(BEMColor.ink)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
    }
}

/// The map's candidate pin, shrunk: grey and hollow, the same "invitation, not
/// data" reading as `EntryPin`.
struct CandidatePinBadge: View {
    var body: some View {
        Circle()
            .fill(BEMColor.saltGlazeElevated)
            .stroke(BEMColor.glazeLine, lineWidth: 2)
            .frame(width: 34, height: 34)
            .overlay {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
    }
}
