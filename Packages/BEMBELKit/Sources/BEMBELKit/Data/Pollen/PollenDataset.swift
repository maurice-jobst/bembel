import Foundation

/// DWD's `s31fg.json` exactly as it is on the wire (BEM-G04, #71): a 3-day
/// pollen forecast for every DWD partregion in Germany, refreshed every six
/// hours.
/// https://opendata.dwd.de/climate_environment/health/alerts/s31fg.json
///
/// **The one trap that costs a live probe:** Rhein-Main is a DWD
/// *partregion* nested inside the region "Hessen" — `region_name == "Hessen"`
/// and `partregion_name == "Rhein-Main"` — and the assignment is the name,
/// never coordinates. Nordrhein-Westfalen's partregion is called
/// "Rhein.-Westfäl. Tiefland" and Rheinland-Pfalz has one starting "Rhein,
/// Pfalz…" — a bounding box or a substring match on "Rhein" lands in the
/// wrong Land.
struct PollenForecastFile: Decodable, Sendable {
    struct Partregion: Decodable, Sendable {
        struct Kind: Decodable, Sendable {
            let today: String?
            let tomorrow: String?
            let dayafterTo: String?

            enum CodingKeys: String, CodingKey {
                case today, tomorrow
                case dayafterTo = "dayafter_to"
            }
        }

        let partregionName: String
        let regionName: String
        let pollen: [String: Kind]

        enum CodingKeys: String, CodingKey {
            case partregionName = "partregion_name"
            case regionName = "region_name"
            case pollen = "Pollen"
        }
    }

    let content: [Partregion]
    /// Flat `id1`…`id7` / `id1_desc`…`id7_desc` pairs — DWD's own sentence for
    /// each Belastungsstufe. `legendByLevel()` turns this into a lookup.
    let legend: [String: String]
    /// "2026-09-04 11:00 Uhr" — kept as DWD wrote it; see `PollenReading.stampLabel`.
    let lastUpdate: String

    enum CodingKeys: String, CodingKey {
        case content, legend
        case lastUpdate = "last_update"
    }

    /// `{"0": "keine Belastung", "0-1": "keine bis geringe Belastung", …}` —
    /// the raw level value is the lookup key because that is what a
    /// `PollenLevel` carries; `id1`/`id2`/… is purely the file's own indexing
    /// and has no meaning outside it.
    func legendByLevel() -> [String: String] {
        var result: [String: String] = [:]
        for i in 1...7 {
            if let level = legend["id\(i)"], let description = legend["id\(i)_desc"] {
                result[level] = description
            }
        }
        return result
    }
}

enum PollenDataset: CuratedDataset {
    typealias Payload = PollenForecastFile
    static let id = "pollen"
}

enum PollenError: Error, Equatable, Sendable {
    /// The file no longer carries a Hessen / Rhein-Main partregion — DWD
    /// reshaped the file, or dropped the region. Either way this is a real
    /// failure, not "nothing is in the air": rendering an empty list here
    /// would say the opposite of what actually happened.
    case missingRhineMainPartregion
}

extension PollenForecastFile {
    /// Wire → domain: resolves Rhein-Main by name, drops levels DWD itself
    /// rates "keine Belastung", and attaches DWD's own sentence for today's
    /// level. Sorted by today's severity (most elevated first) so the row a
    /// reader most needs is the one they see without scrolling.
    func reading() throws -> PollenReading {
        guard
            let partregion = content.first(where: { $0.regionName == "Hessen" && $0.partregionName == "Rhein-Main" })
        else {
            throw PollenError.missingRhineMainPartregion
        }
        let descriptions = legendByLevel()

        let values =
            partregion.pollen
            .map { name, kind -> PollenTypeReading in
                let today = PollenLevel(rawValue: kind.today ?? PollenLevel.none.rawValue)
                return PollenTypeReading(
                    name: name,
                    today: today,
                    tomorrow: PollenLevel(rawValue: kind.tomorrow ?? PollenLevel.none.rawValue),
                    dayAfterTomorrow: PollenLevel(rawValue: kind.dayafterTo ?? PollenLevel.none.rawValue),
                    todayDescription: descriptions[today.rawValue] ?? today.rawValue
                )
            }
            .filter(\.today.isElevated)
            .sorted { $0.today.severityRank > $1.today.severityRank }

        return PollenReading(values: values, stampLabel: "DWD · \(lastUpdate)")
    }
}
