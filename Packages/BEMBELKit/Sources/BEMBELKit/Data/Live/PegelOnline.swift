import Foundation

// PEGELONLINE (WSV) REST v2. No key, no registration, DL-DE/BY 2.0 with
// attribution. Three endpoints per station, all under
// .../v2/stations/<uuid>/W:
//
//   W.json                    unit + gauge zero — read, never assumed
//   W/currentmeasurement.json the latest value plus WSV's own classification
//   W/measurements.json?…     the series behind the sparkline
//
// `characteristicvalues.json` is empty for Frankfurt Osthafen, so the
// flood/low-water context comes from the classification WSV publishes with the
// reading rather than from marks this app compares against itself.

/// `W.json` — the timeseries description.
struct PegelTimeseries: Decodable, Sendable {
    struct GaugeZero: Decodable, Sendable {
        let unit: String
        let value: Double
    }

    let unit: String
    let gaugeZero: GaugeZero?
}

/// `W/currentmeasurement.json`.
struct PegelCurrentMeasurement: Decodable, Sendable {
    let timestamp: String
    let value: Double
    let stateMnwMhw: String?
    let stateNswHsw: String?
}

/// One row of `W/measurements.json`.
struct PegelMeasurement: Decodable, Sendable {
    let timestamp: String
    let value: Double
}

/// A station's identity, as the app pins it. The uuid is stable; the name is
/// what the card shows.
public struct PegelStation: Sendable {
    public let uuid: String
    public let name: String

    public init(uuid: String, name: String) {
        self.uuid = uuid
        self.name = name
    }

    /// Frankfurt Osthafen, Main km 37.591 — the gauge the Stadtzustand card
    /// has always named.
    public static let frankfurtOsthafen = PegelStation(
        uuid: "66ff3eb4-513b-478b-abd2-2f5126ea66fd",
        name: "Osthafen"
    )
}

/// Turns PEGELONLINE's three responses into one `GaugeReading`. Pure — wire
/// values in, domain out — so the fixtures test the arithmetic and the
/// formatting without a network or a clock.
public enum PegelRules {
    /// Below this the level has not moved enough to call it a direction. Two
    /// centimetres is inside the noise of a river gauge read every 15 minutes.
    public static let steadyThresholdMetres = 0.02

    /// How far back the trend looks. The card says "/ 24 h".
    public static let trendWindow: TimeInterval = 24 * 60 * 60

    /// Points kept for the sparkline. The series arrives every 15 minutes;
    /// drawing 192 of them into 60 points of width is noise, not information.
    public static let sparklinePoints = 12

    /// PEGELONLINE reports most stations in cm and a minority in metres above
    /// a datum (`m+NN`, `m+PNP`). The card renders metres, so the unit decides
    /// the scale — assuming cm would be wrong for 68 of the 738 stations that
    /// answered when this was written.
    static func metres(_ value: Double, unit: String) -> Double? {
        switch unit.lowercased() {
        case "cm": value / 100
        case "m", "m+nn", "m+pnp", "m ü. nhn", "m. ü. nhn": value
        default: nil
        }
    }

    static func trend(currentMetres: Double, earlierMetres: Double?) -> (GaugeTrend, String) {
        guard let earlierMetres else {
            // No comparison point — say nothing rather than imply "steady",
            // which would be a claim about the river.
            return (.steady, "—")
        }
        let delta = currentMetres - earlierMetres
        let centimetres = Int((abs(delta) * 100).rounded())
        let label = "\(centimetres) cm / 24 h"
        if abs(delta) < steadyThresholdMetres {
            return (.steady, label)
        }
        return (delta > 0 ? .rising : .falling, label)
    }

    /// Evenly spaced samples, oldest first, always including the newest — the
    /// sparkline's right edge must be the value the headline shows.
    static func sparkline(from values: [Double], points: Int = sparklinePoints) -> [Double] {
        guard values.count > points, points > 1 else { return values }
        let step = Double(values.count - 1) / Double(points - 1)
        return (0..<points).map { values[Int((Double($0) * step).rounded())] }
    }
}

