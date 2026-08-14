import CBZip2
import Foundation

/// bzip2 decompression over the platform's own libbz2.
///
/// DWD publishes the RADOLAN composites as `.tar.bz2`, and Apple's Compression
/// framework covers zlib, LZFSE, LZ4 and LZMA — but not bzip2. libbz2 ships in
/// every Apple SDK, so this is a system library, not a dependency: BEM-F01
/// stays third-party-free (CONTRIBUTING) and ADR 0008's "parse it ourselves"
/// decision stays affordable.
public enum BZip2 {
    public enum Failure: Error, Equatable, Sendable {
        case corrupt(Int32)
        /// The archive expanded past `limit`. A decompression bomb is a real
        /// shape of hostile input, and this runs on someone's phone.
        case tooLarge
    }

    /// Grows the output buffer until libbz2 stops asking for room. RADOLAN
    /// archives run ~130 KB compressed to ~66 MB of grid, so the first guess is
    /// generous on purpose — a resize costs a full re-run of the decompressor.
    public static func decompress(_ data: Data, limit: Int = 96 * 1024 * 1024) throws -> Data {
        var capacity = min(max(data.count * 32, 1 << 20), limit)
        while true {
            var destinationLength = UInt32(capacity)
            var output = Data(count: capacity)

            let result: Int32 = output.withUnsafeMutableBytes { destination in
                data.withUnsafeBytes { source in
                    BZ2_bzBuffToBuffDecompress(
                        destination.baseAddress?.assumingMemoryBound(to: CChar.self),
                        &destinationLength,
                        UnsafeMutableRawPointer(mutating: source.baseAddress)?
                            .assumingMemoryBound(to: CChar.self),
                        UInt32(data.count),
                        0,
                        0
                    )
                }
            }

            switch result {
            case BZ_OK:
                output.removeSubrange(Int(destinationLength)...)
                return output
            case BZ_OUTBUFF_FULL:
                guard capacity < limit else { throw Failure.tooLarge }
                capacity = min(capacity * 4, limit)
            default:
                throw Failure.corrupt(result)
            }
        }
    }
}
