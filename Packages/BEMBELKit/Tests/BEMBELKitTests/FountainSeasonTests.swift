import Foundation
import Testing

@testable import BEMBELKit

@Suite("Fountain season")
struct FountainSeasonTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    @Test("Season opens on World Water Day, 22 March")
    func opening() {
        #expect(!FountainSeason.isOpen(on: day(3, 21), calendar: calendar))
        #expect(FountainSeason.isOpen(on: day(3, 22), calendar: calendar))
    }

    @Test("Season closes after 30 September")
    func closing() {
        #expect(FountainSeason.isOpen(on: day(9, 30), calendar: calendar))
        #expect(!FountainSeason.isOpen(on: day(10, 1), calendar: calendar))
    }

    @Test("Midsummer open, midwinter closed")
    func midpoints() {
        #expect(FountainSeason.isOpen(on: day(7, 15), calendar: calendar))
        #expect(!FountainSeason.isOpen(on: day(1, 15), calendar: calendar))
    }
}
