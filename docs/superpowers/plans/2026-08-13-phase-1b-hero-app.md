# Phase 1b — Hero app layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build BEMBEL's hero layer in the app: the Wasserhäuschen and Ebbelwei registers loaded from bembel-data, Merkmale-first navigation, a provenance byline on every entry, the in-app rating funnel, the coverage game, and the data-linked stickers with kiosk visit stamps.

**Architecture:** No new patterns — the ADR-0007 provider seam and the ADR-0002 curated data layer already carry this. `RegisterProviding` joins the four existing protocols in BEMBELKit with domain models and a `SampleRegisterProvider`; the live provider decodes a bembel-data bundle through the existing `DatasetStore` (bundled snapshot → conditional GET → last-good), which grows exactly one field: a per-dataset absolute `url` for datasets published by another repo. The funnel and the sticker engine are pure functions — URL construction and rule evaluation over `contributors.json`-style tallies plus on-device state. In the app, a new **Orte** tab takes position 1 and carries all three place datasets (Wasserhäuschen, Ebbelwei, Trinkbrunnen) behind a segmented control; the old Trinkwasser tab folds into it, so the tab bar stays at five.

**Tech Stack:** Swift 6, SwiftUI, MapKit, CoreLocation (`CLMonitor`), Swift Testing, iOS 18.5+, zero third-party dependencies.

## Global Constraints

- **Repo: `~/Projects/BEMBEL`.** The bembel-data side is Phase 1a and must be merged first — Task 3 fetches from the URL it publishes.
- **No TDD** (operator rule, and `AGENTS.md`: "Tests earn their keep… no TDD ceremony"). Write the implementation, then the tests that earn their place: the loader, the funnel URL builder, the sticker rules, the bundle decoder. **No tests on SwiftUI view bodies.**
- **Verification after every task:** `make test`, `make build`, `make validate`, `make format-check` — all four green before the commit. `make format` first if the lint fails.
- **German is the UI language.** Every user-facing string is a key in `App/Resources/Localizable.xcstrings` with a German value; no hardcoded user-facing text (`BEM-H02` sweeps for this at M2). Code, comments, and commit messages are English.
- **Commit convention:** one commit per ticket, message prefixed `BEM-S04:` / `BEM-S05:` / `BEM-S11:` / `BEM-S01:` as the task states. `Closes #N` goes in the PR body, never the commit.
- **Privacy is load-bearing:** nothing leaves the device except the GitHub URLs the user explicitly taps. No analytics, no BEMBEL backend, no account. The App Store label stays **Data Not Collected**. Visit detection is opt-in and on-device.
- **Repo gotchas:** the `.pbxproj` uses filesystem-synchronised groups (objectVersion 77) — adding a file under `App/` adds it to the target, never hand-edit target membership. `#Preview` only in `App/`. `data/*.json` and their BEMBELKit `Resources/` copies must stay byte-identical (`make validate` enforces it) — generate both, never hand-edit one. A stale `DerivedData` directory can shadow the real build product; resolve via `xcodebuild -showBuildSettings | grep TARGET_BUILD_DIR`, not `find`.
- **Bundle URL of record:** `https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json`.
- Ship date **2027-03-22**. Milestone **M2**. Issues: #39 (BEM-S04), #40 (BEM-S05), #46 (BEM-S11), #36 (BEM-S01, partial — the Sammelalbum remainder stays in M4).
- Lane ownership for review: **frontend + stickers = @cybeerboy** (`App/`, `Widgets/`), **backend = @monsdroid + @jaypikay** (`data/`, `scripts/`, providers). Label PRs accordingly.

---

### Task 1: Register domain models and the provider seam

**Files:**
- Create: `Packages/BEMBELKit/Sources/BEMBELKit/Domain/Register.swift`
- Create: `Packages/BEMBELKit/Sources/BEMBELKit/Providers/Sample/SampleRegisterProvider.swift`
- Modify: `Packages/BEMBELKit/Sources/BEMBELKit/Providers/Providing.swift`

**Interfaces:**
- Produces: `PlaceRegister`, `Merkmal`, `RegisterEntry`, `Provenance`, `RatingSummary`, `Rating`, `Contributor`, `CoverageArea`, `RegisterSnapshot`, `RegisterProviding` (`func snapshot() async throws -> RegisterSnapshot`), `SampleRegisterProvider`. Every later task in this plan consumes these exact names.

- [ ] **Step 1: Create the branch**

```bash
cd /Users/krazykraut/Projects/BEMBEL && git checkout main && git pull && git checkout -b feat/hero-registers
```

- [ ] **Step 2: Write the domain models**

Create `Packages/BEMBELKit/Sources/BEMBELKit/Domain/Register.swift`:

```swift
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

    public func contributor(login: String) -> Contributor? {
        let wanted = login.lowercased()
        return contributors.first { $0.login.lowercased() == wanted }
    }
}
```

- [ ] **Step 3: Add the protocol**

Append to `Packages/BEMBELKit/Sources/BEMBELKit/Providers/Providing.swift`:

```swift
public protocol RegisterProviding: Sendable {
    /// The whole published bundle. Registers are small (hundreds of entries)
    /// and the UI slices them by register and Merkmal locally — paging here
    /// would be speculative generality.
    func snapshot() async throws -> RegisterSnapshot
}
```

- [ ] **Step 4: Write the sample provider**

Create `Packages/BEMBELKit/Sources/BEMBELKit/Providers/Sample/SampleRegisterProvider.swift`. Real places, real coordinates, fabricated ratings and provenance — this is the fixture the UI is built against before the live loader lands (Task 3), and it stays as the preview/testing double:

```swift
import Foundation

/// Real Frankfurt places, fabricated ratings and provenance. The live bundle
/// (`BembelDataRegisterProvider`) replaces this; previews keep it.
public struct SampleRegisterProvider: RegisterProviding {
    public init() {}

    private static func provenance(_ id: String, register: PlaceRegister, editor: String?, verified: Bool) -> Provenance {
        let path = "data/\(register.rawValue)/\(id).json"
        return Provenance(
            lastEditor: editor,
            lastChangedAt: Date(timeIntervalSince1970: 1_786_000_000),
            verifiedAt: verified ? Date(timeIntervalSince1970: 1_786_000_000) : nil,
            historyURL: URL(string: "https://github.com/maurice-jobst/bembel-data/commits/main/\(path)")!,
            fileURL: URL(string: "https://github.com/maurice-jobst/bembel-data/blob/main/\(path)")!
        )
    }

    public static let snapshot = RegisterSnapshot(
        schemaVersion: 1,
        generatedAt: Date(timeIntervalSince1970: 1_786_000_000),
        entries: [
            RegisterEntry(
                id: "yok-yok",
                register: .wasserhaeuschen,
                name: "City Kiosk Yok-Yok",
                street: "Münchener Straße 32",
                postalCode: "60329",
                city: "Frankfurt am Main",
                district: "Bahnhofsviertel",
                latitude: 50.10761,
                longitude: 8.66833,
                merkmale: [.eigenmarke, .kunst, .spaeti, .spaetOffen],
                note: "Bahnhofsviertel-Institution mit eigenem Bier und zweitem Standort in der Fahrgasse.",
                sources: [URL(string: "https://www.gewerbeverein-bahnhofsviertel-frankfurt.de/kiosk-yok-yok")!],
                verified: true,
                provenance: provenance("yok-yok", register: .wasserhaeuschen, editor: "maurice-jobst", verified: true),
                rating: RatingSummary(
                    average: 4.7,
                    count: 3,
                    ratings: [
                        Rating(login: "cybeerboy", stars: 5, date: Date(timeIntervalSince1970: 1_785_000_000), comment: "Nachts um drei die letzte Rettung."),
                        Rating(login: "jaypikay", stars: 5, date: Date(timeIntervalSince1970: 1_785_500_000), comment: nil),
                        Rating(login: "monsdroid", stars: 4, date: Date(timeIntervalSince1970: 1_786_000_000), comment: "Eigenmarke lohnt."),
                    ]
                )
            ),
            RegisterEntry(
                id: "kiosk-guenes",
                register: .wasserhaeuschen,
                name: "Kiosk Güneş",
                street: "Berger Straße 178",
                postalCode: "60385",
                city: "Frankfurt am Main",
                district: "Bornheim",
                latitude: 50.1279,
                longitude: 8.7031,
                merkmale: [.sitzplaetze, .baenkeDraussen],
                note: nil,
                sources: [URL(string: "https://www.openstreetmap.org/")!],
                verified: false,
                provenance: provenance("kiosk-guenes", register: .wasserhaeuschen, editor: nil, verified: false),
                rating: nil
            ),
            RegisterEntry(
                id: "zum-gemalten-haus",
                register: .ebbelwei,
                name: "Zum Gemalten Haus",
                street: "Schweizer Straße 67",
                postalCode: "60594",
                city: "Frankfurt am Main",
                district: "Sachsenhausen",
                latitude: 50.1017,
                longitude: 8.6836,
                since: 1922,
                merkmale: [.historisch, .handkaes, .schoppenVomFass, .garten],
                note: "Bemalte Fassade, langer Tisch, Schoppen vom Fass.",
                sources: [URL(string: "https://www.openstreetmap.org/")!],
                verified: true,
                provenance: provenance("zum-gemalten-haus", register: .ebbelwei, editor: "maurice-jobst", verified: true),
                rating: RatingSummary(
                    average: 4.0,
                    count: 1,
                    ratings: [Rating(login: "cybeerboy", stars: 4, date: Date(timeIntervalSince1970: 1_785_900_000), comment: nil)]
                )
            ),
        ],
        contributors: [
            Contributor(login: "maurice-jobst", entries: 2, verifications: 2, ratings: 0, firstRatings: []),
            Contributor(login: "cybeerboy", entries: 0, verifications: 0, ratings: 2, firstRatings: ["yok-yok", "zum-gemalten-haus"]),
        ],
        coverage: [
            CoverageArea(district: "Bahnhofsviertel", verified: 1, candidates: 0),
            CoverageArea(district: "Bornheim", verified: 0, candidates: 1),
            CoverageArea(district: "Sachsenhausen", verified: 1, candidates: 0),
        ]
    )

    public func snapshot() async throws -> RegisterSnapshot {
        Self.snapshot
    }
}
```

