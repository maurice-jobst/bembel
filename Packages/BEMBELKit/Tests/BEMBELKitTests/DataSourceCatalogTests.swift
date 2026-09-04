import Foundation
import Testing

@testable import BEMBELKit

@Suite("Data source catalog (BEM-B06)")
struct DataSourceCatalogTests {
    @Test("Loads the bundled datasources.json without throwing")
    func loadsBundledCatalog() throws {
        let catalog = try DataSourceCatalog.load()
        #expect(!catalog.live.isEmpty)
        #expect(!catalog.bundled.isEmpty)
    }

    @Test("A live entry actually shipped in Settings carries name, license and attribution")
    func liveEntriesAreComplete() throws {
        let catalog = try DataSourceCatalog.load()
        let ninaEntry = try #require(catalog.live.first { $0.id == "nina_mowas" })
        #expect(ninaEntry.name == "NINA / MoWaS Bevölkerungswarnungen")
        #expect(!ninaEntry.license.isEmpty)
        #expect(!ninaEntry.attribution.isEmpty)
        #expect(ninaEntry.tier != nil)
    }

    @Test("PEGELONLINE and the fountains registry gap this ticket found are closed")
    func closesTheKnownRegistryGaps() throws {
        let catalog = try DataSourceCatalog.load()
        #expect(catalog.live.contains { $0.id == "pegelonline" })
        #expect(catalog.bundled.contains { $0.id == "fountains-ffm" })
        #expect(catalog.bundled.contains { $0.id == "fountains-osm" })
        #expect(catalog.bundled.contains { $0.id == "bembel-data" })
    }

    @Test("Neither list carries an id known to be unonboarded or research-only")
    func excludesWhatTheAppDoesNotCall() throws {
        let catalog = try DataSourceCatalog.load()
        let allIDs = Set((catalog.live + catalog.bundled).map(\.id))
        // RMV and a direct HLNUG line were the two false claims BEM-B06 exists
        // to remove (#70) — neither has a "consumption" tag in the registry,
        // so a regression here would mean someone re-added one by hand.
        #expect(!allIDs.contains("rmv_hapi"))
        #expect(!allIDs.contains("hessen_ckan"))
        #expect(!allIDs.contains("mobilithek_parkdaten"))
    }

    @Test("Decoding tolerates a bundled entry with no tier or status")
    func decodesMinimalEntry() throws {
        let json = Data(
            """
            {"id": "x", "name": "X", "license": "ODbL", "attribution": "X-Mitwirkende"}
            """.utf8
        )
        let entry = try JSONDecoder().decode(DataSourceEntry.self, from: json)
        #expect(entry.tier == nil)
        #expect(entry.status == nil)
    }
}
