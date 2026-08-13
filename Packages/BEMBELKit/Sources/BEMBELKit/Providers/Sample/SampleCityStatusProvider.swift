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
        gauge: GaugeReading(
            levelLabel: "3,42",
            trendLabel: "4 cm / 24 h",
            falling: true,
            stationName: "Osthafen",
            stampLabel: "10:45",
            history: [20, 17, 22, 16, 12, 18, 26, 22, 28, 33, 30, 36]
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
