import CoreLocation
import Foundation

/// Turns a stack of RADOLAN grids into the one sentence the user wants.
/// Pure — a series in, a nowcast out — so the phrasing rules are testable
/// without a network or a clock.
public enum RadarNowcastRules {
    /// Below this, the radar is seeing drizzle the user would not call rain.
    /// 0.1 mm per five minutes is 1.2 mm/h.
    public static let rainThreshold = 0.1

    public static func intensity(_ millimetres: Double) -> String {
        switch millimetres {
        case ..<0.5: "leicht"
        case ..<2.0: "mäßig"
        default: "stark"
        }
    }

    public static func nowcast(
        series: [RadarSample],
        measuredAt: Date?,
        now: Date,
        timeZone: TimeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
    ) -> RadarNowcast {
        var clock = DateFormatter()
        clock.locale = Locale(identifier: "de_DE")
        clock.timeZone = timeZone
        clock.dateFormat = "HH:mm"

        let wet = series.filter { ($0.millimetres ?? 0) >= rainThreshold }
        let headline: String
        let detail: String

        if let first = wet.first, first.minute == 0 {
            let run = consecutiveRun(from: series, startingAt: 0)
            headline = "Regen jetzt"
            detail =
                run.minutes >= series.last?.minute ?? 0
                ? "\(intensity(run.peak)), hält die nächsten zwei Stunden an"
                : "\(intensity(run.peak)), noch etwa \(run.minutes) Minuten"
        } else if let first = wet.first {
            let run = consecutiveRun(from: series, startingAt: first.minute)
            headline = "Regen in \(first.minute) Min"
            detail = "\(intensity(run.peak)), etwa \(run.minutes) Minuten lang"
        } else {
            headline = "Kein Regen"
            let horizon = series.last?.minute ?? 0
            detail = horizon > 0 ? "in den nächsten \(horizon) Minuten" : "keine Radardaten"
        }

        return RadarNowcast(
            headline: headline,
            detail: detail,
            clockLabel: clock.string(from: now),
            stampLabel: measuredAt.map(clock.string(from:)) ?? "—",
            // The view's axis runs −60…+90; the composite starts at now, so the
            // playhead sits where "now" falls on that axis. BEM-F02 owns making
            // the axis match the data it actually has.
            progress: 60.0 / 150.0,
            series: series,
            measuredAt: measuredAt,
            attribution: "Datenbasis: Deutscher Wetterdienst (RADOLAN RV, GeoNutzV)"
        )
    }

    /// How long the rain lasts from `minute`, and how hard it gets, stopping at
    /// the first dry step. A shower that stops and starts again is two showers
    /// to somebody deciding whether to leave now.
    private static func consecutiveRun(
        from series: [RadarSample], startingAt minute: Int
    )
        -> (minutes: Int, peak: Double)
    {
        var peak = 0.0
        var last = minute
        for sample in series where sample.minute >= minute {
            guard let value = sample.millimetres, value >= rainThreshold else { break }
            peak = max(peak, value)
            last = sample.minute
        }
        return (max(5, last - minute + 5), peak)
    }
}

/// Live rain radar: DWD's RV nowcast composite, parsed on device.
///
/// ADR 0008 chose this over the Bright Sky wrapper — a hosted service in the
/// critical path is exactly what a no-backend app must not have. The archive is
/// ~130 KB for 25 frames covering the next two hours in five-minute steps.
public actor RadolanRadarProvider: RadarProviding {
    /// DWD refreshes RV every five minutes; asking more often than that only
    /// re-downloads the same archive.
    private static let staleness = Staleness(maxAge: 5 * 60)
    public static let latestURL = URL(
        string: "https://opendata.dwd.de/weather/radar/composite/rv/DE1200_RV_LATEST.tar.bz2"
    )!

    private let url: URL
    private let session: URLSession
    private let coordinate: CLLocationCoordinate2D
    private let grid: RadolanGrid
    private var cached: (nowcast: RadarNowcast, fetchedAt: Date)?

    public init(
        url: URL = RadolanRadarProvider.latestURL,
        coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821),
        grid: RadolanGrid = .de1200,
        session: URLSession = .shared
    ) {
        self.url = url
        self.coordinate = coordinate
        self.grid = grid
        self.session = session
    }

    public enum Failure: Error, Equatable, Sendable {
        case transport
        case status(Int)
        case unreadableArchive
        /// The coordinate is outside the composite — the app is regional, but
        /// the grid is national, so this should never fire in Rhein-Main.
        case outsideGrid
        case noUsableFrames
    }

    public func nowcast() async throws -> RadarNowcast {
        if let cached, !Self.staleness.isStale(fetchedAt: cached.fetchedAt) {
            return cached.nowcast
        }
        let archive = try await download()
        let nowcast = try Self.nowcast(fromArchive: archive, at: coordinate, grid: grid, now: Date())
        cached = (nowcast, Date())
        return nowcast
    }

    private func download() async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw Failure.transport
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw Failure.status(http.statusCode)
        }
        return data
    }

    /// Pure from here down, which is what makes the fixture test meaningful:
    /// bytes in, nowcast out, no clock and no network.
    public static func nowcast(
        fromArchive archive: Data,
        at coordinate: CLLocationCoordinate2D,
        grid: RadolanGrid = .de1200,
        now: Date
    ) throws -> RadarNowcast {
        let tar: Data
        do {
            tar = try BZip2.decompress(archive)
        } catch {
            throw Failure.unreadableArchive
        }
        guard let cell = grid.cell(for: coordinate) else { throw Failure.outsideGrid }

        var samples: [RadarSample] = []
        var measuredAt: Date?
        for entry in TarArchive.entries(in: tar) {
            // One malformed frame costs that frame, never the whole nowcast.
            guard let composite = try? RadolanComposite(data: entry.data) else { continue }
            if measuredAt == nil { measuredAt = composite.measuredAt }
            samples.append(
                RadarSample(
                    minute: composite.forecastMinute,
                    millimetres: composite.peak(row: cell.row, column: cell.column)
                )
            )
        }
        guard !samples.isEmpty else { throw Failure.noUsableFrames }
        samples.sort { $0.minute < $1.minute }
        return RadarNowcastRules.nowcast(series: samples, measuredAt: measuredAt, now: now)
    }
}
