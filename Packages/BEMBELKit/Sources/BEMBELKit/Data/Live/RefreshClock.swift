import Foundation

/// Where a provider remembers when it last *completed* a refresh attempt —
/// success, 304, 5xx or offline alike. Persisted in the shared defaults suite,
/// so a widget waking up does not restart the app's staleness window.
///
/// `@unchecked Sendable` for exactly the reason `AppGroup.defaults` is
/// `nonisolated(unsafe)`: UserDefaults is documented thread-safe, it just
/// predates Sendable. Keeping the suite behind this type means the concession
/// is made once, here, instead of inside every provider actor — and an actor
/// cannot hold the suite directly anyway, because a synchronous actor
/// initializer is isolated and the deliberately shared suite can never be a
/// `sending` value.
public struct RefreshClock: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    /// Namespaced by dataset id, so two datasets can never share a clock.
    public init(id: String, defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.key = "\(id).lastRefreshedAt"
    }

    /// `nil` when no attempt has ever completed — which reads as "stale".
    public var lastRefreshedAt: Date? {
        let stamp = defaults.double(forKey: key)
        return stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }

    public func stamp(_ date: Date = Date()) {
        defaults.set(date.timeIntervalSince1970, forKey: key)
    }

    /// Forget the window entirely, so the next read refreshes. Pull-to-refresh.
    public func reset() {
        defaults.removeObject(forKey: key)
    }

    public func isStale(_ staleness: Staleness, now: Date = Date()) -> Bool {
        guard let last = lastRefreshedAt else { return true }
        return staleness.isStale(fetchedAt: last, now: now)
    }
}
