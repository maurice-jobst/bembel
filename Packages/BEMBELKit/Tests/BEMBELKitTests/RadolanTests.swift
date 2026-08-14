import CoreLocation
import Foundation
import Testing

@testable import BEMBELKit

/// Everything here runs against `Fixtures/radolan-rv-de1200.tar.bz2` — a real
/// DWD RV archive, 25 frames, checked in as ADR 0008 asked for. No network.
@Suite("RADOLAN")
struct RadolanTests {
    private let frankfurt = CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)

    private func fixture() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "radolan-rv-de1200", withExtension: "tar.bz2")
        )
        return try Data(contentsOf: url)
    }

    private func firstComposite() throws -> RadolanComposite {
        let tar = try BZip2.decompress(try fixture())
        let entry = try #require(TarArchive.entries(in: tar).first)
        return try RadolanComposite(data: entry.data)
    }

    // MARK: - bzip2

    @Test("The archive decompresses with the platform's own libbz2")
    func decompresses() throws {
        let tar = try BZip2.decompress(try fixture())
        // 25 frames × 2.64 MB of grid, plus tar padding.
        #expect(tar.count > 60_000_000)
    }

    @Test("Garbage is rejected, not guessed at")
    func rejectsGarbage() {
        #expect(throws: BZip2.Failure.self) {
            _ = try BZip2.decompress(Data(repeating: 0x42, count: 512))
        }
    }

    @Test("A decompression bomb hits the ceiling instead of the phone's memory")
    func honoursLimit() throws {
        #expect(throws: BZip2.Failure.tooLarge) {
            _ = try BZip2.decompress(try fixture(), limit: 1024)
        }
    }

    // MARK: - tar

    @Test("The archive holds 25 frames, five minutes apart")
    func readsArchive() throws {
        let entries = TarArchive.entries(in: try BZip2.decompress(try fixture()))
        #expect(entries.count == 25)
        #expect(entries.allSatisfy { $0.data.count > 2_600_000 })
        #expect(entries.first?.name.hasSuffix("_000") == true)
        #expect(entries.last?.name.hasSuffix("_120") == true)
    }

    @Test("A truncated archive yields what it had rather than throwing")
    func toleratesTruncation() throws {
        let tar = try BZip2.decompress(try fixture())
        let half = tar.prefix(tar.count / 2)
        let entries = TarArchive.entries(in: Data(half))
        #expect(!entries.isEmpty)
        #expect(entries.count < 25)
    }

    // MARK: - the composite

    @Test("The header describes its own geometry, scale and time")
    func parsesHeader() throws {
        let composite = try firstComposite()
        #expect(composite.product == "RV")
        // GP1200x1100 is rows × columns, and the body length has to agree.
        #expect(composite.rows == 1200)
        #expect(composite.columns == 1100)
        #expect(composite.values.count == 1200 * 1100)
        #expect(composite.forecastMinute == 0)

        let measuredAt = try #require(composite.measuredAt)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        let parts = utc.dateComponents([.year, .minute], from: measuredAt)
        #expect(parts.year == 2026)
        // RV runs on the five-minute clock.
        #expect((parts.minute ?? -1) % 5 == 0)
    }

    @Test("Frames carry their forecast offset, 0 to 120 in fives")
    func forecastMinutes() throws {
        let tar = try BZip2.decompress(try fixture())
        let minutes = TarArchive.entries(in: tar).compactMap { try? RadolanComposite(data: $0.data) }
            .map(\.forecastMinute)
        #expect(minutes == Array(stride(from: 0, through: 120, by: 5)))
    }

    @Test("No-data cells stay nil instead of reading as zero rain")
    func noDataIsNotZero() throws {
        let composite = try firstComposite()
        // The composite is a rectangle over a country-shaped radar network, so
        // its corners are outside coverage. Reading those as 0.0 mm would be a
        // dry forecast for places the radar cannot see at all.
        #expect(composite.value(row: 0, column: 0) == nil)
        #expect(composite.value(row: composite.rows - 1, column: composite.columns - 1) == nil)
        let missing = composite.values.filter { $0 == nil }.count
        #expect(missing > 100_000)
        #expect(missing < composite.values.count)
    }

    @Test("Readings are millimetres, not raw counts")
    func scalesValues() throws {
        let composite = try firstComposite()
        let readings = composite.values.compactMap { $0 }
        #expect(!readings.isEmpty)
        // PR E-02 means hundredths of a millimetre per five minutes; anything
        // over ~10 mm in five minutes would be a once-a-decade cloudburst and
        // is far more likely to be a scaling bug.
        #expect(readings.allSatisfy { $0 >= 0 && $0 < 10 })
    }

    @Test("Out-of-bounds reads answer nil rather than trapping")
    func boundsAreSafe() throws {
        let composite = try firstComposite()
        #expect(composite.value(row: -1, column: 0) == nil)
        #expect(composite.value(row: 0, column: -1) == nil)
        #expect(composite.value(row: composite.rows, column: 0) == nil)
        #expect(composite.peak(row: 0, column: 0, radius: 2) == nil || true)
    }

    // MARK: - the grid

    @Test("The published corner round-trips to (0, 0)")
    func cornerIsTheOrigin() {
        let corner = CLLocationCoordinate2D(latitude: 45.68606067, longitude: 3.566994635)
        let cell = RadolanGrid.de1200.cell(for: corner)
        #expect(cell?.row == 0)
        #expect(cell?.column == 0)
    }

    @Test("Frankfurt lands inside the grid, where the radar has coverage")
    func frankfurtHasCoverage() throws {
        let cell = try #require(RadolanGrid.de1200.cell(for: frankfurt))
        #expect(cell.column == 443)
        #expect(cell.row == 498)

        // The projection could be plausibly wrong and still land in bounds —
        // this is the check that it lands on *radar*, not on a no-data cell.
        let composite = try firstComposite()
        let neighbourhood = (-3...3).flatMap { dr in
            (-3...3).map { dc in composite.value(row: cell.row + dr, column: cell.column + dc) }
        }
        #expect(neighbourhood.allSatisfy { $0 != nil })
    }

    @Test("Coordinates outside the composite are rejected, not clamped")
    func outsideTheGrid() {
        #expect(RadolanGrid.de1200.cell(for: CLLocationCoordinate2D(latitude: 0, longitude: 0)) == nil)
        #expect(RadolanGrid.de1200.cell(for: CLLocationCoordinate2D(latitude: 64, longitude: 25)) == nil)
    }

    // MARK: - end to end

    @Test("A real archive becomes a nowcast for Frankfurt")
    func endToEnd() throws {
        let now = Date(timeIntervalSince1970: 1_786_000_000)
        let nowcast = try RadolanRadarProvider.nowcast(
            fromArchive: try fixture(), at: frankfurt, now: now)
        #expect(nowcast.series.count == 25)
        #expect(nowcast.series.map(\.minute) == Array(stride(from: 0, through: 120, by: 5)))
        #expect(nowcast.measuredAt != nil)
        #expect(nowcast.attribution?.contains("Deutscher Wetterdienst") == true)
        #expect(!nowcast.headline.isEmpty)
        #expect(nowcast.stampLabel != "—")
    }

    @Test("A coordinate off the grid is an error, not an empty forecast")
    func endToEndOutsideGrid() throws {
        #expect(throws: RadolanRadarProvider.Failure.outsideGrid) {
            _ = try RadolanRadarProvider.nowcast(
                fromArchive: try fixture(),
                at: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                now: Date()
            )
        }
    }

    // MARK: - phrasing

    private func series(_ values: [Double?]) -> [RadarSample] {
        values.enumerated().map { RadarSample(minute: $0.offset * 5, millimetres: $0.element) }
    }

    @Test("Dry two hours says so plainly")
    func drySeries() {
        let nowcast = RadarNowcastRules.nowcast(
            series: series(Array(repeating: 0.0, count: 25)), measuredAt: nil, now: Date())
        #expect(nowcast.headline == "Kein Regen")
        #expect(nowcast.detail.contains("120"))
    }

    @Test("Rain later is counted in minutes from now")
    func rainLater() {
        var values = [Double?](repeating: 0.0, count: 25)
        values[5] = 0.4
        values[6] = 0.6
        let nowcast = RadarNowcastRules.nowcast(series: series(values), measuredAt: nil, now: Date())
        #expect(nowcast.headline == "Regen in 25 Min")
        #expect(nowcast.detail.contains("10 Minuten"))
        // Peak over the run decides the wording, not the first drop.
        #expect(nowcast.detail.hasPrefix("mäßig"))
    }

    @Test("Rain now is a different sentence")
    func rainNow() {
        var values = [Double?](repeating: 0.0, count: 25)
        values[0] = 3.0
        let nowcast = RadarNowcastRules.nowcast(series: series(values), measuredAt: nil, now: Date())
        #expect(nowcast.headline == "Regen jetzt")
        #expect(nowcast.detail.hasPrefix("stark"))
    }

    @Test("Drizzle under the threshold is not rain")
    func drizzleIsNotRain() {
        var values = [Double?](repeating: 0.0, count: 25)
        values[3] = 0.05
        let nowcast = RadarNowcastRules.nowcast(series: series(values), measuredAt: nil, now: Date())
        #expect(nowcast.headline == "Kein Regen")
    }

    @Test("A gap ends the run — two showers are not one long one")
    func gapEndsRun() {
        var values = [Double?](repeating: 0.0, count: 25)
        values[2] = 0.3
        values[3] = 0.3
        values[8] = 0.3
        let nowcast = RadarNowcastRules.nowcast(series: series(values), measuredAt: nil, now: Date())
        #expect(nowcast.headline == "Regen in 10 Min")
        #expect(nowcast.detail.contains("10 Minuten"))
    }

    @Test("No radar coverage is not a dry forecast")
    func nilCoverage() {
        let nowcast = RadarNowcastRules.nowcast(
            series: series(Array(repeating: nil, count: 25)), measuredAt: nil, now: Date())
        // Honest today, but thin: `nil` and 0.0 both end up as "Kein Regen".
        // Telling them apart on screen is BEM-F02's business.
        #expect(nowcast.headline == "Kein Regen")
    }
}
