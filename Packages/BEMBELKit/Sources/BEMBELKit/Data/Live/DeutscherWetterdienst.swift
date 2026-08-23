import Foundation

// DWD "POI" surface observations — opendata.dwd.de, no key, no registration,
// GeoNutzV with attribution. One CSV per station, the last 25 hourly reports,
// newest row first:
//
//   https://opendata.dwd.de/weather/weather_reports/poi/10637-BEOB.csv
//
// BEM-G06's brief named Bright Sky and told whoever picked it up to check
// first whether DWD's own data is parseable directly, because a hosted
// third-party service in the critical path is exactly what ADR 0008 rejected
// for the radar. It is: this file is 7 KB of semicolon-separated ASCII from
// DWD itself. Bright Sky stays in `data/sources.json` as a documented
// alternative, and out of the app.
//
// Three header lines, then the rows:
//
//   line 1  surface observations;Parameter description;cloud_cover_total;…
//   line 2  10637;Unit;%;Grad C;…
//   line 3  Datum;Uhrzeit (UTC);Wolkenbedeckung;…      (German labels, unused)
//   line 4+ 23.08.26;18:00;0;---;---;6;42;---;---;19,7;…
//
// Column order is read from line 1 and the unit from line 2, never assumed —
// same rule the RADOLAN header parser follows, and the same trap PEGELONLINE
// set with its cm-vs-metre stations.

/// One station's hourly report, already keyed by DWD's parameter names.
struct PoiReport: Sendable, Equatable {
    /// The report hour. DWD stamps these in UTC and says so in the column
    /// label; the card renders Europe/Berlin.
    let measuredAt: Date
    /// Only the parameters this build reads. `---` cells are absent, not zero.
    let values: [String: Double]
}

/// Parsing rules for the POI CSV. Pure — bytes in, reports out — so the
/// fixtures test the parse without a network or a clock.
enum PoiRules {
    /// DWD's name for the 2 m air temperature, the one the card shows.
    static let temperatureParameter = "dry_bulb_temperature_at_2_meter_above_ground"
    /// What line 2 must say for that column. A station that switched to
    /// Kelvin or Fahrenheit would otherwise render as a plausible number.
    static let temperatureUnit = "Grad C"

    /// The cell DWD writes when a station did not report a parameter that
    /// hour. Distinct from 0, which several of these parameters legitimately
    /// are (sunshine, precipitation).
    static let missingCell = "---"

    enum Failure: Error, Equatable, Sendable {
        /// Fewer than one header block plus one row, or a header line that is
        /// not the one documented above.
        case malformedHeader
        /// The parameter is not among line 1's columns.
        case missingParameter(String)
        /// Line 2 gives that column a unit this build does not read.
        case unexpectedUnit(parameter: String, unit: String)
        /// Every row's cell for the parameter was `---`, or no row parsed.
        case noReading
    }

    /// The whole file, newest report first.
    ///
    /// `parameters` maps a DWD parameter name to the unit this build expects
    /// line 2 to give it. Reading the unit rather than assuming it is what
    /// stops a station that switched scales from rendering as a plausible
    /// number — the same trap PEGELONLINE set with its cm-vs-metre stations.
    ///
    /// Rows arrive newest-first today, and nothing in DWD's documentation
    /// promises they will keep doing so, so the order is re-established here
    /// rather than trusted. Twenty-five rows make that free.
    static func reports(from csv: String, parameters: [String: String]) throws -> [PoiReport] {
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count >= 4 else { throw Failure.malformedHeader }

        let names = lines[0].components(separatedBy: ";")
        let units = lines[1].components(separatedBy: ";")
        // Column 0 is the date and column 1 the time in the data rows; line 1
        // labels those two "surface observations" and "Parameter description".
        guard names.count > 2, units.count == names.count else { throw Failure.malformedHeader }

        var indices: [String: Int] = [:]
        for (parameter, expectedUnit) in parameters {
            guard let index = names.firstIndex(of: parameter) else {
                throw Failure.missingParameter(parameter)
            }
            let unit = units[index].trimmingCharacters(in: .whitespaces)
            guard unit == expectedUnit else {
                throw Failure.unexpectedUnit(parameter: parameter, unit: unit)
            }
            indices[parameter] = index
        }

        return
            lines
            .dropFirst(3)
            .compactMap { row -> PoiReport? in
                let cells = row.components(separatedBy: ";")
                guard cells.count == names.count, let measuredAt = date(from: cells) else { return nil }
                var values: [String: Double] = [:]
                for (parameter, index) in indices {
                    if let value = number(cells[index]) { values[parameter] = value }
                }
                return PoiReport(measuredAt: measuredAt, values: values)
            }
            .sorted { $0.measuredAt > $1.measuredAt }
    }

