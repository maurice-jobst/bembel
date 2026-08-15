import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class RadarModel {
    private(set) var nowcast: Loadable<RadarNowcast> = .idle

    func load(from provider: any RadarProviding) async {
        guard !nowcast.hasLoaded else { return }
        nowcast = .loading
        nowcast = await .result { try await provider.nowcast() }
    }
}
