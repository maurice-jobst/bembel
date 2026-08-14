import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class CityModel {
    private(set) var status: CityStatus?
    /// Surfaced by BEM-C06's failure states; until then it just isn't lost.
    private(set) var lastError: Error?

    func load(from provider: any CityStatusProviding) async {
        guard status == nil else { return }
        do {
            status = try await provider.status()
        } catch {
            lastError = error
        }
    }
}
