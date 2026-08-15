import Foundation

/// Persists the ETag per dataset id next to the override files. Persistence
/// failures cost only an unnecessary re-download, so they are swallowed.
///
/// The file is the authority, not an in-memory copy: several `DatasetStore`
/// actors can sit over the same directory — `makeDefault()` hands every
/// provider the same one — and a store holding a dict it read at init would
/// persist that stale version over a sibling's write, silently dropping the
/// sibling's ETag and turning its next conditional GET back into a full
/// download. The file is a handful of bytes and is touched once per refresh
/// window, so re-reading it is cheaper than the bug.
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
