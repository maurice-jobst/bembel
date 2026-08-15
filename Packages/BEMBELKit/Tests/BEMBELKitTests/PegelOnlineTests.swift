import Foundation
import Testing

@testable import BEMBELKit

/// Real PEGELONLINE responses for Frankfurt Osthafen, captured 2026-08-15.
/// Fixtures rather than a live call, for the same reason the RADOLAN tests use
/// a checked-in archive: the assertions have to stay true next winter.
private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private func decoded<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
    try JSONDecoder().decode(T.self, from: fixture(name))
}

@Suite("PEGELONLINE")
struct PegelOnlineTests {
    private func liveReading() throws -> GaugeReading {
        try PegelOnlineProvider.reading(
            station: .frankfurtOsthafen,
            timeseries: decoded(PegelTimeseries.self, "pegel-timeseries"),
            current: decoded(PegelCurrentMeasurement.self, "pegel-current"),
            series: decoded([PegelMeasurement].self, "pegel-measurements")
        )
    }

    @Test("The wire responses decode as published")
    func decodes() throws {
        let timeseries = try decoded(PegelTimeseries.self, "pegel-timeseries")
        #expect(timeseries.unit == "cm")
        #expect(timeseries.gaugeZero?.value == 90.626)

        let current = try decoded(PegelCurrentMeasurement.self, "pegel-current")
        #expect(current.value == 158.0)
        #expect(current.stateMnwMhw == "normal")

        let series = try decoded([PegelMeasurement].self, "pegel-measurements")
        #expect(series.count == 672)  // seven days at WSV's 15-minute equidistance
    }

    @Test("Centimetres become metres — the card renders 1,58 m, not 158 m")
    func unitConversion() throws {
        // The single most consequential fact about this API: 670 of 738
        // stations report cm. Reading 158 as metres would put the Main four
        // storeys up.
        #expect(PegelRules.metres(158, unit: "cm") == 1.58)
        #expect(PegelRules.metres(1.58, unit: "m+NN") == 1.58)
        #expect(PegelRules.metres(1.58, unit: "m+PNP") == 1.58)
        #expect(try liveReading().levelLabel == "1,58")
    }

    @Test("An unknown unit is an error, never a number in the wrong scale")
    func unsupportedUnit() throws {
        #expect(PegelRules.metres(1, unit: "furlong") == nil)
        let odd = try JSONDecoder().decode(PegelTimeseries.self, from: Data(#"{"unit": "furlong"}"#.utf8))
        #expect(throws: PegelOnlineProvider.Failure.unsupportedUnit("furlong")) {
            try PegelOnlineProvider.reading(
                station: .frankfurtOsthafen,
                timeseries: odd,
                current: decoded(PegelCurrentMeasurement.self, "pegel-current"),
                series: []
            )
        }
    }

    @Test("Trend is three-state, and a move inside the noise is steady")
    func trend() {
        #expect(PegelRules.trend(currentMetres: 1.58, earlierMetres: 1.52).0 == .rising)
        #expect(PegelRules.trend(currentMetres: 1.52, earlierMetres: 1.58).0 == .falling)
        // 1 cm over a day is not a direction.
        #expect(PegelRules.trend(currentMetres: 1.58, earlierMetres: 1.57).0 == .steady)
        #expect(PegelRules.trend(currentMetres: 1.58, earlierMetres: 1.52).1 == "6 cm / 24 h")
        // Absolute value: falling reads "6 cm", never "-6 cm".
        #expect(PegelRules.trend(currentMetres: 1.52, earlierMetres: 1.58).1 == "6 cm / 24 h")
    }

    @Test("A series too short for 24 h claims no 24-hour trend")
    func shortSeriesHasNoTrend() throws {
        let current = try decoded(PegelCurrentMeasurement.self, "pegel-current")
        let series = Array(try decoded([PegelMeasurement].self, "pegel-measurements").suffix(4))
        let reading = try PegelOnlineProvider.reading(
            station: .frankfurtOsthafen,
            timeseries: decoded(PegelTimeseries.self, "pegel-timeseries"),
            current: current,
            series: series
        )
        // An hour of data must not be labelled "/ 24 h" with a made-up delta.
        #expect(reading.trendLabel == "—")
        #expect(reading.trend == .steady)
    }

    @Test("The sparkline is downsampled but still ends on the newest sample")
    func sparkline() throws {
        let reading = try liveReading()
        #expect(reading.history.count == PegelRules.sparklinePoints)
        let all = try decoded([PegelMeasurement].self, "pegel-measurements").map { $0.value / 100 }
        #expect(reading.history.last == all.last)
        #expect(reading.history.first == all.first)
    }

    @Test("A shorter series than the sparkline wants is passed through, not padded")
    func shortSparkline() {
        #expect(PegelRules.sparkline(from: [1, 2, 3]) == [1, 2, 3])
        #expect(PegelRules.sparkline(from: []) == [])
    }

    @Test("WSV's own classification is carried through, not re-derived")
    func statesCarried() throws {
        let reading = try liveReading()
        #expect(reading.stateMnwMhw == .normal)
        #expect(reading.stateNswHsw == .normal)
        #expect(reading.stateMnwMhw.isAssessed)
    }

    @Test("A state this build has not heard of degrades to unknown, not to reassurance")
    func openVocabulary() throws {
        // `commented` and `out-dated` are real values WSV publishes; neither is
        // an assessment, and a card must not render them as "normal".
        #expect(!GaugeState(rawValue: "commented").isAssessed)
        #expect(!GaugeState(rawValue: "out-dated").isAssessed)
        #expect(!GaugeState(rawValue: "hochwassermeldedienst-eingestellt").isAssessed)
        #expect(GaugeState(rawValue: "high").isAssessed)

        let missing = try JSONDecoder().decode(
            PegelCurrentMeasurement.self,
            from: Data(#"{"timestamp": "2026-08-15T12:30:00+02:00", "value": 158.0}"#.utf8)
        )
        let reading = try PegelOnlineProvider.reading(
            station: .frankfurtOsthafen,
            timeseries: decoded(PegelTimeseries.self, "pegel-timeseries"),
            current: missing,
            series: []
        )
        #expect(reading.stateMnwMhw == .unknown)
    }

    @Test("The stamp is the measurement's own time, in Berlin")
    func stamp() throws {
        // 12:30+02:00 is 12:30 in Frankfurt — the card must not show UTC.
        #expect(try liveReading().stampLabel == "12:30")
    }

    @Test("An unparseable timestamp is an error rather than a silent 'now'")
    func badTimestamp() throws {
        let broken = try JSONDecoder().decode(
            PegelCurrentMeasurement.self,
            from: Data(#"{"timestamp": "gestern", "value": 158.0}"#.utf8)
        )
        #expect(throws: PegelOnlineProvider.Failure.unreadableTimestamp("gestern")) {
            try PegelOnlineProvider.reading(
                station: .frankfurtOsthafen,
                timeseries: decoded(PegelTimeseries.self, "pegel-timeseries"),
                current: broken,
                series: []
            )
        }
    }
}
