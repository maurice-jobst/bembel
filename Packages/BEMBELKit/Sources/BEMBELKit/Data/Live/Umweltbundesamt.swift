import CoreLocation
import Foundation

// Umweltbundesamt Luftdaten API v3. No key, DL-DE/BY 2.0. The Hessen network
// in it *is* HLNUG's Luftmessnetz — UBA publishes the Länder networks, and
// HLNUG has no machine-readable endpoint of its own (2026-08-19 sweep). So the
// card keeps naming HLNUG's station while reading UBA's API.
//
// Three endpoints, three very different weights:
//
//   components/json    847 bytes. The pollutant vocabulary: id → symbol, unit.
//   stations/json      92 KB. Every active station in Germany, with coordinates.
//   airquality/json    a few KB per station-day. Hourly index plus components.
//
// Four facts that cost a live probe each:
//
//   * The documented host is a redirect. `umweltbundesamt.de/api/air_data/v3`
//     answers 301 to `luftdaten.umweltbundesamt.de/api/air-data/v3` — different
//     host, and an underscore that became a hyphen. Follow it once here rather
//     than paying a redirect on every call.
//   * `airquality/json` **without** a `station` parameter times out. It is not
//     slow, it does not answer: 40 s and zero bytes. Always name a station.
//   * `network=…` on `stations/json` is ignored, silently. Asking for Hessen
//     returns all 405 active stations, so the filtering is ours to do.
//   * The `data_incomplete` flag means "not every component the full index
//     wants is present", not "this reading is bad". Every Verkehr station
//     trips it, because they do not measure ozone. Dropping incomplete rows
//     would leave Frankfurt Friedberger Landstraße permanently blank.

/// One measuring station, as `stations/json` describes it.
public struct UBAStation: Sendable, Hashable {
    public let id: String
    /// EU station code — `DEHE008` for Frankfurt Ost.
    public let code: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    /// The Land network that runs it: "Hessen" is HLNUG.
    public let networkName: String
    /// "Hintergrund" or "Verkehr". A kerbside station and a background station
    /// a kilometre apart legitimately disagree, so the card names it.
    public let typeName: String

    public init(
        id: String,
        code: String,
        name: String,
        latitude: Double,
        longitude: Double,
        networkName: String,
        typeName: String
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.networkName = networkName
        self.typeName = typeName
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Frankfurt Ost (DEHE008), the urban background station the card has
    /// always named. The fallback when there is no fix to be nearest to.
    public static let frankfurtOst = UBAStation(
        id: "636",
        code: "DEHE008",
        name: "Frankfurt Ost",
        latitude: 50.1253,
        longitude: 8.7463,
        networkName: "Hessen",
        typeName: "Hintergrund"
    )
}

/// UBA answers every endpoint as an object of positional arrays plus an
/// `indices` array naming the columns. Decoding it as a shape is not possible,
/// so these two types carry the raw JSON and the rules below read it by name.
struct UBATable: Decodable, Sendable {
    let indices: [String]
    let data: [String: [UBAField]]
}

/// `airquality/json` nests one level deeper than the other endpoints: station
/// id → hour → row. Its own type rather than a generic one, because the
/// difference is exactly the sort of thing a `[String: Any]` would swallow.
struct UBAAirQualityTable: Decodable, Sendable {
    let data: [String: [String: [UBAField]]]
}

/// `components/json` is a third shape again: no `data` wrapper at all, the
/// rows sit at the top level beside `count` and `indices`. Three endpoints of
/// one API, three envelopes — which is exactly why each one is decoded as the
/// shape it actually is rather than through a shared guess.
struct UBAFlatTable: Decodable, Sendable {
    let indices: [String]
    let data: [String: [UBAField]]

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { Int(stringValue) }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { stringValue = String(intValue) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        indices = try container.decode([String].self, forKey: AnyKey(stringValue: "indices"))
        var rows = [String: [UBAField]]()
        for key in container.allKeys where key.intValue != nil {
            rows[key.stringValue] = try container.decode([UBAField].self, forKey: key)
        }
        data = rows
    }
}

/// One cell. UBA mixes strings, numbers and nulls inside a single column —
/// `station id` is `"636"` in one endpoint and `636` in another — so the
/// decoder has to accept all three rather than trust the first sample.
enum UBAField: Decodable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case null
    /// The component tuples nested inside an `airquality` row.
    case list([UBAField])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([UBAField].self) {
            self = .list(value)
        } else {
            self = .null
        }
    }

    var text: String? {
        switch self {
        case .string(let value): value
        case .number(let value): value == value.rounded() ? String(Int(value)) : String(value)
        case .null, .list: nil
        }
    }

    var double: Double? {
        switch self {
        case .string(let value): Double(value)
        case .number(let value): value
        case .null, .list: nil
        }
    }

    var int: Int? { double.map { Int($0.rounded()) } }

    var items: [UBAField]? {
        if case .list(let values) = self { return values }
        return nil
    }
}

