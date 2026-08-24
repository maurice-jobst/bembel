import Foundation

/// One reading on the nowcast timeline.
public struct RadarSample: Hashable, Sendable, Identifiable {
    /// Minutes ahead of the composite's measurement time. 0 is "now".
    public let minute: Int
    /// Millimetres of rain in that five-minute step, `nil` where the radar
    /// cannot see. Not a rate — the product's own interval.
    public let millimetres: Double?

    public var id: Int { minute }

    public init(minute: Int, millimetres: Double?) {
        self.minute = minute
        self.millimetres = millimetres
    }
}

/// How hard it is raining, in the three steps a person actually distinguishes.
/// The thresholds live in `RadarNowcastRules`; the words live in the String
/// Catalog, because they are user-facing text and the data layer is not where
/// German sentences belong.
public enum RainIntensity: Sendable, Equatable, CaseIterable {
    case light
    case moderate
    case heavy
}

/// What the radar says is about to happen, as data rather than as a sentence.
///
/// This used to be two preformatted German strings built in the data layer. The
/// view then had nothing to localise and nothing to test against; worse, the
/// same phrasing could not be reused by a widget without shipping the whole
/// nowcast through it. Every case here maps to one String Catalog key.
public enum RainOutlook: Sendable, Equatable {
    /// Raining at the playhead. `minutesRemaining` is `nil` when the rain runs
    /// past the end of the forecast — "two more hours" and "we cannot see far
    /// enough to say" are the same picture and must not read the same.
    case rainingNow(intensity: RainIntensity, minutesRemaining: Int?)
    case rainStarting(inMinutes: Int, intensity: RainIntensity, lastingMinutes: Int)
    /// Dry for the whole horizon the composite covers.
    case dry(horizonMinutes: Int)
    /// The radar produced no usable reading here. Not the same as dry.
    case noData
}

/// The rain nowcast: what is coming, the series behind it, and the frames the
/// map draws.
public struct RadarNowcast: Sendable {
    public let outlook: RainOutlook
    /// The forecast at the user's location, five minutes apart, oldest first.
    public let series: [RadarSample]
    /// One resampled raster per step, in the same order as `series`. Empty for
    /// fixtures that only exercise the phrasing rules.
    public let frames: [RadarFrame]
    /// The box `frames` cover.
    public let bounds: RadarBounds
    /// When the radar measured. `nil` when the source did not say.
    public let measuredAt: Date?
    /// Data stamp of the composite ("10:45").
    public let stampLabel: String
    /// Licence attribution the UI must show — GeoNutzV requires naming DWD.
    public let attribution: String?

    public init(
        outlook: RainOutlook,
        series: [RadarSample] = [],
        frames: [RadarFrame] = [],
        bounds: RadarBounds = .rheinMain,
        measuredAt: Date? = nil,
        stampLabel: String = "—",
        attribution: String? = nil
    ) {
        self.outlook = outlook
        self.series = series
        self.frames = frames
        self.bounds = bounds
        self.measuredAt = measuredAt
        self.stampLabel = stampLabel
        self.attribution = attribution
    }

    /// How far ahead the composite reaches, in minutes.
    public var horizonMinutes: Int { series.last?.minute ?? 0 }

    /// Wall-clock label for a step, so the playhead can say what time it is
    /// showing. Falls back to the step offset when the composite carried no
    /// measurement time — a clock that guesses would be worse than an offset
    /// that admits what it is.
    public func clockLabel(atMinute minute: Int) -> String? {
        guard let measuredAt else { return nil }
        return DateFormatter.berlinClock.string(
            from: measuredAt.addingTimeInterval(TimeInterval(minute) * 60))
    }
}
