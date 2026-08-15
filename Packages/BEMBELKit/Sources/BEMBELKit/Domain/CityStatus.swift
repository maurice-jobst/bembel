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

/// Which way the water is going over the trend window. Three states, not a
/// `falling` flag: a river that has not moved a measurable amount is neither
/// rising nor falling, and an arrow that must point somewhere would invent a
/// direction the data does not have.
public enum GaugeTrend: Sendable, Equatable {
    case rising
    case falling
    case steady
}

/// Where the level sits against the gauge's own reference marks, as WSV
/// classifies it — not something this app derives. PEGELONLINE ships two
/// independent assessments per reading, and `characteristicvalues.json` is
/// empty for Frankfurt Osthafen, so its own classification is the only honest
/// source for this.
///
/// Open vocabulary, like `Merkmal` and `FountainKind`: a value this build has
/// not heard of degrades to `unknown` and keeps its raw spelling, rather than
/// costing the whole reading. Observed live across 738 stations: `normal`,
/// `low`, `unknown`, `commented`, `out-dated`. `high` is documented and
/// expected but was not observed on the day this was written — which is
/// exactly why nothing here enumerates a closed set.
public struct GaugeState: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let normal = GaugeState(rawValue: "normal")
    public static let low = GaugeState(rawValue: "low")
    public static let high = GaugeState(rawValue: "high")
    public static let unknown = GaugeState(rawValue: "unknown")
    /// The station has a human note attached instead of a classification.
    public static let commented = GaugeState(rawValue: "commented")
    /// WSV itself flags the reading as too old to classify.
    public static let outdated = GaugeState(rawValue: "out-dated")

    /// True only for a state that actually says something. `unknown`,
    /// `commented` and `out-dated` are all "no assessment" in different words,
    /// and a UI must not render them as reassurance.
    public var isAssessed: Bool {
        self == .normal || self == .low || self == .high
    }
}

/// Main water level at one gauge (PEGELONLINE).
public struct GaugeReading: Sendable {
    /// Level in metres with German decimal comma ("1,58"); the unit is
    /// rendered separately by the card.
    public let levelLabel: String
    public let trendLabel: String
    public let trend: GaugeTrend
    public let stationName: String
    public let stampLabel: String
    /// Recent samples for the sparkline, oldest first, arbitrary unit.
    public let history: [Double]
    /// Level against the mean low/high water marks (MNW/MHW).
    public let stateMnwMhw: GaugeState
    /// Level against the shipping marks (NSW/HSW) — the navigation view of the
    /// same river, which can read differently from the hydrological one.
    public let stateNswHsw: GaugeState

    public init(
        levelLabel: String,
        trendLabel: String,
        trend: GaugeTrend,
        stationName: String,
        stampLabel: String,
        history: [Double],
        stateMnwMhw: GaugeState = .unknown,
        stateNswHsw: GaugeState = .unknown
    ) {
        self.levelLabel = levelLabel
        self.trendLabel = trendLabel
        self.trend = trend
        self.stationName = stationName
        self.stampLabel = stampLabel
        self.history = history
        self.stateMnwMhw = stateMnwMhw
        self.stateNswHsw = stateNswHsw
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
