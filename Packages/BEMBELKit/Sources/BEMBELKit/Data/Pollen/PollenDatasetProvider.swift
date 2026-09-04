import Foundation

/// Live pollen: DWD's `s31fg.json`, cached and conditionally refreshed by
/// `CachedDatasetProvider` (#64) — the same shape `FountainDatasetProvider`
/// uses, because this dataset is exactly that shape too: one static URL,
/// bundled for a cold start, refreshed on a cadence rather than fetched with
/// per-call parameters the way PEGELONLINE or NINA are.
public struct PollenDatasetProvider: PollenProviding {
    /// Matches `data/sources.json`'s registered cadence for `dwd_pollen`.
    /// DWD republishes twice a day; six hours is generous headroom that still
    /// answers 304 most of the time.
    private static let maxAge: TimeInterval = 6 * 60 * 60

    private let base: CachedDatasetProvider<PollenDataset, PollenMapResult>

    public init(store: DatasetStore, defaults: UserDefaults = AppGroup.defaults) {
        base = CachedDatasetProvider(
            PollenDataset.self,
            store: store,
            maxAge: Self.maxAge,
            clock: RefreshClock(id: PollenDataset.id, defaults: defaults)
        ) { payload in
            // `CachedDatasetProvider.map` cannot throw — `reading()` only
            // throws when Rhein-Main is missing from the file entirely, which
            // an empty reading would misreport as "nothing is in the air".
            // `.missing` carries that failure through to `value()`'s caller
            // instead of swallowing it here.
            (try? payload.reading()).map(PollenMapResult.reading) ?? .missing
        }
    }

    public func pollen() async throws -> PollenReading {
        switch try await base.value() {
        case .reading(let reading): return reading
        case .missing: throw PollenError.missingRhineMainPartregion
        }
    }

    public func invalidate() async {
        await base.invalidate()
    }
}

/// `CachedDatasetProvider`'s `map` closure is non-throwing, so a decode-time
/// failure has to travel as a value instead of an error until `pollen()` can
/// re-throw it.
private enum PollenMapResult: Sendable {
    case reading(PollenReading)
    case missing
}
