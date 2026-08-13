import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class DeparturesModel {
    private(set) var stations: [Station] = []
    private(set) var selectedStation: Station?
    private(set) var board: DepartureBoard?
    /// Surfaced by BEM-C06's failure states; until then it just isn't lost.
    private(set) var lastError: Error?

    func load(from provider: any DeparturesProviding) async {
        guard stations.isEmpty else { return }
        do {
            stations = try await provider.stations()
            if let first = stations.first {
                await select(first, from: provider)
            }
        } catch {
            lastError = error
        }
    }

    func select(_ station: Station, from provider: any DeparturesProviding) async {
        selectedStation = station
        do {
            board = try await provider.board(for: station)
        } catch {
            lastError = error
        }
    }
}
