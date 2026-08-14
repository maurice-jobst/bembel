import Foundation

/// The published bembel-data bundle, exactly as it is on the wire.
/// Contract: https://github.com/maurice-jobst/bembel-data (scripts/build_bundle.py).
struct BembelDataBundle: Decodable, Sendable {
    struct Address: Decodable, Sendable {
        let street: String
        let postalCode: String
        let city: String
    }

    struct Provenance: Decodable, Sendable {
        let lastEditor: String?
        let lastChangedAt: String?
        let verifiedAt: String?
        let historyURL: String
        let fileURL: String
    }

    struct Rating: Decodable, Sendable {
        let login: String
        let stars: Int
        let date: String?
        let comment: String?
    }

    struct RatingSummary: Decodable, Sendable {
        let average: Double
        let count: Int
        let ratings: [Rating]
    }

    struct Entry: Decodable, Sendable {
        let id: String
        let kind: String
        let name: String
        let address: Address
        let district: String?
        let latitude: Double
        let longitude: Double
        let openingHours: String?
        let since: Int?
        let merkmale: [String]
        let note: String?
        let sources: [String]
        let verified: Bool
        let provenance: Provenance
        let rating: RatingSummary?
    }

    struct Contributor: Decodable, Sendable {
        let login: String
        let entries: Int
        let verifications: Int
        let ratings: Int
        let firstRatings: [String]
    }

    struct Coverage: Decodable, Sendable {
        let district: String
        let verified: Int
        let candidates: Int
    }

    let schemaVersion: Int
    let generatedAt: String?
    let entries: [Entry]
    let contributors: [Contributor]
    /// Optional: a bundle built before the coverage step existed still loads,
    /// and the coverage game degrades to "no progress shown".
    let coverage: [Coverage]?
}

enum BembelDataDataset: CuratedDataset {
    typealias Payload = BembelDataBundle
    /// Also the manifest key and the bundled snapshot filename.
    static let id = "bembeldata"
}

extension BembelDataBundle {
    /// Wire → domain. Total by construction: an entry the app cannot make
    /// sense of (unknown register, unusable history URL) is dropped, never
    /// thrown — one bad row must not cost the user the register.
    func snapshot() -> RegisterSnapshot {
        RegisterSnapshot(
            schemaVersion: schemaVersion,
            generatedAt: Self.date(generatedAt),
            entries: entries.compactMap(Self.entry),
            contributors: contributors.map {
                BEMBELKit.Contributor(
                    login: $0.login,
                    entries: $0.entries,
                    verifications: $0.verifications,
                    ratings: $0.ratings,
                    firstRatings: $0.firstRatings
                )
            },
            coverage: (coverage ?? []).map {
                CoverageArea(district: $0.district, verified: $0.verified, candidates: $0.candidates)
            }
        )
    }

    private static func entry(_ wire: Entry) -> RegisterEntry? {
        guard
            let register = PlaceRegister(rawValue: wire.kind), register.isCommunity,
            let historyURL = URL(string: wire.provenance.historyURL)
        else { return nil }
        // Nothing renders fileURL yet — a malformed value must not cost the
        // whole entry, so it degrades to the history link instead of guarding.
        let fileURL = URL(string: wire.provenance.fileURL) ?? historyURL

        return RegisterEntry(
            id: wire.id,
            register: register,
            name: wire.name,
            street: wire.address.street,
            postalCode: wire.address.postalCode,
            city: wire.address.city,
            district: wire.district,
            latitude: wire.latitude,
            longitude: wire.longitude,
            openingHours: wire.openingHours,
            since: wire.since,
            merkmale: wire.merkmale.map(Merkmal.init(rawValue:)),
            note: wire.note,
            sources: wire.sources.compactMap(URL.init(string:)),
            verified: wire.verified,
            provenance: BEMBELKit.Provenance(
                lastEditor: wire.provenance.lastEditor,
                lastChangedAt: date(wire.provenance.lastChangedAt),
                verifiedAt: date(wire.provenance.verifiedAt),
                historyURL: historyURL,
                fileURL: fileURL
            ),
            rating: wire.rating.map { summary in
                BEMBELKit.RatingSummary(
                    average: summary.average,
                    count: summary.count,
                    ratings: summary.ratings.map {
                        BEMBELKit.Rating(
                            login: $0.login,
                            stars: $0.stars,
                            date: date($0.date),
                            comment: $0.comment
                        )
                    }
                )
            }
        )
    }

    // One formatter each for the whole decode — this runs 3× per entry plus
    // once per rating, and formatter construction dominates the parse cost.
    // Both classes are documented thread-safe; they just predate Sendable
    // (same justification as AppGroup.defaults).
    private nonisolated(unsafe) static let isoDate: ISO8601DateFormatter = {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso
    }()

    private nonisolated(unsafe) static let dayOnlyDate: DateFormatter = {
        let dayOnly = DateFormatter()
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        dayOnly.timeZone = TimeZone(identifier: "Europe/Berlin")
        dayOnly.dateFormat = "yyyy-MM-dd"
        return dayOnly
    }()

    /// Accepts both shapes bembel-data emits: full ISO-8601 timestamps from
    /// git (`%aI`) and plain `YYYY-MM-DD` rating dates.
    static func date(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        // Rating dates are always day-only by contract — try that first so
        // they don't pay for a guaranteed-miss ISO attempt.
        if raw.count == 10 { return dayOnlyDate.date(from: raw) }
        return isoDate.date(from: raw) ?? dayOnlyDate.date(from: raw)
    }
}
