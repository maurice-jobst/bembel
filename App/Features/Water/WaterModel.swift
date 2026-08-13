import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class WaterModel {
    private(set) var fountains: [Fountain] = []
    var selectedFountain: Fountain?
    /// Surfaced by BEM-C06's failure states; until then it just isn't lost.
    private(set) var lastError: Error?

    func load(from provider: any FountainProviding) async {
        guard fountains.isEmpty else { return }
        do {
            fountains = try await provider.fountains()
            selectedFountain = fountains.first(where: \.featured) ?? fountains.first
        } catch {
            lastError = error
        }
    }
}
