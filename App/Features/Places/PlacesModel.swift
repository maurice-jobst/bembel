import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class PlacesModel {
    private(set) var snapshot = RegisterSnapshot.empty
    private(set) var fountains: [Fountain] = []
    private(set) var lastError: Error?
    private(set) var isLoading = false
    /// One load per tab lifetime. Not "is the snapshot empty" — an empty
    /// register is a legitimate result and must not retrigger the load.
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
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await register.snapshot()
        } catch {
            lastError = error
        }
        do {
            fountains = try await fountainProvider.fountains()
            selectedFountain = fountains.first(where: \.featured) ?? fountains.first
        } catch {
            lastError = error
        }
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
