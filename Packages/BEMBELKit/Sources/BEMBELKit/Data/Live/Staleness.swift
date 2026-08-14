import Foundation

/// Age policy for live data: features show cached values with a staleness
/// marker instead of blanking out when a poll fails.
public struct Staleness: Sendable {
    public let maxAge: TimeInterval

    public init(maxAge: TimeInterval) {
        self.maxAge = maxAge
    }

    public func isStale(fetchedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) > maxAge
    }
}
