import Foundation

// DWD RADOLAN **RY** — the observation product, five minutes apart, roughly two
// days deep:
//
//   https://opendata.dwd.de/weather/radar/radolan/ry/raa01-ry_10000-2608240615-dwd---bin.bz2
//
// One file per frame, classic RADOLAN binary inside bzip2 — both of which this
// client already reads (BEM-F01). What it is *not* is the same grid as RV:
// the header says `GP 900x 900`, so these frames live on
// `RadolanGrid.radolan900` and are resampled onto the same `RadarBounds` as the
// forecast, which is what makes past and future frames interchangeable to the
// view (BEM-F03).

/// Builds the RY URLs for the recent past and turns them into frames.
enum RadolanObservations {
    static let base = URL(string: "https://opendata.dwd.de/weather/radar/radolan/ry/")!

    /// DWD publishes RY every five minutes.
    static let stepMinutes = 5

    /// How far back the timeline reaches. **One hour, not two.**
    ///
    /// Each frame is a separate request, against a public service, every five
    /// minutes, per user — where the whole forecast is one tar archive. Two
    /// hours would double that for a question the last hour already answers:
    /// is the shower coming towards me or leaving. A constant so the number
    /// stays a decision rather than becoming an assumption.
    static let frameCount = 12

    /// The most recent frame DWD can be expected to have published.
    ///
    /// Rounded **down** to a five-minute boundary and then backed off by one
    /// step: a composite is not on the server the instant its timestamp says,
    /// and asking for it produces a 404 rather than a wait.
    static func latestStamp(now: Date, calendar: Calendar = utcCalendar) -> Date {
        let minute = calendar.component(.minute, from: now)
        let flooredMinute = minute - (minute % stepMinutes)
        var parts = calendar.dateComponents([.year, .month, .day, .hour], from: now)
        parts.minute = flooredMinute
        parts.second = 0
        let floored = calendar.date(from: parts) ?? now
        return floored.addingTimeInterval(TimeInterval(-stepMinutes * 60))
    }

    /// Frame timestamps, oldest first, ending at `latestStamp`.
    static func stamps(now: Date, count: Int = frameCount, calendar: Calendar = utcCalendar) -> [Date] {
        let latest = latestStamp(now: now, calendar: calendar)
        return (0..<count)
            .map { latest.addingTimeInterval(TimeInterval(-$0 * stepMinutes * 60)) }
            .reversed()
    }

    /// `raa01-ry_10000-2608240615-dwd---bin.bz2` — the stamp is UTC, and the
    /// year is two digits, which is DWD's habit throughout.
    static func url(for stamp: Date) -> URL {
        base.appending(path: "raa01-ry_10000-\(fileStamp.string(from: stamp))-dwd---bin.bz2")
    }

    /// Minutes from the reference instant, negative because these are the past.
    /// Rounded to the five-minute step so a frame lands on a tick rather than
    /// at −4 or −6 because of a second's drift in the clock.
    static func offsetMinutes(of stamp: Date, from reference: Date) -> Int {
        let raw = stamp.timeIntervalSince(reference) / 60
        return Int((raw / Double(stepMinutes)).rounded()) * stepMinutes
    }

    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    private nonisolated(unsafe) static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyMMddHHmm"
        return formatter
    }()

    /// One downloaded frame, decompressed, parsed and resampled.
    ///
    /// Throws only for the caller to drop this one frame. A missing or
    /// malformed observation costs its own tick on the timeline and nothing
    /// else — twelve separate requests fail in ways one tar archive does not,
    /// and the forecast must survive all of them.
    static func frame(from archive: Data, minute: Int, bounds: RadarBounds) throws -> RadarFrame {
        let composite = try RadolanComposite(data: try BZip2.decompress(archive))
        return try frame(from: composite, minute: minute, bounds: bounds)
    }

    /// Split from the download so the geometry guard can be tested against a
    /// composite this repo already has, rather than needing a bzip2 *encoder*
    /// that nothing else would ever use.
    static func frame(
        from composite: RadolanComposite, minute: Int, bounds: RadarBounds
    ) throws
        -> RadarFrame
    {
        // The header states its own geometry. A frame that is not 900×900 is
        // not the product this grid describes, and drawing it would put rain
        // in the wrong country rather than fail.
        guard
            composite.rows == RadolanGrid.radolan900.rows,
            composite.columns == RadolanGrid.radolan900.columns
        else {
            throw Failure.unexpectedGeometry(rows: composite.rows, columns: composite.columns)
        }
        let frame = RadolanResampler.frame(from: composite, grid: .radolan900, bounds: bounds)
        return RadarFrame(
            minute: minute, width: frame.width, height: frame.height, millimetres: frame.millimetres)
    }

    enum Failure: Error, Equatable, Sendable {
        case unexpectedGeometry(rows: Int, columns: Int)
    }
}
