import Foundation
import Testing

@testable import BEMBELKit

private struct CachedTestPayload: Codable, Equatable, Sendable {
    let version: Int
    let items: [String]
}

private enum CachedTestDataset: CuratedDataset {
    typealias Payload = CachedTestPayload
    static let id = "testdata"
}

/// A defaults suite per test, so one test's clock cannot answer another's.
private func scratchDefaults() -> UserDefaults {
    let suite = UserDefaults(suiteName: "bembel-tests-\(UUID().uuidString)")!
    return suite
}

@Suite("Refresh clock")
struct RefreshClockTests {
    @Test("The key is the dataset id plus .lastRefreshedAt")
    func keyShape() {
        // Load-bearing: this is the key the hand-rolled providers wrote, so an
        // installed app keeps its window across the upgrade instead of
        // refetching every dataset once on first launch.
        let defaults = scratchDefaults()
        RefreshClock(id: "bembeldata", defaults: defaults).stamp(Date(timeIntervalSince1970: 1000))
        RefreshClock(id: "fountains", defaults: defaults).stamp(Date(timeIntervalSince1970: 2000))

        #expect(defaults.double(forKey: "bembeldata.lastRefreshedAt") == 1000)
        #expect(defaults.double(forKey: "fountains.lastRefreshedAt") == 2000)
    }

    @Test("Two datasets do not share a clock")
    func namespaced() {
        let defaults = scratchDefaults()
        let register = RefreshClock(id: "bembeldata", defaults: defaults)
        let fountains = RefreshClock(id: "fountains", defaults: defaults)

        register.stamp(Date(timeIntervalSince1970: 1000))
        #expect(register.lastRefreshedAt == Date(timeIntervalSince1970: 1000))
        #expect(fountains.lastRefreshedAt == nil)
    }

    @Test("Never stamped reads as stale, so the first read always refreshes")
    func neverStamped() {
        let clock = RefreshClock(id: "testdata", defaults: scratchDefaults())
        #expect(clock.lastRefreshedAt == nil)
        #expect(clock.isStale(Staleness(maxAge: 6 * 60 * 60)))
    }

    @Test("Inside the window is fresh, outside is stale, reset is stale again")
    func window() {
        let clock = RefreshClock(id: "testdata", defaults: scratchDefaults())
        let staleness = Staleness(maxAge: 3600)
        let stamped = Date(timeIntervalSince1970: 10_000)
        clock.stamp(stamped)

        #expect(!clock.isStale(staleness, now: stamped.addingTimeInterval(1800)))
        #expect(clock.isStale(staleness, now: stamped.addingTimeInterval(3601)))

        clock.reset()
        #expect(clock.isStale(staleness, now: stamped))
    }
}

/// Own host, so this suite cannot race the store's suite over the mock's
/// handler table; serialized because these tests share that one host between
/// themselves.
@Suite("Cached dataset provider", .serialized)
struct CachedDatasetProviderTests {
    private func makeStore() throws -> DatasetStore {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.urlCache = nil
        return try DatasetStore(
            manifest: DatasetManifest(
                version: 1,
                baseURL: URL(string: "https://provider.test/")!,
                datasets: ["testdata": .init(path: "testdata.json")]
            ),
            bundle: .module,
            directory: FileManager.default.temporaryDirectory
                .appending(path: "bembel-tests-\(UUID().uuidString)"),
            session: URLSession(configuration: config)
        )
    }

    private func makeProvider(
        store: DatasetStore,
        defaults: UserDefaults,
        maxAge: TimeInterval = 3600
    ) -> CachedDatasetProvider<CachedTestDataset, [String]> {
        CachedDatasetProvider(
            CachedTestDataset.self,
            store: store,
            maxAge: maxAge,
            clock: RefreshClock(id: CachedTestDataset.id, defaults: defaults)
        ) { $0.items }
    }

