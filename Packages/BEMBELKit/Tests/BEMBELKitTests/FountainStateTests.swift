import Foundation
import Testing

@testable import BEMBELKit

@Suite("Fountain seasonal state")
struct FountainStateTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func at(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func state(_ kind: FountainKind, _ date: Date) -> FountainState {
        FountainSeason.state(of: kind, at: date, calendar: calendar)
    }

    // --- Easter, because everything historic hangs off it --------------------

    @Test("Gregorian computus matches the published Easter dates")
    func easterDates() {
        // Published Easter Sundays; 2027 is the interesting one — it lands
        // inside the general season, six days after it opens.
        let published: [Int: (Int, Int)] = [
            2026: (4, 5), 2027: (3, 28), 2028: (4, 16), 2029: (4, 1), 2030: (4, 21),
            2031: (4, 13), 2032: (3, 28), 2033: (4, 17), 2034: (4, 9), 2035: (3, 25),
        ]
        for (year, expected) in published.sorted(by: { $0.key < $1.key }) {
            let computed = FountainSeason.easter(year: year)
            #expect(
                computed.month == expected.0 && computed.day == expected.1,
                "Easter \(year): expected \(expected), got \(computed.month ?? -1)/\(computed.day ?? -1)"
            )
        }
    }

    @Test("Easter never falls outside its 22 March – 25 April window")
    func easterStaysInWindow() {
        for year in 1900...2100 {
            let easter = FountainSeason.easter(year: year)
            let month = easter.month ?? 0
            let day = easter.day ?? 0
            #expect(month == 3 || month == 4)
            if month == 3 { #expect(day >= 22) } else { #expect(day <= 25) }
        }
    }

    // --- the general season --------------------------------------------------

    @Test("City fountains run the whole season and stop in October")
    func citySeason() {
        #expect(state(.stadt, at(2026, 3, 22)) == .running)
        #expect(state(.stadt, at(2026, 7, 15)) == .running)
        #expect(state(.stadt, at(2026, 9, 30)) == .running)
        #expect(state(.stadt, at(2026, 1, 15)).hasWater == false)
        #expect(state(.stadt, at(2026, 10, 1)).hasWater == false)
    }

    @Test("Winter names the date the season reopens")
    func winterKnowsWhenItEnds() {
        #expect(state(.stadt, at(2026, 1, 15)) == .closedForWinter(opensOn: at(2026, 3, 22, 0)))
        // After the season, the next opening is next year's — not a date in
        // the past, which is what a naive same-year answer would give.
        #expect(state(.stadt, at(2026, 10, 1)) == .closedForWinter(opensOn: at(2027, 3, 22, 0)))
        #expect(state(.stadt, at(2026, 12, 31)) == .closedForWinter(opensOn: at(2027, 3, 22, 0)))
    }

    @Test("Mainova and untyped fountains follow the plain city season")
    func otherSeasonalKinds() {
        for kind in [FountainKind.mainova, .sonstige] {
            #expect(state(kind, at(2026, 7, 15)) == .running)
            #expect(state(kind, at(2026, 12, 1)).hasWater == false)
        }
    }

    // --- historic: Easter, then daily hours ----------------------------------

    @Test("Historic fountains stay off between 22 March and Easter")
    func historicWaitsForEaster() {
        // Easter 2026 is 5 April, so the whole late-March window is closed for
        // historic fountains while city ones already run.
        #expect(state(.stadt, at(2026, 3, 25)) == .running)
        #expect(state(.historisch, at(2026, 3, 25)) == .notYetInSeason(opensOn: at(2026, 4, 5, 0)))
        #expect(state(.historisch, at(2026, 4, 4)) == .notYetInSeason(opensOn: at(2026, 4, 5, 0)))
        #expect(state(.historisch, at(2026, 4, 5)) == .running)
    }

    @Test("A late season opening still beats an early Easter")
    func earlyEaster() {
        // Easter 2027 falls on 28 March — inside the season. 22–27 March the
        // historic fountains are off; from the 28th they run.
        #expect(state(.historisch, at(2027, 3, 23)) == .notYetInSeason(opensOn: at(2027, 3, 28, 0)))
        #expect(state(.historisch, at(2027, 3, 28)) == .running)
        // And before the season opens at all, the season rule wins — the answer
        // is "winter", not "waiting for Easter".
        #expect(state(.historisch, at(2027, 3, 21)) == .closedForWinter(opensOn: at(2027, 3, 22, 0)))
    }

    @Test("Historic fountains keep 10:00–22:00")
    func historicDailyHours() {
        #expect(state(.historisch, at(2026, 7, 15, 9)) == .closedForNow(opensAt: at(2026, 7, 15, 10)))
        #expect(state(.historisch, at(2026, 7, 15, 10)) == .running)
        #expect(state(.historisch, at(2026, 7, 15, 21)) == .running)
        #expect(state(.historisch, at(2026, 7, 15, 22)) == .closedForToday(opensAt: at(2026, 7, 16, 10)))
        #expect(state(.historisch, at(2026, 7, 15, 23)) == .closedForToday(opensAt: at(2026, 7, 16, 10)))
    }

    @Test("The daily window does not leak into the winter answer")
    func historicWinterBeatsHours() {
        // 09:00 in January is not "opens at 10" — it is January.
        #expect(state(.historisch, at(2026, 1, 15, 9)) == .closedForWinter(opensOn: at(2026, 3, 22, 0)))
    }

    // --- refill --------------------------------------------------------------

    @Test("Refill partners are never given a season we do not know")
    func refillIsUnknown() {
        #expect(state(.refill, at(2026, 7, 15)) == .unknown)
        #expect(state(.refill, at(2026, 1, 15)) == .unknown)
        #expect(state(.refill, at(2026, 7, 15, 3)) == .unknown)
    }

    // --- decoding ------------------------------------------------------------

    @Test("An art this build has never heard of decodes to sonstige, not to a throw")
    func unknownKindDegrades() throws {
        let decoded = try JSONDecoder().decode([FountainKind].self, from: Data(#"["stadt","zapfsaeule"]"#.utf8))
        #expect(decoded == [.stadt, .sonstige])
    }

    @Test("Every published art round-trips")
    func kindRoundTrip() throws {
        for kind in FountainKind.allCases {
            let data = try JSONEncoder().encode([kind])
            #expect(try JSONDecoder().decode([FountainKind].self, from: data) == [kind])
        }
    }

    // --- the convenience on Fountain ----------------------------------------

    @Test("Fountain.state defers to the engine for its own kind")
    func fountainState() {
        let historic = Fountain(
            id: "goldener-brunnen", name: "Goldener Brunnen", latitude: 50.11, longitude: 8.68,
            distanceLabel: "220 m", walkMinutes: 3, kind: .historisch, tested: false)
        #expect(historic.state(at: at(2026, 7, 15, 9), calendar: calendar) != .running)
        #expect(historic.state(at: at(2026, 7, 15, 12), calendar: calendar) == .running)
        #expect(historic.tested == false)
    }
}
