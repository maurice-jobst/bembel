import BEMBELKit
import CoreLocation
import Foundation
import Observation
import WidgetKit

/// What the map should centre on, and why. Equatable so a repeated request for
/// the same place is one event, not a camera that keeps re-snapping.
struct MapFocus: Equatable {
    let id: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

@MainActor
@Observable
final class PlacesModel {
    private(set) var snapshot = RegisterSnapshot.empty
    private(set) var fountains: [Fountain] = []
    /// Surfaced by BEM-C06's failure states; until then it just isn't lost.
    private(set) var lastError: Error?
    /// One *successful* load per tab lifetime. Not "is the snapshot empty" —
    /// an empty register is a legitimate result and must not retrigger the
    /// load — but a cancelled or failed load must stay retryable.
    private var hasLoaded = false

    /// An entry a deep link asked for that the current data cannot resolve
    /// yet. Held until the first successful load answers the question one way
    /// or the other, then dropped — a link naming an entry this bundle does
    /// not carry must not lie in wait and hijack a later refresh.
    private var pendingEntryID: String?

    var selectedRegister: PlaceRegister = .wasserhaeuschen
    /// Merkmale-first navigation: an empty set means "everything", and the
    /// chips are generated from the data, never from a hardcoded list.
    var selectedMerkmale: Set<Merkmal> = []
    /// Same rule for the Trinkbrunnen segment: empty means "every kind".
    var selectedKinds: Set<FountainKind> = []
    var selectedEntry: RegisterEntry?
    var selectedFountain: Fountain?
    private(set) var focus: MapFocus?

    /// Where the user is, when they have said we may know. `nil` is a
    /// supported answer everywhere it appears.
    var userCoordinate: CLLocationCoordinate2D?
    /// The ring the user picked in Settings. Filtering happens here rather than
    /// in the provider so switching rings needs no reload (BEM-A04 AC).
    var selectedRing: Ring = RegionSettings.defaultRing

    var availableMerkmale: [Merkmal] {
        snapshot.merkmale(in: selectedRegister)
    }

    /// Entries in the current register matching every selected Merkmal
    /// (intersection — "spät offen *und* Bänke draußen" is the question people
    /// actually ask), verified first, then alphabetical.
    var visibleEntries: [RegisterEntry] {
        snapshot.entries(in: selectedRegister)
            .filter { entry in selectedMerkmale.isSubset(of: Set(entry.merkmale)) }
            .sorted { lhs, rhs in
                lhs.verified == rhs.verified ? lhs.name < rhs.name : lhs.verified
            }
    }

    var coverage: [CoverageArea] {
        snapshot.coverage.sorted { $0.district < $1.district }
    }

    /// Fountains in the selected ring — a ring selection includes every inner
    /// ring, so "Rhein-Main" also shows Frankfurt's.
    private var fountainsInRing: [Fountain] {
        fountains.filter { $0.ring <= selectedRing }
    }

    /// The kinds actually present in the current ring, in the order the enum
    /// declares them. Generated from the data like the Merkmal chips: a ring
    /// with no Refill partner must not offer a Refill filter that empties the
    /// map.
    var availableKinds: [FountainKind] {
        let present = Set(fountainsInRing.map(\.kind))
        return FountainKind.allCases.filter(present.contains)
    }

    /// Nearest first when we know where the user is, alphabetical when we do
    /// not — never a fabricated distance (ADR 0007 / BEM-E03 AC).
    var visibleFountains: [RankedFountain] {
        let filtered = fountainsInRing.filter { selectedKinds.isEmpty || selectedKinds.contains($0.kind) }
        return FountainRanking.ranked(filtered, from: userCoordinate)
    }

    func toggle(_ kind: FountainKind) {
        if selectedKinds.contains(kind) {
            selectedKinds.remove(kind)
        } else {
            selectedKinds.insert(kind)
        }
        // A filter that hides the open card leaves the user staring at a
        // detail for something no longer on the map.
        if let selected = selectedFountain, !visibleFountains.contains(where: { $0.id == selected.id }) {
            selectedFountain = nil
        }
    }

    func load(register: any RegisterProviding, fountains fountainProvider: any FountainProviding) async {
        guard !hasLoaded else { return }
        // The two sources are independent — load them concurrently so a slow
        // register refresh cannot hold up the Trinkbrunnen segment.
        async let snapshotLoad = register.snapshot()
        async let fountainLoad = fountainProvider.fountains()
        var succeeded = true
        do {
            snapshot = try await snapshotLoad
        } catch {
            lastError = error
            succeeded = false
        }
        do {
            fountains = try await fountainLoad
            // Drop a standing selection only when it left the data; picking a
            // default is the *view's* job now, because "which one is nearest"
            // depends on the user's position, not on the dataset.
            if let selected = selectedFountain, !fountains.contains(where: { $0.id == selected.id }) {
                selectedFountain = nil
            }
        } catch {
            lastError = error
            succeeded = false
        }
        hasLoaded = succeeded
        resolvePendingEntry()
    }

    /// Pull-to-refresh: the user is telling us the staleness window is wrong
    /// for this moment, so the provider's cache goes first and the read path
    /// runs again from the source.
    func refresh(register: any RegisterProviding, fountains fountainProvider: any FountainProviding) async {
        await register.invalidate()
        await fountainProvider.invalidate()
        hasLoaded = false
        lastError = nil
        await load(register: register, fountains: fountainProvider)
    }

    func toggle(_ merkmal: Merkmal) {
        if selectedMerkmale.contains(merkmal) {
            selectedMerkmale.remove(merkmal)
        } else {
            selectedMerkmale.insert(merkmal)
        }
    }

    /// Switching register drops filters — a Merkmal from another register's
    /// vocabulary would silently empty the list.
    func select(register: PlaceRegister) {
        guard register != selectedRegister else { return }
        selectedRegister = register
        selectedMerkmale = []
        selectedEntry = nil
    }

    /// Deep-link entry point. The register in the URL is a hint, not a
    /// constraint: ids are unique across the published bundle, so finding the
    /// entry under a different register is a better answer than "not found".
    func focus(entryID: String) {
        pendingEntryID = entryID
        resolvePendingEntry()
    }

    private func resolvePendingEntry() {
        guard let id = pendingEntryID else { return }

        if let entry = snapshot.entries.first(where: { $0.id == id }) {
            selectedRegister = entry.register
            // A standing Merkmal filter from the previous register could hide
            // the very entry the link asked for.
            selectedMerkmale = []
            selectedEntry = entry
            focus = MapFocus(id: entry.id, latitude: entry.latitude, longitude: entry.longitude)
            pendingEntryID = nil
        } else if let fountain = fountains.first(where: { $0.id == id }) {
            selectedRegister = .trinkbrunnen
            selectedFountain = fountain
            focus = MapFocus(id: fountain.id, latitude: fountain.latitude, longitude: fountain.longitude)
            pendingEntryID = nil
        } else if hasLoaded {
            pendingEntryID = nil
        }
    }

    /// Hands the widget the nearest unverified entries. Called from the map,
    /// which is the only place that knows where the user is looking.
    func publishCandidateDigest(near center: CLLocationCoordinate2D) {
        guard hasLoaded else { return }
        let digest = CandidateDigest.make(from: snapshot, near: center)
        guard CandidateDigestStore.save(digest) else { return }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.nearestCandidate)
    }
}
