import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class ShadowModel {
    var minutes: Double = SunModel.nowMinutes()

    var sun: SunSample {
        SunModel.sample(atMinutes: minutes)
    }

    func resetToNow() {
        minutes = SunModel.nowMinutes()
    }
}
