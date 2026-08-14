import CoreLocation
import Foundation

/// The place datasets the Orte tab shows. `trinkbrunnen` is not a bembel-data
/// register — it rides along because the tab shows every place dataset, and
/// grouping them is what freed the tab slot for the hero.
public enum PlaceRegister: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case wasserhaeuschen
    case ebbelwei
    case trinkbrunnen

    public var id: String { rawValue }

    /// The two registers that come from bembel-data — the ones with entries,
    /// ratings, provenance and a contribution funnel.
    public static let community: [PlaceRegister] = [.wasserhaeuschen, .ebbelwei]

    public var isCommunity: Bool { Self.community.contains(self) }
}

/// A Merkmal is an *open* vocabulary. bembel-data may publish a tag this build
/// has never heard of; an unknown tag must degrade to "shown under its raw
/// name", never to a decode failure that costs the user the whole register.
public struct Merkmal: RawRepresentable, Hashable, Codable, Sendable, Identifiable {
    public let rawValue: String

    public var id: String { rawValue }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    // The vocabulary bembel-data's schemas enumerate today. Statics are for
    // call sites and previews; decoding accepts anything.
    public static let sitzplaetze = Merkmal(rawValue: "sitzplaetze")
    public static let eigenmarke = Merkmal(rawValue: "eigenmarke")
    public static let kunst = Merkmal(rawValue: "kunst")
    public static let spaeti = Merkmal(rawValue: "spaeti")
    public static let historisch = Merkmal(rawValue: "historisch")
    public static let trinkhalleKlassisch = Merkmal(rawValue: "trinkhalle-klassisch")
    public static let spaetOffen = Merkmal(rawValue: "spaet-offen")
    public static let baenkeDraussen = Merkmal(rawValue: "baenke-draussen")
    public static let ebbelwei = Merkmal(rawValue: "ebbelwei")
    public static let garten = Merkmal(rawValue: "garten")
    public static let eigenkelterei = Merkmal(rawValue: "eigenkelterei")
    public static let handkaes = Merkmal(rawValue: "handkaes")
    public static let schoppenVomFass = Merkmal(rawValue: "schoppen-vom-fass")

    /// Localisation key. An unknown Merkmal has no catalogue entry — the UI
    /// falls back to `rawValue`, which is a readable slug by construction.
    public var localizationKey: String { "merkmal.\(rawValue)" }

    public var systemImage: String {
        switch self {
        case .sitzplaetze, .baenkeDraussen: "chair.lounge"
        case .eigenmarke: "bottle"
        case .kunst: "paintpalette"
        case .spaeti, .spaetOffen: "moon.stars"
        case .historisch: "building.columns"
        case .trinkhalleKlassisch: "house"
        case .ebbelwei, .schoppenVomFass: "wineglass"
        case .garten: "tree"
        case .eigenkelterei: "gearshape.2"
        case .handkaes: "fork.knife"
        default: "tag"
        }
    }
}

/// Who touched this entry, when, and where to read the whole story. The
/// anti-Yelp move: every fact on screen is one tap from its git history.
public struct Provenance: Hashable, Sendable {
    /// GitHub login of the last editor. `nil` when the commit's author could
    /// not be resolved to an account — bembel-data derives, never guesses.
    public let lastEditor: String?
    public let lastChangedAt: Date?
    public let verifiedAt: Date?
    public let historyURL: URL
    public let fileURL: URL

    public init(
        lastEditor: String?,
        lastChangedAt: Date?,
        verifiedAt: Date?,
        historyURL: URL,
        fileURL: URL
    ) {
        self.lastEditor = lastEditor
        self.lastChangedAt = lastChangedAt
        self.verifiedAt = verifiedAt
        self.historyURL = historyURL
        self.fileURL = fileURL
    }
}

public struct Rating: Identifiable, Hashable, Sendable {
    public var id: String { login }
    public let login: String
    public let stars: Int
    public let date: Date?
    public let comment: String?

    public init(login: String, stars: Int, date: Date?, comment: String?) {
        self.login = login
        self.stars = stars
        self.date = date
        self.comment = comment
    }
}

