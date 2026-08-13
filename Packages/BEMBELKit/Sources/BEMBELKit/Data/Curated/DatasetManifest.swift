import Foundation

/// The published index of curated datasets: where refreshes come from.
/// A copy ships in the bundle; the real `baseURL` is decided by the publish
/// workflow (BEM-B03) — until then it points at a guaranteed-dead host so
/// refresh attempts fail loudly-but-gracefully instead of hitting something.
public struct DatasetManifest: Codable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        public let path: String

        public init(path: String) {
            self.path = path
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
