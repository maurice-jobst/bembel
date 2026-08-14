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
