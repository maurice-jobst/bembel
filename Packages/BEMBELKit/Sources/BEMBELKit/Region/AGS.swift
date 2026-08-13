import Foundation

/// Amtlicher Gemeindeschlüssel — 8 ASCII digits, e.g. 06412000 for Frankfurt.
/// Invalid strings are unrepresentable; decoding a malformed key throws.
public struct AGS: Hashable, Sendable, RawRepresentable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        guard rawValue.utf8.count == 8, rawValue.utf8.allSatisfy({ $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let ags = AGS(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "'\(raw)' is not an 8-digit Gemeindeschlüssel"
            )
        }
        self = ags
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}
