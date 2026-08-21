import Foundation
import Testing

@testable import BEMBELKit

/// Real warnung.bund.de responses captured 2026-08-19: one MOWAS alert
/// (Landkreis Waldeck-Frankenberg, Afrikanische Schweinepest) and one DWD
/// alert relayed by BBK (Stadt Wernigerode, Sturmböen). Two providers on
/// purpose — they disagree about the language tag and about markup, which is
/// most of what there is to get wrong here.
///
/// Each pair was captured through the path the client actually walks:
/// `dashboard/<ars>.json`, then `warnings/<that row's id>.json`. It matters
/// for DWD — the nationwide `dwd/mapData.json` feed lists the same warning
/// under a `dwdmap.…` identifier while the dashboard uses `dwd.…`, and a
/// fixture pairing one feed's row with the other's detail would be a warning
/// that does not exist.
private func ninaFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private func ninaDecoded<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
    try JSONDecoder().decode(T.self, from: ninaFixture(name))
}

@Suite("NINA wire format")
struct NinaWireTests {
    @Test("Both dashboards decode as published")
    func dashboards() throws {
        let mowas = try #require(ninaDecoded([NinaDashboardItem].self, "nina-dashboard-mowas").first)
        #expect(mowas.id == "mow.DE-HE-KS-SE106-20260304-106-000")
        #expect(mowas.payload.data.provider == "MOWAS")
        #expect(mowas.payload.data.valid == true)

        let dwd = try #require(ninaDecoded([NinaDashboardItem].self, "nina-dashboard-dwd").first)
        // BBK relays DWD's weather warnings through the same endpoint, which
        // is why this card needs no second client for the JSONP feed.
        #expect(dwd.payload.data.provider == "DWD")
        #expect(dwd.payload.data.severity == "Moderate")
        // The detail is fetched by the dashboard row's own id. DWD's warnings
        // carry a different one in the nationwide map feed.
        #expect(dwd.id.hasPrefix("dwd.2.49"))
        #expect(try ninaDecoded(NinaWarningDetail.self, "nina-warning-dwd").identifier == dwd.id)
    }

    @Test("Both CAP messages decode as published")
    func details() throws {
        let mowas = try ninaDecoded(NinaWarningDetail.self, "nina-warning-mowas")
        #expect(mowas.status == "Actual")
        #expect(mowas.msgType == "Alert")
        #expect(mowas.info.map(\.language) == ["de", "DE-LS", "EN", "AR", "ES", "FR", "PL", "RU", "TR"])

        let dwd = try ninaDecoded(NinaWarningDetail.self, "nina-warning-dwd")
        #expect(dwd.info.first?.language == "de-DE")
        #expect(dwd.info.first?.expires == "2026-08-20T00:00:00+02:00")
    }

    @Test("A CAP message with no expiry is still a message")
    func mowasHasNoExpiry() throws {
        // The Schweinepest-Schutzzone runs until somebody withdraws it. An
        // implementation that required `expires` would drop it.
        let mowas = try ninaDecoded(NinaWarningDetail.self, "nina-warning-mowas")
        #expect(mowas.info.first?.expires == nil)
    }
}

@Suite("NINA rules")
struct NinaRulesTests {
    @Test("The German block is 'de'/'de-DE' — never DE-LS")
    func picksGermanNotLeichteSprache() throws {
        // MOWAS ships Leichte Sprache as the *second* entry, tagged DE-LS.
        // Any match that merely tests a `de` prefix takes it, and the card
        // then shows a rewritten simplification nobody asked for.
        let mowas = try ninaDecoded(NinaWarningDetail.self, "nina-warning-mowas")
        let german = try #require(NinaRules.germanInfo(mowas.info))
        #expect(german.language == "de")
        #expect(german.headline?.hasPrefix("Einrichtung von Schutzzonen") == true)

        let dwd = try ninaDecoded(NinaWarningDetail.self, "nina-warning-dwd")
        #expect(NinaRules.germanInfo(dwd.info)?.language == "de-DE")
    }

    @Test("With no German block at all, the first one beats nothing")
    func fallsBackToFirstInfo() throws {
        let dwd = try ninaDecoded(NinaWarningDetail.self, "nina-warning-dwd")
        let foreignOnly = Array(dwd.info.dropFirst())
        #expect(NinaRules.germanInfo(foreignOnly)?.language == "en")
        #expect(NinaRules.germanInfo([]) == nil)
    }

