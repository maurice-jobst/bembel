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
        #expect(
            StickerRules.awarded(login: "@CyBeerBoy", contributors: contributors, visitedEntryIDs: [])
                .contains(.ersteBewertung))
    }

    @Test("No handle, or an unknown one, earns no data-linked sticker")
    func withoutHandle() {
        #expect(StickerRules.awarded(login: nil, contributors: contributors, visitedEntryIDs: []).isEmpty)
        #expect(StickerRules.awarded(login: "", contributors: contributors, visitedEntryIDs: []).isEmpty)
        #expect(StickerRules.awarded(login: "niemand", contributors: contributors, visitedEntryIDs: []).isEmpty)
    }

    @Test("Visit stamps are independent of any handle")
    func visitStamps() {
        let earned = StickerRules.awarded(
            login: nil, contributors: contributors, visitedEntryIDs: ["yok-yok", "kiosk-guenes"])
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
