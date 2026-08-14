import Foundation

/// The published index of curated datasets: where refreshes come from.
/// A copy ships in the bundle; the real `baseURL` is decided by the publish
/// workflow (BEM-B03) — until then it points at a guaranteed-dead host so
/// refresh attempts fail loudly-but-gracefully instead of hitting something.
public struct DatasetManifest: Codable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        /// Relative to `baseURL`, and the name of the bundled snapshot.
        public let path: String
        /// Absolute source, overriding `baseURL + path`. Datasets published by
        /// another repo — bembel-data — live at their own host; `path` still
        /// names the bundled snapshot that answers offline and on first launch.
        public let url: URL?

        public init(path: String, url: URL? = nil) {
            self.path = path
            self.url = url
        }
    }

    public let version: Int
    public let baseURL: URL
    public let datasets: [String: Entry]

    public init(version: Int, baseURL: URL, datasets: [String: Entry]) {
        self.version = version
        self.baseURL = baseURL
        self.datasets = datasets
    }

    public static func bundled(in bundle: Bundle) throws -> DatasetManifest {
        guard
            let url = bundle.url(forResource: "manifest", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            throw DatasetError.missingBundledResource("manifest")
        }
        return try JSONDecoder().decode(DatasetManifest.self, from: data)
    }
}
