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
        let nowcast = try RadolanRadarProvider.nowcast(fromArchive: try fixture(), at: frankfurt)
        #expect(nowcast.series.count == 25)
        #expect(nowcast.series.map(\.minute) == Array(stride(from: 0, through: 120, by: 5)))
        #expect(nowcast.measuredAt != nil)
        #expect(nowcast.attribution?.contains("Deutscher Wetterdienst") == true)
        #expect(nowcast.stampLabel != "—")
        #expect(nowcast.horizonMinutes == 120)
    }

    @Test("Every step carries a drawable frame, in the same order as the series")
    func endToEndFrames() throws {
        let nowcast = try RadolanRadarProvider.nowcast(fromArchive: try fixture(), at: frankfurt)
        #expect(nowcast.frames.count == nowcast.series.count)
        #expect(nowcast.frames.map(\.minute) == nowcast.series.map(\.minute))
        #expect(nowcast.frames.allSatisfy { $0.width == RadarRaster.width })
        #expect(nowcast.frames.allSatisfy { $0.millimetres.count == RadarRaster.width * RadarRaster.height })
        // Rhein-Main is inside the radar's coverage, so a real frame must not
        // be entirely no-data — that would mean the box is in the wrong place.
        #expect(nowcast.frames.contains { !$0.isEmpty })
    }

    @Test("The playhead's clock is the composite's time plus the step")
    func frameClock() throws {
        let nowcast = try RadolanRadarProvider.nowcast(fromArchive: try fixture(), at: frankfurt)
        let measuredAt = try #require(nowcast.measuredAt)
        let atNow = try #require(nowcast.clockLabel(atMinute: 0))
        let plusHour = try #require(nowcast.clockLabel(atMinute: 60))
        #expect(atNow == DateFormatter.berlinClock.string(from: measuredAt))
        #expect(plusHour == DateFormatter.berlinClock.string(from: measuredAt.addingTimeInterval(3600)))
        // No measurement time means no clock, rather than a guessed one.
        #expect(RadarNowcast(outlook: .noData).clockLabel(atMinute: 0) == nil)
    }

    @Test("A coordinate off the grid is an error, not an empty forecast")
    func endToEndOutsideGrid() throws {
        #expect(throws: RadolanRadarProvider.Failure.outsideGrid) {
            _ = try RadolanRadarProvider.nowcast(
                fromArchive: try fixture(),
                at: CLLocationCoordinate2D(latitude: 0, longitude: 0)
            )
        }
    }

    // MARK: - outlook

    private func series(_ values: [Double?]) -> [RadarSample] {
        values.enumerated().map { RadarSample(minute: $0.offset * 5, millimetres: $0.element) }
    }

    private func outlook(_ values: [Double?]) -> RainOutlook {
        RadarNowcastRules.outlook(series: series(values))
    }

    @Test("Dry two hours says so plainly")
    func drySeries() {
        #expect(outlook(Array(repeating: 0.0, count: 25)) == .dry(horizonMinutes: 120))
    }

    @Test("Rain later is counted in minutes from now")
    func rainLater() {
        var values = [Double?](repeating: 0.0, count: 25)
        values[5] = 0.4
        values[6] = 0.6
        // Peak over the run decides the intensity, not the first drop.
        #expect(
            outlook(values) == .rainStarting(inMinutes: 25, intensity: .moderate, lastingMinutes: 10))
    }

    @Test("Rain now is a different case, and it says how much longer")
    func rainNow() {
        var values = [Double?](repeating: 0.0, count: 25)
        values[0] = 3.0
        #expect(outlook(values) == .rainingNow(intensity: .heavy, minutesRemaining: 5))
    }

    @Test("Rain past the end of the forecast admits it cannot see the end")
    func rainBeyondHorizon() {
        // `minutesRemaining: nil` is the difference between "it stops at 12:20"
        // and "we cannot see that far". Rendering the second as the first would
        // be the radar promising something it never measured.
        #expect(
            outlook(Array(repeating: 3.0, count: 25))
                == .rainingNow(intensity: .heavy, minutesRemaining: nil))
    }

    @Test("Drizzle under the threshold is not rain")
    func drizzleIsNotRain() {
        var values = [Double?](repeating: 0.0, count: 25)
        values[3] = 0.05
        #expect(outlook(values) == .dry(horizonMinutes: 120))
    }

    @Test("A gap ends the run — two showers are not one long one")
    func gapEndsRun() {
        var values = [Double?](repeating: 0.0, count: 25)
        values[2] = 0.3
        values[3] = 0.3
        values[8] = 0.3
        #expect(outlook(values) == .rainStarting(inMinutes: 10, intensity: .light, lastingMinutes: 10))
    }

    @Test("No radar coverage is not a dry forecast")
    func nilCoverage() {
        // This is what BEM-F02 promised to fix: `nil` and 0.0 used to collapse
        // into the same "Kein Regen". They are now different cases and the
        // screen renders them differently.
        #expect(outlook(Array(repeating: nil, count: 25)) == .noData)
        #expect(outlook(Array(repeating: 0.0, count: 25)) != .noData)
    }

    @Test("Intensity thresholds are the published boundaries, not a feel")
    func intensityBands() {
        #expect(RadarNowcastRules.intensity(0.49) == .light)
        #expect(RadarNowcastRules.intensity(0.5) == .moderate)
        #expect(RadarNowcastRules.intensity(1.99) == .moderate)
        #expect(RadarNowcastRules.intensity(2.0) == .heavy)
    }
}

