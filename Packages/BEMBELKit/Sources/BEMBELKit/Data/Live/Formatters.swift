import Foundation

// Cached because formatter construction dominates the parse. Both classes are
// documented thread-safe, hence `nonisolated(unsafe)`. One copy for all live
// providers — PEGELONLINE, NINA and the radar each grew their own identical
// statics before these existed.

extension DateFormatter {
    /// `HH:mm` in Europe/Berlin — the clock stamp every live card carries.
    nonisolated(unsafe) static let berlinClock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

extension ISO8601DateFormatter {
    /// `2026-08-15T12:30:00+02:00` — offset, no fractional seconds. PEGELONLINE
    /// and NINA both stamp this way; DWD's CAP variant with fractional seconds
    /// stays next to its parser in Nina.swift.
    nonisolated(unsafe) static let internetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
