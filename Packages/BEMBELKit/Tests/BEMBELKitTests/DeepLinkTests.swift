import Foundation
import Testing

@testable import BEMBELKit

@Suite("DeepLink parsing")
struct DeepLinkTests {
    private func link(_ string: String) -> DeepLink? {
        guard let url = URL(string: string) else { return nil }
        return DeepLink.parse(url)
    }

    @Test("English and German hosts resolve to the same tab")
    func hostAliases() {
        #expect(link("bembel://departures") == .tab(.departures))
        #expect(link("bembel://abfahrten") == .tab(.departures))
        #expect(link("bembel://radar") == .tab(.radar))
        #expect(link("bembel://regen") == .tab(.radar))
        #expect(link("bembel://city") == .tab(.city))
        #expect(link("bembel://stadt") == .tab(.city))
        #expect(link("bembel://settings") == .settings)
        #expect(link("bembel://einstellungen") == .settings)
    }

    @Test("Orte opens with and without a preselected register")
    func placesLinks() {
        #expect(link("bembel://places") == .places(nil))
        #expect(link("bembel://orte") == .places(nil))
        #expect(link("bembel://kiosk") == .places(.wasserhaeuschen))
        #expect(link("bembel://wasserhaeuschen") == .places(.wasserhaeuschen))
        #expect(link("bembel://ebbelwei") == .places(.ebbelwei))
        #expect(link("bembel://apfelwein") == .places(.ebbelwei))
    }

    @Test("The old water hosts still land somewhere sensible")
    func legacyWaterAliases() {
        #expect(link("bembel://water") == .places(.trinkbrunnen))
        #expect(link("bembel://wasser") == .places(.trinkbrunnen))
        #expect(link("bembel://brunnen") == .places(.trinkbrunnen))
    }

    @Test("Scheme and host are case-insensitive")
    func caseInsensitivity() {
        #expect(link("BEMBEL://WASSER") == .places(.trinkbrunnen))
        #expect(link("Bembel://Schatten") == .shadow(at: nil))
    }

    @Test("Foreign schemes and unknown hosts are rejected, not crashed on")
    func rejection() {
        #expect(link("https://bembel.example/wasser") == nil)
        #expect(link("bembel://") == nil)
        #expect(link("bembel://nonsense") == nil)
        #expect(link("bembel://wasser2") == nil)
        #expect(link("mailto:x@example.com") == nil)
        #expect(link("bembel://\(String(repeating: "a", count: 10_000))") == nil)
    }

    @Test("Zoned shadow timestamp is parsed exactly")
    func zonedTimestamp() {
        let parsed = link("bembel://shadow?t=2027-06-21T15:00:00%2B02:00")
        let expected = Date(timeIntervalSince1970: 1_813_582_800)  // 2027-06-21 13:00 UTC
        #expect(parsed == .shadow(at: expected))
    }

    @Test("Naive shadow timestamp is Frankfurt local time")
    func naiveTimestamp() throws {
        let parsed = link("bembel://schatten?t=2027-06-21T15:00")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let expected = try #require(
            calendar.date(from: DateComponents(year: 2027, month: 6, day: 21, hour: 15))
        )
        #expect(parsed == .shadow(at: expected))
    }

    @Test("Garbage timestamp degrades to shadow-at-now, not to failure")
    func garbageTimestamp() {
        #expect(link("bembel://shadow?t=notadate") == .shadow(at: nil))
        #expect(link("bembel://shadow?t=") == .shadow(at: nil))
        #expect(link("bembel://shadow") == .shadow(at: nil))
        #expect(link("bembel://shadow?x=1&t=2027-13-45T99:99") == .shadow(at: nil))
    }
}
