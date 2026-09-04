import Foundation

/// One DWD Belastungsstufe (`legend.id1`…`id7` in the source file), e.g.
/// `"0"`, `"0-1"`, `"1"` … `"3"`. Half-steps are real values the source
/// publishes, not a rounding convenience — this stays a raw string, never an
/// `Int`, so nothing downstream can round `"1-2"` to `1` or `2`.
///
/// Open, like `GaugeState`: a raw value this build has not seen keeps its
/// spelling rather than costing the whole reading.
public struct PollenLevel: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// `legend.id1` — "keine Belastung". The one level BEM-G04's acceptance
    /// criteria says to suppress rather than render as a zero row.
    public static let none = PollenLevel(rawValue: "0")

    public var isElevated: Bool { self != .none }

    /// DWD's own severity order, least to most. Used only for display
    /// ordering — deliberately not a string comparison on `rawValue`, which
    /// would put `"2"` ahead of `"1-2"` for the wrong reason (string length,
    /// not severity) if the vocabulary ever grew a value this ordering does
    /// not already know. A level this build has not seen sorts after every
    /// known one rather than crashing the sort.
    private static let knownOrder = ["0", "0-1", "1", "1-2", "2", "2-3", "3"]

    public var severityRank: Int {
        Self.knownOrder.firstIndex(of: rawValue) ?? Self.knownOrder.count
    }
}

/// One pollen type's three-day forecast at the Rhein-Main partregion, plus
/// DWD's own sentence for what today's level means — the DWD vocabulary,
/// never a wording this app invents.
public struct PollenTypeReading: Identifiable, Hashable, Sendable {
    public var id: String { name }
    /// The type name as DWD spells its key ("Graeser", "Beifuss") — ASCII,
    /// not the correct German ("Gräser", "Beifuß"). `CityView` maps display
    /// spelling; this stays the raw key so a lookup back into the payload
    /// (retry, tests) matches exactly.
    public let name: String
    public let today: PollenLevel
    public let tomorrow: PollenLevel
    public let dayAfterTomorrow: PollenLevel
    /// DWD's own legend text for `today`, e.g. "geringe bis mittlere Belastung".
    public let todayDescription: String

    public init(
        name: String,
        today: PollenLevel,
        tomorrow: PollenLevel,
        dayAfterTomorrow: PollenLevel,
        todayDescription: String
    ) {
        self.name = name
        self.today = today
        self.tomorrow = tomorrow
        self.dayAfterTomorrow = dayAfterTomorrow
        self.todayDescription = todayDescription
    }
}

/// Pollenflug for the Rhein-Main DWD partregion (BEM-G04, #71).
///
/// Only pollen types carrying a load today are here — `today == .none` is
/// filtered before this type exists (`PollenForecastFile.reading(for:)`), so
/// an empty `values` array is itself the honest "nothing in the air right
/// now" state, the same rule `CityWarning`'s empty list follows for warnings.
public struct PollenReading: Sendable {
    public let values: [PollenTypeReading]
    /// DWD's own stamp, source text ("DWD · 2026-09-04 11:00 Uhr") — not
    /// reparsed and reformatted, the same choice `CityWarning.body` makes for
    /// its text.
    public let stampLabel: String

    public init(values: [PollenTypeReading], stampLabel: String) {
        self.values = values
        self.stampLabel = stampLabel
    }
}
