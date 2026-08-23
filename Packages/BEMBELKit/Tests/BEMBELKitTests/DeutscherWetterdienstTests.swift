import Foundation
import Testing

@testable import BEMBELKit

/// `dwd-poi-10637.csv` is the live body of
/// `opendata.dwd.de/weather/weather_reports/poi/10637-BEOB.csv`, captured
/// 2026-08-23 — all three header lines and all 25 hourly rows, untouched.
private func poiFixture() throws -> String {
    let url = try #require(Bundle.module.url(forResource: "dwd-poi-10637", withExtension: "csv"))
    return try String(contentsOf: url, encoding: .utf8)
}

private let temperature = PoiRules.temperatureParameter

/// Berlin was on CEST (UTC+2) on the fixture's day, so the 18:00 UTC report is
/// 20:00 on the card.
private func utc(_ text: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return try #require(formatter.date(from: text))
}

@Suite("DWD POI wire format")
struct DWDPoiWireTests {
    @Test("Columns are found by name, and the newest report wins")
    func parse() throws {
        let reports = try PoiRules.reports(
            from: try poiFixture(), parameters: [temperature: PoiRules.temperatureUnit])
        #expect(reports.count == 25)
        #expect(reports[0].measuredAt == (try utc("2026-08-23 18:00")))
        #expect(reports[0].values[temperature] == 19.7)
        // Sorted newest first regardless of how the file was ordered.
        #expect(reports.last?.measuredAt == (try utc("2026-08-22 18:00")))
        #expect(zip(reports, reports.dropFirst()).allSatisfy { $0.measuredAt > $1.measuredAt })
    }

    @Test("`---` is absent, not zero")
    func missingCells() throws {
        #expect(PoiRules.number("---") == nil)
        #expect(PoiRules.number("") == nil)
        #expect(PoiRules.number("0") == 0)
        // The German decimal comma is the only decimal separator in this file.
        #expect(PoiRules.number("19,7") == 19.7)
        #expect(PoiRules.number("-3,4") == -3.4)
        #expect(PoiRules.number("1022,7") == 1022.7)

        // Several parameters in the real fixture are `---` throughout, and a
        // row that carries none of them still parses — it just has no value
        // for that key.
        let reports = try PoiRules.reports(
            from: try poiFixture(), parameters: [temperature: PoiRules.temperatureUnit])
        #expect(reports.allSatisfy { $0.values[temperature] != nil })
    }

    @Test("A two-digit year lands in this century, not the last one")
    func twoDigitYear() throws {
        // Foundation's default window starts in 1950. Without the pinned
        // start date, "26" would eventually read as 1926 — a date that parses,
        // sorts and formats perfectly well while being a century wrong.
        let reports = try PoiRules.reports(
            from: try poiFixture(), parameters: [temperature: PoiRules.temperatureUnit])
        let year = Calendar(identifier: .gregorian).component(.year, from: reports[0].measuredAt)
        #expect(year == 2026)
    }
}

@Suite("DWD POI degradation")
struct DWDPoiDegradationTests {
    @Test("A column that changed unit is refused, not rendered")
    func unitChange() throws {
        // The failure PEGELONLINE taught: a station that starts publishing
        // Fahrenheit would otherwise draw 67,5 on a card labelled °C.
        let broken = try poiFixture().replacingOccurrences(of: ";Grad C;", with: ";Grad F;")
        #expect(throws: PoiRules.Failure.unexpectedUnit(parameter: temperature, unit: "Grad F")) {
            _ = try PoiRules.reports(from: broken, parameters: [temperature: PoiRules.temperatureUnit])
        }
    }

    @Test("A parameter that vanished from the header is an error, not a blank")
    func missingParameter() throws {
        let broken = try poiFixture().replacingOccurrences(of: temperature, with: "something_else")
        #expect(throws: PoiRules.Failure.missingParameter(temperature)) {
            _ = try PoiRules.reports(from: broken, parameters: [temperature: PoiRules.temperatureUnit])
        }
    }

    @Test("Truncated and empty bodies fail as malformed")
    func truncated() throws {
        let lines = try poiFixture().split(whereSeparator: \.isNewline).map(String.init)
        for count in 0...3 {
            let head = lines.prefix(count).joined(separator: "\n")
            #expect(throws: PoiRules.Failure.malformedHeader) {
                _ = try PoiRules.reports(from: head, parameters: [temperature: PoiRules.temperatureUnit])
            }
        }
        // An HTML error page served with status 200 is the realistic version
        // of this, and it must not reach the card either.
        #expect(throws: PoiRules.Failure.self) {
            _ = try PoiRules.reports(
                from: "<html><body>404</body></html>",
                parameters: [temperature: PoiRules.temperatureUnit]
            )
        }
    }

    @Test("A station reporting no temperature at all says so")
    func noReading() throws {
        let reports = [
            PoiReport(measuredAt: try utc("2026-08-23 18:00"), values: [:]),
            PoiReport(measuredAt: try utc("2026-08-23 17:00"), values: [:]),
        ]
        #expect(throws: PoiRules.Failure.noReading) {
            _ = try PoiRules.latest(reports, of: temperature)
        }
    }

    @Test("A gap in the newest hour falls back to the hour below it")
    func gapInNewestHour() throws {
        // DWD publishes the hour before the station has reported often enough
        // that blanking the card for it would be wrong: the reading one row
        // down is an hour old and true, and it carries its own stamp.
        let reports = [
            PoiReport(measuredAt: try utc("2026-08-23 18:00"), values: [:]),
            PoiReport(measuredAt: try utc("2026-08-23 17:00"), values: [temperature: 20.9]),
        ]
        let (measuredAt, celsius) = try PoiRules.latest(reports, of: temperature)
        #expect(celsius == 20.9)
        #expect(measuredAt == (try utc("2026-08-23 17:00")))
    }
}

