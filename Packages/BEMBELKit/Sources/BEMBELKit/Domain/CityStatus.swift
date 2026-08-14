import Foundation

/// An active civil-protection warning (NINA). Text arrives as-is from the
/// source; it is not localized by the app.
public struct CityWarning: Hashable, Sendable {
    public let title: String
    public let body: String
    /// Source + clock stamp ("NINA · 09:12").
    public let stampLabel: String

    public init(title: String, body: String, stampLabel: String) {
        self.title = title
        self.body = body
        self.stampLabel = stampLabel
    }
}

/// Main water level at one gauge (PEGELONLINE).
public struct GaugeReading: Sendable {
    /// Level with German decimal comma ("3,42"); unit rendered separately.
    public let levelLabel: String
    public let trendLabel: String
    /// True when the level is falling — drives the good/caution tint.
    public let falling: Bool
    public let stationName: String
    public let stampLabel: String
    /// Recent samples for the sparkline, oldest first, arbitrary unit.
    public let history: [Double]

    public init(
        levelLabel: String,
        trendLabel: String,
        falling: Bool,
        stationName: String,
        stampLabel: String,
        history: [Double]
    ) {
        self.levelLabel = levelLabel
        self.trendLabel = trendLabel
        self.falling = falling
        self.stationName = stationName
        self.stampLabel = stampLabel
        self.history = history
    }
}

/// One pollutant bar (HLNUG).
public struct AirValue: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let readingLabel: String
    /// Fill fraction of the bar, 0…1, relative to the assessment threshold.
    public let fraction: Double
    public let elevated: Bool

    public init(name: String, readingLabel: String, fraction: Double, elevated: Bool) {
        self.name = name
        self.readingLabel = readingLabel
        self.fraction = fraction
        self.elevated = elevated
    }
}

/// Everything the Stadtzustand screen renders.
public struct CityStatus: Sendable {
    public let temperatureLabel: String
    public let warning: CityWarning?
    public let gauge: GaugeReading
    public let airValues: [AirValue]
    public let airStampLabel: String

    public init(
        temperatureLabel: String,
        warning: CityWarning?,
        gauge: GaugeReading,
        airValues: [AirValue],
        airStampLabel: String
    ) {
        self.temperatureLabel = temperatureLabel
        self.warning = warning
        self.gauge = gauge
        self.airValues = airValues
        self.airStampLabel = airStampLabel
    }
}
