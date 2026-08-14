import Foundation

/// Everything a `bembel://` URL can express. The parser is total: any input
/// yields a `DeepLink` or `nil`, never a trap — deep links are hostile input.
///
/// Grammar (hosts accept German aliases):
///   bembel://places     | orte
///   bembel://kiosk      | wasserhaeuschen   [/<entry-id>]
///   bembel://ebbelwei   | apfelwein         [/<entry-id>]
///   bembel://water      | wasser | brunnen  [/<fountain-id>]  (opens Orte on Trinkbrunnen)
///   bembel://departures | abfahrten
///   bembel://shadow     | schatten     [?t=ISO-8601, naive times = Europe/Berlin]
///   bembel://radar      | regen
///   bembel://city       | stadt
///   bembel://settings   | einstellungen
///
/// A single path component names one entry inside the host's register. The
/// register-less `places` host takes no id — nothing on screen could resolve
/// it unambiguously, so it is rejected rather than guessed at.
public enum DeepLink: Hashable, Sendable {
    case tab(BEMTab)
    /// Orte, optionally preselecting one register's segment.
    case places(PlaceRegister?)
    /// One entry inside a register. The register is where to *look first* —
    /// resolution is deliberately lenient about it (see `PlacesModel`), because
    /// ids are unique across the published bundle anyway.
    case entry(register: PlaceRegister, id: String)
    case shadow(at: Date?)
    case settings

    /// An id longer than this is not a bembel-data slug, it is an attack.
    static let maxEntryIDLength = 128

    public static func parse(_ url: URL) -> DeepLink? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "bembel"
        else { return nil }

        // `path` is already percent-decoded. Exactly one non-empty component is
        // an entry link; anything deeper is not a grammar we publish.
        let segments = components.path.split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count <= 1 else { return nil }
        let entryID = segments.first.map(String.init)
        if let entryID, entryID.isEmpty || entryID.count > maxEntryIDLength { return nil }

        switch components.host?.lowercased() {
        case "departures", "abfahrten":
            return entryID == nil ? .tab(.departures) : nil
        case "places", "orte":
            return entryID == nil ? .places(nil) : nil
        case "kiosk", "wasserhaeuschen":
            return place(.wasserhaeuschen, entryID)
        case "ebbelwei", "apfelwein":
            return place(.ebbelwei, entryID)
        case "water", "wasser", "brunnen":
            return place(.trinkbrunnen, entryID)
        case "radar", "regen":
            return entryID == nil ? .tab(.radar) : nil
        case "city", "stadt":
            return entryID == nil ? .tab(.city) : nil
        case "settings", "einstellungen":
            return entryID == nil ? .settings : nil
        case "shadow", "schatten":
            guard entryID == nil else { return nil }
            let raw = components.queryItems?.first { $0.name == "t" }?.value
            return .shadow(at: raw.flatMap(parseTimestamp))
        default:
            return nil
        }
    }

    private static func place(_ register: PlaceRegister, _ entryID: String?) -> DeepLink {
        guard let entryID else { return .places(register) }
        return .entry(register: register, id: entryID)
    }

    /// The canonical URL for one entry — the inverse of `parse`, used by the
    /// widgets. Round-tripping it is a test, not an assumption.
    public static func url(register: PlaceRegister, entryID: String) -> URL? {
        guard !entryID.isEmpty, entryID.count <= maxEntryIDLength else { return nil }
        var components = URLComponents()
        components.scheme = "bembel"
        components.host = register.canonicalHost
        components.path = "/\(entryID)"
        return components.url
    }

    /// ISO 8601; a timestamp without zone designator is local Frankfurt time.
    /// Unparseable input degrades to `nil` (shadow map opens at "now").
    static func parseTimestamp(_ raw: String) -> Date? {
        let zoned = ISO8601DateFormatter()
        zoned.formatOptions = [.withInternetDateTime]
        if let date = zoned.date(from: raw) { return date }

        let naive = DateFormatter()
        naive.locale = Locale(identifier: "en_US_POSIX")
        naive.timeZone = TimeZone(identifier: "Europe/Berlin")
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"] {
            naive.dateFormat = format
            if let date = naive.date(from: raw) { return date }
        }
        return nil
    }
}
