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

/// The rain nowcast headline plus the state of the timeline.
///
/// The string fields are what the Regenradar renders today. They are built in
/// the data layer only because the view takes them ready-made; when BEM-F02
/// touches that view, the phrasing belongs in `Localizable.xcstrings` and this
/// type should carry `series` alone.
public struct RadarNowcast: Sendable {
    /// "Regen in 25 Min"
    public let headline: String
    /// "leicht, etwa 20 Minuten lang"
    public let detail: String
    /// Clock label at the playhead ("10:47").
    public let clockLabel: String
    /// Data stamp of the radar composite ("10:45").
    public let stampLabel: String
    /// Playhead position along the timeline, 0…1.
    public let progress: Double

    /// The actual forecast, five minutes apart. Empty for fixtures that only
    /// carry display strings.
    public let series: [RadarSample]
    /// When the radar measured. `nil` when the source did not say.
    public let measuredAt: Date?
    /// Licence attribution the UI must show — GeoNutzV requires naming DWD.
    public let attribution: String?

    public init(
        headline: String,
        detail: String,
        clockLabel: String,
        stampLabel: String,
        progress: Double,
        series: [RadarSample] = [],
        measuredAt: Date? = nil,
        attribution: String? = nil
    ) {
        self.headline = headline
        self.detail = detail
        self.clockLabel = clockLabel
        self.stampLabel = stampLabel
        self.progress = progress
        self.series = series
        self.measuredAt = measuredAt
        self.attribution = attribution
    }
}
