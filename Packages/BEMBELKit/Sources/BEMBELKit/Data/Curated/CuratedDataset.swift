/// A curated dataset: bundled at build time, refreshed via conditional GET.
/// Conformances are tiny — an id and a payload type. Everything else
/// (storage, refresh, fallback) is `DatasetStore`'s job, so adding a dataset
/// is a data change plus one conformance, never new plumbing.
public protocol CuratedDataset: Sendable {
    associatedtype Payload: Decodable & Sendable

    /// Stable identifier — also the manifest key and the bundled resource
    /// name.
    static var id: String { get }

    /// Extension of the bundled resource. Defaults to `json`; the curated
    /// point layers are `geojson`, and the suffix is what tells a reader which
    /// shape a file is in before opening it.
    static var fileExtension: String { get }
}

extension CuratedDataset {
    public static var fileExtension: String { "json" }

    /// `<id>.<ext>` — the bundled filename, the override filename, and what the
    /// manifest's `path` points at.
    public static var filename: String { "\(id).\(fileExtension)" }
}
