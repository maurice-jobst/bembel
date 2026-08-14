import CoreLocation
import Foundation
import Testing

@testable import BEMBELKit

@Suite("Candidate digest")
struct CandidateDigestTests {
    private func entry(
        _ id: String,
        lat: Double,
        lon: Double,
        verified: Bool = false,
        register: PlaceRegister = .wasserhaeuschen,
        district: String? = "Innenstadt"
    ) -> RegisterEntry {
        RegisterEntry(
            id: id,
            register: register,
            name: id.capitalized,
            street: "-",
            postalCode: "60311",
            city: "Frankfurt am Main",
            district: district,
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

    private func snapshot(_ entries: [RegisterEntry]) -> RegisterSnapshot {
        RegisterSnapshot(
            schemaVersion: 1,
            generatedAt: nil,
            entries: entries,
            contributors: [],
            coverage: []
        )
    }

    private let hauptwache = CLLocationCoordinate2D(latitude: 50.1136, longitude: 8.6797)
    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Only unverified entries — a verified one is not a target")
    func onlyCandidates() {
        let digest = CandidateDigest.make(
            from: snapshot([
                entry("bestaetigt", lat: 50.1137, lon: 8.6798, verified: true),
                entry("offen", lat: 50.1200, lon: 8.6900),
            ]),
            near: hauptwache,
            now: epoch
        )
        #expect(digest.items.map(\.id) == ["offen"])
    }

    @Test("Nearest first, and the reference point is recorded")
    func nearestFirst() {
        let digest = CandidateDigest.make(
            from: snapshot([
                entry("weit", lat: 50.2000, lon: 8.9000),
                entry("nah", lat: 50.1137, lon: 8.6798),
                entry("mittel", lat: 50.1200, lon: 8.6900),
            ]),
            near: hauptwache,
            now: epoch
        )
        #expect(digest.items.map(\.id) == ["nah", "mittel", "weit"])
        #expect(digest.referenceLatitude == hauptwache.latitude)
        #expect(digest.referenceLongitude == hauptwache.longitude)
        #expect(digest.updatedAt == epoch)
        #expect(digest.items[0].distance < digest.items[1].distance)
    }

    @Test("Equal distances break on id, so the same input yields the same digest")
    func deterministicTies() {
        let entries = [
            entry("zzz", lat: 50.1200, lon: 8.6900),
            entry("aaa", lat: 50.1200, lon: 8.6900),
        ]
        #expect(CandidateDigest.make(from: snapshot(entries), near: hauptwache).items.map(\.id) == ["aaa", "zzz"])
        #expect(
            CandidateDigest.make(from: snapshot(entries.reversed()), near: hauptwache).items.map(\.id)
                == ["aaa", "zzz"]
        )
    }

    @Test("The limit caps the payload, and a zero limit is not a crash")
    func respectsLimit() {
        let entries = (0..<20).map { entry("k\($0)", lat: 50.11 + Double($0) / 1000, lon: 8.68) }
        #expect(CandidateDigest.make(from: snapshot(entries), near: hauptwache).items.count == 5)
        #expect(CandidateDigest.make(from: snapshot(entries), near: hauptwache, limit: 3).items.count == 3)
        #expect(CandidateDigest.make(from: snapshot(entries), near: hauptwache, limit: 0).items.isEmpty)
        #expect(CandidateDigest.make(from: snapshot(entries), near: hauptwache, limit: -1).items.isEmpty)
    }

    @Test("An entry without a Stadtteil falls back to the city, never to blank")
    func areaFallback() {
        let digest = CandidateDigest.make(
            from: snapshot([entry("ohne", lat: 50.1137, lon: 8.6798, district: nil)]),
            near: hauptwache
        )
        #expect(digest.items.first?.area == "Frankfurt am Main")
    }

    @Test("Every item carries a deep link back into its own register")
    func itemsLinkHome() {
        let digest = CandidateDigest.make(
            from: snapshot([
                entry("yok-yok", lat: 50.1075, lon: 8.6665),
                entry("solzer", lat: 50.1284, lon: 8.7111, register: .ebbelwei),
            ]),
            near: hauptwache
        )
        let links = digest.items.compactMap { $0.url.flatMap(DeepLink.parse) }
        #expect(
            links == [
                .entry(register: .wasserhaeuschen, id: "yok-yok"),
                .entry(register: .ebbelwei, id: "solzer"),
            ]
        )
    }
}

@Suite("Candidate digest store")
struct CandidateDigestStoreTests {
    private func defaults(_ name: String = UUID().uuidString) throws -> UserDefaults {
        try #require(UserDefaults(suiteName: name))
    }

    private func digest(
        _ ids: [String], updatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
    )
        -> CandidateDigest
    {
        CandidateDigest(
            items: ids.enumerated().map { index, id in
                CandidateDigest.Item(
                    id: id,
                    register: .wasserhaeuschen,
                    name: id,
                    area: "Innenstadt",
                    latitude: 50.11,
                    longitude: 8.68,
                    distance: Double(index) * 100
                )
            },
            referenceLatitude: 50.1136,
            referenceLongitude: 8.6797,
            updatedAt: updatedAt
        )
    }

    @Test("Round-trips through the App Group defaults")
    func roundTrip() throws {
        let store = try defaults()
        let original = digest(["a", "b"])
        CandidateDigestStore.save(original, to: store)
        #expect(CandidateDigestStore.load(from: store) == original)
    }

    @Test("Nothing stored reads as nil, not as an empty digest")
    func missingIsNil() throws {
        #expect(CandidateDigestStore.load(from: try defaults()) == nil)
    }

    @Test("Garbage in the slot degrades to nil instead of trapping")
    func garbageIsNil() throws {
        let store = try defaults()
        store.set(Data("not json".utf8), forKey: CandidateDigestStore.key)
        #expect(CandidateDigestStore.load(from: store) == nil)
    }

    @Test("Only a changed candidate list reports a change — timestamps alone do not")
    func changeDetection() throws {
        let store = try defaults()
        #expect(CandidateDigestStore.save(digest(["a", "b"]), to: store))
        #expect(!CandidateDigestStore.save(digest(["a", "b"]), to: store))
        // Same places, newer measurement: the widget would render identically.
        let later = digest(["a", "b"], updatedAt: Date(timeIntervalSince1970: 1_800_009_999))
        #expect(!CandidateDigestStore.save(later, to: store))
        #expect(CandidateDigestStore.load(from: store)?.updatedAt == later.updatedAt)
        // Order is meaning here — "nearest" changed.
        #expect(CandidateDigestStore.save(digest(["b", "a"]), to: store))
        #expect(CandidateDigestStore.save(digest([]), to: store))
    }
}
