import Foundation
import Testing

@testable import BEMBELKit

@Suite("Pollen dataset (BEM-G04)")
struct PollenDatasetTests {
    private func loadBundled() throws -> PollenForecastFile {
        let url = try #require(Bundle.module.url(forResource: "pollen", withExtension: "json"))
        return try JSONDecoder().decode(PollenForecastFile.self, from: Data(contentsOf: url))
    }

    @Test("Decodes the bundled DWD snapshot without throwing")
    func decodesBundledFile() throws {
        let file = try loadBundled()
        #expect(!file.content.isEmpty)
        #expect(!file.lastUpdate.isEmpty)
    }

    @Test("Resolves Rhein-Main by region name, against the real checked-in response")
    func resolvesRhineMainByName() throws {
        let file = try loadBundled()
        let reading = try file.reading()
        // Every value present is one the bundled snapshot actually carries for
        // Hessen/Rhein-Main and rates above "keine Belastung" — a wrong-region
        // match (NRW's own "Rhein…" partregion) would pull in different names.
        #expect(reading.values.allSatisfy { $0.today.isElevated })
        #expect(reading.stampLabel == "DWD · \(file.lastUpdate)")
    }

    @Test(
        "A substring match on \"Rhein\" would pick the wrong Land — this is the trap the ticket names"
    )
    func doesNotConfuseSimilarlyNamedPartregions() throws {
        let json = Data(
            """
            {
                "content": [
                    {
                        "region_name": "Nordrhein-Westfalen",
                        "partregion_name": "Rhein.-Westfäl. Tiefland",
                        "Pollen": {"Birke": {"today": "3", "tomorrow": "3", "dayafter_to": "3"}}
                    },
                    {
                        "region_name": "Hessen",
                        "partregion_name": "Rhein-Main",
                        "Pollen": {"Ambrosia": {"today": "1", "tomorrow": "0-1", "dayafter_to": "0"}}
                    }
                ],
                "legend": {"id3": "1", "id3_desc": "geringe Belastung"},
                "last_update": "2026-09-04 11:00 Uhr"
            }
            """.utf8
        )
        let file = try JSONDecoder().decode(PollenForecastFile.self, from: json)
        let reading = try file.reading()
        #expect(reading.values.map(\.name) == ["Ambrosia"])
        #expect(!reading.values.contains { $0.name == "Birke" })
    }

    @Test("A file with no Hessen/Rhein-Main entry fails loudly instead of reading as \"nothing in the air\"")
    func throwsWhenPartregionIsMissing() throws {
        let json = Data(
            """
            {"content": [], "legend": {}, "last_update": "2026-09-04 11:00 Uhr"}
            """.utf8
        )
        let file = try JSONDecoder().decode(PollenForecastFile.self, from: json)
        #expect(throws: PollenError.missingRhineMainPartregion) {
            try file.reading()
        }
    }

    @Test("Half-step levels survive as their own string, never rounded to a whole band")
    func keepsHalfSteps() throws {
        let json = Data(
            """
            {
                "content": [{
                    "region_name": "Hessen",
                    "partregion_name": "Rhein-Main",
                    "Pollen": {"Graeser": {"today": "1-2", "tomorrow": "2", "dayafter_to": "2-3"}}
                }],
                "legend": {
                    "id4": "1-2", "id4_desc": "geringe bis mittlere Belastung",
                    "id5": "2", "id5_desc": "mittlere Belastung"
                },
                "last_update": "2026-09-04 11:00 Uhr"
            }
            """.utf8
        )
        let file = try JSONDecoder().decode(PollenForecastFile.self, from: json)
        let value = try #require(try file.reading().values.first)
        #expect(value.today.rawValue == "1-2")
        #expect(value.today.rawValue != "1")
        #expect(value.today.rawValue != "2")
        #expect(value.todayDescription == "geringe bis mittlere Belastung")
        #expect(value.dayAfterTomorrow.rawValue == "2-3")
    }

    @Test("A pollen type resting at \"keine Belastung\" today is dropped, not rendered as a zero row")
    func dropsUnelevatedTypes() throws {
        let json = Data(
            """
            {
                "content": [{
                    "region_name": "Hessen",
                    "partregion_name": "Rhein-Main",
                    "Pollen": {
                        "Hasel": {"today": "0", "tomorrow": "0", "dayafter_to": "0"},
                        "Erle": {"today": "1", "tomorrow": "0", "dayafter_to": "0"}
                    }
                }],
                "legend": {"id3": "1", "id3_desc": "geringe Belastung"},
                "last_update": "2026-09-04 11:00 Uhr"
            }
            """.utf8
        )
        let file = try JSONDecoder().decode(PollenForecastFile.self, from: json)
        let reading = try file.reading()
        #expect(reading.values.map(\.name) == ["Erle"])
    }

    @Test("Severity order is explicit, not a string comparison that happens to agree with it")
    func severityRankOrdersKnownLevelsCorrectly() {
        let ordered = ["0", "0-1", "1", "1-2", "2", "2-3", "3"].map { PollenLevel(rawValue: $0) }
        for (lower, higher) in zip(ordered, ordered.dropFirst()) {
            #expect(lower.severityRank < higher.severityRank)
        }
        #expect(PollenLevel(rawValue: "unbekannt").severityRank > PollenLevel(rawValue: "3").severityRank)
    }
}
