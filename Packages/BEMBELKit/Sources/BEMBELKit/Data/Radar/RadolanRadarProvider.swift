import CoreLocation
import Foundation

/// Turns a stack of RADOLAN grids into the one sentence the user wants.
/// Pure — a series in, a nowcast out — so the phrasing rules are testable
/// without a network or a clock.
public enum RadarNowcastRules {
    /// Below this, the radar is seeing drizzle the user would not call rain.
    /// 0.1 mm per five minutes is 1.2 mm/h.
    public static let rainThreshold = 0.1

    public static func intensity(_ millimetres: Double) -> RainIntensity {
        switch millimetres {
        case ..<0.5: .light
        case ..<2.0: .moderate
        default: .heavy
        }
    }

    public static func outlook(series: [RadarSample]) -> RainOutlook {
        let horizon = series.last?.minute ?? 0
        guard series.contains(where: { $0.millimetres != nil }) else { return .noData }

        let wet = series.filter { ($0.millimetres ?? 0) >= rainThreshold }
        guard let first = wet.first else { return .dry(horizonMinutes: horizon) }

        let run = consecutiveRun(from: series, startingAt: first.minute)
        if first.minute == 0 {
            // Rain that runs off the end of the composite is not "two more
            // hours" — it is the edge of what the radar can see.
            let remaining = run.lastMinute >= horizon ? nil : run.minutes
            return .rainingNow(intensity: intensity(run.peak), minutesRemaining: remaining)
        }
        return .rainStarting(
            inMinutes: first.minute,
            intensity: intensity(run.peak),
            lastingMinutes: run.minutes
        )
    }

    public static func nowcast(
        series: [RadarSample],
        frames: [RadarFrame] = [],
        bounds: RadarBounds = .rheinMain,
        measuredAt: Date?
    ) -> RadarNowcast {
        RadarNowcast(
            outlook: outlook(series: series),
            series: series,
            frames: frames,
            bounds: bounds,
            measuredAt: measuredAt,
            stampLabel: measuredAt.map(DateFormatter.berlinClock.string(from:)) ?? "—",
            attribution: "Datenbasis: Deutscher Wetterdienst (RADOLAN RV, GeoNutzV)"
        )
    }

    /// How long the rain lasts from `minute`, and how hard it gets, stopping at
    /// the first dry step. A shower that stops and starts again is two showers
    /// to somebody deciding whether to leave now.
    private static func consecutiveRun(
        from series: [RadarSample], startingAt minute: Int
    )
        -> (minutes: Int, lastMinute: Int, peak: Double)
    {
        var peak = 0.0
        var last = minute
        for sample in series where sample.minute >= minute {
            guard let value = sample.millimetres, value >= rainThreshold else { break }
            peak = max(peak, value)
            last = sample.minute
        }
        return (max(5, last - minute + 5), last, peak)
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
    private let bounds: RadarBounds
    private var cached: (nowcast: RadarNowcast, fetchedAt: Date)?

    public init(
        url: URL = RadolanRadarProvider.latestURL,
        coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821),
        grid: RadolanGrid = .de1200,
        /// Which slice of the national composite gets resampled for drawing.
        /// Injectable because verifying the overlay means pointing it at wherever
        /// it is actually raining, which on most days is not Frankfurt.
        bounds: RadarBounds = .rheinMain,
        session: URLSession = .shared
    ) {
        self.url = url
        self.coordinate = coordinate
        self.grid = grid
        self.bounds = bounds
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
        let forecast = try Self.nowcast(
            fromArchive: archive, at: coordinate, grid: grid, bounds: bounds)
        // The past is a bonus, never a precondition (BEM-F03). Twelve separate
        // requests fail in ways one tar archive does not, and none of those
        // ways may cost the forecast.
        let past = await observations(before: forecast.measuredAt ?? Date())
        let nowcast = forecast.prepending(past)
        cached = (nowcast, Date())
        return nowcast
    }

    /// The last hour of RY observations, oldest first. Frames that do not
    /// arrive are simply absent — a shorter axis, not a failure.
    private func observations(before reference: Date) async -> [RadarFrame] {
        let stamps = RadolanObservations.stamps(now: reference)
        return await withTaskGroup(of: RadarFrame?.self) { group in
            for stamp in stamps {
                let minute = RadolanObservations.offsetMinutes(of: stamp, from: reference)
                // Only the past belongs here. A clock that has drifted forward
                // must not push an observation onto the forecast's ticks.
                guard minute < 0 else { continue }
                let url = RadolanObservations.url(for: stamp)
                let session = session
                let bounds = bounds
                group.addTask {
                    guard
                        let (data, response) = try? await session.data(from: url),
                        (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false
                    else { return nil }
                    return try? RadolanObservations.frame(
                        from: data, minute: minute, bounds: bounds)
                }
            }
            var frames: [RadarFrame] = []
            for await frame in group {
                if let frame { frames.append(frame) }
            }
            return frames.sorted { $0.minute < $1.minute }
        }
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
        bounds: RadarBounds = .rheinMain
    ) throws -> RadarNowcast {
        let tar: Data
        do {
            tar = try BZip2.decompress(archive)
        } catch {
            throw Failure.unreadableArchive
        }
        guard let cell = grid.cell(for: coordinate) else { throw Failure.outsideGrid }

        var samples: [RadarSample] = []
        var frames: [RadarFrame] = []
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
            // Resampled here and the composite dropped immediately: a national
            // grid is 1100×1200 doubles, and holding 25 of them to draw a
            // Rhein-Main box would be ~260 MB for 1.6 MB of pixels.
            frames.append(RadolanResampler.frame(from: composite, grid: grid, bounds: bounds))
        }
        guard !samples.isEmpty else { throw Failure.noUsableFrames }
        samples.sort { $0.minute < $1.minute }
        frames.sort { $0.minute < $1.minute }
        return RadarNowcastRules.nowcast(
            series: samples, frames: frames, bounds: bounds, measuredAt: measuredAt)
    }
}
