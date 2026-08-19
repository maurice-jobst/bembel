import CoreLocation
import Foundation

/// Fabricated Stadtzustand sources for previews and for the seams that have no
/// live implementation yet: Bright Sky (no ticket). The Main level
/// (`PegelOnlineProvider`), the air (`UBAAirQualityProvider`) and the
/// warnings (`NinaWarningProvider`) are live.
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
            AirValue(name: "NO₂", readingLabel: "21 µg/m³", fraction: 0.21, index: .veryGood),
            AirValue(name: "PM₂,₅", readingLabel: "8 µg/m³", fraction: 0.16, index: .veryGood),
            AirValue(name: "O₃", readingLabel: "96 µg/m³", fraction: 0.36, index: .good),
        ],
        // The station's index is the worst of its pollutants, not an average.
        index: .good,
        stationName: "Frankfurt Ost",
        stampLabel: "HLNUG · Frankfurt Ost (Hintergrund) · 10:00"
    )

    public init() {}

    public func airQuality(near coordinate: CLLocationCoordinate2D?) async throws -> AirQuality {
        Self.airQuality
    }
}

/// Previews only. **Never wire this into a shipping build** — the live
/// configuration reads NINA (`NinaWarningProvider`, BEM-G03). A fabricated
/// civil-protection warning on that card is worse than no card at all, which
/// is why the live provider fails visibly instead of degrading to this one.
///
/// Warning text is source text and is not localized by the app.
public struct SampleCityWarningProvider: CityWarningProviding {
    public static let warnings = [
        CityWarning(
            title: "Hitzewarnung Stufe 1",
            body: "Bis Donnerstag 19 Uhr. Viel trinken, Mittagssonne meiden.",
            areaLabel: "Stadt Frankfurt am Main",
            stampLabel: "NINA · DWD · 09:12"
        )
    ]

    public init() {}

    public func warnings() async throws -> [CityWarning] { Self.warnings }
}
