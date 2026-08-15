import Foundation

/// Persists the ETag per dataset id next to the override files. Persistence
/// failures cost only an unnecessary re-download, so they are swallowed.
///
/// The file is the authority, never an in-memory copy. Nothing stops two
/// `DatasetStore` actors sitting over the same directory — every
/// `makeDefault()` call builds a fresh store over the *same* path — and a
/// store holding a dict it read at init would persist that stale version over
/// a sibling's write, silently dropping the sibling's ETag and turning its
/// next conditional GET back into a full download. That is exactly what the
/// app did until the wiring was changed to share one store.
///
/// Sharing the store is the fix for the app; this is the fix for the type, so
/// the next caller to build a second store does not reintroduce the bug. The
/// file is a handful of bytes and is touched once per refresh window, so
/// re-reading it is cheaper than the bug.
struct ETagStore {
    private let fileURL: URL

    init(directory: URL) {
        self.fileURL = directory.appending(path: "etags.json")
    }

    func etag(for id: String) -> String? {
        persisted()[id]
    }

    func set(_ etag: String, for id: String) {
        var values = persisted()
        values[id] = etag
        if let data = try? JSONEncoder().encode(values) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func persisted() -> [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: fileURL))) ?? [:]
    }
}