public struct RatingSummary: Hashable, Sendable {
    public let average: Double
    public let count: Int
    public let ratings: [Rating]

    public init(average: Double, count: Int, ratings: [Rating]) {
        self.average = average
        self.count = count
        self.ratings = ratings
    }
}

public struct RegisterEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let register: PlaceRegister
    public let name: String
    public let street: String
    public let postalCode: String
    public let city: String
    public let district: String?
    public let latitude: Double
    public let longitude: Double
    public let openingHours: String?
    public let since: Int?
    public let merkmale: [Merkmal]
    public let note: String?
    public let sources: [URL]
    public let verified: Bool
    public let provenance: Provenance
    public let rating: RatingSummary?

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Unverified entries are the coverage game's targets: rendered greyed,
    /// with the "help verify this one" call to action.
    public var isCandidate: Bool { !verified }

    public var addressLine: String { "\(street), \(postalCode) \(city)" }

    /// Grouping key for coverage — bembel-data groups the same way.
    public var area: String { district ?? city }

    public init(
        id: String,
        register: PlaceRegister,
        name: String,
        street: String,
        postalCode: String,
        city: String,
        district: String? = nil,
        latitude: Double,
        longitude: Double,
        openingHours: String? = nil,
        since: Int? = nil,
        merkmale: [Merkmal] = [],
        note: String? = nil,
        sources: [URL] = [],
        verified: Bool = false,
        provenance: Provenance,
        rating: RatingSummary? = nil
    ) {
        self.id = id
        self.register = register
        self.name = name
        self.street = street
        self.postalCode = postalCode
        self.city = city
        self.district = district
        self.latitude = latitude
        self.longitude = longitude
        self.openingHours = openingHours
        self.since = since
        self.merkmale = merkmale
        self.note = note
        self.sources = sources
        self.verified = verified
        self.provenance = provenance
        self.rating = rating
    }
}

/// One contributor's tallies, computed in bembel-data's CI from the git
/// history. The sticker engine reads nothing else about a person.
public struct Contributor: Identifiable, Hashable, Sendable {
    public var id: String { login }
    public let login: String
    public let entries: Int
    public let verifications: Int
    public let ratings: Int
    public let firstRatings: [String]

    public init(login: String, entries: Int, verifications: Int, ratings: Int, firstRatings: [String]) {
        self.login = login
        self.entries = entries
        self.verifications = verifications
        self.ratings = ratings
        self.firstRatings = firstRatings
    }
}

public struct CoverageArea: Identifiable, Hashable, Sendable {
    public var id: String { district }
    public let district: String
    public let verified: Int
    public let candidates: Int

    public var total: Int { verified + candidates }
    public var fraction: Double { total == 0 ? 0 : Double(verified) / Double(total) }

    public init(district: String, verified: Int, candidates: Int) {
        self.district = district
        self.verified = verified
        self.candidates = candidates
    }
}

/// One published bembel-data bundle, as the app sees it.
public struct RegisterSnapshot: Hashable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date?
    public let entries: [RegisterEntry]
    public let contributors: [Contributor]
    public let coverage: [CoverageArea]

    public static let empty = RegisterSnapshot(
        schemaVersion: 0, generatedAt: nil, entries: [], contributors: [], coverage: []
    )

    public init(
        schemaVersion: Int,
        generatedAt: Date?,
        entries: [RegisterEntry],
        contributors: [Contributor],
        coverage: [CoverageArea]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.entries = entries
        self.contributors = contributors
        self.coverage = coverage
    }

    public func entries(in register: PlaceRegister) -> [RegisterEntry] {
        entries.filter { $0.register == register }
    }

    /// Merkmale actually present in a register, most common first — the tag
    /// bar is generated from the data, never from a hardcoded list.
    public func merkmale(in register: PlaceRegister) -> [Merkmal] {
        var counts: [Merkmal: Int] = [:]
        for entry in entries(in: register) {
            for merkmal in entry.merkmale { counts[merkmal, default: 0] += 1 }
        }
        return
            counts
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value
            }
            .map(\.key)
    }
}