/// Where the rain is drawn, as opposed to what it says. Separate suite because
/// this is pure geometry and does not need the archive.
@Suite("RADOLAN geometry")
struct RadolanGeometryTests {
    private let frankfurt = CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)

    @Test("The projection inverts exactly, corner and centre alike")
    func roundTrip() throws {
        for (latitude, longitude) in [
            (50.1109, 8.6821),  // Frankfurt
            (45.68606067, 3.566994635),  // the published south-west corner
            (55.0, 15.0), (47.0, 5.5), (50.0, 10.0),  // on the central meridian
        ] {
            let point = RadolanGrid.project(latitude: latitude, longitude: longitude)
            let back = RadolanGrid.unproject(x: point.x, y: point.y)
            #expect(abs(back.latitude - latitude) < 1e-9)
            #expect(abs(back.longitude - longitude) < 1e-9)
        }
    }

    @Test("A cell's centre lands back in that same cell")
    func cellRoundTrip() throws {
        let grid = RadolanGrid.de1200
        let cell = try #require(grid.cell(for: frankfurt))
        let centre = grid.coordinate(row: cell.row, column: cell.column)
        let again = try #require(grid.cell(for: centre))
        #expect(again.row == cell.row)
        #expect(again.column == cell.column)
        // And it is genuinely near Frankfurt, not merely self-consistent.
        #expect(abs(centre.latitude - frankfurt.latitude) < 0.01)
        #expect(abs(centre.longitude - frankfurt.longitude) < 0.02)
    }

    @Test("Grid north is not true north, which is why the raster is resampled")
    func gridRotation() {
        let grid = RadolanGrid.de1200
        let cell = grid.cell(for: frankfurt)!
        let here = grid.coordinate(row: cell.row, column: cell.column)
        // Walk 40 cells "up" the grid and see how far east the longitude drifts.
        // If the grid were axis-aligned this would be zero; it is not, and at
        // 40 km the drift is most of a kilometre. Stretching the raw grid into
        // a lat/lon rectangle would put that error on screen.
        let north = grid.coordinate(row: cell.row + 40, column: cell.column)
        let drift = abs(north.longitude - here.longitude)
        #expect(drift > 0.005)
        #expect(drift < 0.05)
    }

    @Test("The Rhein-Main box contains the cities it claims to")
    func boundsCoverRheinMain() {
        let bounds = RadarBounds.rheinMain
        for (name, latitude, longitude) in [
            ("Frankfurt", 50.1109, 8.6821),
            ("Wiesbaden", 50.0825, 8.2400),
            ("Darmstadt", 49.8728, 8.6512),
            ("Hanau", 50.1330, 8.9160),
            ("Bad Homburg", 50.2268, 8.6180),
        ] {
            let inside =
                (bounds.south...bounds.north).contains(latitude)
                && (bounds.west...bounds.east).contains(longitude)
            #expect(inside, "\(name) is outside the drawn box")
        }
        // Wiesbaden sits 0.14° west of the box edge at 8.24 — the box starts at
        // 8.10 on purpose, so the western half of the region is not cut off.
        #expect(bounds.west < 8.24)
    }
}

@Suite("RADOLAN resampling")
struct RadolanResamplerTests {
    /// A synthetic composite: every cell no-data except a single 1 km square at
    /// a known grid position. Where that square lands in the output frame is
    /// the whole question this suite exists to answer.
    private func spike(atRow row: Int, column: Int, minute: Int = 0) throws -> RadolanComposite {
        let grid = RadolanGrid.de1200
        var header = Data(
            "RV\(String(format: "%02d", minute))BY1120001VS 3SW   0.0.0PR E-02INT   5GP1200x1100VV   \(minute)MS 1<xyz>"
                .utf8)
        header.append(0x03)
        var body = [UInt16](repeating: 0x29C4, count: grid.rows * grid.columns)
        body[row * grid.columns + column] = 250  // 2.50 mm at PR E-02
        var data = header
        for word in body {
            data.append(UInt8(word & 0xFF))
            data.append(UInt8(word >> 8))
        }
        return try RadolanComposite(data: data)
    }

    @Test("A single lit cell lands at its own coordinate in the output frame")
    func spikePlacement() throws {
        let grid = RadolanGrid.de1200
        let frankfurt = CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)
        let cell = try #require(grid.cell(for: frankfurt))
        let composite = try spike(atRow: cell.row, column: cell.column)

