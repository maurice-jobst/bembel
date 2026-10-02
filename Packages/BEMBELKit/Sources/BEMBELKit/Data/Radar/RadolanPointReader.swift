import CBZip2
import CoreLocation
import Foundation

/// The nowcast at one point, read in a single pass without ever holding a grid.
///
/// `RadolanRadarProvider.nowcast(fromArchive:)` is built for the map: it inflates
/// the ~130 KB archive to ~66 MB of tar and parses every frame into 1.3 million
/// cells. A widget extension gets about 30 MB in total, so it cannot take that
/// path (ADR 0011). This one streams — bzip2 in 64 KB chunks, tar headers as
/// they pass, and of each frame's 2.6 MB of grid it keeps the nine cells around
/// the point. The series it produces is the one the map path computes; the
/// tests hold the two against each other on the real fixture.
public enum RadolanPointReader {
    /// The same nowcast `RadolanRadarProvider` would give for `coordinate`,
    /// minus the frames — a widget has no map to draw them on.
    public static func nowcast(
        fromArchive archive: Data,
        at coordinate: CLLocationCoordinate2D,
        grid: RadolanGrid = .de1200,
        limit: Int = 96 * 1024 * 1024
    ) throws -> RadarNowcast {
        guard let cell = grid.cell(for: coordinate) else { throw RadolanRadarProvider.Failure.outsideGrid }

        var tar = TarStream(row: cell.row, column: cell.column)
        do {
            try inflate(archive, limit: limit) { chunk in tar.consume(chunk) }
        } catch {
            // Corrupt, cut short or over the ceiling: the map path refuses all
            // three the same way, and the two readers must not disagree.
            throw RadolanRadarProvider.Failure.unreadableArchive
        }
        tar.finish()

        guard !tar.samples.isEmpty else { throw RadolanRadarProvider.Failure.noUsableFrames }
        return RadarNowcastRules.nowcast(
            series: tar.samples.sorted { $0.minute < $1.minute },
            measuredAt: tar.measuredAt
        )
    }

    // MARK: - bzip2, in chunks

