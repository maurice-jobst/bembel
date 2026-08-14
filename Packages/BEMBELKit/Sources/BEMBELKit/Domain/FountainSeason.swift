import Foundation

/// What a fountain is doing right now, and when that changes. Pure functions
/// over (kind, instant) — no clock of their own, no network, so every rule is
/// exhaustively testable against simulated dates (BEM-E02).
public enum FountainState: Hashable, Sendable {
    /// Water now.
    case running
    /// Winterised. The associated date is when the season next opens.
    case closedForWinter(opensOn: Date)
    /// In season, but this fountain has not started yet — historic fountains
    /// wait for Easter.
    case notYetInSeason(opensOn: Date)
    /// Running today, but not at this hour.
    case closedForNow(opensAt: Date)
    /// Done for today; back tomorrow morning.
    case closedForToday(opensAt: Date)
    /// Refill stations follow a shop's opening hours, which no dataset here
    /// carries. Saying "closed" would be a guess and saying "open" would be a
    /// worse one.
    case unknown

    public var hasWater: Bool { self == .running }
}

/// The real seasonal rules, per fountain kind.
///
/// City fountains run from World Water Day (22 March) until they are
/// winterised at the end of September. The historic ones are a different
/// machine: they are turned on only after Easter — a movable feast, so it is
/// computed, never tabled — and they run 10:00–22:00.
public enum FountainSeason {
    public static let openingMonth = 3
    public static let openingDay = 22
    public static let closingMonth = 9
    public static let closingDay = 30
    /// Daily window for historic fountains.
    public static let historicOpeningHour = 10
    public static let historicClosingHour = 22

    /// The base season, ignoring per-kind rules. Kept as-is: the Trinkbrunnen
    /// segment's headline ("Saison läuft") is this question.
    public static func isOpen(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return false }
        if month < openingMonth || month > closingMonth { return false }
        if month == openingMonth { return day >= openingDay }
        return true
    }

    /// Gregorian computus (Meeus/Jones/Butcher). Easter drifts across 22 March
    /// to 25 April, which is exactly why the historic fountains cannot have a
    /// fixed opening date — in 2027 Easter falls on 28 March, six days into the
    /// general season.
    public static func easter(year: Int) -> DateComponents {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return DateComponents(year: year, month: month, day: day)
    }

    /// The whole engine. `kind` decides which rules apply; everything else is
    /// the calendar.
    public static func state(
        of kind: FountainKind,
        at date: Date,
        calendar: Calendar = .current
    ) -> FountainState {
        // Not seasonal at all — a Refill partner is open when its shop is.
        guard kind.isSeasonal else { return .unknown }

        guard let year = calendar.dateComponents([.year], from: date).year else { return .unknown }

        if !isOpen(on: date, calendar: calendar) {
            // Before 22 March the season opens this year; after 30 September,
            // next year.
            let month = calendar.component(.month, from: date)
            let openingYear = month > closingMonth ? year + 1 : year
            guard let opening = seasonOpening(year: openingYear, calendar: calendar) else { return .unknown }
            return .closedForWinter(opensOn: opening)
        }

        guard kind.waitsForEaster else { return .running }

        guard
            let easterDay = calendar.date(from: easter(year: year)),
            let startOfEaster = calendar.dateInterval(of: .day, for: easterDay)?.start,
            let startOfToday = calendar.dateInterval(of: .day, for: date)?.start
        else { return .running }

        if startOfToday < startOfEaster {
            return .notYetInSeason(opensOn: startOfEaster)
        }
        return dailyWindowState(at: date, calendar: calendar)
    }

    /// Historic fountains: 10:00–22:00, and "closed" says when it reopens.
    private static func dailyWindowState(at date: Date, calendar: Calendar) -> FountainState {
        guard
            let opensToday = calendar.date(
                bySettingHour: historicOpeningHour, minute: 0, second: 0, of: date),
            let closesToday = calendar.date(
                bySettingHour: historicClosingHour, minute: 0, second: 0, of: date)
        else { return .running }

        if date < opensToday { return .closedForNow(opensAt: opensToday) }
        if date >= closesToday {
            // Past 22:00 the next opening is tomorrow — unless tomorrow is
            // October, but then the caller sees the season rule first.
            let opensTomorrow = calendar.date(byAdding: .day, value: 1, to: opensToday) ?? opensToday
            return .closedForToday(opensAt: opensTomorrow)
        }
        return .running
    }

    private static func seasonOpening(year: Int, calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: openingMonth, day: openingDay))
    }
}
