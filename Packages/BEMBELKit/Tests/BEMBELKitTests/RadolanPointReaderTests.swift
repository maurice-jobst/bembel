import CoreLocation
import Foundation
import Testing

@testable import BEMBELKit

/// The widget's reader against the map's, on the same real archive. The point
/// reader exists only because the map path does not fit in a widget extension
/// (ADR 0011); if the two ever disagree about a point, the widget is wrong.
@Suite("RADOLAN point reader")
struct RadolanPointReaderTests {
    private let frankfurt = CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)

    private func fixture() throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: "radolan-rv-de1200", withExtension: "tar.bz2")
        )
        return try Data(contentsOf: url)
    }

    private func expectSameSeries(at coordinate: CLLocationCoordinate2D) throws {
        let archive = try fixture()
        let map = try RadolanRadarProvider.nowcast(fromArchive: archive, at: coordinate)
        let point = try RadolanPointReader.nowcast(fromArchive: archive, at: coordinate)
        #expect(point.series == map.series)
        #expect(point.outlook == map.outlook)
        #expect(point.measuredAt == map.measuredAt)
        #expect(point.frames.isEmpty)
    }

    @Test("Frankfurt reads the same series either way")
    func frankfurtMatches() throws {
        try expectSameSeries(at: frankfurt)
    }

    @Test("Where it is actually raining, too — a dry match proves little")
    func wetCellMatches() throws {
        // The wettest cell of the last frame, so the comparison covers real
        // readings and not a run of zeros.
        let tar = try BZip2.decompress(try fixture())
        let entry = try #require(TarArchive.entries(in: tar).last)
        let composite = try RadolanComposite(data: entry.data)
        let wettest = try #require(
            composite.values.indices.max { (composite.values[$0] ?? -1) < (composite.values[$1] ?? -1) }
        )
        #expect((composite.values[wettest] ?? 0) > 0)

        let coordinate = RadolanGrid.de1200.coordinate(
            row: wettest / composite.columns, column: wettest % composite.columns)
        try expectSameSeries(at: coordinate)
        let series = try RadolanPointReader.nowcast(fromArchive: try fixture(), at: coordinate).series
        #expect(series.contains { ($0.millimetres ?? 0) > 0 })
    }

    @Test("At the grid's corner the neighbourhood is clipped the same way")
    func cornerMatches() throws {
        try expectSameSeries(at: RadolanGrid.de1200.coordinate(row: 0, column: 0))
    }

    @Test("Chunk boundaries do not matter — headers and cells may straddle them")
    func chunkingIsInvisible() throws {
        let tar = try BZip2.decompress(try fixture())
        let cell = try #require(RadolanGrid.de1200.cell(for: frankfurt))

        func samples(chunk: Int) -> [RadarSample] {
            var stream = RadolanPointReader.TarStream(row: cell.row, column: cell.column)
            tar.withUnsafeBytes { raw in
                var offset = 0
                while offset < raw.count {
                    let end = min(offset + chunk, raw.count)
                    stream.consume(UnsafeRawBufferPointer(rebasing: raw[offset..<end]))
                    offset = end
                }
            }
            stream.finish()
            return stream.samples
        }

        // Primes, so no size lines up with the 512-byte tar blocks.
        let reference = samples(chunk: 65_536)
        #expect(reference.count == 25)
        for chunk in [7, 509, 4_099] {
            #expect(samples(chunk: chunk) == reference)
        }
    }

    @Test("A truncated download is refused, as the map path refuses it")
    func truncatedIsRefused() throws {
        let archive = try fixture()
        let cut = archive.prefix(archive.count / 2)
        #expect(throws: RadolanRadarProvider.Failure.unreadableArchive) {
            _ = try RadolanRadarProvider.nowcast(fromArchive: Data(cut), at: frankfurt)
        }
        #expect(throws: RadolanRadarProvider.Failure.unreadableArchive) {
            _ = try RadolanPointReader.nowcast(fromArchive: Data(cut), at: frankfurt)
        }
    }

    @Test("Garbage and bombs are refused, not guessed at")
    func garbageAndBombs() throws {
        #expect(throws: RadolanRadarProvider.Failure.unreadableArchive) {
            _ = try RadolanPointReader.nowcast(fromArchive: Data(repeating: 0x42, count: 512), at: frankfurt)
        }
        #expect(throws: RadolanRadarProvider.Failure.unreadableArchive) {
            _ = try RadolanPointReader.nowcast(fromArchive: try fixture(), at: frankfurt, limit: 1024)
        }
    }

    @Test("A coordinate off the grid is an error, not an empty forecast")
    func outsideGrid() throws {
        #expect(throws: RadolanRadarProvider.Failure.outsideGrid) {
            _ = try RadolanPointReader.nowcast(
                fromArchive: try fixture(), at: CLLocationCoordinate2D(latitude: 40.0, longitude: -3.7))
        }
    }
}
