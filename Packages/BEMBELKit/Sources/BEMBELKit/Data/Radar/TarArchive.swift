import Foundation

/// Just enough tar to read DWD's RADOLAN bundles: the archive is 25 plain
/// files with no directories, links or extensions, and writing 60 lines beats
/// taking a dependency to read a 512-byte header (CONTRIBUTING: no third-party
/// packages without PM approval).
public enum TarArchive {
    public struct Entry: Sendable {
        public let name: String
        public let data: Data
    }

    private static let blockSize = 512

    /// Entries in archive order. Anything that is not a plain file is skipped,
    /// and a truncated archive yields what it had rather than throwing — a
    /// short download should cost the last frame, not the whole nowcast.
    public static func entries(in archive: Data) -> [Entry] {
        var entries: [Entry] = []
        var offset = 0

        while offset + blockSize <= archive.count {
            let header = archive[archive.startIndex + offset..<archive.startIndex + offset + blockSize]
            // Two zero blocks mark the end; one is enough to stop reading.
            if header.allSatisfy({ $0 == 0 }) { break }

            guard
                let name = string(header, at: 0, length: 100),
                !name.isEmpty,
                let size = octal(header, at: 124, length: 12)
            else { break }

            // '0' and NUL both mean "regular file"; everything else we skip.
            let typeFlag = header[header.startIndex + 156]
            let start = offset + blockSize
            let end = start + size
            guard end <= archive.count else { break }

            if typeFlag == UInt8(ascii: "0") || typeFlag == 0 {
                entries.append(
                    Entry(
                        name: name,
                        data: archive[archive.startIndex + start..<archive.startIndex + end]
                    )
                )
            }
            // Payloads are padded to a block boundary.
            offset = start + ((size + blockSize - 1) / blockSize) * blockSize
        }
        return entries
    }

    private static func string(_ block: Data, at index: Int, length: Int) -> String? {
        let start = block.startIndex + index
        let slice = block[start..<start + length]
        let trimmed = slice.prefix { $0 != 0 }
        return String(data: Data(trimmed), encoding: .utf8)?.trimmingCharacters(in: .whitespaces)
    }

    private static func octal(_ block: Data, at index: Int, length: Int) -> Int? {
        guard let raw = string(block, at: index, length: length) else { return nil }
        let digits = raw.prefix { $0.isNumber }
        return Int(digits, radix: 8)
    }
}
