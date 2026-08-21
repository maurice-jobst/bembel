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

    @Test("A single path component names one entry in the host's register")
    func entryLinks() {
        #expect(link("bembel://kiosk/yok-yok") == .entry(register: .wasserhaeuschen, id: "yok-yok"))
        #expect(link("bembel://wasserhaeuschen/yok-yok") == .entry(register: .wasserhaeuschen, id: "yok-yok"))
        #expect(link("bembel://ebbelwei/zur-buchscheer") == .entry(register: .ebbelwei, id: "zur-buchscheer"))
        #expect(link("bembel://apfelwein/zur-buchscheer") == .entry(register: .ebbelwei, id: "zur-buchscheer"))
        #expect(link("bembel://brunnen/lorem") == .entry(register: .trinkbrunnen, id: "lorem"))
    }

    @Test("Entry ids are percent-decoded")
    func percentDecoding() {
        #expect(link("bembel://kiosk/caf%C3%A9-nizza") == .entry(register: .wasserhaeuschen, id: "café-nizza"))
    }

    @Test("Trailing slashes are not a different link")
    func trailingSlash() {
        #expect(link("bembel://kiosk/") == .places(.wasserhaeuschen))
        #expect(link("bembel://kiosk/yok-yok/") == .entry(register: .wasserhaeuschen, id: "yok-yok"))
    }

    @Test("Only register hosts take an id, and only one level deep")
    func entryLinkRejection() {
        // Nothing on screen could resolve a register-less entry id.
        #expect(link("bembel://places/yok-yok") == nil)
        #expect(link("bembel://orte/yok-yok") == nil)
        #expect(link("bembel://kiosk/yok-yok/extra") == nil)
        #expect(link("bembel://settings/yok-yok") == nil)
        #expect(link("bembel://radar/yok-yok") == nil)
        #expect(link("bembel://shadow/2027-06-21") == nil)
        #expect(link("bembel://kiosk/\(String(repeating: "a", count: 129))") == nil)
    }

    @Test("Emitted entry URLs parse back to what they were built from")
    func urlRoundTrip() throws {
        for register in PlaceRegister.allCases {
            let url = try #require(DeepLink.url(register: register, entryID: "yok-yok"))
            #expect(DeepLink.parse(url) == .entry(register: register, id: "yok-yok"))
        }
        let unicode = try #require(DeepLink.url(register: .ebbelwei, entryID: "café-nizza"))
        #expect(DeepLink.parse(unicode) == .entry(register: .ebbelwei, id: "café-nizza"))
    }

    @Test("An id the grammar would reject never becomes a URL")
    func urlRefusesBadIDs() {
        #expect(DeepLink.url(register: .wasserhaeuschen, entryID: "") == nil)
        #expect(DeepLink.url(register: .wasserhaeuschen, entryID: String(repeating: "a", count: 129)) == nil)
    }

    @Test("Scheme and host are case-insensitive")
    func caseInsensitivity() {
        #expect(link("BEMBEL://WASSER") == .places(.trinkbrunnen))
        #expect(link("Bembel://Schatten") == .sun(at: nil))
        #expect(link("bembel://sonne") == .sun(at: nil))
        #expect(link("BEMBEL://SUN") == .sun(at: nil))
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

    @Test("Zoned sun timestamp is parsed exactly")
    func zonedTimestamp() {
        let parsed = link("bembel://shadow?t=2027-06-21T15:00:00%2B02:00")
        let expected = Date(timeIntervalSince1970: 1_813_582_800)  // 2027-06-21 13:00 UTC
        #expect(parsed == .sun(at: expected))
    }

    @Test("Naive sun timestamp is Frankfurt local time")
    func naiveTimestamp() throws {
        let parsed = link("bembel://schatten?t=2027-06-21T15:00")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let expected = try #require(
            calendar.date(from: DateComponents(year: 2027, month: 6, day: 21, hour: 15))
        )
        #expect(parsed == .sun(at: expected))
    }

    @Test("Garbage timestamp degrades to sun-at-now, not to failure")
    func garbageTimestamp() {
        #expect(link("bembel://shadow?t=notadate") == .sun(at: nil))
        #expect(link("bembel://shadow?t=") == .sun(at: nil))
        #expect(link("bembel://shadow") == .sun(at: nil))
        #expect(link("bembel://shadow?x=1&t=2027-13-45T99:99") == .sun(at: nil))
    }
}
