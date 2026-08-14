/// A curated dataset: bundled at build time, refreshed via conditional GET.
/// Conformances are tiny — an id and a payload type. Everything else
/// (storage, refresh, fallback) is `DatasetStore`'s job, so adding a dataset
/// is a data change plus one conformance, never new plumbing.
public protocol CuratedDataset: Sendable {
    associatedtype Payload: Decodable & Sendable

    /// Stable identifier — also the manifest key and the bundled resource
    /// filename (`<id>.json`).
    static var id: String { get }
}
