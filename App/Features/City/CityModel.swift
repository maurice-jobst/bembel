import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class CityModel {
    private(set) var status: Loadable<CityStatus> = .idle

    func load(from provider: any CityStatusProviding) async {
        guard !status.hasLoaded else { return }
        status = .loading
        status = await .result { try await provider.status() }
    }
}
