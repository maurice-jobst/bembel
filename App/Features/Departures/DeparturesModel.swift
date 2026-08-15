import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class DeparturesModel {
    private(set) var stations: Loadable<[Station]> = .idle
    private(set) var selectedStation: Station?
    private(set) var board: Loadable<DepartureBoard> = .idle

    func load(from provider: any DeparturesProviding) async {
        // Keyed on the state, not on `stations.isEmpty`: a stop list that
        // legitimately comes back empty — out of the region, RMV down to a
        // valid-but-empty answer — must settle, not re-ask on every appearance.
        guard !stations.hasLoaded else { return }
        stations = .loading
        stations = await .result { try await provider.stations() }
        if let first = stations.value?.first {
            await select(first, from: provider)
        }
    }

    func select(_ station: Station, from provider: any DeparturesProviding) async {
        selectedStation = station
        board = .loading
        board = await .result { try await provider.board(for: station) }
    }
}
