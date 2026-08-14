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
