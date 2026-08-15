import Foundation

/// Live register provider: the published bembel-data bundle, cached and
/// conditionally refreshed by `CachedDatasetProvider`. All this type adds is
/// the freshness window and the payload → domain mapping.
public struct BembelDataRegisterProvider: RegisterProviding {
    /// Six hours. The publisher rebuilds `dist` on merge, and a contributor who
    /// lands an entry over lunch should see it the same afternoon.
    private static let maxAge: TimeInterval = 6 * 60 * 60

    private let base: CachedDatasetProvider<BembelDataDataset, RegisterSnapshot>

    public init(store: DatasetStore, defaults: UserDefaults = AppGroup.defaults) {
        base = CachedDatasetProvider(
            BembelDataDataset.self,
            store: store,
            maxAge: Self.maxAge,
            clock: RefreshClock(id: BembelDataDataset.id, defaults: defaults)
        ) { $0.snapshot() }
    }

    public func snapshot() async throws -> RegisterSnapshot {
        try await base.value()
    }

    public func invalidate() async {
        await base.invalidate()
    }
}
