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

    /// The axis's middle tick. Solar noon is not 13:00, and it is not the same
    /// on any two days of the year — 13:27 in June, 12:23 in December.
    ///
    /// Fixed for the life of the screen rather than recomputed per render: it
    /// sweeps the day to find the peak, which is cheap but not free, and the
    /// answer moves by well under a minute from one day to the next.
    let solarNoonMinutes = SunModel.solarNoonMinutes()

    func resetToNow() {
        minutes = SunModel.nowMinutes()
    }
}