    /// The newest report that actually carries the parameter. A station can
    /// publish an hour with that cell empty, and the row below it is then the
    /// honest answer — the alternative is a card reading "—" while a perfectly
    /// good measurement sits one line down.
    static func latest(_ reports: [PoiReport], of parameter: String) throws -> (Date, Double) {
        for report in reports {
            if let value = report.values[parameter] { return (report.measuredAt, value) }
        }
        throw Failure.noReading
    }

    /// German decimal comma, and `---` for absent.
    static func number(_ cell: String) -> Double? {
        let trimmed = cell.trimmingCharacters(in: .whitespaces)
        guard trimmed != missingCell, !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    /// `23.08.26;18:00` in UTC.
    static func date(from cells: [String]) -> Date? {
        guard cells.count >= 2 else { return nil }
        let stamp =
            cells[0].trimmingCharacters(in: .whitespaces)
            + " " + cells[1].trimmingCharacters(in: .whitespaces)
        return utcStamp.date(from: stamp)
    }

    // Cached, and pinned to a century: a two-digit year is ambiguous, and
    // Foundation's default window starts in 1950, which would read "26" as
    // 1926 once the default rolls. Both classes are documented thread-safe
    // (same justification as `DateFormatter.berlinClock`).
    private nonisolated(unsafe) static let utcStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd.MM.yy HH:mm"
        var century = DateComponents()
        century.year = 2000
        century.month = 1
        century.day = 1
        formatter.twoDigitStartDate = Calendar(identifier: .gregorian).date(from: century)
        return formatter
    }()
}

/// A DWD POI station, as the app pins it.
public struct PoiStation: Sendable, Equatable {
    /// WMO id — the file is `<id>-BEOB.csv`.
    public let id: String
    /// What the card shows. Short, like `PegelStation.frankfurtOsthafen.name`.
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    /// Frankfurt/Main, WMO 10637 (EDDF) — DWD's only reporting POI station
    /// inside the city. Its two neighbours in the region are Kleiner Feldberg
    /// at 805 m and Offenbach-Wetterpark, both worse answers for "how warm is
    /// Frankfurt".
    ///
    /// Named "Flughafen" on purpose. The thermometer stands on the airfield,
    /// outside the built-up core, and on a hot afternoon it reads cooler than
    /// the Innenstadt — for an app positioned around a city that is getting
    /// hotter, that is the one thing the label must not hide.
    public static let frankfurtAirport = PoiStation(id: "10637", name: "Flughafen")
}

/// Live 2 m air temperature for the Stadtzustand header line.
///
/// Cached behind `Staleness`: DWD publishes one report per hour, so half an
/// hour is the widest window that still cannot hide a whole publication cycle.
/// A failed fetch is an error the caller sees — there is no bundled snapshot
/// to fall back to, and a temperature from some earlier day presented as
/// current is worse than a line that says it does not know.
public actor DWDPoiTemperatureProvider: TemperatureProviding {
    private static let base = URL(string: "https://opendata.dwd.de/weather/weather_reports/poi/")!
    private static let staleness = Staleness(maxAge: 30 * 60)

    private let station: PoiStation
    private let client: HTTPClient
    private var cached: (reading: TemperatureReading, fetchedAt: Date)?

    public init(station: PoiStation = .frankfurtAirport, client: HTTPClient = HTTPClient()) {
        self.station = station
        self.client = client
    }

    public func invalidate() {
        cached = nil
    }

    public func temperature() async throws -> TemperatureReading {
        if let cached, !Self.staleness.isStale(fetchedAt: cached.fetchedAt) {
            return cached.reading
        }
        let url = Self.base.appending(path: "\(station.id)-BEOB.csv")
        let csv = try await client.text(from: url)
        let reading = try Self.reading(station: station, csv: csv)
        cached = (reading, Date())
        return reading
    }

    /// Pure from here down.
    static func reading(station: PoiStation, csv: String) throws -> TemperatureReading {
        let reports = try PoiRules.reports(
            from: csv,
            parameters: [PoiRules.temperatureParameter: PoiRules.temperatureUnit]
        )
        let (measuredAt, celsius) = try PoiRules.latest(reports, of: PoiRules.temperatureParameter)

        return TemperatureReading(
            celsius: celsius,
            celsiusLabel: celsiusFormatter.string(from: celsius as NSNumber) ?? "—",
            stationName: station.name,
            stampLabel: DateFormatter.berlinClock.string(from: measuredAt)
        )
    }

    /// One decimal, German comma — the precision DWD publishes. Rounding to a
    /// whole degree here would throw away the only thing that distinguishes
    /// 19,7 from 20,4 on a heat card.
    private nonisolated(unsafe) static let celsiusFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}
