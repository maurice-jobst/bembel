import Foundation

/// The rain nowcast headline plus the state of the −60…+90 min timeline.
public struct RadarNowcast: Sendable {
    /// "Regen in 25 Min"
    public let headline: String
    /// "leicht, etwa 20 Minuten lang"
    public let detail: String
    /// Clock label at the playhead ("10:47").
    public let clockLabel: String
    /// Data stamp of the radar composite ("10:45").
    public let stampLabel: String
    /// Playhead position along the timeline, 0…1.
    public let progress: Double

    public init(headline: String, detail: String, clockLabel: String, stampLabel: String, progress: Double) {
        self.headline = headline
        self.detail = detail
        self.clockLabel = clockLabel
        self.stampLabel = stampLabel
        self.progress = progress
    }
}
