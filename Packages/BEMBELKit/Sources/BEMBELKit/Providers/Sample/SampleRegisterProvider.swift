import Foundation

/// Real Frankfurt places, fabricated ratings and provenance. The live bundle
/// (`BembelDataRegisterProvider`) replaces this; previews keep it.
public struct SampleRegisterProvider: RegisterProviding {
    public init() {}

    private static func provenance(_ id: String, register: PlaceRegister, editor: String?, verified: Bool) -> Provenance
    {
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
                        Rating(
                            login: "cybeerboy", stars: 5, date: Date(timeIntervalSince1970: 1_785_000_000),
                            comment: "Nachts um drei die letzte Rettung."),
                        Rating(
                            login: "jaypikay", stars: 5, date: Date(timeIntervalSince1970: 1_785_500_000), comment: nil),
                        Rating(
                            login: "monsdroid", stars: 4, date: Date(timeIntervalSince1970: 1_786_000_000),
                            comment: "Eigenmarke lohnt."),
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
                provenance: provenance(
                    "zum-gemalten-haus", register: .ebbelwei, editor: "maurice-jobst", verified: true),
                rating: RatingSummary(
                    average: 4.0,
                    count: 1,
                    ratings: [
                        Rating(
                            login: "cybeerboy", stars: 4, date: Date(timeIntervalSince1970: 1_785_900_000), comment: nil
                        )
                    ]
                )
            ),
        ],
        contributors: [
            Contributor(login: "maurice-jobst", entries: 2, verifications: 2, ratings: 0, firstRatings: []),
            Contributor(
                login: "cybeerboy", entries: 0, verifications: 0, ratings: 2,
                firstRatings: ["yok-yok", "zum-gemalten-haus"]),
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
