import Foundation

/// Persists the ETag per dataset id next to the override files. Persistence
/// failures cost only an unnecessary re-download, so they are swallowed.
struct ETagStore {
    private let fileURL: URL
    private var values: [String: String]

    init(directory: URL) {
        self.fileURL = directory.appending(path: "etags.json")
        self.values =
            (try? JSONDecoder().decode(
                [String: String].self,
                from: Data(contentsOf: fileURL)
            )) ?? [:]
    }

    func etag(for id: String) -> String? {
        values[id]
    }

    mutating func set(_ etag: String, for id: String) {
        values[id] = etag
        if let data = try? JSONEncoder().encode(values) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
