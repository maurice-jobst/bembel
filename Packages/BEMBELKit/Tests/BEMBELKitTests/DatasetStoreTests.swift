import Foundation
import Testing

@testable import BEMBELKit

private struct TestPayload: Codable, Equatable, Sendable {
    let version: Int
    let items: [String]
}

private enum TestDataset: CuratedDataset {
    typealias Payload = TestPayload
    static let id = "testdata"
}

/// Serialized because the mock handler is shared static state.
@Suite("Curated dataset store", .serialized)
struct DatasetStoreTests {
    private func makeStore(
        manifest: DatasetManifest? = nil,
        directory: URL? = nil
    ) throws -> (store: DatasetStore, directory: URL) {
        let dir =
            directory
            ?? FileManager.default.temporaryDirectory
            .appending(path: "bembel-tests-\(UUID().uuidString)")
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.urlCache = nil
        let store = try DatasetStore(
            manifest: manifest
                ?? DatasetManifest(
                    version: 1,
                    baseURL: URL(string: "https://mock.test/")!,
                    datasets: ["testdata": .init(path: "testdata.json")]
                ),
            bundle: .module,
            directory: dir,
            session: URLSession(configuration: config)
        )
        return (store, dir)
    }

    @Test("Without any refresh, the bundled snapshot answers")
    func bundledFallback() async throws {
        let (store, _) = try makeStore()
        let payload = try await store.payload(for: TestDataset.self)
        #expect(payload == TestPayload(version: 1, items: ["bundled"]))
    }

    @Test("200 validates, stores the override, and future reads see it — across store instances")
    func fresh200() async throws {
        let (store, dir) = try makeStore()
        MockURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "If-None-Match") == nil)
            return (200, ["ETag": "\"v2\""], Data(#"{"version": 2, "items": ["fresh"]}"#.utf8))
        }
        let outcome = await store.refresh(TestDataset.self)
        #expect(outcome == .updated)
        let payload = try await store.payload(for: TestDataset.self)
        #expect(payload == TestPayload(version: 2, items: ["fresh"]))

        // A new store over the same directory reads the persisted override.
        let (reopened, _) = try makeStore(directory: dir)
        let persisted = try await reopened.payload(for: TestDataset.self)
        #expect(persisted == TestPayload(version: 2, items: ["fresh"]))
    }

    @Test("The stored ETag is sent and a 304 leaves data untouched")
    func etagRoundTrip() async throws {
        let (store, _) = try makeStore()
        MockURLProtocol.handler = { _ in
            (200, ["ETag": "\"v2\""], Data(#"{"version": 2, "items": ["fresh"]}"#.utf8))
        }
        #expect(await store.refresh(TestDataset.self) == .updated)

        MockURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "If-None-Match") == "\"v2\"")
            return (304, [:], Data())
        }
        #expect(await store.refresh(TestDataset.self) == .notModified)
        let payload = try await store.payload(for: TestDataset.self)
        #expect(payload == TestPayload(version: 2, items: ["fresh"]))
    }

    @Test("A malformed 200 never replaces good data")
    func malformedPayload() async throws {
        let (store, _) = try makeStore()
        MockURLProtocol.handler = { _ in
            (200, [:], Data("{definitely not the schema".utf8))
        }
        #expect(await store.refresh(TestDataset.self) == .invalidPayload)
        let payload = try await store.payload(for: TestDataset.self)
        #expect(payload == TestPayload(version: 1, items: ["bundled"]))
    }

    @Test("Offline refresh degrades to the bundled snapshot")
    func offline() async throws {
        let (store, _) = try makeStore()
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        #expect(await store.refresh(TestDataset.self) == .transportFailure)
        let payload = try await store.payload(for: TestDataset.self)
        #expect(payload == TestPayload(version: 1, items: ["bundled"]))
    }

    @Test("Server errors are reported, not retried into")
    func serverError() async throws {
        let (store, _) = try makeStore()
        MockURLProtocol.handler = { _ in (503, [:], Data()) }
        #expect(await store.refresh(TestDataset.self) == .serverError(503))
    }

    @Test("An entry's absolute url wins over baseURL — foreign-host datasets")
    func absoluteURLOverridesBase() async throws {
        let manifest = DatasetManifest(
            version: 2,
            baseURL: URL(string: "https://mock.test/")!,
            datasets: [
                "testdata": .init(
                    path: "testdata.json",
                    url: URL(string: "https://raw.example.test/dist/bembel-data.json")!
                )
            ]
        )
        let (store, _) = try makeStore(manifest: manifest)
        MockURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://raw.example.test/dist/bembel-data.json")
            return (200, ["ETag": "\"v9\""], Data(#"{"version": 9, "items": ["remote"]}"#.utf8))
        }
        #expect(await store.refresh(TestDataset.self) == .updated)
        let payload = try await store.payload(for: TestDataset.self)
        #expect(payload == TestPayload(version: 9, items: ["remote"]))
    }

    @Test("A dataset missing from the manifest is a distinct outcome")
    func notInManifest() async throws {
        let empty = DatasetManifest(
            version: 1,
            baseURL: URL(string: "https://mock.test/")!,
            datasets: [:]
        )
        let (store, _) = try makeStore(manifest: empty)
        #expect(await store.refresh(TestDataset.self) == .notInManifest)
    }
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, [String: String], Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (status, headers, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://mock.test/")!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}