    @Test("The region key is Kreis + seven zeros, and an AGS is not one")
    func regionalKey() {
        // `dashboard/06412000.json` answers HTTP 400; `064120000000.json`
        // answers 200. This function is the difference.
        #expect(NinaRules.kreisRegionalKey("06412") == "064120000000")
        #expect(NinaRules.kreisRegionalKey("06412000") == nil)
        #expect(NinaRules.kreisRegionalKey("0641") == nil)
        #expect(NinaRules.kreisRegionalKey("0641a") == nil)
    }

    @Test("Ring selection collapses to a handful of Kreise")
    func kreisKeys() throws {
        let table = try RegionTable.bundled()
        #expect(table.kreisKeys(in: .frankfurt) == ["06412"])
        // 9 and 26 requests, against 80 and 475 municipalities.
        #expect(table.kreisKeys(in: .kernraum).count == 9)
        #expect(table.kreisKeys(in: .rheinmain).count == 26)
        #expect(table.kreisKeys(in: .rheinmain).contains("06412"))
        #expect(table.kreisKeys(in: .kernraum).allSatisfy { NinaRules.kreisRegionalKey($0) != nil })
    }

    @Test("DWD's <br/> becomes a line break; entities resolve")
    func plainText() {
        #expect(NinaRules.plainText("a<br/>b<br />c<br>d") == "a\nb\nc\nd")
        #expect(NinaRules.plainText("Sturm &amp; Regen") == "Sturm & Regen")
        #expect(NinaRules.plainText("&lt;b&gt;") == "<b>")
        // &amp; is resolved last, so an escaped entity stays escaped rather
        // than being decoded twice.
        #expect(NinaRules.plainText("&amp;lt;") == "&lt;")
        #expect(NinaRules.plainText("  a<br/><br/><br/>b  ") == "a\n\nb")
    }

    @Test("Severity orders, and an unknown one sorts last rather than first")
    func severityRank() {
        #expect(NinaRules.severityRank("Extreme") > NinaRules.severityRank("Severe"))
        #expect(NinaRules.severityRank("Severe") > NinaRules.severityRank("Moderate"))
        #expect(NinaRules.severityRank("Moderate") > NinaRules.severityRank("Minor"))
        #expect(NinaRules.severityRank("Katastrophal") < NinaRules.severityRank("Minor"))
        #expect(NinaRules.severityRank(nil) < NinaRules.severityRank("Minor"))
    }

    @Test("A long area list is cut off, not printed in full")
    func areaLabelTruncates() {
        let many = NinaWarningDetail.Info(
            language: "de", event: nil, headline: nil, description: nil, instruction: nil,
            severity: nil, expires: nil,
            area: ["A", "B", "C", "D", "E"].map { NinaWarningDetail.Info.Area(areaDesc: $0) }
        )
        #expect(NinaRules.areaLabel(many) == "A, B, C …")

        let few = NinaWarningDetail.Info(
            language: "de", event: nil, headline: nil, description: nil, instruction: nil,
            severity: nil, expires: nil,
            area: [.init(areaDesc: "Stadt Frankfurt am Main"), .init(areaDesc: "Stadt Frankfurt am Main")]
        )
        // Deduplicated: a CAP message often repeats the same Gemeinde.
        #expect(NinaRules.areaLabel(few) == "Stadt Frankfurt am Main")

        let none = NinaWarningDetail.Info(
            language: "de", event: nil, headline: nil, description: nil, instruction: nil,
            severity: nil, expires: nil, area: [.init(areaDesc: "  ")]
        )
        #expect(NinaRules.areaLabel(none) == nil)
    }
}

@Suite("NINA warnings")
struct NinaWarningTests {
    private static let duringTheStorm = ISO8601DateFormatter.internetDateTime.date(from: "2026-08-19T12:00:00+02:00")!

    private func mapped(
        _ detail: String, _ dashboard: String, now: Date = duringTheStorm
    ) throws
        -> NinaWarningProvider.SortableWarning?
    {
        NinaWarningProvider.warning(
            from: try ninaDecoded(NinaWarningDetail.self, detail),
            dashboard: try #require(ninaDecoded([NinaDashboardItem].self, dashboard).first),
            now: now
        )
    }