/// Live Main level for the Stadtzustand card.
///
/// Cached behind `Staleness`: WSV publishes every 15 minutes, so asking more
/// often than that re-reads the same number. A failed fetch is an error the
/// caller sees — unlike the curated datasets there is no bundled snapshot to
/// fall back to, and a stale water level presented as current is worse than
/// none.
public actor PegelOnlineProvider {
    private static let base = URL(string: "https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations/")!
    /// WSV's own equidistance for this station is 15 minutes.
    private static let staleness = Staleness(maxAge: 15 * 60)

    private let station: PegelStation
    private let client: HTTPClient
    private var cached: (reading: GaugeReading, fetchedAt: Date)?

    public init(station: PegelStation = .frankfurtOsthafen, client: HTTPClient = HTTPClient()) {
        self.station = station
        self.client = client
    }

    public enum Failure: Error, Equatable, Sendable {
        /// The station reports a unit this build cannot convert to metres.
        case unsupportedUnit(String)
        case unreadableTimestamp(String)
    }

    public func reading() async throws -> GaugeReading {
        if let cached, !Self.staleness.isStale(fetchedAt: cached.fetchedAt) {
            return cached.reading
        }
        // `.../stations/<uuid>/W.json` describes the series; the readings hang
        // one level deeper under `.../W/`. The query cannot go through
        // `appending(path:)`, which would percent-encode the `?`.
        let root = Self.base.appending(path: station.uuid)
        let measurements = root.appending(path: "W/measurements.json").appending(
            queryItems: [URLQueryItem(name: "start", value: "P7D")]
        )
        // Independent requests — the series is the slow one and must not hold
        // up the headline value.
        async let series = client.get([PegelMeasurement].self, from: measurements)
        async let current = client.get(
            PegelCurrentMeasurement.self, from: root.appending(path: "W/currentmeasurement.json")
        )
        async let timeseries = client.get(PegelTimeseries.self, from: root.appending(path: "W.json"))

        let reading = try Self.reading(
            station: station,
            timeseries: try await timeseries,
            current: try await current,
            series: try await series
        )
        cached = (reading, Date())
        return reading
    }

    /// Pure from here down, which is what makes the fixture tests meaningful.
    static func reading(
        station: PegelStation,
        timeseries: PegelTimeseries,
        current: PegelCurrentMeasurement,
        series: [PegelMeasurement]
    ) throws -> GaugeReading {
        guard let currentMetres = PegelRules.metres(current.value, unit: timeseries.unit) else {
            throw Failure.unsupportedUnit(timeseries.unit)
        }
        guard let measuredAt = ISO8601DateFormatter.pegel.date(from: current.timestamp) else {
            throw Failure.unreadableTimestamp(current.timestamp)
        }

        let dated = series.compactMap { row -> (Date, Double)? in
            guard
                let date = ISO8601DateFormatter.pegel.date(from: row.timestamp),
                let metres = PegelRules.metres(row.value, unit: timeseries.unit)
            else { return nil }
            return (date, metres)
        }
        .sorted { $0.0 < $1.0 }

        // The sample nearest to 24 h before the current reading, and only if
        // the series actually reaches back that far — a two-hour-old series
        // must not be labelled a 24-hour trend.
        let target = measuredAt.addingTimeInterval(-PegelRules.trendWindow)
        let earliest = dated.first?.0
        let earlier =
            (earliest.map { $0 <= target } ?? false)
            ? dated.min(by: { abs($0.0.timeIntervalSince(target)) < abs($1.0.timeIntervalSince(target)) })?.1
            : nil

        let (trend, trendLabel) = PegelRules.trend(currentMetres: currentMetres, earlierMetres: earlier)

        return GaugeReading(
            levelLabel: Self.levelFormatter.string(from: currentMetres as NSNumber) ?? "—",
            trendLabel: trendLabel,
            trend: trend,
            stationName: station.name,
            stampLabel: Self.clock.string(from: measuredAt),
            history: PegelRules.sparkline(from: dated.map(\.1)),
            stateMnwMhw: current.stateMnwMhw.map(GaugeState.init(rawValue:)) ?? .unknown,
            stateNswHsw: current.stateNswHsw.map(GaugeState.init(rawValue:)) ?? .unknown
        )
    }

    // Cached: formatter construction dominates this parse, same finding as the
    // bembel-data decoder. Both classes are documented thread-safe; they just
    // predate Sendable (same justification as AppGroup.defaults).
    private nonisolated(unsafe) static let levelFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private nonisolated(unsafe) static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

extension ISO8601DateFormatter {
    /// PEGELONLINE stamps `2026-08-15T12:30:00+02:00` — offset, no fractional
    /// seconds.
    nonisolated(unsafe) static let pegel: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
