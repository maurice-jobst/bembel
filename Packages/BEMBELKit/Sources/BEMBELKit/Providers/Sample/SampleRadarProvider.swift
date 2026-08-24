import Foundation

/// Previews only. The live radar is `RadolanRadarProvider` (BEM-F01), and the
/// map draws its real frames (BEM-F02).
///
/// No frames here, deliberately. A fabricated rain field would be a picture of
/// weather that is not happening, drawn over a real map at real coordinates —
/// the sample overlay this app used to ship, and the same mistake as the
/// invented 3,42 m gauge level. A preview showing the empty-frame state is the
/// honest stand-in.
public struct SampleRadarProvider: RadarProviding {
    public static let nowcast = RadarNowcast(
        outlook: .rainStarting(inMinutes: 25, intensity: .light, lastingMinutes: 20),
        series: (0...120).filter { $0 % 5 == 0 }.map { minute in
            RadarSample(minute: minute, millimetres: (25...45).contains(minute) ? 0.3 : 0)
        },
        stampLabel: "10:45"
    )

    public init() {}

    public func nowcast() async throws -> RadarNowcast {
        Self.nowcast
    }
}
