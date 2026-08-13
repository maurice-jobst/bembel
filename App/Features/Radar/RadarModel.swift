import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class RadarModel {
    private(set) var nowcast: RadarNowcast?
    /// Surfaced by BEM-C06's failure states; until then it just isn't lost.
    private(set) var lastError: Error?

    func load(from provider: any RadarProviding) async {
        guard nowcast == nil else { return }
        do {
            nowcast = try await provider.nowcast()
        } catch {
            lastError = error
        }
    }
}
