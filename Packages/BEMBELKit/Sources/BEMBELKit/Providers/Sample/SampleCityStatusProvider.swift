import Foundation

/// Fabricated city status until PEGELONLINE (BEM-G01), HLNUG (BEM-G02) and
/// NINA (BEM-G03) are wired. Warning text is source text, not localized.
public struct SampleCityStatusProvider: CityStatusProviding {
    public static let status = CityStatus(
        temperatureLabel: "Frankfurt am Main · 24 °C",
        warning: CityWarning(
            title: "Hitzewarnung Stufe 1",
            body: "Bis Donnerstag 19 Uhr. Viel trinken, Mittagssonne meiden.",
            stampLabel: "NINA · 09:12"
        ),
        // Previews and the offline fallback only. The live card reads
        // PEGELONLINE (BEM-G01) — note that this fabricated 3,42 m was never a
        // plausible Osthafen level; the real gauge sat at 1,58 m the day it was
        // wired up.
        gauge: GaugeReading(
            levelLabel: "1,58",
            trendLabel: "6 cm / 24 h",
            trend: .rising,
            stationName: "Osthafen",
            stampLabel: "10:45",
            history: [20, 17, 22, 16, 12, 18, 26, 22, 28, 33, 30, 36],
            stateMnwMhw: .normal,
            stateNswHsw: .normal
        ),
        airValues: [
            AirValue(name: "NO₂", readingLabel: "21 µg/m³", fraction: 0.26, elevated: false),
            AirValue(name: "PM₂,₅", readingLabel: "8 µg/m³", fraction: 0.18, elevated: false),
            AirValue(name: "O₃", readingLabel: "96 µg/m³", fraction: 0.62, elevated: true),
        ],
        airStampLabel: "HLNUG Station Frankfurt-Ost · 10:00"
    )

    public init() {}

    public func status() async throws -> CityStatus {
        Self.status
    }
}