    /// Hands the decompressed stream to `sink` 64 KB at a time. The same
    /// ceiling as `BZip2.decompress` — a bomb is a bomb whether it is buffered
    /// or streamed — but nothing here grows with the archive.
    static func inflate(_ archive: Data, limit: Int, into sink: (UnsafeRawBufferPointer) -> Void) throws {
        var stream = bz_stream()
        guard BZ2_bzDecompressInit(&stream, 0, 0) == BZ_OK else { throw BZip2.Failure.corrupt(BZ_MEM_ERROR) }
        defer { BZ2_bzDecompressEnd(&stream) }

        var output = [UInt8](repeating: 0, count: 64 * 1024)
        var produced = 0
        try archive.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
            stream.next_in = UnsafeMutablePointer(
                mutating: input.baseAddress?.assumingMemoryBound(to: CChar.self))
            stream.avail_in = UInt32(input.count)

            while true {
                let (result, written) = output.withUnsafeMutableBytes { buffer -> (Int32, Int) in
                    stream.next_out = buffer.baseAddress?.assumingMemoryBound(to: CChar.self)
                    stream.avail_out = UInt32(buffer.count)
                    let result = BZ2_bzDecompress(&stream)
                    return (result, buffer.count - Int(stream.avail_out))
                }
                guard result == BZ_OK || result == BZ_STREAM_END else { throw BZip2.Failure.corrupt(result) }

                produced += written
                guard produced <= limit else { throw BZip2.Failure.tooLarge }
                output.withUnsafeBytes { sink(UnsafeRawBufferPointer(rebasing: $0[0..<written])) }

                if result == BZ_STREAM_END { return }
                // Input spent before the stream said it was done: a truncated
                // download. The last block's bytes were never checked against
                // its CRC, so nothing decoded from it can be trusted — the same
                // refusal `BZip2.decompress` gives (BZ_UNEXPECTED_EOF).
                if written == 0 && stream.avail_in == 0 { throw BZip2.Failure.corrupt(BZ_UNEXPECTED_EOF) }
            }
        }
    }

    // MARK: - tar, as it passes

    /// `TarArchive.entries(in:)` as a state machine over chunks. Same rules:
    /// stop at the first zero block or unreadable header, skip anything that is
    /// not a plain file, and let a short archive cost only its last frame.
    struct TarStream {
        private static let blockSize = 512

        private enum State {
            case header
            case payload(remaining: Int, padding: Int, frame: FrameStream?)
            case padding(remaining: Int)
            case done
        }

        private var state = State.header
        private var headerBytes = Data()
        private let row: Int
        private let column: Int
        private(set) var samples: [RadarSample] = []
        private(set) var measuredAt: Date?

        init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }

        mutating func consume(_ chunk: UnsafeRawBufferPointer) {
            var offset = 0
            while offset < chunk.count {
                switch state {
                case .done:
                    return

                case .header:
                    let take = min(Self.blockSize - headerBytes.count, chunk.count - offset)
                    headerBytes.append(contentsOf: chunk[offset..<offset + take])
                    offset += take
                    if headerBytes.count == Self.blockSize {
                        state = nextState(after: headerBytes)
                        headerBytes.removeAll(keepingCapacity: true)
                    }

                case .payload(let remaining, let padding, var frame):
                    let take = min(remaining, chunk.count - offset)
                    frame?.consume(UnsafeRawBufferPointer(rebasing: chunk[offset..<offset + take]))
                    offset += take
                    if take == remaining {
                        if let frame { collect(frame) }
                        state = padding > 0 ? .padding(remaining: padding) : .header
                    } else {
                        state = .payload(remaining: remaining - take, padding: padding, frame: frame)
                    }

                case .padding(let remaining):
                    let take = min(remaining, chunk.count - offset)
                    offset += take
                    state = take == remaining ? .header : .padding(remaining: remaining - take)
                }
            }
        }

        /// The stream ended. A payload still open was cut short: dropped, not
        /// half-read, exactly as `TarArchive` drops an entry past the end.
        mutating func finish() {
            state = .done
        }

        private func nextState(after header: Data) -> State {
            // Two zero blocks mark the end; one is enough to stop reading.
            if header.allSatisfy({ $0 == 0 }) { return .done }
            guard
                let name = TarArchive.string(header, at: 0, length: 100),
                !name.isEmpty,
                let size = TarArchive.octal(header, at: 124, length: 12)
            else { return .done }

            // '0' and NUL both mean "regular file"; everything else we skip.
            let typeFlag = header[header.startIndex + 156]
            let isFile = typeFlag == UInt8(ascii: "0") || typeFlag == 0
            let padding = (Self.blockSize - size % Self.blockSize) % Self.blockSize
            if size == 0 {
                return padding > 0 ? .padding(remaining: padding) : .header
            }
            return .payload(
                remaining: size, padding: padding, frame: isFile ? FrameStream(row: row, column: column) : nil)
        }

        private mutating func collect(_ frame: FrameStream) {
            // One malformed frame costs that frame, never the whole nowcast.
            guard let sample = frame.sample else { return }
            if measuredAt == nil { measuredAt = frame.header?.measuredAt }
            samples.append(sample)
        }
    }

    // MARK: - one frame, nine cells

    /// Reads a composite's header, then lets the grid stream past and keeps
    /// only the bytes of the cells `RadolanComposite.peak(row:column:)` would
    /// look at. Holds at most a header and eighteen bytes.
    struct FrameStream {
        /// DWD headers run ~100 bytes. A frame with no ETX by here is not a
        /// composite, and buffering further would be buffering the grid.
        private static let maxHeaderLength = 4096

        private let row: Int
        private let column: Int
        private var headerBytes = Data()
        private(set) var header: RadolanComposite.Header?
        private var broken = false
        private var bodyRead = 0
        /// Byte offset in the body → cell index in `cells`, low or high byte.
        private var wanted: [Int: (cell: Int, high: Bool)] = [:]
        private var cells: [(low: UInt8?, high: UInt8?)] = []

        init(row: Int, column: Int) {
            self.row = row
            self.column = column
        }

        mutating func consume(_ bytes: UnsafeRawBufferPointer) {
            guard !broken else { return }
            var offset = 0
            if header == nil {
                guard let etx = bytes.firstIndex(of: 0x03) else {
                    headerBytes.append(contentsOf: bytes)
                    if headerBytes.count > Self.maxHeaderLength { broken = true }
                    return
                }
                headerBytes.append(contentsOf: bytes[0..<etx])
                guard let parsed = try? RadolanComposite.Header(headerBytes) else {
                    broken = true
                    return
                }
                header = parsed
                plan(parsed)
                offset = etx + 1
            }

            let start = bodyRead
            let count = bytes.count - offset
            bodyRead += count
            // Eighteen lookups per chunk, not one per byte of grid.
            for (position, target) in wanted where position >= start && position < start + count {
                let byte = bytes[offset + position - start]
                if target.high { cells[target.cell].high = byte } else { cells[target.cell].low = byte }
            }
        }

        /// The 3×3 neighbourhood `peak(row:column:)` reads, clipped to the grid
        /// the header declares — the same clipping `value(row:column:)` does.
        private mutating func plan(_ header: RadolanComposite.Header) {
            for dr in -1...1 {
                for dc in -1...1 {
                    let r = row + dr
                    let c = column + dc
                    guard (0..<header.rows).contains(r), (0..<header.columns).contains(c) else { continue }
                    let position = (r * header.columns + c) * 2
                    wanted[position] = (cells.count, false)
                    wanted[position + 1] = (cells.count, true)
                    cells.append((nil, nil))
                }
            }
        }

        /// `nil` when the frame was not a composite or ended before its grid
        /// did — `RadolanComposite` throws `truncated` there, and the map path
        /// drops the frame for it.
        var sample: RadarSample? {
            guard !broken, let header, bodyRead >= header.bodyLength else { return nil }
            var peak: Double?
            for cell in cells {
                guard let low = cell.low, let high = cell.high,
                    let reading = RadolanComposite.reading(low: low, high: high, scale: header.scale)
                else { continue }
                peak = max(peak ?? 0, reading)
            }
            return RadarSample(minute: header.forecastMinute, millimetres: peak)
        }
    }
}
