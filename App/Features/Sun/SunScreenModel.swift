import BEMBELKit
import Foundation
import Observation

@MainActor
@Observable
final class SunScreenModel {
    /// The day being shown. Deep links can move it (`bembel://sun?t=…`); the
    /// "jetzt" button brings it back.
    private(set) var day: Date = .now
    var minutes: Double = SunModel.nowMinutes()

    var sun: SunSample {
        SunModel.sample(atMinutes: minutes, on: day)
    }

    /// The axis's middle tick. Solar noon is not 13:00, and it is not the same
    /// on any two days of the year — 13:27 in June, 12:23 in December.
    ///
    /// Cached per day rather than recomputed per render: finding it sweeps the
    /// day, which is cheap but not free, and it moves by well under a minute
    /// from one day to the next.
    private(set) var solarNoonMinutes = SunModel.solarNoonMinutes()

    /// The day's real elevation curve, for the scrubber to draw. Same reason
    /// to cache: 96 ephemeris evaluations is nothing once and wasteful sixty
    /// times a second while a finger is down.
    private(set) var curve = SunModel.elevationCurve()

    func resetToNow() {
        show(at: .now)
    }

    /// Point the screen at an instant. The date part chooses the day, the time
    /// part the scrub position — a link that asks for 15:00 on the solstice
    /// means both halves of that.
    func show(at date: Date) {
        minutes = SunModel.nowMinutes(date)
        guard !Calendar.current.isDate(date, inSameDayAs: day) else { return }
        day = date
        solarNoonMinutes = SunModel.solarNoonMinutes(on: date)
        curve = SunModel.elevationCurve(on: date)
    }
}
