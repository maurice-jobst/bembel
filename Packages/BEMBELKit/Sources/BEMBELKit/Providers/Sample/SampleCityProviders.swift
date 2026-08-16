import Foundation

/// Fabricated Stadtzustand sources for previews and for the seams that have no
/// live implementation yet: Bright Sky (no ticket), HLNUG (BEM-G02) and NINA
/// (BEM-G03). The Main level is live — see `PegelOnlineProvider`.
///
/// One type per upstream, matching the protocols. A single sample aggregate
/// would make it impossible to preview "air failed, warnings fine", which is
/// the state this screen most needs to get right.

public struct SampleTemperatureProvider: TemperatureProviding {
    public static let reading = TemperatureReading(label: "Frankfurt am Main · 24 °C")

    public init() {}

    public func temperature() async throws -> TemperatureReading { Self.reading }
}

/// Previews and the offline fallback only. The live card reads PEGELONLINE
/// (BEM-G01) — note that the fabricated 3,42 m this once carried was never a
/// plausible Osthafen level; the real gauge sat at 1,58 m the day it was wired.
public struct SampleGaugeProvider: GaugeProviding {
    public static let reading = GaugeReading(
        levelLabel: "1,58",
        trendLabel: "6 cm / 24 h",
        trend: .rising,
        stationName: "Osthafen",
        stampLabel: "10:45",
        history: [20, 17, 22, 16, 12, 18, 26, 22, 28, 33, 30, 36],
        stateMnwMhw: .normal,
        stateNswHsw: .normal
    )

    public init() {}

    public func reading() async throws -> GaugeReading { Self.reading }
}

public struct SampleAirQualityProvider: AirQualityProviding {
    public static let airQuality = AirQuality(
        values: [
            AirValue(name: "NO₂", readingLabel: "21 µg/m³", fraction: 0.26, elevated: false),
            AirValue(name: "PM₂,₅", readingLabel: "8 µg/m³", fraction: 0.18, elevated: false),
            AirValue(name: "O₃", readingLabel: "96 µg/m³", fraction: 0.62, elevated: true),
        ],
        stampLabel: "HLNUG Station Frankfurt-Ost · 10:00"
    )

    public init() {}

    public func airQuality() async throws -> AirQuality { Self.airQuality }
}

/// Warning text is source text and is not localized by the app.
public struct SampleCityWarningProvider: CityWarningProviding {
    public static let warnings = [
        CityWarning(
            title: "Hitzewarnung Stufe 1",
            body: "Bis Donnerstag 19 Uhr. Viel trinken, Mittagssonne meiden.",
            stampLabel: "NINA · 09:12"
        )
    ]

    public init() {}

    public func warnings() async throws -> [CityWarning] { Self.warnings }
}