- [ ] **Step 5: Verify and commit**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format && make test && make format-check
```

Expected: `swift test` builds the package and the existing 29 tests still pass (nothing new is tested yet — these are types).

```bash
git add Packages && git commit -m "BEM-S04: register domain models and the RegisterProviding seam"
```

---

### Task 2: Decode a bembel-data bundle

**Files:**
- Create: `Packages/BEMBELKit/Sources/BEMBELKit/Data/BembelData/BembelDataBundle.swift`
- Create: `Packages/BEMBELKit/Tests/BEMBELKitTests/Fixtures/bembeldata.json`
- Create: `Packages/BEMBELKit/Tests/BEMBELKitTests/BembelDataBundleTests.swift`

**Interfaces:**
- Consumes: Task 1's domain models.
- Produces: `BembelDataBundle` (internal wire DTO), `BembelDataDataset: CuratedDataset` with `id == "bembeldata"`, and `BembelDataBundle.snapshot() -> RegisterSnapshot`. Task 3's provider calls exactly these.

- [ ] **Step 1: Write the wire type and the mapping**

Create `Packages/BEMBELKit/Sources/BEMBELKit/Data/BembelData/BembelDataBundle.swift`. Dates stay `String` on the wire and are parsed during mapping on purpose: a malformed date must cost that one field, not the whole register.

```swift
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
            let historyURL = URL(string: wire.provenance.historyURL),
            let fileURL = URL(string: wire.provenance.fileURL)
        else { return nil }

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

    /// Accepts both shapes bembel-data emits: full ISO-8601 timestamps from
    /// git (`%aI`) and plain `YYYY-MM-DD` rating dates.
    static func date(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let dayOnly = DateFormatter()
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        dayOnly.timeZone = TimeZone(identifier: "Europe/Berlin")
        dayOnly.dateFormat = "yyyy-MM-dd"
        return dayOnly.date(from: raw)
    }
}
```

- [ ] **Step 2: Write the fixture**

Create `Packages/BEMBELKit/Tests/BEMBELKitTests/Fixtures/bembeldata.json`. It deliberately carries one unknown register, one unknown Merkmal, one entry without ratings, and no `coverage` key — the four degradations that must not throw:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-08-13T18:04:11+00:00",
  "commit": "0912f28",
  "contributors": [
    { "login": "maurice-jobst", "entries": 1, "verifications": 1, "ratings": 0, "firstRatings": [] },
    { "login": "cybeerboy", "entries": 0, "verifications": 0, "ratings": 1, "firstRatings": ["yok-yok"] }
  ],
  "entries": [
    {
      "id": "yok-yok",
      "kind": "wasserhaeuschen",
      "name": "City Kiosk Yok-Yok",
      "address": { "street": "Münchener Straße 32", "postalCode": "60329", "city": "Frankfurt am Main" },
      "district": "Bahnhofsviertel",
      "latitude": 50.10761,
      "longitude": 8.66833,
      "openingHours": null,
      "since": null,
      "merkmale": ["eigenmarke", "kunst", "spaeti", "brandneues-merkmal"],
      "note": "Bahnhofsviertel-Institution.",
      "sources": ["https://example.org/yok-yok"],
      "verified": true,
      "provenance": {
        "lastEditor": "maurice-jobst",
        "lastChangedAt": "2026-08-13T12:00:00+00:00",
        "verifiedAt": "2026-08-13T12:00:00+00:00",
        "historyURL": "https://github.com/maurice-jobst/bembel-data/commits/main/data/wasserhaeuschen/yok-yok.json",
        "fileURL": "https://github.com/maurice-jobst/bembel-data/blob/main/data/wasserhaeuschen/yok-yok.json"
      },
      "rating": {
        "average": 5.0,
        "count": 1,
        "ratings": [{ "login": "cybeerboy", "stars": 5, "date": "2026-08-01", "comment": "Nachts um drei die letzte Rettung." }]
      }
    },
    {
      "id": "zum-gemalten-haus",
      "kind": "ebbelwei",
      "name": "Zum Gemalten Haus",
      "address": { "street": "Schweizer Straße 67", "postalCode": "60594", "city": "Frankfurt am Main" },
      "district": null,
      "latitude": 50.1017,
      "longitude": 8.6836,
      "openingHours": null,
      "since": 1922,
      "merkmale": ["garten", "historisch"],
      "note": null,
      "sources": ["https://example.org/gemaltes-haus"],
      "verified": false,
      "provenance": {
        "lastEditor": null,
        "lastChangedAt": "2026-08-12T09:30:00+00:00",
        "verifiedAt": null,
        "historyURL": "https://github.com/maurice-jobst/bembel-data/commits/main/data/ebbelwei/zum-gemalten-haus.json",
        "fileURL": "https://github.com/maurice-jobst/bembel-data/blob/main/data/ebbelwei/zum-gemalten-haus.json"
      },
      "rating": null
    },
    {
      "id": "unbekanntes-register",
      "kind": "kreppel",
      "name": "Aus der Zukunft",
      "address": { "street": "Zeil 1", "postalCode": "60313", "city": "Frankfurt am Main" },
      "district": null,
      "latitude": 50.1148,
      "longitude": 8.6836,
      "openingHours": null,
      "since": null,
      "merkmale": [],
      "note": null,
      "sources": [],
      "verified": true,
      "provenance": {
        "lastEditor": null,
        "lastChangedAt": null,
        "verifiedAt": null,
        "historyURL": "https://github.com/maurice-jobst/bembel-data/commits/main/data/kreppel/unbekanntes-register.json",
        "fileURL": "https://github.com/maurice-jobst/bembel-data/blob/main/data/kreppel/unbekanntes-register.json"
      },
      "rating": null
    }
  ]
}
```

- [ ] **Step 3: Write the decoder tests**

These earn their keep: the bundle is the one payload written by another repo's CI, so its degradations are exactly what will break silently in the field.

Create `Packages/BEMBELKit/Tests/BEMBELKitTests/BembelDataBundleTests.swift`:

```swift
import Foundation
import Testing

@testable import BEMBELKit

@Suite("bembel-data bundle")
struct BembelDataBundleTests {
    private func loadSnapshot() throws -> RegisterSnapshot {
        let url = try #require(Bundle.module.url(forResource: "bembeldata", withExtension: "json"))
        let bundle = try JSONDecoder().decode(BembelDataBundle.self, from: Data(contentsOf: url))
        return bundle.snapshot()
    }

    @Test("Entries map into the domain, one per known register")
    func mapsEntries() throws {
        let snapshot = try loadSnapshot()
        #expect(snapshot.entries.count == 2)
        #expect(snapshot.entries(in: .wasserhaeuschen).map(\.id) == ["yok-yok"])
        #expect(snapshot.entries(in: .ebbelwei).map(\.id) == ["zum-gemalten-haus"])
    }

    @Test("An entry from a register this build doesn't know is dropped, not thrown")
    func dropsUnknownRegister() throws {
        let snapshot = try loadSnapshot()
        #expect(!snapshot.entries.contains { $0.id == "unbekanntes-register" })
    }

    @Test("An unknown Merkmal survives decoding under its raw name")
    func keepsUnknownMerkmal() throws {
        let snapshot = try loadSnapshot()
        let entry = try #require(snapshot.entries.first { $0.id == "yok-yok" })
        #expect(entry.merkmale.contains(Merkmal(rawValue: "brandneues-merkmal")))
        #expect(entry.merkmale.contains(.eigenmarke))
    }

    @Test("Provenance carries the handle, the dates and the history link")
    func mapsProvenance() throws {
        let snapshot = try loadSnapshot()
        let entry = try #require(snapshot.entries.first { $0.id == "yok-yok" })
        #expect(entry.provenance.lastEditor == "maurice-jobst")
        #expect(entry.provenance.verifiedAt != nil)
        #expect(entry.provenance.historyURL.absoluteString.hasSuffix("/data/wasserhaeuschen/yok-yok.json"))

        let unverified = try #require(snapshot.entries.first { $0.id == "zum-gemalten-haus" })
        #expect(unverified.provenance.lastEditor == nil)
        #expect(unverified.provenance.verifiedAt == nil)
        #expect(unverified.isCandidate)
    }

    @Test("Ratings map with their day-only dates; a rating-less entry stays nil")
    func mapsRatings() throws {
        let snapshot = try loadSnapshot()
        let rated = try #require(snapshot.entries.first { $0.id == "yok-yok" })
        let summary = try #require(rated.rating)
        #expect(summary.count == 1)
        #expect(summary.average == 5.0)
        #expect(summary.ratings.first?.date != nil)
        #expect(snapshot.entries.first { $0.id == "zum-gemalten-haus" }?.rating == nil)
    }

    @Test("A bundle without coverage still loads — the game degrades, nothing breaks")
    func toleratesMissingCoverage() throws {
        let snapshot = try loadSnapshot()
        #expect(snapshot.coverage.isEmpty)
        #expect(snapshot.generatedAt != nil)
    }

    @Test("Merkmale of a register come out data-driven, most common first")
    func merkmaleAreDataDriven() throws {
        let snapshot = try loadSnapshot()
        // Both appear once, so the tie-break decides: raw value ascending.
        #expect(snapshot.merkmale(in: .ebbelwei) == [Merkmal.garten, Merkmal.historisch])
    }
}
```

- [ ] **Step 4: Run the tests**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make test
```

Expected: all pass. If `merkmaleAreDataDriven` fails on ordering, the tie-break in `RegisterSnapshot.merkmale(in:)` is what the assertion must match — fix the assertion to the implementation's documented order (count desc, then raw value asc), not the other way round.

- [ ] **Step 5: Commit**

```bash
make format && make format-check && git add Packages && git commit -m "BEM-S11: decode bembel-data bundles into register snapshots"
```

---

### Task 3: The live loader

**Files:**
- Modify: `Packages/BEMBELKit/Sources/BEMBELKit/Data/Curated/DatasetManifest.swift`
- Modify: `Packages/BEMBELKit/Sources/BEMBELKit/Data/Curated/DatasetStore.swift:54-58`
- Create: `Packages/BEMBELKit/Sources/BEMBELKit/Data/BembelData/BembelDataRegisterProvider.swift`
- Create: `scripts/sync_bembel_data.py`
- Create: `data/bembeldata.json` and `Packages/BEMBELKit/Sources/BEMBELKit/Resources/bembeldata.json` (generated, byte-identical)
- Modify: `data/manifest.json` and `Packages/BEMBELKit/Sources/BEMBELKit/Resources/manifest.json`
- Modify: `scripts/validate_data.py`
- Modify: `Packages/BEMBELKit/Tests/BEMBELKitTests/DatasetStoreTests.swift`

**Interfaces:**
- Consumes: `BembelDataDataset` (Task 2).
- Produces: `DatasetManifest.Entry.url` (optional absolute source), `BembelDataRegisterProvider(store:)`, and `DatasetStore.makeDefault()` gaining the bembel-data dataset. Task 5 injects the provider through `AppDependencies`.

- [ ] **Step 1: Teach the manifest about foreign hosts**

In `DatasetManifest.swift`, replace the `Entry` struct:

```swift
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
```

In `DatasetStore.swift`, replace the URL resolution at the top of `refresh(_:)`:

```swift
        guard
            let entry = manifest.datasets[D.id],
            let url = entry.url ?? URL(string: entry.path, relativeTo: manifest.baseURL)
        else { return .notInManifest }
```

Everything else in `DatasetStore` — ETag, validation-before-write, last-good — is untouched and now covers the register for free.

- [ ] **Step 2: Extend the manifest data (both copies, byte-identical)**

Write this to **both** `data/manifest.json` and `Packages/BEMBELKit/Sources/BEMBELKit/Resources/manifest.json`:

```json
{
  "version": 2,
  "baseURL": "https://data.invalid/bembel/",
  "datasets": {
    "rings": { "path": "rings.json" },
    "bembeldata": {
      "path": "bembeldata.json",
      "url": "https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json"
    }
  }
}
```

- [ ] **Step 3: Write the snapshot sync script**

Create `scripts/sync_bembel_data.py` — the bundled snapshot is generated, never hand-edited, exactly like `rings.json`:

```python
#!/usr/bin/env python3
"""Refresh the bundled bembel-data snapshot in both places.

The app ships a snapshot so a cold install works offline (BEM-A05). That file
is generated — run this before a release, or whenever the register looks stale
in a fresh build. Stdlib only.

    python3 scripts/sync_bembel_data.py                  # from the published dist branch
    python3 scripts/sync_bembel_data.py --from ../bembel-data/dist/bembel-data.json
"""

import argparse
import json
import sys
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
KIT_RESOURCES = REPO / "Packages" / "BEMBELKit" / "Sources" / "BEMBELKit" / "Resources"
SOURCE = "https://raw.githubusercontent.com/maurice-jobst/bembel-data/dist/bembel-data.json"
REQUIRED = {"schemaVersion", "entries", "contributors"}


