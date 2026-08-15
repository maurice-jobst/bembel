import Foundation

/// Offline-first store for curated datasets.
///
/// Read path: override file in the store directory if a refresh ever
/// succeeded, else the bundled snapshot. The app therefore always has data,
/// even if the network never answers once.
///
/// Refresh path: conditional GET with `If-None-Match`. A 200 must decode as
/// the dataset's payload type before it replaces anything — a malformed
/// publish can never break an installed app.
public actor DatasetStore {
    private let manifest: DatasetManifest
    private let bundle: Bundle
    private let directory: URL
    private let session: URLSession
    private let etags: ETagStore

    public init(
        manifest: DatasetManifest,
        bundle: Bundle,
        directory: URL,
        session: URLSession = .shared
    ) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.manifest = manifest
        self.bundle = bundle
        self.directory = directory
        self.session = session
        self.etags = ETagStore(directory: directory)
    }

    /// Store over the Kit's bundled datasets, overrides in App Support.
    public static func makeDefault(session: URLSession = .shared) throws -> DatasetStore {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try DatasetStore(
            manifest: DatasetManifest.bundled(in: .module),
            bundle: .module,
            directory: support.appending(path: "Datasets", directoryHint: .isDirectory),
            session: session
        )
    }

    public func payload<D: CuratedDataset>(for dataset: D.Type) throws -> D.Payload {
        // An override that no longer decodes (written by an older app version,
        // then the payload type evolved) must not brick the dataset forever —
        // fall back to the bundled snapshot, which ships with this decoder.
        if let override = try? Data(contentsOf: overrideURL(for: D.filename)),
            let payload = try? JSONDecoder().decode(D.Payload.self, from: override)
        {
            return payload
        }
        return try JSONDecoder().decode(D.Payload.self, from: bundledData(for: D.self))
    }

    @discardableResult
    public func refresh<D: CuratedDataset>(_ dataset: D.Type) async -> RefreshOutcome {
        guard
            let entry = manifest.datasets[D.id],
            let url = entry.url ?? URL(string: entry.path, relativeTo: manifest.baseURL)
        else { return .notInManifest }

        var request = URLRequest(url: url)
        if let etag = etags.etag(for: D.id) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .transportFailure
        }
        guard let http = response as? HTTPURLResponse else { return .transportFailure }

        switch http.statusCode {
        case 200:
            guard (try? JSONDecoder().decode(D.Payload.self, from: data)) != nil else {
                return .invalidPayload
            }
            do {
                try data.write(to: overrideURL(for: D.filename), options: .atomic)
            } catch {
                return .storageFailure
            }
            if let etag = http.value(forHTTPHeaderField: "ETag") {
                etags.set(etag, for: D.id)
            }
            return .updated
        case 304:
            return .notModified
        default:
            return .serverError(http.statusCode)
        }
    }

    private func overrideURL(for filename: String) -> URL {
        directory.appending(path: filename)
    }

    private func bundledData<D: CuratedDataset>(for dataset: D.Type) throws -> Data {
        guard
            let url = bundle.url(forResource: D.id, withExtension: D.fileExtension),
            let bundled = try? Data(contentsOf: url)
        else {
            throw DatasetError.missingBundledResource(D.filename)
        }
        return bundled
    }
}

public enum RefreshOutcome: Equatable, Sendable {
    case updated
    case notModified
    /// 200 whose body doesn't decode — the old data stays authoritative.
    case invalidPayload
    case serverError(Int)
    /// Offline, DNS failure, timeout — anything below HTTP.
    case transportFailure
    case storageFailure
    case notInManifest
}

public enum DatasetError: Error, Sendable {
    case missingBundledResource(String)
}