    @Test("A DWD warning becomes a card with no markup left in it")
    func dwdCard() throws {
        let mapped = try #require(try mapped("nina-warning-dwd", "nina-dashboard-dwd"))
        let warning = mapped.warning
        #expect(warning.title == "Amtliche WARNUNG vor STURMBÖEN")
        #expect(warning.body.hasPrefix("Es treten oberhalb 1000 m Sturmböen"))
        // Description and Handlungsempfehlungen, in that order.
        #expect(warning.body.contains("\n\nGefahr durch:"))
        #expect(!warning.body.contains("<br"))
        #expect(warning.areaLabel == "Stadt Wernigerode")
        // BBK is relaying somebody else's warning, and the stamp says so.
        #expect(warning.stampLabel == "NINA · DWD · 09:01")
        #expect(mapped.severityRank == NinaRules.severityRank("Moderate"))
    }

    @Test("MOWAS is NINA's own system, so the stamp does not name it twice")
    func mowasCard() throws {
        let warning = try #require(try mapped("nina-warning-mowas", "nina-dashboard-mowas")).warning
        #expect(warning.stampLabel == "NINA · 10:32")
        #expect(warning.title.hasPrefix("Einrichtung von Schutzzonen"))
        #expect(warning.body.contains("Berühren Sie keine toten Tiere"))
        #expect(warning.areaLabel == "Süd-westlicher Bereich des Landkreises Waldeck-Frankenberg")
    }

    @Test("A warning that has run out is not a warning")
    func expired() throws {
        let after = ISO8601DateFormatter.internetDateTime.date(from: "2026-08-20T08:00:00+02:00")!
        #expect(try mapped("nina-warning-dwd", "nina-dashboard-dwd", now: after) == nil)
        // Exactly at the expiry it is already over.
        let atExpiry = ISO8601DateFormatter.internetDateTime.date(from: "2026-08-20T00:00:00+02:00")!
        #expect(try mapped("nina-warning-dwd", "nina-dashboard-dwd", now: atExpiry) == nil)
    }

    @Test("Withdrawn and non-actual messages never reach the card")
    func withdrawn() throws {
        let detail = try ninaDecoded(NinaWarningDetail.self, "nina-warning-dwd")
        let expires = ISO8601DateFormatter.internetDateTime.date(from: "2026-08-20T00:00:00+02:00")
        #expect(NinaRules.isInForce(detail, expires: expires, now: Self.duringTheStorm))

        let cancelled = NinaWarningDetail(
            identifier: detail.identifier, status: "Actual", msgType: "Cancel",
            sent: detail.sent, info: detail.info
        )
        #expect(!NinaRules.isInForce(cancelled, expires: expires, now: Self.duringTheStorm))

        let exercise = NinaWarningDetail(
            identifier: detail.identifier, status: "Exercise", msgType: "Alert",
            sent: detail.sent, info: detail.info
        )
        #expect(!NinaRules.isInForce(exercise, expires: expires, now: Self.duringTheStorm))
    }

    @Test("Most severe first, newest first within a severity")
    func ordering() {
        func entry(_ rank: Int, _ minute: Int, _ title: String) -> NinaWarningProvider.SortableWarning {
            NinaWarningProvider.SortableWarning(
                warning: CityWarning(title: title, body: "", stampLabel: ""),
                severityRank: rank,
                sentAt: Date(timeIntervalSince1970: TimeInterval(minute) * 60)
            )
        }
        // A task group answers in completion order, so this is the only thing
        // deciding what the user reads first.
        let ordered = NinaWarningProvider.ordered([
            entry(1, 90, "minor, newest"),
            entry(4, 10, "extreme, oldest"),
            entry(2, 50, "moderate"),
            entry(4, 20, "extreme, newer"),
        ])
        #expect(ordered.map(\.title) == ["extreme, newer", "extreme, oldest", "moderate", "minor, newest"])
    }

    @Test("Without rings.json there is no filter, and no card either")
    func missingRegionTable() async throws {
        // Explicitly not a fall back to SampleCityWarningProvider: an invented
        // civil-protection warning is worse than a card that says it failed.
        let provider = NinaWarningProvider(table: nil, selectedRing: { .frankfurt })
        await #expect(throws: NinaWarningProvider.Failure.missingRegionTable) {
            try await provider.warnings()
        }
    }
}
