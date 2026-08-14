import BEMBELKit
import Foundation
import Observation

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

    var selectedRegister: PlaceRegister = .wasserhaeuschen
    /// Merkmale-first navigation: an empty set means "everything", and the
    /// chips are generated from the data, never from a hardcoded list.
    var selectedMerkmale: Set<Merkmal> = []
    var selectedEntry: RegisterEntry?
    var selectedFountain: Fountain?

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
            selectedFountain = fountains.first(where: \.featured) ?? fountains.first
        } catch {
            lastError = error
            succeeded = false
        }
        hasLoaded = succeeded
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
}