    @Test("The payload is mapped into the domain shape, not handed over raw")
    func maps() async throws {
        let defaults = scratchDefaults()
        MockURLProtocol.setHandler(host: "provider.test") { _ in
            (200, ["ETag": "\"v2\""], Data(#"{"version": 2, "items": ["fresh"]}"#.utf8))
        }
        let provider = makeProvider(store: try makeStore(), defaults: defaults)
        #expect(try await provider.value() == ["fresh"])
    }

    @Test("A completed attempt stamps the clock, so the window starts closed")
    func stampsAfterRefresh() async throws {
        let defaults = scratchDefaults()
        MockURLProtocol.setHandler(host: "provider.test") { _ in
            (200, ["ETag": "\"v2\""], Data(#"{"version": 2, "items": ["fresh"]}"#.utf8))
        }
        let provider = makeProvider(store: try makeStore(), defaults: defaults)
        _ = try await provider.value()

        let clock = RefreshClock(id: CachedTestDataset.id, defaults: defaults)
        #expect(clock.lastRefreshedAt != nil)
        #expect(!clock.isStale(Staleness(maxAge: 3600)))
    }

    @Test("A failed refresh is not an error the caller sees — bundled data answers")
    func failureDegrades() async throws {
        let defaults = scratchDefaults()
        MockURLProtocol.setHandler(host: "provider.test") { _ in throw URLError(.notConnectedToInternet) }
        let provider = makeProvider(store: try makeStore(), defaults: defaults)
        #expect(try await provider.value() == ["bundled"])
    }

    @Test("Offline still stamps, so a dead host costs one request per window")
    func failureStampsToo() async throws {
        let defaults = scratchDefaults()
        MockURLProtocol.setHandler(host: "provider.test") { _ in throw URLError(.notConnectedToInternet) }
        _ = try await makeProvider(store: try makeStore(), defaults: defaults).value()
        #expect(RefreshClock(id: CachedTestDataset.id, defaults: defaults).lastRefreshedAt != nil)
    }

    @Test("A fresh clock suppresses the request entirely")
    func freshClockSkipsRefresh() async throws {
        let defaults = scratchDefaults()
        RefreshClock(id: CachedTestDataset.id, defaults: defaults).stamp()

        MockURLProtocol.setHandler(host: "provider.test") { _ in
            Issue.record("refreshed while the clock was still fresh")
            return (200, [:], Data(#"{"version": 9, "items": ["remote"]}"#.utf8))
        }
        let provider = makeProvider(store: try makeStore(), defaults: defaults)
        #expect(try await provider.value() == ["bundled"])
    }

    @Test("The second read is served from memory, not from the store again")
    func cachesInMemory() async throws {
        let defaults = scratchDefaults()
        MockURLProtocol.setHandler(host: "provider.test") { _ in
            (200, ["ETag": "\"v2\""], Data(#"{"version": 2, "items": ["fresh"]}"#.utf8))
        }
        let provider = makeProvider(store: try makeStore(), defaults: defaults)
        #expect(try await provider.value() == ["fresh"])

        MockURLProtocol.setHandler(host: "provider.test") { _ in
            Issue.record("went back to the network while the value was cached")
            return (200, [:], Data())
        }
        #expect(try await provider.value() == ["fresh"])
    }

    @Test("invalidate() drops the memory cache and the clock, so the next read refreshes")
    func invalidateReopensBoth() async throws {
        let defaults = scratchDefaults()
        MockURLProtocol.setHandler(host: "provider.test") { _ in
            (200, ["ETag": "\"v2\""], Data(#"{"version": 2, "items": ["fresh"]}"#.utf8))
        }
        let provider = makeProvider(store: try makeStore(), defaults: defaults)
        #expect(try await provider.value() == ["fresh"])

        await provider.invalidate()
        #expect(RefreshClock(id: CachedTestDataset.id, defaults: defaults).lastRefreshedAt == nil)

        MockURLProtocol.setHandler(host: "provider.test") { _ in
            (200, ["ETag": "\"v3\""], Data(#"{"version": 3, "items": ["newer"]}"#.utf8))
        }
        #expect(try await provider.value() == ["newer"])
    }
}
