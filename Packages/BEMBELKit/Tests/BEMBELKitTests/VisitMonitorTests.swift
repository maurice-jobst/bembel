import CoreLocation
import Foundation
import Testing

@testable import BEMBELKit

@Suite("Visit monitor region selection")
struct VisitMonitorTests {
    private func entry(_ id: String, lat: Double, lon: Double, verified: Bool = true) -> RegisterEntry {
        RegisterEntry(
            id: id,
            register: .wasserhaeuschen,
            name: id,
            street: "-",
            postalCode: "60311",
            city: "Frankfurt am Main",
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

    private let hauptwache = CLLocationCoordinate2D(latitude: 50.1136, longitude: 8.6797)

    @Test("Nearest entries win, in distance order")
    func picksNearest() {
        let entries = [
            entry("weit", lat: 50.2000, lon: 8.9000),
            entry("nah", lat: 50.1137, lon: 8.6798),
            entry("mittel", lat: 50.1200, lon: 8.6900),
        ]
        let picked = VisitMonitor.candidates(from: entries, near: hauptwache)
        #expect(picked.map(\.id) == ["nah", "mittel", "weit"])
    }

    @Test("Unverified entries are never monitored — they may not exist")
    func skipsCandidates() {
        let entries = [
            entry("kandidat", lat: 50.1136, lon: 8.6797, verified: false),
            entry("echt", lat: 50.1200, lon: 8.6900),
        ]
        #expect(VisitMonitor.candidates(from: entries, near: hauptwache).map(\.id) == ["echt"])
    }

    @Test("The region limit is respected")
    func respectsLimit() {
        let entries = (0..<40).map { entry("k\($0)", lat: 50.11 + Double($0) / 1000, lon: 8.68) }
        #expect(VisitMonitor.candidates(from: entries, near: hauptwache).count == VisitMonitor.regionLimit)
        #expect(VisitMonitor.candidates(from: entries, near: hauptwache, limit: 3).count == 3)
    }
}
