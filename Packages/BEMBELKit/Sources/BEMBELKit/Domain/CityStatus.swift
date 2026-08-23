import Foundation

/// An active civil-protection warning (NINA). Text arrives as-is from the
/// source; it is not localized by the app.
public struct CityWarning: Hashable, Sendable {
    public let title: String
    public let body: String
    /// Where the issuer says the warning applies, in their words ("Stadt
    /// Frankfurt am Main"), or `nil` when the message names no area.
    ///
    /// Not decoration. `NinaWarningProvider` filters at Kreis granularity —
    /// the finest the BBK endpoint can be keyed to from an AGS — so a warning
    /// can reach a user whose ring contains only part of that Kreis. This line
    /// is what stops them reading it as local.
    public let areaLabel: String?
    /// Source + clock stamp ("NINA · 09:12", or "NINA · DWD · 09:12" when BBK
    /// is relaying another issuer's warning).
    public let stampLabel: String

    public init(title: String, body: String, areaLabel: String? = nil, stampLabel: String) {
        self.title = title
        self.body = body
        self.areaLabel = areaLabel
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

/// Ambient 2 m air temperature for the screen's header line. Its own type
/// because it is its own upstream — DWD's POI station reports, per
/// `data/sources.json` — and not a field on a reading it would otherwise
/// share a failure with.
public struct TemperatureReading: Sendable, Equatable {
    /// Degrees Celsius as measured. Kept alongside the label because a heat
    /// app will eventually band this, and re-parsing a formatted German
    /// decimal to get the number back would be the wrong way round.
    public let celsius: Double
    /// One decimal with German decimal comma ("19,7"); the unit is rendered
    /// by the view, the same split `GaugeReading.levelLabel` makes.
    public let celsiusLabel: String
    /// Where the thermometer stands — not the city. The nearest DWD station
    /// can be well outside the built-up core, which is exactly the difference
    /// this app should not paper over.
    public let stationName: String
    /// Clock stamp of the measurement hour, Europe/Berlin.
    public let stampLabel: String

    public init(celsius: Double, celsiusLabel: String, stationName: String, stampLabel: String) {
        self.celsius = celsius
        self.celsiusLabel = celsiusLabel
        self.stationName = stationName
        self.stampLabel = stampLabel
    }
}

/// Where a reading sits on the Umweltbundesamt's five-band
/// Luftqualitätsindex — the official German assessment, and the same scale
/// HLNUG publishes its own stations against.
///
/// The bands are the plain-language interpretation: the app does not invent
/// its own wording for "how bad is this", and it does not carry a table of
/// µg/m³ thresholds either. Thresholds differ per pollutant and change when
/// the assessment changes; asking the API which band a value fell into is the
/// only version of this that cannot silently go out of date.
public enum AirIndex: Sendable, Hashable, CaseIterable {
    case veryGood
    case good
    case moderate
    case poor
    case veryPoor
    /// The station published a value the index does not assess, or none at
    /// all. Rendered as "keine Bewertung", never as reassurance.
    case unassessed

    /// UBA numbers the bands 0…4. Anything else — including the -1 the API
    /// uses for "not assessed" — is an absence of judgement, not a good one.
    public init(uba: Int?) {
        switch uba {
        case 0: self = .veryGood
        case 1: self = .good
        case 2: self = .moderate
        case 3: self = .poor
        case 4: self = .veryPoor
        default: self = .unassessed
        }
    }

    /// Position on the scale, or `nil` when there is no assessment.
    public var band: Int? {
        switch self {
        case .veryGood: 0
        case .good: 1
        case .moderate: 2
        case .poor: 3
        case .veryPoor: 4
        case .unassessed: nil
        }
    }

    /// From "mäßig" upwards, which is where UBA starts advising sensitive
    /// people to change their behaviour. `unassessed` is deliberately not
    /// elevated *and* not calm — callers must handle it as its own case.
    public var isElevated: Bool {
        guard let band else { return false }
        return band >= 2
    }
}

/// One pollutant bar.
public struct AirValue: Identifiable, Sendable {
    public var id: String { name }
    /// The pollutant's symbol as the source spells it ("NO₂", "PM₂,₅").
    public let name: String
    public let readingLabel: String
    /// Fill fraction of the bar, 0…1, across the **whole** five-band scale.
    ///
    /// Not the fraction within the current band, which is what the API's own
    /// `y` field gives: 38 µg/m³ of ozone and 121 µg/m³ both sit near 0.65 of
    /// their respective bands, and a bar that drew them the same length would
    /// erase the difference between "sehr gut" and "mäßig".
    public let fraction: Double
    public let index: AirIndex

    public init(name: String, readingLabel: String, fraction: Double, index: AirIndex) {
        self.name = name
        self.readingLabel = readingLabel
        self.fraction = fraction
        self.index = index
    }
}

/// One air-quality reading: the bars, the station's overall index, and the
/// station and clock they came from.
///
/// The stamp travels with the values rather than beside them, because a stamp
/// left over from a previous successful load next to bars that failed to
/// refresh is a lie the type should not be able to express. The same argument
/// applies to `index`, which is why the screen's summary capsule reads it from
/// here instead of being written into the view.
public struct AirQuality: Sendable {
    public let values: [AirValue]
    /// The station's own overall assessment — the worst of its pollutants, as
    /// UBA computes it, not something this app derives from the bars.
    public let index: AirIndex
    public let stationName: String
    public let stampLabel: String

    public init(values: [AirValue], index: AirIndex, stationName: String, stampLabel: String) {
        self.values = values
        self.index = index
        self.stationName = stationName
        self.stampLabel = stampLabel
    }
}