def fetch(origin: str) -> bytes:
    if origin.startswith(("http://", "https://")):
        with urllib.request.urlopen(origin, timeout=30) as response:
            return response.read()
    return Path(origin).read_bytes()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--from", dest="origin", default=SOURCE)
    args = parser.parse_args()

    raw = fetch(args.origin)
    try:
        doc = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"FAIL — {args.origin} is not JSON: {exc}", file=sys.stderr)
        return 1
    if missing := REQUIRED - doc.keys():
        print(f"FAIL — bundle is missing {sorted(missing)}; refusing to ship it", file=sys.stderr)
        return 1

    for target in (REPO / "data" / "bembeldata.json", KIT_RESOURCES / "bembeldata.json"):
        target.write_bytes(raw)

    print(
        f"snapshot updated from {args.origin}: "
        f"{len(doc['entries'])} entries, schemaVersion {doc['schemaVersion']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Generate the snapshot**

```bash
cd /Users/krazykraut/Projects/BEMBEL && python3 scripts/sync_bembel_data.py
```

Expected: `snapshot updated from https://raw.githubusercontent.com/…` with a non-zero entry count. If it 404s, Phase 1a Task 3 has not merged yet — merge it first rather than hand-writing a snapshot.

- [ ] **Step 5: Extend the data validator**

In `scripts/validate_data.py`, inside `check_manifest`'s per-dataset loop, after the existing `path` checks, add the `url` rule:

```python
        if "url" in entry:
            url = entry["url"]
            if not isinstance(url, str) or not url.startswith("https://"):
                err(f"{where}: 'url' must be an https URL, got {url!r}")
```

and in `main()`, next to the existing mirror checks:

```python
    check_mirror("bembeldata.json")
```

Then run it:

```bash
cd /Users/krazykraut/Projects/BEMBEL && make validate
```

Expected: `data validation OK`. The mirror check proves both snapshot copies are byte-identical — the failure mode `make validate` exists to catch.

- [ ] **Step 6: Write the provider**

Create `Packages/BEMBELKit/Sources/BEMBELKit/Data/BembelData/BembelDataRegisterProvider.swift`:

```swift
import Foundation

/// Live register provider: bundled snapshot first, conditional GET against
/// the published bembel-data bundle when the cached copy ages out. A failed
/// refresh is not an error the UI ever sees — the read path always answers.
public actor BembelDataRegisterProvider: RegisterProviding {
    private static let staleness = Staleness(maxAge: 6 * 60 * 60)
    private static let lastRefreshKey = "bembeldata.lastRefreshedAt"

    private let store: DatasetStore
    private let defaults: UserDefaults
    private var cached: RegisterSnapshot?

    public init(store: DatasetStore, defaults: UserDefaults = AppGroup.defaults) {
        self.store = store
        self.defaults = defaults
    }

    public static func makeDefault() throws -> BembelDataRegisterProvider {
        BembelDataRegisterProvider(store: try DatasetStore.makeDefault())
    }

    public func snapshot() async throws -> RegisterSnapshot {
        if let cached { return cached }
        if shouldRefresh {
            // The outcome is deliberately ignored: the read path below falls
            // back to the last good data anyway, and any completed attempt —
            // 304, 5xx or offline — resets the clock rather than hammering
            // the host once per view appearance.
            await store.refresh(BembelDataDataset.self)
            defaults.set(Date().timeIntervalSince1970, forKey: Self.lastRefreshKey)
        }
        let snapshot = try await store.payload(for: BembelDataDataset.self).snapshot()
        cached = snapshot
        return snapshot
    }

    /// Drops the in-memory cache so the next read re-reads from disk and may
    /// refresh again — used by pull-to-refresh.
    public func invalidate() {
        cached = nil
        defaults.removeObject(forKey: Self.lastRefreshKey)
    }

    private var shouldRefresh: Bool {
        let stamp = defaults.double(forKey: Self.lastRefreshKey)
        guard stamp > 0 else { return true }
        return Self.staleness.isStale(fetchedAt: Date(timeIntervalSince1970: stamp))
    }
}
```

`store.refresh(_:)` is `@discardableResult`, so the bare call compiles as written.

- [ ] **Step 7: Extend the store tests**

Add to the existing `DatasetStoreTests` suite in `Packages/BEMBELKit/Tests/BEMBELKitTests/DatasetStoreTests.swift`:

```swift
    @Test("An entry's absolute url wins over baseURL — foreign-host datasets")
    func absoluteURLOverridesBase() async throws {
        let manifest = DatasetManifest(
            version: 2,
            baseURL: URL(string: "https://mock.test/")!,
            datasets: [
                "testdata": .init(
                    path: "testdata.json",
                    url: URL(string: "https://raw.example.test/dist/bembel-data.json")!
                )
            ]
        )
        let (store, _) = try makeStore(manifest: manifest)
        MockURLProtocol.handler = { request in
            #expect(request.url?.absoluteString == "https://raw.example.test/dist/bembel-data.json")
            return (200, ["ETag": "\"v9\""], Data(#"{"version": 9, "items": ["remote"]}"#.utf8))
        }
        #expect(await store.refresh(TestDataset.self) == .updated)
        let payload = try await store.payload(for: TestDataset.self)
        #expect(payload == TestPayload(version: 9, items: ["remote"]))
    }
```

- [ ] **Step 8: Verify and commit**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format && make test && make validate && make build && make format-check
```

Expected: tests pass including the new one; `make validate` OK; the app builds.

```bash
git add -A && git commit -m "BEM-S11: bembel-data loader — foreign-host manifest entries, bundled snapshot, staleness window"
```

---

### Task 4: The rating funnel

**Files:**
- Create: `Packages/BEMBELKit/Sources/BEMBELKit/Community/RatingFunnel.swift`
- Create: `Packages/BEMBELKit/Tests/BEMBELKitTests/RatingFunnelTests.swift`

**Interfaces:**
- Produces: `RatingFunnel.rate(entryID:stars:login:date:)`, `.report(register:name:)`, `.verify(entryID:name:)`, `RatingFunnel.placeholderLogin`, `RatingFunnel.sanitizedLogin(_:)`. Tasks 7 and 8 open these URLs.
- Contract: the field ids come from `docs/app-funnel.md` in bembel-data, enforced there by `scripts/check_funnel.py` (Phase 1a Task 4).

- [ ] **Step 1: Write the builder**

Create `Packages/BEMBELKit/Sources/BEMBELKit/Community/RatingFunnel.swift`:

```swift
import Foundation

/// The app is the top of the rating funnel — and nothing more than that.
/// Every "contribute" action is a URL into bembel-data: no auth, no API, no
/// token, no BEMBEL account. What travels is what is already public.
///
/// The query field ids are a contract with bembel-data's issue forms,
/// documented in that repo's `docs/app-funnel.md` and checked in its CI by
/// `scripts/check_funnel.py`. Renaming one there breaks the prefill here.
public enum RatingFunnel {
    public static let repository = URL(string: "https://github.com/maurice-jobst/bembel-data")!
    /// Shown in the filename when no handle is configured — GitHub lets the
    /// contributor fix it in the browser before opening the PR.
    public static let placeholderLogin = "DEIN-LOGIN"

    /// GitHub logins: alphanumerics and single hyphens, at most 39 characters.
    /// This value lands in a URL path, so anything else is rejected outright
    /// rather than escaped — the Settings field is user input.
    public static func sanitizedLogin(_ raw: String?) -> String? {
        guard var candidate = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty else {
            return nil
        }
        if candidate.hasPrefix("@") { candidate.removeFirst() }
        guard candidate.count <= 39,
            candidate.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }),
            !candidate.hasPrefix("-"), !candidate.hasSuffix("-"), !candidate.contains("--")
        else { return nil }
        return candidate
    }

    /// Opens GitHub's "create new file" flow with the rating file prefilled.
    /// GitHub forks the repo and opens the pull request; the file's name is
    /// the account that opened it, which is the whole trust model.
    public static func rate(entryID: String, stars: Int, login: String?, date: Date = Date()) -> URL? {
        guard isValidEntryID(entryID) else { return nil }
        let handle = sanitizedLogin(login) ?? placeholderLogin
        let clamped = min(max(stars, 1), 5)

        let body = """
            {
              "entry": "\(entryID)",
              "login": "\(handle)",
              "stars": \(clamped),
              "date": "\(day(date))"
            }
            """

        return url(
            path: "new/main",
            items: [
                "filename": "data/bewertungen/\(entryID)/\(handle).json",
                "value": body,
            ]
        )
    }

    /// "Ein Eintrag fehlt" — the register's issue form, prefilled with a name.
    public static func report(register: PlaceRegister, name: String? = nil) -> URL? {
        guard register.isCommunity else { return nil }
        let label = register == .ebbelwei ? "Ebbelwei" : "Wasserhäuschen"
        var items = ["template": "\(register.rawValue).yml", "title": "[\(label)] \(name ?? "")"]
        if let name { items["name"] = name }
        return url(path: "issues/new", items: items)
    }

    /// "Hilf mit, verifizieren" — the coverage game's call to action, and the
    /// correction link on every entry.
    public static func verify(entryID: String, name: String) -> URL? {
        guard isValidEntryID(entryID) else { return nil }
        return url(
            path: "issues/new",
            items: [
                "template": "verifizierung.yml",
                "title": "[Verifizierung] \(name)",
                "eintrag": entryID,
            ]
        )
    }

    private static func isValidEntryID(_ id: String) -> Bool {
        !id.isEmpty
            && id.allSatisfy { $0.isASCII && ($0.isLowercase && $0.isLetter || $0.isNumber || $0 == "-") }
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func url(path: String, items: [String: String]) -> URL? {
        guard var components = URLComponents(
            url: repository.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else { return nil }
        components.queryItems = items.sorted { $0.key < $1.key }.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        return components.url
    }
}
```

- [ ] **Step 2: Write the tests**

These earn their keep: a wrong path or a wrong field id produces a URL that opens a *plausible but empty* form — the failure is invisible without a test. Assert on parsed components, not on percent-encoded strings, so the test survives Foundation's encoding choices.

Create `Packages/BEMBELKit/Tests/BEMBELKitTests/RatingFunnelTests.swift`:

```swift
import Foundation
import Testing

@testable import BEMBELKit

@Suite("Rating funnel URLs")
struct RatingFunnelTests {
    private func items(_ url: URL?) throws -> [String: String] {
        let url = try #require(url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    @Test("A rating with a configured handle targets that account's file")
    func rateWithHandle() throws {
        let date = Date(timeIntervalSince1970: 1_786_000_000)
        let url = try #require(RatingFunnel.rate(entryID: "yok-yok", stars: 5, login: "cybeerboy", date: date))
        #expect(url.path() == "/maurice-jobst/bembel-data/new/main")

        let query = try items(url)
        #expect(query["filename"] == "data/bewertungen/yok-yok/cybeerboy.json")

        let body = try #require(query["value"])
        let decoded = try #require(try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any])
        #expect(decoded["entry"] as? String == "yok-yok")
        #expect(decoded["login"] as? String == "cybeerboy")
        #expect(decoded["stars"] as? Int == 5)
        #expect(decoded["date"] as? String != nil)
    }

    @Test("Without a handle the filename carries the placeholder, not an empty segment")
    func rateWithoutHandle() throws {
        let query = try items(RatingFunnel.rate(entryID: "yok-yok", stars: 3, login: nil))
        #expect(query["filename"] == "data/bewertungen/yok-yok/DEIN-LOGIN.json")
    }

    @Test("Stars are clamped into the schema's 1…5")
    func clampsStarsIntoRange() throws {
        let low = try items(RatingFunnel.rate(entryID: "yok-yok", stars: 0, login: "a"))
        let high = try items(RatingFunnel.rate(entryID: "yok-yok", stars: 99, login: "a"))
        #expect(try #require(low["value"]).contains("\"stars\": 1"))
        #expect(try #require(high["value"]).contains("\"stars\": 5"))
    }

    @Test("A hostile handle never reaches the URL path")
    func rejectsHostileHandle() {
        #expect(RatingFunnel.sanitizedLogin("../../etc/passwd") == nil)
        #expect(RatingFunnel.sanitizedLogin("has space") == nil)
        #expect(RatingFunnel.sanitizedLogin("-leading") == nil)
        #expect(RatingFunnel.sanitizedLogin("double--hyphen") == nil)
        #expect(RatingFunnel.sanitizedLogin(String(repeating: "a", count: 40)) == nil)
        #expect(RatingFunnel.sanitizedLogin("@cybeerboy") == "cybeerboy")
        #expect(RatingFunnel.sanitizedLogin("  monsdroid  ") == "monsdroid")
    }

    @Test("A hostile entry id yields no URL at all")
    func rejectsHostileEntryID() {
        #expect(RatingFunnel.rate(entryID: "../secrets", stars: 5, login: "a") == nil)
        #expect(RatingFunnel.verify(entryID: "Yok Yok", name: "x") == nil)
    }

    @Test("Reporting a missing entry hits the register's own issue form")
    func reportForm() throws {
        let kiosk = try items(RatingFunnel.report(register: .wasserhaeuschen, name: "Kiosk Güneş"))
        #expect(kiosk["template"] == "wasserhaeuschen.yml")
        #expect(kiosk["name"] == "Kiosk Güneş")
        #expect(kiosk["title"] == "[Wasserhäuschen] Kiosk Güneş")

        let ebbelwei = try items(RatingFunnel.report(register: .ebbelwei, name: nil))
        #expect(ebbelwei["template"] == "ebbelwei.yml")

        #expect(RatingFunnel.report(register: .trinkbrunnen, name: nil) == nil)
    }

    @Test("Verifying prefills the entry id the coverage game is about")
    func verifyForm() throws {
        let query = try items(RatingFunnel.verify(entryID: "kiosk-guenes", name: "Kiosk Güneş"))
        #expect(query["template"] == "verifizierung.yml")
        #expect(query["eintrag"] == "kiosk-guenes")
        #expect(query["title"] == "[Verifizierung] Kiosk Güneş")
    }
}
```

- [ ] **Step 3: Verify and commit**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format && make test && make format-check
```

Expected: all funnel tests pass.

```bash
git add Packages && git commit -m "BEM-S04: rating funnel URL builder (no auth, no API, no accounts)"
```

---

### Task 5: The sticker engine

**Files:**
- Create: `Packages/BEMBELKit/Sources/BEMBELKit/Community/Sticker.swift`
- Create: `Packages/BEMBELKit/Tests/BEMBELKitTests/StickerRulesTests.swift`

**Interfaces:**
- Consumes: `Contributor` (Task 1).
- Produces: `Sticker`, `StickerRules.awarded(login:contributors:visitedEntryIDs:)`, `StickerState` (App Group persistence with keys `sticker.githubLogin`, `sticker.visitedEntryIDs`, `sticker.visitDetectionEnabled`). Tasks 9 and 10 read and write these.

- [ ] **Step 1: Write the engine**

Create `Packages/BEMBELKit/Sources/BEMBELKit/Community/Sticker.swift`:

```swift
import Foundation

/// Stickers that ship at 1.0. The full Sammelalbum — city hotspots, Game
/// Center mirroring, seasonal drops — stays M4 (BEM-S01).
public enum Sticker: Hashable, Sendable, Identifiable {
    /// A merged bembel-data entry contribution.
    case datenspender
    /// A verification that flipped an entry to verified.
    case verifizierer
    /// The first rating on some entry.
    case ersteBewertung
    /// Visited a kiosk in person, detected on-device.
    case kioskStempel(entryID: String)

    public var id: String {
        switch self {
        case .datenspender: "datenspender"
        case .verifizierer: "verifizierer"
        case .ersteBewertung: "erste-bewertung"
        case .kioskStempel(let entryID): "stempel-\(entryID)"
        }
    }

    /// Data-linked stickers are earned in bembel-data and recognised by
    /// handle; stamps are earned on the phone and never leave it.
    public var isDataLinked: Bool {
        if case .kioskStempel = self { return false }
        return true
    }

    public var systemImage: String {
        switch self {
        case .datenspender: "square.and.arrow.up.on.square"
        case .verifizierer: "checkmark.seal"
        case .ersteBewertung: "star.circle"
        case .kioskStempel: "mappin.and.ellipse"
        }
    }

    /// The three data-linked stickers, in album order.
    public static let dataLinked: [Sticker] = [.datenspender, .verifizierer, .ersteBewertung]
}

/// Pure rules over (contributor tallies, on-device visits). No network, no
/// clock, no storage — the whole engine is this function, which is why it can
/// be tested exhaustively and trusted in the album.
public enum StickerRules {
    public static func awarded(
        login: String?,
        contributors: [Contributor],
        visitedEntryIDs: Set<String>
    ) -> Set<Sticker> {
        var earned = Set(visitedEntryIDs.map { Sticker.kioskStempel(entryID: $0) })

        guard
            let login = RatingFunnel.sanitizedLogin(login)?.lowercased(),
            let me = contributors.first(where: { $0.login.lowercased() == login })
        else { return earned }

        if me.entries > 0 { earned.insert(.datenspender) }
        if me.verifications > 0 { earned.insert(.verifizierer) }
        if !me.firstRatings.isEmpty { earned.insert(.ersteBewertung) }
        return earned
    }
}

/// On-device sticker state in the App Group store. Handle squatting is
/// accepted and harmless: the field only decides which public tallies the
/// album mirrors, and nothing is written back anywhere.
public enum StickerState {
    public static let loginKey = "sticker.githubLogin"
    public static let visitsKey = "sticker.visitedEntryIDs"
    public static let visitDetectionKey = "sticker.visitDetectionEnabled"

    public static func login(_ defaults: UserDefaults = AppGroup.defaults) -> String? {
        defaults.string(forKey: loginKey).flatMap(RatingFunnel.sanitizedLogin)
    }

    public static func visitedEntryIDs(_ defaults: UserDefaults = AppGroup.defaults) -> Set<String> {
        Set(defaults.stringArray(forKey: visitsKey) ?? [])
    }

    @discardableResult
    public static func recordVisit(entryID: String, _ defaults: UserDefaults = AppGroup.defaults) -> Bool {
        var visits = visitedEntryIDs(defaults)
        guard visits.insert(entryID).inserted else { return false }
        defaults.set(visits.sorted(), forKey: visitsKey)
        return true
    }

    public static func isVisitDetectionEnabled(_ defaults: UserDefaults = AppGroup.defaults) -> Bool {
        defaults.bool(forKey: visitDetectionKey)
    }
}
```

- [ ] **Step 2: Write the tests**

Create `Packages/BEMBELKit/Tests/BEMBELKitTests/StickerRulesTests.swift`:

```swift
import Foundation
import Testing

@testable import BEMBELKit

@Suite("Sticker rules")
struct StickerRulesTests {
    private let contributors = [
        Contributor(login: "maurice-jobst", entries: 2, verifications: 1, ratings: 0, firstRatings: []),
        Contributor(login: "cybeerboy", entries: 0, verifications: 0, ratings: 3, firstRatings: ["yok-yok"]),
        Contributor(login: "jaypikay", entries: 0, verifications: 0, ratings: 1, firstRatings: []),
    ]

    @Test("Contributing an entry earns Datenspender; verifying earns Verifizierer")
    func contributorStickers() {
        let earned = StickerRules.awarded(login: "maurice-jobst", contributors: contributors, visitedEntryIDs: [])
        #expect(earned.contains(.datenspender))
        #expect(earned.contains(.verifizierer))
        #expect(!earned.contains(.ersteBewertung))
    }

    @Test("Being first to rate an entry earns Erste Bewertung — rating alone does not")
    func firstRatingSticker() {
        let first = StickerRules.awarded(login: "cybeerboy", contributors: contributors, visitedEntryIDs: [])
        #expect(first == [.ersteBewertung])

        let later = StickerRules.awarded(login: "jaypikay", contributors: contributors, visitedEntryIDs: [])
        #expect(later.isEmpty)
    }

    @Test("Handles match case-insensitively and tolerate a leading @")
    func handleMatching() {
        #expect(StickerRules.awarded(login: "@CyBeerBoy", contributors: contributors, visitedEntryIDs: []).contains(.ersteBewertung))
    }

    @Test("No handle, or an unknown one, earns no data-linked sticker")
    func withoutHandle() {
        #expect(StickerRules.awarded(login: nil, contributors: contributors, visitedEntryIDs: []).isEmpty)
        #expect(StickerRules.awarded(login: "", contributors: contributors, visitedEntryIDs: []).isEmpty)
        #expect(StickerRules.awarded(login: "niemand", contributors: contributors, visitedEntryIDs: []).isEmpty)
    }

    @Test("Visit stamps are independent of any handle")
    func visitStamps() {
        let earned = StickerRules.awarded(login: nil, contributors: contributors, visitedEntryIDs: ["yok-yok", "kiosk-guenes"])
        #expect(earned == [.kioskStempel(entryID: "yok-yok"), .kioskStempel(entryID: "kiosk-guenes")])
        #expect(earned.allSatisfy { !$0.isDataLinked })
    }

    @Test("Recording the same visit twice is idempotent")
    func recordVisitIsIdempotent() throws {
        let defaults = try #require(UserDefaults(suiteName: "bembel-sticker-tests-\(UUID().uuidString)"))
        #expect(StickerState.recordVisit(entryID: "yok-yok", defaults))
        #expect(!StickerState.recordVisit(entryID: "yok-yok", defaults))
        #expect(StickerState.visitedEntryIDs(defaults) == ["yok-yok"])
    }
}
```

- [ ] **Step 3: Verify and commit**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format && make test && make format-check
```

Expected: all sticker tests pass.

```bash
git add Packages && git commit -m "BEM-S01: data-linked sticker rules and on-device sticker state"
```

---

### Task 6: The Orte tab — navigation rework

Restructures navigation so the hero sits in position 1 without a sixth tab: Trinkwasser folds into a new **Orte** tab that carries all three place datasets behind a segmented control.

**Files:**
- Modify: `Packages/BEMBELKit/Sources/BEMBELKit/Navigation/BEMTab.swift`
- Modify: `Packages/BEMBELKit/Sources/BEMBELKit/Navigation/DeepLink.swift`
- Modify: `Packages/BEMBELKit/Sources/BEMBELKit/Navigation/Router.swift`
- Modify: `Packages/BEMBELKit/Tests/BEMBELKitTests/DeepLinkTests.swift`
- Create: `App/Features/Places/PlacesModel.swift`
- Create: `App/Features/Places/PlacesView.swift`
- Create: `App/Features/Places/FountainViews.swift` (moved from `App/Features/Water/WaterView.swift`)
- Delete: `App/Features/Water/` (both files)
- Modify: `App/RootView.swift`
- Modify: `App/AppDependencies.swift`
- Modify: `App/BEMBELApp.swift`
- Modify: `App/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `RegisterProviding`, `PlaceRegister`, `BembelDataRegisterProvider` (Tasks 1, 3).
- Produces: `BEMTab.places` (first case), `DeepLink.places(PlaceRegister?)`, `Router.selectedRegister`, `PlacesModel` (`snapshot`, `fountains`, `selectedRegister`, `selectedMerkmale`, `visibleEntries`, `load(register:fountains:)`), `PlacesView`. Tasks 7–10 extend `PlacesView` and `PlacesModel`.

- [ ] **Step 1: Rework the tab enum**

Replace `BEMTab.swift`'s enum body — `water` becomes `places`, in position 1:

```swift
/// The five v1.0 surfaces. Order is tab order. `places` carries all three
/// place datasets (Wasserhäuschen, Ebbelwei, Trinkbrunnen) so the hero gets
/// position one without pushing the tab bar into an overflow menu.
public enum BEMTab: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case places
    case departures
    case shadow
    case radar
    case city

    public var id: String { rawValue }
}
```

- [ ] **Step 2: Extend deep links**

In `DeepLink.swift`, update the grammar comment and the enum, keeping the old water hosts alive as aliases — deep links already exist in the wild (widgets, shortcuts) and breaking them is a regression:

```swift
/// Grammar (hosts accept German aliases):
///   bembel://places     | orte
///   bembel://kiosk      | wasserhaeuschen
///   bembel://ebbelwei   | apfelwein
///   bembel://water      | wasser | brunnen   (legacy: opens Orte on Trinkbrunnen)
///   bembel://departures | abfahrten
///   bembel://shadow     | schatten     [?t=ISO-8601, naive times = Europe/Berlin]
///   bembel://radar      | regen
///   bembel://city       | stadt
///   bembel://settings   | einstellungen
public enum DeepLink: Hashable, Sendable {
    case tab(BEMTab)
    /// Orte, optionally preselecting one register's segment.
    case places(PlaceRegister?)
    case shadow(at: Date?)
    case settings
```

and in `parse(_:)` replace the `water` case with:

```swift
        case "places", "orte":
            return .places(nil)
        case "kiosk", "wasserhaeuschen":
            return .places(.wasserhaeuschen)
        case "ebbelwei", "apfelwein":
            return .places(.ebbelwei)
        case "water", "wasser", "brunnen":
            return .places(.trinkbrunnen)
```

- [ ] **Step 3: Teach the router about the segment**

In `Router.swift`, change the default tab and add the register selection:

```swift
    public var selectedTab: BEMTab = .places
    public var selectedRegister: PlaceRegister = .wasserhaeuschen
```

and add the case to `open(_:)`:

```swift
        case .places(let register):
            if let register { selectedRegister = register }
            selectedTab = .places
```

- [ ] **Step 4: Update the deep link tests**

In `DeepLinkTests.swift`, replace every assertion that expects `.tab(.water)` with the new shape, and add the alias coverage:

```swift
    @Test("Orte opens with and without a preselected register")
    func placesLinks() {
        #expect(DeepLink.parse(URL(string: "bembel://orte")!) == .places(nil))
        #expect(DeepLink.parse(URL(string: "bembel://kiosk")!) == .places(.wasserhaeuschen))
        #expect(DeepLink.parse(URL(string: "bembel://ebbelwei")!) == .places(.ebbelwei))
    }

    @Test("The old water hosts still land somewhere sensible")
    func legacyWaterAliases() {
        #expect(DeepLink.parse(URL(string: "bembel://water")!) == .places(.trinkbrunnen))
        #expect(DeepLink.parse(URL(string: "bembel://wasser")!) == .places(.trinkbrunnen))
    }
```

- [ ] **Step 5: Move the fountain views**

```bash
cd /Users/krazykraut/Projects/BEMBEL && mkdir -p App/Features/Places && git mv App/Features/Water/WaterView.swift App/Features/Places/FountainViews.swift && git rm App/Features/Water/WaterModel.swift
```

In `FountainViews.swift`, delete `struct WaterView` and `enum WaterFilter` entirely (the tab shell replaces both) and keep `FountainPin` and `FountainDetailCard` unchanged — they are the Trinkbrunnen segment's rendering and stay exactly as they are.

- [ ] **Step 6: Write the tab model**

Create `App/Features/Places/PlacesModel.swift`:

```swift
import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class PlacesModel {
    private(set) var snapshot = RegisterSnapshot.empty
    private(set) var fountains: [Fountain] = []
    private(set) var lastError: Error?
    private(set) var isLoading = false
    /// One load per tab lifetime. Not "is the snapshot empty" — an empty
    /// register is a legitimate result and must not retrigger the load.
    private var hasLoaded = false

    var selectedRegister: PlaceRegister = .wasserhaeuschen
    /// Merkmale-first navigation: an empty set means "everything", and the
    /// chips are generated from the data, never from a hardcoded list.
    var selectedMerkmale: Set<Merkmal> = []
    var selectedEntry: RegisterEntry?
    var selectedFountain: Fountain?

    var availableMerkmale: [Merkmal] {
        snapshot.merkmale(in: selectedRegister)
    }

    /// Entries in the current register matching every selected Merkmal
    /// (intersection — "spät offen *und* Bänke draußen" is the question people
    /// actually ask), verified first, then alphabetical.
    var visibleEntries: [RegisterEntry] {
        snapshot.entries(in: selectedRegister)
            .filter { entry in selectedMerkmale.isSubset(of: Set(entry.merkmale)) }
            .sorted { lhs, rhs in
                lhs.verified == rhs.verified ? lhs.name < rhs.name : lhs.verified
            }
    }

    var coverage: [CoverageArea] {
        snapshot.coverage.sorted { $0.district < $1.district }
    }

    func load(register: any RegisterProviding, fountains fountainProvider: any FountainProviding) async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await register.snapshot()
        } catch {
            lastError = error
        }
        do {
            fountains = try await fountainProvider.fountains()
            selectedFountain = fountains.first(where: \.featured) ?? fountains.first
        } catch {
            lastError = error
        }
    }

    func toggle(_ merkmal: Merkmal) {
        if selectedMerkmale.contains(merkmal) {
            selectedMerkmale.remove(merkmal)
        } else {
            selectedMerkmale.insert(merkmal)
        }
    }

    /// Switching register drops filters — a Merkmal from another register's
    /// vocabulary would silently empty the list.
    func select(register: PlaceRegister) {
        guard register != selectedRegister else { return }
        selectedRegister = register
        selectedMerkmale = []
        selectedEntry = nil
    }
}
```

- [ ] **Step 7: Write the tab shell**

Create `App/Features/Places/PlacesView.swift`. Map first (matching the Trinkwasser design language), register segments on top, Merkmale chips below, detail as a bottom card:

```swift
import BEMBELKit
import MapKit
import SwiftUI

/// Orte: the community registers plus the drinking fountains, one map, one
/// segmented control. The hero surface — Merkmale are the navigation, not a
/// filter buried in a sheet.
struct PlacesView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(Router.self) private var router
    @State private var model = PlacesModel()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.1122, longitude: 8.6780),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        ZStack {
            map
            VStack(spacing: BEMSpacing.m) {
                registerPicker
                if model.selectedRegister.isCommunity {
                    MerkmalBar(model: model)
                }
                Spacer()
                detailCard
            }
            .padding(.horizontal, BEMSpacing.m)
        }
        .task {
            await model.load(register: dependencies.register, fountains: dependencies.fountains)
        }
        .onChange(of: router.selectedRegister) { _, new in
            model.select(register: new)
        }
    }

    @ViewBuilder
    private var map: some View {
        Map(position: $position) {
            if model.selectedRegister == .trinkbrunnen {
                ForEach(model.fountains) { fountain in
                    Annotation(fountain.name, coordinate: fountain.coordinate) {
                        FountainPin(featured: fountain.id == model.selectedFountain?.id)
                            .onTapGesture { model.selectedFountain = fountain }
                    }
                    .annotationTitles(.hidden)
                }
            } else {
                ForEach(model.visibleEntries) { entry in
                    Annotation(entry.name, coordinate: entry.coordinate) {
                        EntryPin(entry: entry, selected: entry.id == model.selectedEntry?.id)
                            .onTapGesture { model.selectedEntry = entry }
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
    }

    private var registerPicker: some View {
        Picker("places.register.picker", selection: registerBinding) {
            ForEach(PlaceRegister.allCases) { register in
                Text(register.titleKey).tag(register)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var registerBinding: Binding<PlaceRegister> {
        Binding(get: { model.selectedRegister }, set: { model.select(register: $0) })
    }

    @ViewBuilder
    private var detailCard: some View {
        if model.selectedRegister == .trinkbrunnen {
            if let fountain = model.selectedFountain {
                FountainDetailCard(fountain: fountain)
            }
        } else if let entry = model.selectedEntry {
            EntryDetailCard(entry: entry)
        }
    }
}

/// Pin for a register entry. A candidate — an entry nobody has verified yet —
/// is deliberately grey and hollow: it reads as an invitation, not as data.
struct EntryPin: View {
    let entry: RegisterEntry
    let selected: Bool

    var body: some View {
        Circle()
            .fill(entry.isCandidate ? BEMColor.saltGlazeElevated : BEMColor.cobalt)
            .stroke(entry.isCandidate ? BEMColor.glazeLine : BEMColor.saltGlaze, lineWidth: selected ? 3 : 2)
            .frame(width: selected ? 38 : 28, height: selected ? 38 : 28)
            .overlay {
                Image(systemName: entry.register == .ebbelwei ? "wineglass.fill" : "cup.and.saucer.fill")
                    .font(.footnote)
                    .foregroundStyle(entry.isCandidate ? BEMColor.inkSecondary : BEMColor.inkOnCobalt)
            }
            .shadow(color: .black.opacity(selected ? 0.5 : 0), radius: 6, y: 4)
    }
}

extension PlaceRegister {
    var titleKey: LocalizedStringKey {
        switch self {
        case .wasserhaeuschen: "places.register.wasserhaeuschen"
        case .ebbelwei: "places.register.ebbelwei"
        case .trinkbrunnen: "places.register.trinkbrunnen"
        }
    }
}

#Preview {
    PlacesView()
        .environment(Router())
}
```

`MerkmalBar` and `EntryDetailCard` land in Task 7; until then, stub them at the bottom of `PlacesView.swift` as two-line placeholders so this task builds, and delete the stubs when Task 7 creates the real files.

- [ ] **Step 8: Wire the app**

In `App/AppDependencies.swift`, add the register provider — live by default, sample only if construction fails (a broken Application Support directory must not take the hero down):

```swift
struct AppDependencies {
    var departures: any DeparturesProviding = SampleDeparturesProvider()
    var fountains: any FountainProviding = SampleFountainProvider()
    var radar: any RadarProviding = SampleRadarProvider()
    var cityStatus: any CityStatusProviding = SampleCityStatusProvider()
    var register: any RegisterProviding = AppDependencies.liveRegister()

    /// `??` cannot bridge the two concrete types into `any RegisterProviding`,
    /// so this stays an explicit branch.
    static func liveRegister() -> any RegisterProviding {
        if let live = try? BembelDataRegisterProvider.makeDefault() { return live }
        return SampleRegisterProvider()
    }
}
```

In `App/RootView.swift`, replace the `.water` arm of `screen(for:)` and its title/icon entries:

```swift
        case .places: PlacesView()
```

```swift
        case .places: "tab.places"
```

```swift
        case .places: "mappin.and.ellipse"
```

- [ ] **Step 9: Add the strings**

Insert into `App/Resources/Localizable.xcstrings`, keeping the file's alphabetical key order:

```json
    "places.register.ebbelwei": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Ebbelwei" } } }
    },
    "places.register.picker": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Register" } } }
    },
    "places.register.trinkbrunnen": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Brunnen" } } }
    },
    "places.register.wasserhaeuschen": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Wasserhäuschen" } } }
    },
    "tab.places": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Orte" } } }
    },
```

and delete the now-unused `tab.water`, `water.filter.*` and `water.search` keys — `BEM-H02` audits for exactly this kind of leftover. Keep every `water.*` key that `FountainDetailCard` still uses (`water.distance`, `water.status.*`, `water.season*`, `water.hours*`, `water.quality*`, `water.route`, `water.bookmark`, `water.share`, `water.source`).

- [ ] **Step 10: Verify and commit**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format && make test && make build && make format-check
```

Expected: deep-link tests pass with the new shapes; the app builds with five tabs, Orte first.

```bash
git add -A && git commit -m "BEM-S04: Orte tab — registers and fountains under one surface, deep links kept alive"
```

---

### Task 7: Merkmale navigation, entry detail, provenance byline, funnel

The hero's actual content: the tag bar that drives navigation, and the detail card whose byline is the anti-Yelp move.

**Files:**
- Create: `App/Features/Places/MerkmalBar.swift`
- Create: `App/Features/Places/EntryDetailCard.swift`
- Create: `App/Features/Places/ProvenanceByline.swift`
- Modify: `App/Features/Places/PlacesView.swift` (delete the stubs from Task 6)
- Modify: `App/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `PlacesModel`, `RatingFunnel`, `StickerState`.
- Produces: `MerkmalBar(model:)`, `EntryDetailCard(entry:)`, `ProvenanceByline(provenance:verified:)`.

- [ ] **Step 1: The Merkmale bar**

Create `App/Features/Places/MerkmalBar.swift`:

```swift
import BEMBELKit
import SwiftUI

/// Merkmale as primary navigation. The chips come from the data — whatever
/// the current register actually carries, most common first — so a new tag
/// published in bembel-data appears here without an app update.
struct MerkmalBar: View {
    @Bindable var model: PlacesModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BEMSpacing.s) {
                SelectionChip(
                    title: Text("places.merkmale.all"),
                    isSelected: model.selectedMerkmale.isEmpty,
                    glass: true
                ) {
                    model.selectedMerkmale = []
                }

                ForEach(model.availableMerkmale) { merkmal in
                    SelectionChip(
                        title: Text(merkmal.displayName),
                        isSelected: model.selectedMerkmale.contains(merkmal),
                        glass: true
                    ) {
                        model.toggle(merkmal)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Text("places.merkmale.a11y"))
    }
}

extension Merkmal {
    /// Known Merkmale are localised; an unknown one shows its raw slug, which
    /// is readable by construction and better than hiding the entry.
    var displayName: String {
        let localized = String(localized: String.LocalizationValue(localizationKey))
        return localized == localizationKey ? rawValue : localized
    }
}
```

- [ ] **Step 2: The provenance byline**

Create `App/Features/Places/ProvenanceByline.swift`:

```swift
import BEMBELKit
import SwiftUI

/// Every entry says who stands behind it. Verified date, last editor, one tap
/// to the full git history — the difference between this register and an
/// anonymous star average.
struct ProvenanceByline: View {
    let provenance: Provenance
    let verified: Bool

    private static let dateStyle = Date.FormatStyle.dateTime.day().month(.abbreviated).year()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: verified ? "checkmark.seal.fill" : "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(verified ? BEMColor.good : BEMColor.inkSecondary)
                if verified, let verifiedAt = provenance.verifiedAt {
                    Text("entry.provenance.verified \(verifiedAt.formatted(Self.dateStyle))")
                } else {
                    Text("entry.provenance.unverified")
                }
            }
            .font(BEMFont.dataLabel)
            .foregroundStyle(verified ? BEMColor.ink : BEMColor.inkSecondary)

            if let editor = provenance.lastEditor {
                Text("entry.provenance.editor \(editor)")
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
            }

            Link(destination: provenance.historyURL) {
                HStack(spacing: 4) {
                    Text("entry.provenance.history")
                    Image(systemName: "arrow.up.right")
                }
                .font(BEMFont.dataLabel)
                .foregroundStyle(BEMColor.cobalt)
            }
        }
    }
}
```

- [ ] **Step 3: The entry detail card**

Create `App/Features/Places/EntryDetailCard.swift`. Structure and chrome deliberately mirror `FountainDetailCard` (same card shape, same `BEMRadius.card`, same padding scale) so the two segments feel like one surface:

```swift
import BEMBELKit
import MapKit
import SwiftUI

struct EntryDetailCard: View {
    let entry: RegisterEntry
    @AppStorage(StickerState.loginKey, store: AppGroup.defaults) private var login = ""
    @State private var isRating = false

    var body: some View {
        VStack(alignment: .leading, spacing: BEMSpacing.m) {
            Capsule()
                .fill(BEMColor.glazeLine)
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)

            header
            if !entry.merkmale.isEmpty { merkmale }
            if let note = entry.note {
                Text(verbatim: note)
                    .font(.subheadline)
                    .foregroundStyle(BEMColor.ink)
            }
            ratings
            ProvenanceByline(provenance: entry.provenance, verified: entry.verified)
            actions
            sources
        }
        .padding(.horizontal, BEMSpacing.l)
        .padding(.top, BEMSpacing.s)
        .padding(.bottom, BEMSpacing.l)
        .background(BEMColor.saltGlaze, in: RoundedRectangle(cornerRadius: BEMRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: BEMRadius.card)
                .stroke(BEMColor.glazeLine.opacity(0.6), lineWidth: 0.5)
        )
        .padding(.bottom, BEMSpacing.s)
        .sheet(isPresented: $isRating) {
            RatingSheet(entry: entry, login: login)
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: BEMSpacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BEMColor.ink)
                Text(verbatim: entry.addressLine)
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
            Spacer()
            if let rating = entry.rating {
                StatusCapsule(
                    label: Text(verbatim: rating.average.formatted(.number.precision(.fractionLength(1)))),
                    color: BEMColor.cobalt
                )
            }
        }
    }

    private var merkmale: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BEMSpacing.s) {
                ForEach(entry.merkmale) { merkmal in
                    HStack(spacing: 5) {
                        Image(systemName: merkmal.systemImage).font(.caption2)
                        Text(verbatim: merkmal.displayName).font(.caption.weight(.medium))
                    }
                    .foregroundStyle(BEMColor.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(BEMColor.glazeLine, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private var ratings: some View {
        if let rating = entry.rating {
            VStack(alignment: .leading, spacing: BEMSpacing.s) {
                Text("entry.rating.count \(rating.count)")
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
                ForEach(rating.ratings.prefix(3)) { single in
                    HStack(alignment: .top, spacing: BEMSpacing.s) {
                        Text(verbatim: String(repeating: "★", count: single.stars))
                            .font(.footnote)
                            .foregroundStyle(BEMColor.cobalt)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: "@\(single.login)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BEMColor.ink)
                            if let comment = single.comment {
                                Text(verbatim: comment)
                                    .font(.caption)
                                    .foregroundStyle(BEMColor.inkSecondary)
                            }
                        }
                    }
                }
            }
        } else {
            Text("entry.rating.none")
                .font(BEMFont.dataLabel)
                .foregroundStyle(BEMColor.inkSecondary)
        }
    }

    private var actions: some View {
        HStack(spacing: BEMSpacing.s + 2) {
            CobaltButton(title: Text("entry.action.rate"), systemImage: "star") {
                isRating = true
            }
            Button {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: entry.coordinate))
                item.name = entry.name
                item.openInMaps()
            } label: {
                Image(systemName: "location.north.fill")
                    .font(.body.weight(.medium))
                    .foregroundStyle(BEMColor.cobalt)
                    .frame(width: 48, height: 48)
                    .overlay(RoundedRectangle(cornerRadius: BEMRadius.control).stroke(BEMColor.glazeLine, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("entry.action.route"))
        }
    }

    @ViewBuilder
    private var sources: some View {
        if let source = entry.sources.first {
            Link(destination: source) {
                SourceLine(systemImage: "link", text: Text("entry.sources"))
            }
        }
    }
}

/// Picking stars, then handing off to GitHub. The sheet never posts anything —
/// it builds a URL and opens it, which is the entire write path of this app.
struct RatingSheet: View {
    let entry: RegisterEntry
    let login: String
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var stars = 5

    var body: some View {
        VStack(spacing: BEMSpacing.l) {
            Text(verbatim: entry.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(BEMColor.ink)

            HStack(spacing: BEMSpacing.s) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        stars = value
                    } label: {
                        Image(systemName: value <= stars ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(BEMColor.cobalt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("entry.rating.stars \(value)"))
                }
            }

            Text("funnel.hint")
                .font(.footnote)
                .foregroundStyle(BEMColor.inkSecondary)
                .multilineTextAlignment(.center)

            CobaltButton(title: Text("entry.action.rate.open"), systemImage: "arrow.up.right") {
                if let url = RatingFunnel.rate(entryID: entry.id, stars: stars, login: login) {
                    openURL(url)
                }
                dismiss()
            }
        }
        .padding(BEMSpacing.l)
    }
}
```

- [ ] **Step 4: Delete the stubs**

Remove the placeholder `MerkmalBar` and `EntryDetailCard` declarations left at the bottom of `PlacesView.swift` in Task 6.

- [ ] **Step 5: Add the strings**

Insert into `Localizable.xcstrings` in alphabetical position:

```json
    "entry.action.rate": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Bewerten" } } }
    },
    "entry.action.rate.open": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Auf GitHub bewerten" } } }
    },
    "entry.action.route": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Route" } } }
    },
    "entry.provenance.editor %@": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Zuletzt bearbeitet von @%@" } } }
    },
    "entry.provenance.history": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Änderungen auf GitHub" } } }
    },
    "entry.provenance.unverified": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Noch nicht geprüft" } } }
    },
    "entry.provenance.verified %@": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Geprüft am %@" } } }
    },
    "entry.rating.count %lld": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "%lld Bewertungen" } } }
    },
    "entry.rating.none": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Noch keine Bewertung" } } }
    },
    "entry.rating.stars %lld": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "%lld Sterne" } } }
    },
    "entry.sources": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Quelle öffnen" } } }
    },
    "funnel.hint": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "„Bewerten“ öffnet GitHub. Deine Bewertung ist ein Pull Request aus deinem Account — kein BEMBEL-Konto, keine Daten für uns." } } }
    },
    "places.merkmale.a11y": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Nach Merkmalen filtern" } } }
    },
    "places.merkmale.all": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Alle" } } }
    },
```

plus one `merkmal.<raw>` key per vocabulary entry:

```json
    "merkmal.baenke-draussen": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Bänke draußen" } } } },
    "merkmal.ebbelwei": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Ebbelwei" } } } },
    "merkmal.eigenkelterei": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Eigenkelterei" } } } },
    "merkmal.eigenmarke": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Eigenmarke" } } } },
    "merkmal.garten": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Garten" } } } },
    "merkmal.handkaes": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Handkäs" } } } },
    "merkmal.historisch": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Historisch" } } } },
    "merkmal.kunst": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Kunst" } } } },
    "merkmal.schoppen-vom-fass": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Schoppen vom Fass" } } } },
    "merkmal.sitzplaetze": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Sitzplätze" } } } },
    "merkmal.spaet-offen": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Spät offen" } } } },
    "merkmal.spaeti": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Späti" } } } },
    "merkmal.trinkhalle-klassisch": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Klassische Trinkhalle" } } } },
```

- [ ] **Step 6: Verify in the simulator, not just in the compiler**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format && make build && make test && make format-check
```

Then run the app on a booted simulator and check three things by eye: the Merkmale chips filter the map, an entry's byline shows a verified date and an `@handle`, and "Bewerten" opens the sheet. Tapping through to GitHub opens Safari — do not submit anything.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "BEM-S04: Merkmale navigation, entry detail with provenance byline, rating funnel"
```

---

### Task 8: The coverage game

**Files:**
- Create: `App/Features/Places/CoverageView.swift`
- Modify: `App/Features/Places/EntryDetailCard.swift`
- Modify: `App/Features/Places/PlacesView.swift`
- Modify: `App/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `PlacesModel.coverage`, `RegisterEntry.isCandidate`, `RatingFunnel.verify(entryID:name:)`, `RatingFunnel.report(register:name:)`.
- Produces: `CoverageView(model:)` presented as a sheet from the Orte toolbar.

- [ ] **Step 1: The candidate call to action**

In `EntryDetailCard.swift`, add a candidate banner directly above `actions` in the body — greyed entries are the game's targets and must say so:

```swift
            if entry.isCandidate { candidateCallout }
```

and the view:

```swift
    private var candidateCallout: some View {
        VStack(alignment: .leading, spacing: BEMSpacing.s) {
            Text("entry.candidate.cta")
                .font(.footnote.weight(.medium))
                .foregroundStyle(BEMColor.ink)
            Link(destination: RatingFunnel.verify(entryID: entry.id, name: entry.name) ?? RatingFunnel.repository) {
                HStack(spacing: 4) {
                    Text("entry.candidate.action")
                    Image(systemName: "arrow.up.right")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BEMColor.cobalt)
            }
        }
        .padding(BEMSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BEMColor.saltGlazeElevated, in: RoundedRectangle(cornerRadius: BEMRadius.control))
    }
```

- [ ] **Step 2: The coverage sheet**

Create `App/Features/Places/CoverageView.swift`:

```swift
import BEMBELKit
import SwiftUI

/// The coverage game: how much of the city is actually verified, per
/// Stadtteil. Degrades honestly — a bundle without coverage counts shows the
/// empty state instead of a fake zero.
struct CoverageView: View {
    let model: PlacesModel
    @Environment(\.dismiss) private var dismiss

    private var totals: (verified: Int, total: Int) {
        model.coverage.reduce(into: (0, 0)) { sum, area in
            sum.0 += area.verified
            sum.1 += area.total
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if model.coverage.isEmpty {
                    Text("coverage.empty")
                        .font(.subheadline)
                        .foregroundStyle(BEMColor.inkSecondary)
                } else {
                    Section {
                        ForEach(model.coverage) { area in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(verbatim: area.district)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("coverage.progress \(area.verified) \(area.total)")
                                        .font(BEMFont.dataLabel)
                                        .foregroundStyle(BEMColor.inkSecondary)
                                }
                                ProgressView(value: area.fraction)
                                    .tint(BEMColor.cobalt)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("coverage.progress \(totals.verified) \(totals.total)")
                    } footer: {
                        Text("coverage.footer")
                    }
                }

                if let report = RatingFunnel.report(register: model.selectedRegister, name: nil) {
                    Section {
                        Link(destination: report) {
                            Label("coverage.report", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("coverage.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Present it from the tab**

In `PlacesView.swift`, add the state and the entry point. The toolbar row sits above the register picker so it reads as chrome, not as data:

```swift
    @State private var isShowingCoverage = false
```

```swift
            VStack(spacing: BEMSpacing.m) {
                HStack {
                    Spacer()
                    GlassCircleButton(systemImage: "chart.bar.doc.horizontal", accessibilityLabel: "coverage.title") {
                        isShowingCoverage = true
                    }
                }
                registerPicker
```

```swift
        .sheet(isPresented: $isShowingCoverage) {
            CoverageView(model: model)
        }
```

- [ ] **Step 4: Add the strings**

```json
    "coverage.empty": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Noch keine Abdeckungsdaten — sobald Einträge Stadtteile tragen, steht hier, wie weit wir sind." } } }
    },
    "coverage.footer": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Geprüft heißt: jemand hat die Angaben an der Quelle oder vor Ort bestätigt. Graue Pins auf der Karte warten noch darauf." } } }
    },
    "coverage.progress %lld %lld": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "%lld von %lld geprüft" } } }
    },
    "coverage.report": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Einen fehlenden Ort melden" } } }
    },
    "coverage.title": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Abdeckung" } } }
    },
    "entry.candidate.action": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Auf GitHub verifizieren" } } }
    },
    "entry.candidate.cta": {
      "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Noch niemand hat diesen Ort geprüft. Hilf mit — warst du da?" } } }
    },
```

- [ ] **Step 5: Verify and commit**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format && make build && make test && make format-check
```

Then in the simulator: unverified entries render grey, their card shows the callout, and the coverage sheet lists Stadtteile with progress bars.

```bash
git add -A && git commit -m "BEM-S04: coverage game — candidate pins, verify call to action, per-Stadtteil progress"
```

---

### Task 9: Kiosk visit stamps

**Files:**
- Create: `Packages/BEMBELKit/Sources/BEMBELKit/Community/VisitMonitor.swift`
- Create: `Packages/BEMBELKit/Tests/BEMBELKitTests/VisitMonitorTests.swift`
- Modify: `App/Info.plist`
- Modify: `App/Features/Places/PlacesView.swift`

**Interfaces:**
- Consumes: `RegisterEntry`, `StickerState`.
- Produces: `VisitMonitor.candidates(from:near:limit:)` (pure, tested) and `VisitMonitor.start(for:onVisit:)` (CoreLocation, not tested). Task 10 shows the stamps.

- [ ] **Step 1: Write the monitor**

Create `Packages/BEMBELKit/Sources/BEMBELKit/Community/VisitMonitor.swift`. The region selection is a pure function because that is the part with a rule worth checking; the CoreLocation plumbing around it is not:

```swift
import CoreLocation
import Foundation

/// Kiosk visit stamps: on-device region monitoring, opt-in, nothing leaves the
/// phone. iOS caps simultaneously monitored regions, so the app watches the
/// nearest few verified entries and re-selects as the user moves.
public enum VisitMonitor {
    /// Apple's per-app region limit is 20; leave headroom for future layers.
    public static let regionLimit = 16
    public static let radius: CLLocationDistance = 75

    /// The entries worth watching right now: verified ones only (a candidate
    /// may not exist), nearest first, capped at `limit`.
    public static func candidates(
        from entries: [RegisterEntry],
        near location: CLLocationCoordinate2D,
        limit: Int = regionLimit
    ) -> [RegisterEntry] {
        let origin = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return
            entries
            .filter(\.verified)
            .map { ($0, CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: origin)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}

#if os(iOS)
    /// Thin wrapper over `CLMonitor`. Untested by design — CoreLocation is not
    /// something a unit test can honestly exercise; the rule that decides
    /// *what* to monitor is `VisitMonitor.candidates`, and that is tested.
    @MainActor
    public final class KioskVisitMonitor {
        private var monitor: CLMonitor?
        private var task: Task<Void, Never>?

        public init() {}

        /// Starts monitoring the given entries. `onVisit` fires once per entry
        /// per install — `StickerState.recordVisit` is the idempotence gate.
        public func start(for entries: [RegisterEntry], onVisit: @escaping @MainActor (String) -> Void) async {
            stop()
            let monitor = await CLMonitor("de.mauricejobst.bembel.kiosks")
            self.monitor = monitor

            for identifier in await monitor.identifiers {
                await monitor.remove(identifier)
            }
            for entry in entries {
                await monitor.add(
                    CLMonitor.CircularGeographicCondition(
                        center: entry.coordinate,
                        radius: VisitMonitor.radius
                    ),
                    identifier: entry.id
                )
            }

            task = Task { [weak self] in
                guard let events = await self?.monitor?.events else { return }
                for try? await event in events where event.state == .satisfied {
                    onVisit(event.identifier)
                }
            }
        }

        public func stop() {
            task?.cancel()
            task = nil
        }
    }
#endif
```

If `for try? await` does not compile in this Swift version, use an explicit `do { for try await event in events { … } } catch { }` — the loop must swallow monitor errors rather than propagate them, because a failed stamp is not worth an error state.

- [ ] **Step 2: Test the selection rule**

Create `Packages/BEMBELKit/Tests/BEMBELKitTests/VisitMonitorTests.swift`:

```swift
import CoreLocation
import Foundation
import Testing

@testable import BEMBELKit

@Suite("Visit monitor region selection")
struct VisitMonitorTests {
    private func entry(_ id: String, lat: Double, lon: Double, verified: Bool = true) -> RegisterEntry {
        RegisterEntry(
            id: id,
            register: .wasserhaeuschen,
            name: id,
            street: "-",
            postalCode: "60311",
            city: "Frankfurt am Main",
            latitude: lat,
            longitude: lon,
            verified: verified,
            provenance: Provenance(
                lastEditor: nil,
                lastChangedAt: nil,
                verifiedAt: nil,
                historyURL: URL(string: "https://example.test/h")!,
                fileURL: URL(string: "https://example.test/f")!
            )
        )
    }

    private let hauptwache = CLLocationCoordinate2D(latitude: 50.1136, longitude: 8.6797)

    @Test("Nearest entries win, in distance order")
    func picksNearest() {
        let entries = [
            entry("weit", lat: 50.2000, lon: 8.9000),
            entry("nah", lat: 50.1137, lon: 8.6798),
            entry("mittel", lat: 50.1200, lon: 8.6900),
        ]
        let picked = VisitMonitor.candidates(from: entries, near: hauptwache)
        #expect(picked.map(\.id) == ["nah", "mittel", "weit"])
    }

    @Test("Unverified entries are never monitored — they may not exist")
    func skipsCandidates() {
        let entries = [
            entry("kandidat", lat: 50.1136, lon: 8.6797, verified: false),
            entry("echt", lat: 50.1200, lon: 8.6900),
        ]
        #expect(VisitMonitor.candidates(from: entries, near: hauptwache).map(\.id) == ["echt"])
    }

    @Test("The region limit is respected")
    func respectsLimit() {
        let entries = (0..<40).map { entry("k\($0)", lat: 50.11 + Double($0) / 1000, lon: 8.68) }
        #expect(VisitMonitor.candidates(from: entries, near: hauptwache).count == VisitMonitor.regionLimit)
        #expect(VisitMonitor.candidates(from: entries, near: hauptwache, limit: 3).count == 3)
    }
}
```

- [ ] **Step 3: Update the location usage string**

In `App/Info.plist`, replace the `NSLocationWhenInUseUsageDescription` value — the old text promises fountains and stops only, and a usage string that under-describes the use is an App Review rejection:

```xml
	<string>BEMBEL nutzt deinen Standort für die nächste Haltestelle, den nächsten Brunnen und — wenn du Kiosk-Stempel einschaltest — um zu merken, an welchem Wasserhäuschen du warst. Alles bleibt auf dem Gerät.</string>
```

- [ ] **Step 4: Start monitoring when the user opted in**

In `PlacesView.swift`, add the monitor and drive it from the loaded snapshot. Guard on the opt-in toggle — never start it otherwise:

```swift
    @AppStorage(StickerState.visitDetectionKey, store: AppGroup.defaults) private var visitDetection = false
    @State private var visitMonitor = KioskVisitMonitor()
```

and after the existing `.task`:

```swift
        .task(id: visitDetection) {
            guard visitDetection else {
                visitMonitor.stop()
                return
            }
            let entries = VisitMonitor.candidates(
                from: model.snapshot.entries(in: .wasserhaeuschen),
                near: position.region?.center ?? CLLocationCoordinate2D(latitude: 50.1122, longitude: 8.6780)
            )
            await visitMonitor.start(for: entries) { entryID in
                StickerState.recordVisit(entryID: entryID)
            }
        }
```

If `MapCameraPosition.region` is unavailable, fall back to the Frankfurt centre constant already used for the initial camera — precision here only affects which 16 kiosks are watched first.

- [ ] **Step 5: Verify and commit**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format && make test && make build && make format-check
```

Expected: the three selection tests pass; the app builds. Simulator check: with the toggle off (Task 10 adds it — until then flip the default in the debugger or skip), no location prompt appears on the Orte tab.

```bash
git add -A && git commit -m "BEM-S01: kiosk visit stamps — on-device region monitoring, opt-in"
```

---

### Task 10: Sammlung, settings, and the data-state row

**Files:**
- Create: `App/Features/Places/StickerAlbumView.swift`
- Modify: `App/Features/Places/PlacesView.swift`
- Modify: `App/Settings/SettingsView.swift`
- Modify: `App/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `StickerRules`, `StickerState`, `Sticker`, `RegisterSnapshot`.
- Produces: `StickerAlbumView(model:)` reachable from the Orte toolbar; Settings gains the GitHub handle field, the visit-stamp toggle, and the bundle-state rows that close BEM-S11's third acceptance criterion.

- [ ] **Step 1: The album**

Create `App/Features/Places/StickerAlbumView.swift`:

```swift
import BEMBELKit
import SwiftUI

/// "Deine Sammlung" — the data-linked stickers plus the kiosk stamps. Earned
/// in bembel-data and recognised by handle; the full Sammelalbum (city
/// hotspots, Game Center, seasonal drops) is M4.
struct StickerAlbumView: View {
    let model: PlacesModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StickerState.loginKey, store: AppGroup.defaults) private var login = ""

    private var earned: Set<Sticker> {
        StickerRules.awarded(
            login: login,
            contributors: model.snapshot.contributors,
            visitedEntryIDs: StickerState.visitedEntryIDs()
        )
    }

    private var stamps: [Sticker] {
        earned.filter { !$0.isDataLinked }.sorted { $0.id < $1.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Sticker.dataLinked, id: \.id) { sticker in
                        StickerRow(sticker: sticker, unlocked: earned.contains(sticker), title: sticker.title)
                    }
                } header: {
                    Text("stickers.contributions")
                } footer: {
                    Text(RatingFunnel.sanitizedLogin(login) == nil ? "stickers.locked.hint" : "stickers.unlocked.hint")
                }

                Section {
                    if stamps.isEmpty {
                        Text("stickers.stamps.empty")
                            .font(.subheadline)
                            .foregroundStyle(BEMColor.inkSecondary)
                    } else {
                        ForEach(stamps, id: \.id) { stamp in
                            StickerRow(sticker: stamp, unlocked: true, title: name(for: stamp))
                        }
                    }
                } header: {
                    Text("stickers.stamps")
                } footer: {
                    Text("stickers.stamps.footer")
                }
            }
            .navigationTitle("stickers.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
        }
    }

    /// A stamp names its place; an entry that has since left the register
    /// keeps its stamp under the raw id rather than vanishing.
    private func name(for sticker: Sticker) -> String {
        guard case .kioskStempel(let entryID) = sticker else { return sticker.id }
        return model.snapshot.entries.first { $0.id == entryID }?.name ?? entryID
    }
}

struct StickerRow: View {
    let sticker: Sticker
    let unlocked: Bool
    let title: String

    var body: some View {
        HStack(spacing: BEMSpacing.m) {
            Image(systemName: sticker.systemImage)
                .font(.title3)
                .foregroundStyle(unlocked ? BEMColor.inkOnCobalt : BEMColor.inkSecondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(unlocked ? BEMColor.cobalt : BEMColor.saltGlazeElevated)
                )
                .overlay(Circle().stroke(BEMColor.glazeLine, lineWidth: unlocked ? 0 : 1))
            Text(verbatim: title)
                .font(.body.weight(unlocked ? .semibold : .regular))
                .foregroundStyle(unlocked ? BEMColor.ink : BEMColor.inkSecondary)
            Spacer()
            if !unlocked {
                Image(systemName: "lock")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension Sticker {
    var title: String {
        switch self {
        case .datenspender: String(localized: "stickers.datenspender")
        case .verifizierer: String(localized: "stickers.verifizierer")
        case .ersteBewertung: String(localized: "stickers.erste-bewertung")
        case .kioskStempel(let entryID): entryID
        }
    }
}
```

- [ ] **Step 2: Reach it from the Orte toolbar**

In `PlacesView.swift`, add the state and a second glass button next to the coverage one:

```swift
    @State private var isShowingAlbum = false
```

```swift
                HStack(spacing: BEMSpacing.s) {
                    Spacer()
                    GlassCircleButton(systemImage: "seal", accessibilityLabel: "stickers.title") {
                        isShowingAlbum = true
                    }
                    GlassCircleButton(systemImage: "chart.bar.doc.horizontal", accessibilityLabel: "coverage.title") {
                        isShowingCoverage = true
                    }
                }
```

```swift
        .sheet(isPresented: $isShowingAlbum) {
            StickerAlbumView(model: model)
        }
```

- [ ] **Step 3: Settings — handle, stamps, data state**

In `SettingsView.swift`, add the storage bindings:

```swift
    @AppStorage(StickerState.loginKey, store: AppGroup.defaults) private var githubLogin = ""
    @AppStorage(StickerState.visitDetectionKey, store: AppGroup.defaults) private var visitDetection = false
```

and two sections between the region section and the sources section:

```swift
                Section {
                    TextField("settings.github.field", text: $githubLogin)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("settings.github.header")
                } footer: {
                    Text("settings.github.footer")
                }

                Section {
                    Toggle("settings.visits.toggle", isOn: $visitDetection)
                } footer: {
                    Text("settings.visits.footer")
                }
```

- [ ] **Step 4: The Datenstand rows (BEM-S11 AC 3)**

`DataSourcesView` currently hardcodes a list. Give it the bundle state — this is the acceptance criterion "Bundle version + release date surface in Settings → Datenquellen". Add the environment and state:

```swift
struct DataSourcesView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var snapshot: RegisterSnapshot?
```

add `("bembel-data (Community)", "ODbL")` to the `sources` array, and add a section above the existing one:

```swift
            Section {
                if let snapshot, snapshot.schemaVersion > 0 {
                    LabeledContent("settings.data.version") {
                        Text(verbatim: String(snapshot.schemaVersion))
                    }
                    if let generatedAt = snapshot.generatedAt {
                        LabeledContent("settings.data.generated") {
                            Text(generatedAt, format: .dateTime.day().month(.abbreviated).year())
                        }
                    }
                    LabeledContent("settings.data.entries") {
                        Text(verbatim: String(snapshot.entries.count))
                    }
                } else {
                    Text("settings.data.unavailable")
                        .foregroundStyle(BEMColor.inkSecondary)
                }
            } header: {
                Text("settings.data.header")
            }
```

and load it:

```swift
        .task {
            snapshot = try? await dependencies.register.snapshot()
        }
```

- [ ] **Step 5: Add the strings**

```json
    "settings.data.entries": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Einträge" } } } },
    "settings.data.generated": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Stand" } } } },
    "settings.data.header": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Datenstand bembel-data" } } } },
    "settings.data.unavailable": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Noch keine Daten geladen" } } } },
    "settings.data.version": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Schema-Version" } } } },
    "settings.github.field": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "GitHub-Benutzername" } } } },
    "settings.github.footer": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Nur auf diesem Gerät. BEMBEL nutzt ihn, um deine Beiträge in bembel-data wiederzuerkennen und Sticker freizuschalten — es wird nichts gesendet und nichts geprüft." } } } },
    "settings.github.header": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Mitmachen" } } } },
    "settings.visits.footer": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Erkennt auf dem Gerät, wenn du an einem Wasserhäuschen bist, und schaltet den Stempel frei. Kein Standort verlässt das Telefon." } } } },
    "settings.visits.toggle": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Kiosk-Stempel sammeln" } } } },
    "stickers.contributions": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Beiträge" } } } },
    "stickers.datenspender": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Datenspender" } } } },
    "stickers.erste-bewertung": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Erste Bewertung" } } } },
    "stickers.locked.hint": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Trag deinen GitHub-Benutzernamen in den Einstellungen ein, damit wir deine Beiträge wiedererkennen." } } } },
    "stickers.stamps": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Kiosk-Stempel" } } } },
    "stickers.stamps.empty": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Noch kein Stempel. Schalte sie in den Einstellungen ein und geh raus." } } } },
    "stickers.stamps.footer": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Stempel entstehen auf dem Gerät und bleiben dort." } } } },
    "stickers.title": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Deine Sammlung" } } } },
    "stickers.unlocked.hint": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Freigeschaltet wird, was in bembel-data unter deinem Account gemerged ist." } } } },
    "stickers.verifizierer": { "localizations": { "de": { "stringUnit": { "state": "translated", "value": "Verifizierer" } } } },
```

- [ ] **Step 6: Verify and commit**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format && make test && make build && make format-check
```

Simulator check: enter `cybeerboy` in Settings → the album unlocks "Erste Bewertung" against the sample data; clear it → the stickers lock again. Settings → Datenquellen shows a schema version and an entry count.

```bash
git add -A && git commit -m "BEM-S01: Sammlung, GitHub handle, visit toggle, bembel-data Datenstand in Settings"
```

---

### Task 11: Docs, issues, and the pull request

**Files:**
- Modify: `docs/BACKLOG.md`
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Create: `docs/adr/0009-registers-in-one-places-tab.md`

- [ ] **Step 1: Write the navigation ADR**

The tab-bar restructuring is a decision a future contributor will otherwise relitigate — it is why `BEMTab.water` no longer exists. Create `docs/adr/0009-registers-in-one-places-tab.md`, mirroring the layout of `docs/adr/0007-provider-seam.md`:

```markdown
# 0009 — All place datasets live in one Orte tab

- Status: accepted
- Date: 2026-08-13

## Context

The hero repositioning (spec 2026-08-13) makes the bembel-data registers
v1.0's flagship, which means they need position one in the tab bar. The bar
was already full with the five original features, and a sixth tab pushes
iPhone into the "More" overflow — hiding two shipped features behind a menu
to promote a third.

## Decision

One **Orte** tab in position one carries every place dataset —
Wasserhäuschen, Ebbelwei, Trinkbrunnen — behind a segmented control, with
Merkmale as the navigation inside it. `BEMTab.water` is replaced by
`BEMTab.places`; `bembel://water` and `bembel://wasser` remain valid and open
Orte on the Trinkbrunnen segment.

## Consequences

- The tab bar stays at five, and the hero sits first.
- Trinkbrunnen keeps its full scope (`BEM-E02`/`BEM-E03`): the seasonal state
  engine, the detail card and the fountain pins moved unchanged into
  `App/Features/Places/`.
- The three datasets share one map, one camera and one detail-card idiom, so
  a fourth place register later is a segment, not a redesign.
- Deep links are additive: `bembel://kiosk`, `bembel://ebbelwei`,
  `bembel://orte`. Nothing that worked before stopped working.
```

- [ ] **Step 2: Update the backlog**

In `docs/BACKLOG.md`, mark the hero tickets and record what shipped. Under the hero paragraph, append the delivery note; and where `BEM-E03` describes the fountain map, add the pointer that it now lives in the Orte tab (ADR 0009). Add to the `Locked decisions` table:

| Navigation | Five tabs. Orte (Wasserhäuschen · Ebbelwei · Trinkbrunnen) first — ADR 0009 |

- [ ] **Step 3: CHANGELOG**

Under `## [Unreleased]`:

```markdown
### Added
- Wasserhäuschen- und Ebbelwei-Register aus bembel-data: Karte, Merkmale-Navigation,
  Detailkarte mit Provenienz-Zeile (geprüft am, letzte Bearbeitung, Link in die
  Git-Historie).
- In-App-Trichter: „Bewerten“, „verifizieren“ und „Ort melden“ öffnen vorausgefüllte
  GitHub-Flows — ohne Konto, ohne Token, ohne Backend.
- Abdeckungsspiel: ungeprüfte Einträge als graue Kandidaten, Fortschritt je Stadtteil.
- Sticker: Datenspender, Verifizierer, Erste Bewertung (über den GitHub-Benutzernamen
  aus den Einstellungen) sowie Kiosk-Stempel per opt-in Standorterkennung auf dem Gerät.
- BEM-S11-Loader: gebündelter Snapshot, Conditional GET gegen das veröffentlichte
  bembel-data-Bundle, Datenstand in den Einstellungen.

### Changed
- Der Trinkwasser-Tab ist im neuen **Orte**-Tab aufgegangen (ADR 0009); Trinkbrunnen
  bleiben unverändert im Funktionsumfang. `bembel://water` funktioniert weiter.
```

- [ ] **Step 4: README and AGENTS**

In `README.md`, extend the hero section's feature list with the shipped capabilities (registers, Merkmale navigation, provenance, funnel, coverage, stickers) — the section text from Phase 0 stays, the "planned" framing goes.

In `AGENTS.md`, under Conventions, add the one thing a future agent will otherwise get wrong:

```markdown
- The Orte tab (`App/Features/Places/`) carries all three place datasets behind
  one segmented control — there is no Water feature folder any more (ADR 0009).
  `BEMTab` has five cases; adding a sixth pushes iPhone into a "More" overflow.
```

- [ ] **Step 5: Full verification before the PR**

```bash
cd /Users/krazykraut/Projects/BEMBEL && make format-check && make test && make validate && make build
```

Expected: four green runs. Paste the actual output into the PR body — an assertion that it passed is not evidence; the pasted output is.

- [ ] **Step 6: Open the PR**

```bash
git push -u origin feat/hero-registers
gh pr create -R maurice-jobst/bembel --title "Hero: bembel-data registers, funnel, coverage game, stickers (Phase 1b)" --body "Implements the Phase 1b plan (docs/superpowers/plans/2026-08-13-phase-1b-hero-app.md) — the hero layer of the 2026-08-13 repositioning spec.

Closes #39. Closes #40. Closes #46. Partially addresses #36 (data-linked stickers + kiosk stamps ship here; the Sammelalbum remainder stays M4).

**Kit** — register domain models behind \`RegisterProviding\` (ADR 0007), bembel-data bundle decoder, live loader through the existing \`DatasetStore\` (one new field: a per-dataset absolute \`url\` for foreign-host datasets), funnel URL builder, sticker rules, visit-region selection. 4 new test suites.

**App** — new Orte tab in position 1 carrying Wasserhäuschen, Ebbelwei and Trinkbrunnen behind a segmented control (ADR 0009 — the alternative was a sixth tab and an iOS \"More\" overflow); Merkmale-first navigation generated from the data; provenance byline with a tap-through to git history; rating/verify/report funnel; coverage game; Sammlung with data-linked stickers and opt-in kiosk stamps.

**Privacy** — unchanged: no backend, no accounts, no analytics, region monitoring is opt-in and on-device, label stays Data Not Collected.

Verification: \`make format-check\`, \`make test\`, \`make validate\`, \`make build\` — output below.

The model proposes, a deterministic layer accepts (bembel-data's CI computes the aggregates, the app only renders them); every task ends in a runnable check; the app↔data field-id contract is enforced by \`check_funnel.py\` in bembel-data, not by prose.

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 7: Review gate**

Run `/code-review` on the PR before merging — the team inherits this history, and the whole point of building feature-complete before the flip is that the review trail is reviewable. Fix findings, push, then merge:

```bash
gh pr merge --squash --delete-branch
```

- [ ] **Step 8: Refresh project memory**

Update the `bembel-project` memory file: hero layer built, ADR 0009, the Orte tab shape, the bembel-data dist URL, and what remains (Phase 2 live providers, Phase 3 polish, flip).

---

## Self-review notes

**Spec coverage (hero-repositioning spec §2–§4).** Wasserhäuschen register with map/list/detail and aggregated stars → Tasks 6–7. Merkmale as primary navigation → Task 7. Provenance byline → Task 7. In-app rating funnel → Tasks 4, 7. Coverage game → Task 8. Ebbelwei as a second register through the same loader → Tasks 1–3, 6 (one segment, zero new plumbing — the platform claim the spec wants proven at launch). Data-linked stickers → Tasks 5, 10. Kiosk visit stamps → Task 9. `RegisterProviding` + Sample provider + BEM-S11 loader semantics (offline → bundled, malformed → last-good, missing coverage → degraded) → Tasks 1–3. Privacy → Tasks 9, 10.

**Deliberately not here.** Live providers for RMV, Trinkbrunnen, RADOLAN, Stadtzustand and the Schattenkarte are Phase 2 — this plan leaves the Sample providers wired for all four. The full Sammelalbum (hotspot geofences, Game Center, seasonal drops) stays M4 per #36. Ring filtering does not apply to registers: they are Frankfurt-first, and `RegionSettings` filters by AGS, which register entries do not carry.

**Known follow-ups worth an issue, not a task here.** A pull-to-refresh gesture on Orte calling `BembelDataRegisterProvider.invalidate()`; an entry-level deep link (`bembel://kiosk/<id>`) once something needs to link into a single entry; a widget surfacing the nearest unverified candidate.
