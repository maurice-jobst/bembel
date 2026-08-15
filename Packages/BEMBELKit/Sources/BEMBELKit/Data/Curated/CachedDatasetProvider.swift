import Foundation

/// The read path every curated dataset shares: answer from memory, else from
/// the store — last good override, or the bundled snapshot — and fire a
/// conditional GET first when the cached copy has aged out.
///
/// A failed refresh is never an error the UI sees. The read below falls back to
/// the last good data anyway, and *any* completed attempt — 304, 5xx, offline —
/// stamps the clock, so an unreachable host costs one request per staleness
/// window rather than one per view appearance.
///
/// A dataset provider is this actor plus two things it cannot share: how long
/// its data stays fresh, and how its payload becomes a domain type. Every new
/// curated layer (Pegel, Luftqualität, Baustellen, …) should be a few lines
/// against this, not another copy of the caching rules.
public actor CachedDatasetProvider<D: CuratedDataset, Value: Sendable> {
    private let store: DatasetStore
    private let staleness: Staleness
    private let clock: RefreshClock
    private let map: @Sendable (D.Payload) -> Value
    private var cached: Value?

    public init(
        _ dataset: D.Type,
        store: DatasetStore,
        maxAge: TimeInterval,
        clock: RefreshClock,
        map: @escaping @Sendable (D.Payload) -> Value
    ) {
        self.store = store
        self.staleness = Staleness(maxAge: maxAge)
        self.clock = clock
        self.map = map
    }

    public func value() async throws -> Value {
        if let cached { return cached }
        if clock.isStale(staleness) {
            // Outcome deliberately ignored — see the note above.
            await store.refresh(D.self)
            clock.stamp()
        }
        let value = map(try await store.payload(for: D.self))
        cached = value
        return value
    }

    /// Drops the in-memory cache *and* the clock, so the next read goes back to
    /// disk and refreshes again. Pull-to-refresh is the only caller: a user who
    /// pulls is telling us the staleness window is wrong for this moment.
    public func invalidate() {
        cached = nil
        clock.reset()
    }
}
