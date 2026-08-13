import Foundation

/// Fabricated nowcast until BEM-F01 wires DWD RADOLAN.
public struct SampleRadarProvider: RadarProviding {
    public static let nowcast = RadarNowcast(
        headline: "Regen in 25 Min",
        detail: "leicht, etwa 20 Minuten lang",
        clockLabel: "10:47",
        stampLabel: "10:45",
        progress: 0.4
    )

    public init() {}

    public func nowcast() async throws -> RadarNowcast {
        Self.nowcast
    }
}
