import Foundation
import Testing

@testable import BEMBELKit

@Suite("Sun model")
struct SunModelTests {
    @Test("Elevation peaks at model noon and never drops below 2°")
    func elevationEnvelope() {
        #expect(SunModel.sample(atMinutes: SunModel.peakMinutes).elevation == Int(SunModel.peakElevation))
        #expect(SunModel.sample(atMinutes: SunModel.dayStart).elevation >= 2)
        #expect(SunModel.sample(atMinutes: SunModel.dayEnd).elevation >= 2)
    }

    @Test("Shadows point west in the morning, east after model noon")
    func shadowDirectionFlips() {
        #expect(SunModel.sample(atMinutes: SunModel.peakMinutes - 60).westward)
        #expect(!SunModel.sample(atMinutes: SunModel.peakMinutes + 60).westward)
    }

    @Test func clockLabelPadsZeros() {
        #expect(SunModel.clockLabel(minutes: 330) == "05:30")
        #expect(SunModel.clockLabel(minutes: 885) == "14:45")
        #expect(SunModel.clockLabel(minutes: 1290) == "21:30")
    }

    @Test("Now is clamped into the modeled day")
    func nowClamped() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 0, minute: 5))!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 12, minute: 0))!
        #expect(SunModel.nowMinutes(midnight, calendar: calendar) == SunModel.dayStart)
        #expect(SunModel.nowMinutes(noon, calendar: calendar) == 720)
    }
}
