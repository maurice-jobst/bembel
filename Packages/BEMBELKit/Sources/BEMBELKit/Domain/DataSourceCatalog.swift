import Foundation

/// One row of the app-facing source list — the filtered view of
/// `data/sources.json` (and, for a bundled dataset, `data/ATTRIBUTION.json`)
/// that `scripts/generate_data_sources_view.py` produces (BEM-B06, #70).
///
/// `tier` and `status` are only ever present on a live entry; a bundled one
/// carries neither, so both stay optional here rather than forking the type.
public struct DataSourceEntry: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let license: String
    public let attribution: String
    public let tier: Int?
    public let status: String?

    public init(id: String, name: String, license: String, attribution: String, tier: Int? = nil, status: String? = nil)
    {
        self.id = id
        self.name = name
        self.license = license
        self.attribution = attribution
        self.tier = tier
        self.status = status
    }
}

/// The Settings source list, read from the bundle instead of hand-typed.
///
/// `live` is fetched by the running app; `bundled` was fetched once by a
/// build-time script and ships inside the app. Both are the registry's own
/// truth, not a copy someone can forget to update — a source with no
/// `consumption` tag in `data/sources.json` appears in neither list, which is
/// the fix for the bug this type exists to close: the array it replaces once
/// listed RMV and HLNUG as sources this app reads, and it read neither.
public struct DataSourceCatalog: Codable, Sendable {
    public let updated: String
    public let live: [DataSourceEntry]
    public let bundled: [DataSourceEntry]

    public init(updated: String, live: [DataSourceEntry], bundled: [DataSourceEntry]) {
        self.updated = updated
        self.live = live
        self.bundled = bundled
    }

    /// Loads `datasources.json` from the Kit's bundled resources. Throws
    /// rather than returning an empty catalog — an empty Settings screen
    /// should read as a bug, not as "this app calls nothing".
    public static func load() throws -> DataSourceCatalog {
        guard let url = Bundle.module.url(forResource: "datasources", withExtension: "json") else {
            throw DataSourceCatalogError.missingBundledCatalog
        }
        return try JSONDecoder().decode(DataSourceCatalog.self, from: Data(contentsOf: url))
    }
}

public enum DataSourceCatalogError: Error, Sendable {
    case missingBundledCatalog
}