/// Wire values in, card content out. Pure, so the fixtures pin the parts that
/// are easy to get subtly wrong — which row is the newest, and how a band and
/// a within-band fraction combine into one bar.
public enum UBARules {
    /// Beyond this the stored station is far enough that a nearer one probably
    /// exists and is worth the 92 KB to look for. Inside it, the choice
    /// stands — which is what keeps a Frankfurt user from downloading every
    /// station in Germany on every cold launch.
    public static let restickDistanceMetres: CLLocationDistance = 5_000

    static func stations(from table: UBATable) -> [UBAStation] {
        let column = Dictionary(uniqueKeysWithValues: table.indices.enumerated().map { ($1, $0) })
        func field(_ row: [UBAField], _ name: String) -> UBAField? {
            column[name].flatMap { $0 < row.count ? row[$0] : nil }
        }
        return table.data.values.compactMap { row -> UBAStation? in
            guard
                let id = field(row, "station id")?.text,
                let code = field(row, "station code")?.text,
                let name = field(row, "station name")?.text,
                let latitude = field(row, "station latitude")?.double,
                let longitude = field(row, "station longitude")?.double
            else { return nil }
            return UBAStation(
                id: id,
                code: code,
                name: name,
                latitude: latitude,
                longitude: longitude,
                networkName: field(row, "network name")?.text ?? "",
                typeName: field(row, "station type name")?.text ?? ""
            )
        }
        // The wire order is a dictionary's, which is no order at all. Sorting
        // by id makes "nearest" deterministic when two stations tie.
        .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    /// The pollutant vocabulary: component id → (symbol, unit).
    static func components(from table: UBAFlatTable) -> [String: (symbol: String, unit: String)] {
        let column = Dictionary(uniqueKeysWithValues: table.indices.enumerated().map { ($1, $0) })
        func field(_ row: [UBAField], _ name: String) -> String? {
            column[name].flatMap { $0 < row.count ? row[$0].text : nil }
        }
        var vocabulary = [String: (symbol: String, unit: String)]()
        for row in table.data.values {
            guard let id = field(row, "component id"), let symbol = field(row, "component symbol") else { continue }
            vocabulary[id] = (symbol, field(row, "component unit") ?? "")
        }
        return vocabulary
    }

    static func nearest(_ stations: [UBAStation], to coordinate: CLLocationCoordinate2D?) -> UBAStation? {
        guard let coordinate else { return nil }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return stations.min {
            origin.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                < origin.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }
    }

    static func metres(from coordinate: CLLocationCoordinate2D, to station: UBAStation) -> CLLocationDistance {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            .distance(from: CLLocation(latitude: station.latitude, longitude: station.longitude))
    }

    /// One bar's fill, 0…1, across the whole five-band scale.
    ///
    /// UBA's `y` is the value's position *inside* its own band — 38 µg/m³ of
    /// ozone is 0.63 of "sehr gut" and 121 is 0.67 of "mäßig". Drawn as-is
    /// those two bars are the same length, which is the opposite of what the
    /// reader needs. Folding the band back in restores the ordering.
    ///
    /// The top band is open-ended, so `y` there can exceed 1; the result is
    /// clamped rather than allowed to overflow the capsule.
    static func fraction(band: Int?, y: Double?) -> Double {
        guard let band else { return 0 }
        // No `y` means the band is all we know: draw its middle rather than
        // its edge, which would claim precision the row does not have.
        let within = y ?? 0.5
        return min(1, max(0, (Double(band) + within) / 5))
    }

    /// The newest hour in an `airquality` response for one station.
    ///
    /// Keys are `"YYYY-MM-DD HH:MM:SS"` in local CET, which sort correctly as
    /// strings — no date parsing needed to find the latest, and none wanted:
    /// a parse failure must not be able to hide the current reading.
    static func newestHour(_ hours: [String: [UBAField]]) -> (key: String, row: [UBAField])? {
        hours.max { $0.key < $1.key }.map { (key: $0.key, row: $0.value) }
    }
}

/// Live air quality for the Stadtzustand card.
public actor UBAAirQualityProvider: AirQualityProviding {
    private static let base = URL(string: "https://luftdaten.umweltbundesamt.de/api/air-data/v3/")!
    /// UBA publishes hourly means; asking more often re-reads the same hour.
    private static let staleness = Staleness(maxAge: 20 * 60)

    private let client: HTTPClient
    private let defaults: UserDefaults
    private var stations: [UBAStation]?
    private var vocabulary: [String: (symbol: String, unit: String)]?
    private var cached: (stationID: String, quality: AirQuality, fetchedAt: Date)?

    public init(client: HTTPClient = HTTPClient(), defaults: UserDefaults = AppGroup.defaults) {
        self.client = client
        self.defaults = defaults
    }

    public enum Failure: Error, Equatable, Sendable {
        /// The station answered, but with no hour in the window at all.
        case noReading(station: String)
    }

    public func airQuality(near coordinate: CLLocationCoordinate2D?) async throws -> AirQuality {
        let station = try await resolveStation(near: coordinate)
        if let cached, cached.stationID == station.id, !Self.staleness.isStale(fetchedAt: cached.fetchedAt) {
            return cached.quality
        }

        async let vocabularyTask = loadVocabulary()
        let table = try await client.get(UBAAirQualityTable.self, from: Self.airQualityURL(station: station.id))
        let vocabulary = await vocabularyTask

        guard
            let hours = table.data[station.id],
            let newest = UBARules.newestHour(hours)
        else {
            throw Failure.noReading(station: station.code)
        }

        let quality = Self.quality(
            station: station,
            hourKey: newest.key,
            row: newest.row,
            vocabulary: vocabulary
        )
        cached = (station.id, quality, Date())
        return quality
    }

    /// Pure from here down.
    static func quality(
        station: UBAStation,
        hourKey: String,
        row: [UBAField],
        vocabulary: [String: (symbol: String, unit: String)]
    ) -> AirQuality {
        // Row layout: [end stamp, total index, incomplete flag, component…].
        let index = AirIndex(uba: row.count > 1 ? row[1].int : nil)
        let values = row.dropFirst(3).compactMap { field -> AirValue? in
            guard let cells = field.items, cells.count >= 3, let componentID = cells[0].text else { return nil }
            let component = vocabulary[componentID]
            let band = AirIndex(uba: cells[2].int)
            let reading = cells[1].double
            return AirValue(
                name: component?.symbol ?? componentID,
                readingLabel: Self.readingLabel(reading, unit: component?.unit ?? ""),
                fraction: UBARules.fraction(band: band.band, y: cells.count > 3 ? cells[3].double : nil),
                index: band
            )
        }
        return AirQuality(
            values: values,
            index: index,
            stationName: station.name,
            stampLabel: Self.stampLabel(station: station, hourKey: hourKey)
        )
    }

    static func readingLabel(_ value: Double?, unit: String) -> String {
        guard let value else { return "—" }
        let number = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    /// "HLNUG Frankfurt Ost (Hintergrund) · 13:00".
    ///
    /// The network, not the API operator: the reading is HLNUG's, UBA only
    /// publishes it. The station type is in there because a Verkehr station
    /// reads differently from a Hintergrund one by design, and a user standing
    /// beside a quiet park deserves to know which one they are looking at.
    static func stampLabel(station: UBAStation, hourKey: String) -> String {
        let network = station.networkName == "Hessen" ? "HLNUG" : station.networkName
        let name = station.typeName.isEmpty ? station.name : "\(station.name) (\(station.typeName))"
        let clock = hourKey.split(separator: " ").last.map { $0.prefix(5) }.map(String.init)
        return [network.isEmpty ? nil : network, name, clock].compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: - Station resolution

    /// Which station to read, without downloading Germany every launch.
    ///
    /// The chosen station is remembered — its id, name and coordinates, which
    /// are public facts about a measuring post, never the user's position.
    /// `UserLocation` promises it stores nothing, and that promise holds here:
    /// the fix is compared against the stored station and then dropped.
    private func resolveStation(near coordinate: CLLocationCoordinate2D?) async throws -> UBAStation {
        let remembered = StationStore(defaults: defaults).station
        guard let coordinate else { return remembered ?? .frankfurtOst }
        if let remembered, UBARules.metres(from: coordinate, to: remembered) <= UBARules.restickDistanceMetres {
            return remembered
        }

        let stations = try await loadStations()
        guard let nearest = UBARules.nearest(stations, to: coordinate) else {
            return remembered ?? .frankfurtOst
        }
        StationStore(defaults: defaults).station = nearest
        return nearest
    }

    private func loadStations() async throws -> [UBAStation] {
        if let stations { return stations }
        let table = try await client.get(UBATable.self, from: Self.stationsURL(), timeout: 30)
        let stations = UBARules.stations(from: table)
        self.stations = stations
        return stations
    }

    /// 847 bytes, and a failure here costs symbols, not readings — so it
    /// degrades to the raw component ids rather than failing the card.
    private func loadVocabulary() async -> [String: (symbol: String, unit: String)] {
        if let vocabulary { return vocabulary }
        guard
            let table = try? await client.get(
                UBAFlatTable.self, from: Self.base.appending(path: "components/json"))
        else {
            return [:]
        }
        let vocabulary = UBARules.components(from: table)
        self.vocabulary = vocabulary
        return vocabulary
    }

    // MARK: - URLs

    /// Yesterday and today. At half past midnight "today" holds no hour yet,
    /// and a card that goes blank for an hour every night would be a bug
    /// nobody is awake to notice.
    static func airQualityURL(station: String, now: Date = Date()) -> URL {
        let today = Self.day.string(from: now)
        let yesterday = Self.day.string(from: now.addingTimeInterval(-24 * 60 * 60))
        return base.appending(path: "airquality/json").appending(queryItems: [
            URLQueryItem(name: "date_from", value: yesterday),
            URLQueryItem(name: "time_from", value: "1"),
            URLQueryItem(name: "date_to", value: today),
            URLQueryItem(name: "time_to", value: "24"),
            URLQueryItem(name: "station", value: station),
            URLQueryItem(name: "lang", value: "de"),
        ])
    }

    static func stationsURL(now: Date = Date()) -> URL {
        let today = Self.day.string(from: now)
        return base.appending(path: "stations/json").appending(queryItems: [
            URLQueryItem(name: "use", value: "airquality"),
            URLQueryItem(name: "lang", value: "de"),
            URLQueryItem(name: "date_from", value: today),
            URLQueryItem(name: "time_from", value: "1"),
            URLQueryItem(name: "date_to", value: today),
            URLQueryItem(name: "time_to", value: "24"),
        ])
    }

    // Cached: same finding as the other live clients, and both classes are
    // documented thread-safe.
    private nonisolated(unsafe) static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// Where the chosen station is remembered between launches.
///
/// Facts about a measuring post — id, code, name, coordinates — and nothing
/// about the person reading it. Kept behind a `Sendable` type for the same
/// reason `RefreshClock` is: a synchronous actor initializer is isolated, so
/// the shared suite can never be handed to an actor directly.
struct StationStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private static let key = "air.station"

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    var station: UBAStation? {
        get {
            guard let raw = defaults.array(forKey: Self.key) as? [String], raw.count == 7,
                let latitude = Double(raw[3]), let longitude = Double(raw[4])
            else { return nil }
            return UBAStation(
                id: raw[0], code: raw[1], name: raw[2],
                latitude: latitude, longitude: longitude,
                networkName: raw[5], typeName: raw[6]
            )
        }
        nonmutating set {
            guard let newValue else {
                defaults.removeObject(forKey: Self.key)
                return
            }
            defaults.set(
                [
                    newValue.id, newValue.code, newValue.name,
                    String(newValue.latitude), String(newValue.longitude),
                    newValue.networkName, newValue.typeName,
                ],
                forKey: Self.key
            )
        }
    }
}
