import Foundation

/// Live register provider: bundled snapshot first, conditional GET against
/// the published bembel-data bundle when the cached copy ages out. A failed
/// refresh is not an error the UI ever sees — the read path always answers.
public actor BembelDataRegisterProvider: RegisterProviding {
    private static let staleness = Staleness(maxAge: 6 * 60 * 60)
    private static let lastRefreshKey = "bembeldata.lastRefreshedAt"

    private let store: DatasetStore
    private let defaults: UserDefaults
    private var cached: RegisterSnapshot?

    public init(store: DatasetStore, defaults: UserDefaults = AppGroup.defaults) {
        self.store = store
        self.defaults = defaults
    }

    public func snapshot() async throws -> RegisterSnapshot {
        if let cached { return cached }
        if shouldRefresh {
            // The outcome is deliberately ignored: the read path below falls
            // back to the last good data anyway, and any completed attempt —
            // 304, 5xx or offline — resets the clock rather than hammering
            // the host once per view appearance.
            await store.refresh(BembelDataDataset.self)
            defaults.set(Date().timeIntervalSince1970, forKey: Self.lastRefreshKey)
        }
        let snapshot = try await store.payload(for: BembelDataDataset.self).snapshot()
        cached = snapshot
        return snapshot
    }

    /// Drops the in-memory cache so the next read re-reads from disk and may
    /// refresh again — used by pull-to-refresh.
    public func invalidate() {
        cached = nil
        defaults.removeObject(forKey: Self.lastRefreshKey)
    }

    private var shouldRefresh: Bool {
        let stamp = defaults.double(forKey: Self.lastRefreshKey)
        guard stamp > 0 else { return true }
        return Self.staleness.isStale(fetchedAt: Date(timeIntervalSince1970: stamp))
    }
}
