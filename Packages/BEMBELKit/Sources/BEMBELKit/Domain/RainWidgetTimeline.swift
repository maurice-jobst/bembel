import Foundation

/// What the rain widget shows at one moment. Data, not a sentence — the widget
/// words it, the way the Radar tab words a `RainOutlook`.
public enum RainWidgetState: Sendable, Equatable {
    /// The forecast re-read from this entry's own time: "Regen in 10 Min" at
    /// 11:05 is "Regen in 5 Min" at 11:10, without a new download.
    case forecast(RainOutlook, measuredAt: Date)
    /// The newest forecast is too old to say anything about now. "Trocken"
    /// from an hour ago is not a softer truth, it is a wrong one.
    case stale(measuredAt: Date?)
    /// Nothing arrived at all — offline, or DWD did not answer.
    case unavailable
}

/// The widget's timeline as a rule, so it is tested here and not in a view.
///
/// One download buys a whole timeline: the composite already says what each
/// five-minute step brings, so every entry re-reads the same series from its
/// own position instead of asking the network again (ADR 0011).
public enum RainWidgetTimeline {
    /// RV's own step; entries finer than this would repeat themselves.
    public static let step: TimeInterval = 5 * 60
    /// Past this a forecast is a record, not a forecast.
    public static let maxAge: TimeInterval = 60 * 60
    /// How often WidgetKit is asked for a fresh download. Half the lifetime of
    /// a forecast, so a widget that gets its reload on time never goes stale,
    /// and ~48 reloads a day stays inside the budget WidgetKit hands out.
    public static let reloadInterval: TimeInterval = 30 * 60
    /// After a failed download: sooner, but not so soon that a dead network
    /// burns the day's budget.
    public static let retryInterval: TimeInterval = 15 * 60

    /// The state at `date`. The series' minute 0 is when the radar measured,
    /// not when it was downloaded — DWD publishes a few minutes late, and the
    /// widget should not be.
    public static func state(for nowcast: RadarNowcast, at date: Date) -> RainWidgetState {
        guard let measuredAt = nowcast.measuredAt else { return .stale(measuredAt: nil) }
        guard let remaining = remaining(nowcast, at: date) else { return .stale(measuredAt: measuredAt) }
        return .forecast(RadarNowcastRules.outlook(series: remaining), measuredAt: measuredAt)
    }

    /// The series as seen from `date`: minute 0 is the step `date` falls in,
    /// earlier steps are gone. `nil` once the forecast is stale or cannot be
    /// aged — the widget's bars and its sentence come from the same cut.
    public static func remaining(_ nowcast: RadarNowcast, at date: Date) -> [RadarSample]? {
        guard let measuredAt = nowcast.measuredAt else { return nil }
        let elapsed = max(0, date.timeIntervalSince(measuredAt))
        guard elapsed < maxAge else { return nil }

        let offset = Int(elapsed / step) * Int(step / 60)
        return nowcast.series
            .filter { $0.minute >= offset }
            .map { RadarSample(minute: $0.minute - offset, millimetres: $0.millimetres) }
    }

    /// Entries from `now` every five minutes while the forecast holds, then
    /// one stale entry that stays until the next reload replaces it.
    public static func entries(for nowcast: RadarNowcast, now: Date) -> [(date: Date, state: RainWidgetState)] {
        guard let measuredAt = nowcast.measuredAt else { return [(now, .stale(measuredAt: nil))] }
        let expiry = measuredAt.addingTimeInterval(maxAge)

        var entries: [(date: Date, state: RainWidgetState)] = []
        var date = now
        while date < expiry {
            entries.append((date, state(for: nowcast, at: date)))
            date = date.addingTimeInterval(step)
        }
        entries.append((max(now, expiry), .stale(measuredAt: measuredAt)))
        return entries
    }
}
