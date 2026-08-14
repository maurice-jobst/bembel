import Foundation

/// Everything a `bembel://` URL can express. The parser is total: any input
/// yields a `DeepLink` or `nil`, never a trap — deep links are hostile input.
///
/// Grammar (hosts accept German aliases):
///   bembel://places     | orte
///   bembel://kiosk      | wasserhaeuschen
///   bembel://ebbelwei   | apfelwein
///   bembel://water      | wasser | brunnen   (legacy: opens Orte on Trinkbrunnen)
///   bembel://departures | abfahrten
///   bembel://shadow     | schatten     [?t=ISO-8601, naive times = Europe/Berlin]
///   bembel://radar      | regen
///   bembel://city       | stadt
///   bembel://settings   | einstellungen
public enum DeepLink: Hashable, Sendable {
    case tab(BEMTab)
    /// Orte, optionally preselecting one register's segment.
    case places(PlaceRegister?)
    case shadow(at: Date?)
    case settings

    public static func parse(_ url: URL) -> DeepLink? {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "bembel"
        else { return nil }

        switch components.host?.lowercased() {
        case "departures", "abfahrten":
            return .tab(.departures)
        case "places", "orte":
            return .places(nil)
        case "kiosk", "wasserhaeuschen":
            return .places(.wasserhaeuschen)
        case "ebbelwei", "apfelwein":
            return .places(.ebbelwei)
        case "water", "wasser", "brunnen":
            return .places(.trinkbrunnen)
        case "radar", "regen":
            return .tab(.radar)
        case "city", "stadt":
            return .tab(.city)
        case "settings", "einstellungen":
            return .settings
        case "shadow", "schatten":
            let raw = components.queryItems?.first { $0.name == "t" }?.value
            return .shadow(at: raw.flatMap(parseTimestamp))
        default:
            return nil
        }
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