        let frame = RadolanResampler.frame(from: composite, grid: grid)
        let lit = (0..<frame.height).flatMap { y in
            (0..<frame.width).compactMap { x in frame.value(x: x, y: y) != nil ? (x, y) : nil }
        }
        #expect(!lit.isEmpty)

        // Every lit pixel must sit where Frankfurt is in the box: x from the
        // west edge, y from the *north* edge, because an image counts rows
        // downwards and the composite counts them upwards.
        let bounds = RadarBounds.rheinMain
        let expectedX = (frankfurt.longitude - bounds.west) / bounds.longitudeSpan * Double(frame.width)
        let expectedY = (bounds.north - frankfurt.latitude) / bounds.latitudeSpan * Double(frame.height)
        for (x, y) in lit {
            #expect(abs(Double(x) - expectedX) < 3)
            #expect(abs(Double(y) - expectedY) < 3)
        }
        // 1 km of source at ~0.6 km per pixel: a handful of pixels, not one and
        // not a quarter of the frame.
        #expect((1...12).contains(lit.count))
    }

    @Test("The image is not flipped — south stays south")
    func verticalOrientation() throws {
        let grid = RadolanGrid.de1200
        let north = try #require(
            grid.cell(for: CLLocationCoordinate2D(latitude: 50.45, longitude: 8.65)))
        let frame = RadolanResampler.frame(
            from: try spike(atRow: north.row, column: north.column), grid: grid)
        let ys = (0..<frame.height).filter { y in
            (0..<frame.width).contains { frame.value(x: $0, y: y) != nil }
        }
        // A northern spike belongs in the top rows of the image.
        #expect(try #require(ys.first) < frame.height / 4)
    }

    @Test("Values survive the resample as millimetres, not raw counts")
    func valueScale() throws {
        let grid = RadolanGrid.de1200
        let cell = try #require(
            grid.cell(for: CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)))
        let frame = RadolanResampler.frame(
            from: try spike(atRow: cell.row, column: cell.column), grid: grid)
        let values = frame.millimetres.filter { !$0.isNaN }
        #expect(values.allSatisfy { abs($0 - 2.5) < 0.001 })
    }

    @Test("No-data stays no-data, and an empty frame knows it is empty")
    func emptyFrame() throws {
        let grid = RadolanGrid.de1200
        // A spike far outside the Rhein-Main box: nothing to draw here.
        let elsewhere = try #require(
            grid.cell(for: CLLocationCoordinate2D(latitude: 53.55, longitude: 9.99)))
        let frame = RadolanResampler.frame(
            from: try spike(atRow: elsewhere.row, column: elsewhere.column), grid: grid)
        #expect(frame.isEmpty)
        #expect(frame.value(x: 0, y: 0) == nil)
        // Out of bounds reads answer nil rather than trapping.
        #expect(frame.value(x: -1, y: 0) == nil)
        #expect(frame.value(x: frame.width, y: 0) == nil)
    }
}

@Suite("Rain intensity bands")
struct RadarBandTests {
    @Test("Bands are read in mm/h, and the step conversion is not forgotten")
    func stepConversion() {
        // The trap: RADOLAN reports millimetres per five-minute step. 0.1 mm
        // per step is 1.2 mm/h — real, drawable rain. Reading it as 0.1 mm/h
        // would put it under the floor and draw nothing at all.
        #expect(RadarRaster.band(millimetresPerHour: 1.2) == 1)
        #expect(RadarRaster.band(millimetresPerStep: 0.1) == 1)
        #expect(RadarRaster.stepsPerHour == 12)
    }

    @Test("Every boundary lands in its own band, and drizzle lands in none")
    func boundaries() {
        for (index, boundary) in RadarRaster.bands.enumerated() {
            #expect(RadarRaster.band(millimetresPerHour: boundary) == index)
        }
        // Just under a boundary belongs to the band below it.
        #expect(RadarRaster.band(millimetresPerHour: 0.99) == 0)
        #expect(RadarRaster.band(millimetresPerHour: 19.99) == 4)
        // The top band is open-ended: a cloudburst is not off the scale.
        #expect(RadarRaster.band(millimetresPerHour: 500) == RadarRaster.bands.count - 1)
        // Under the floor, and no-data, draw nothing rather than a faint wash.
        #expect(RadarRaster.band(millimetresPerHour: 0.49) == nil)
        #expect(RadarRaster.band(millimetresPerHour: 0) == nil)
        #expect(RadarRaster.band(millimetresPerStep: .nan) == nil)
    }

    @Test("The bands rise monotonically, which is what a sequential scale means")
    func monotonic() {
        #expect(zip(RadarRaster.bands, RadarRaster.bands.dropFirst()).allSatisfy { $0 < $1 })
    }
}
