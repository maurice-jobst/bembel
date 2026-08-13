import Foundation
import Testing

@testable import BEMBELKit

@Suite("AGS validation")
struct AGSTests {
    @Test func validKey() {
        #expect(AGS(rawValue: "06412000")?.rawValue == "06412000")
    }

    @Test("Wrong length, letters, and non-ASCII digits are rejected")
    func invalidKeys() {
        #expect(AGS(rawValue: "0641200") == nil)
        #expect(AGS(rawValue: "064120000") == nil)
        #expect(AGS(rawValue: "0641200a") == nil)
        #expect(AGS(rawValue: "") == nil)
        #expect(AGS(rawValue: "0641200٠") == nil) // Arabic-Indic zero
    }

    @Test("Decoding a malformed key throws instead of admitting it")
    func decodingRejectsMalformed() {
        let json = Data(#"{"ags": "64120", "name": "X", "ring": "frankfurt"}"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(RegionTable.Municipality.self, from: json)
        }
    }
}

@Suite("Region table")
struct RegionTableTests {
    private let frankfurt = AGS(rawValue: "06412000")!
    private let offenbach = AGS(rawValue: "06413000")!
    private let mainz = AGS(rawValue: "07315000")!
    private let unknown = AGS(rawValue: "05315000")! // Köln — not Rhein-Main

    @Test("Rings are ordered inside-out")
    func ringOrdering() {
        #expect(Ring.frankfurt < Ring.kernraum)
        #expect(Ring.kernraum < Ring.rheinmain)
    }

    @Test("Bundled table loads and knows Frankfurt")
    func bundledTable() throws {
        let table = try RegionTable.bundled()
        #expect(table.ring(for: frankfurt) == .frankfurt)
        #expect(!table.municipalities.isEmpty)
    }

    @Test("Selection includes inner rings and excludes outer ones")
    func inclusion() throws {
        let table = try RegionTable.bundled()
        // Frankfurt is visible under every selection.
        for selection in Ring.allCases {
            #expect(table.isIncluded(frankfurt, in: selection))
        }
        // A kernraum city is hidden under the frankfurt-only selection.
        #expect(!table.isIncluded(offenbach, in: .frankfurt))
        #expect(table.isIncluded(offenbach, in: .kernraum))
        #expect(table.isIncluded(offenbach, in: .rheinmain))
        // An outer-ring city appears only under the widest selection.
        #expect(!table.isIncluded(mainz, in: .kernraum))
        #expect(table.isIncluded(mainz, in: .rheinmain))
    }

    @Test("Unknown municipalities are excluded, never defaulted in")
    func unknownExcluded() throws {
        let table = try RegionTable.bundled()
        for selection in Ring.allCases {
            #expect(!table.isIncluded(unknown, in: selection))
        }
    }

    @Test("Defaults fall back to kernraum on garbage")
    func settingsFallback() {
        let defaults = UserDefaults(suiteName: "test.region.\(UUID().uuidString)")!
        #expect(RegionSettings.selectedRing(from: defaults) == .kernraum)
        defaults.set("atlantis", forKey: RegionSettings.selectedRingKey)
        #expect(RegionSettings.selectedRing(from: defaults) == .kernraum)
        defaults.set("rheinmain", forKey: RegionSettings.selectedRingKey)
        #expect(RegionSettings.selectedRing(from: defaults) == .rheinmain)
    }
}