@Suite("DWD POI reading")
struct DWDPoiReadingTests {
    @Test("The card gets the value, the station and the local clock")
    func reading() throws {
        let reading = try DWDPoiTemperatureProvider.reading(
            station: .frankfurtAirport, csv: try poiFixture())
        #expect(reading.celsius == 19.7)
        #expect(reading.celsiusLabel == "19,7")
        #expect(reading.stationName == "Flughafen")
        // 18:00 UTC, rendered in Europe/Berlin — the summer offset is the
        // whole reason the stamp is not passed through as it arrives.
        #expect(reading.stampLabel == "20:00")
    }

    @Test("A whole degree still shows its decimal")
    func wholeDegree() throws {
        // Only the newest row matters, and it is the first `;19,7;` in the
        // file — the header lines carry no numbers.
        var csv = try poiFixture()
        let hit = try #require(csv.range(of: ";19,7;"))
        csv.replaceSubrange(hit, with: ";20;")
        let reading = try DWDPoiTemperatureProvider.reading(station: .frankfurtAirport, csv: csv)
        #expect(reading.celsius == 20)
        #expect(reading.celsiusLabel == "20,0")
    }

    @Test("The pinned station is the file the app actually fetches")
    func station() {
        #expect(PoiStation.frankfurtAirport.id == "10637")
        // The path is built from the id; a typo here is a 404 at runtime and
        // nowhere else.
        let url = URL(string: "https://opendata.dwd.de/weather/weather_reports/poi/")!
            .appending(path: "\(PoiStation.frankfurtAirport.id)-BEOB.csv")
        #expect(url.absoluteString == "https://opendata.dwd.de/weather/weather_reports/poi/10637-BEOB.csv")
    }
}

@Suite("DWD POI provider", .serialized)
struct DWDPoiProviderTests {
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.urlCache = nil
        return URLSession(configuration: config)
    }

    @Test("The staleness window answers from cache; invalidate goes back out")
    func caching() async throws {
        let counter = RequestCounter()
        let body = Data(try poiFixture().utf8)
        MockURLProtocol.setHandler(host: "opendata.dwd.de") { _ in
            counter.increment()
            return (200, [:], body)
        }
        let provider = DWDPoiTemperatureProvider(client: HTTPClient(session: session()))

        _ = try await provider.temperature()
        #expect(counter.value == 1)
        _ = try await provider.temperature()
        #expect(counter.value == 1)

        await (provider as any TemperatureProviding).invalidate()
        _ = try await provider.temperature()
        #expect(counter.value == 2)
    }

    @Test("A 5xx is an error the caller sees, not a stale reading")
    func serverError() async throws {
        MockURLProtocol.setHandler(host: "opendata.dwd.de") { _ in (503, [:], Data()) }
        let provider = DWDPoiTemperatureProvider(client: HTTPClient(session: session()))
        await #expect(throws: HTTPClientError.status(503)) {
            _ = try await provider.temperature()
        }
    }

    @Test("Offline surfaces as a failure, and nothing is cached from it")
    func offline() async throws {
        MockURLProtocol.setHandler(host: "opendata.dwd.de") { _ in
            throw URLError(.notConnectedToInternet)
        }
        let provider = DWDPoiTemperatureProvider(client: HTTPClient(session: session()))
        await #expect(throws: (any Error).self) { _ = try await provider.temperature() }

        // The next attempt must go back to the network rather than answer from
        // a half-filled cache.
        let counter = RequestCounter()
        let body = Data(try poiFixture().utf8)
        MockURLProtocol.setHandler(host: "opendata.dwd.de") { _ in
            counter.increment()
            return (200, [:], body)
        }
        _ = try await provider.temperature()
        #expect(counter.value == 1)
    }
}

/// Local to this file — `PegelOnlineTests` keeps its own for the same reason a
/// shared test helper would need a home nobody has picked yet.
private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}
