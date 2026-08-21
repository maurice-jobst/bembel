import CoreLocation
import Foundation

/// One instant of sun, in the shape the Schatten screen consumes.
public struct SunSample: Sendable {
    /// Degrees above the horizon, **floored at zero**: below the horizon there
    /// is no sunlight and therefore no shadow, and every consumer of this
    /// value divides by `SunModel.peakElevation` to get a 0…1 weight. The
    /// unclamped truth is one field down, so nothing is lost.
    public let elevation: Int
    /// Whether shadows fall towards the west — that is, whether the sun is in
    /// the eastern half of the sky.
    public let westward: Bool
    /// The real position this sample was reduced from.
    public let position: SolarPosition

    public init(elevation: Int, westward: Bool, position: SolarPosition) {
        self.elevation = elevation
        self.westward = westward
        self.position = position
    }

    /// Convenience for the screen: no sun, no shadow map worth drawing.
    public var isUp: Bool { position.isUp }
}

/// The sun over Frankfurt, from real ephemeris (`SolarPosition`, BEM-D03).
///
/// This used to be a parabola with a hardcoded peak of 58° at 13:20 and a
/// fixed day of 05:30–21:30. That is roughly right for one week in May and
/// wrong every other week of the year: the real peak ranges from 16.4° at the
/// winter solstice to 63.3° at the summer one, and Frankfurt's sunrise moves
/// by more than three hours across the year. A shadow map drawn on the
/// parabola would have been confidently wrong every day it was used.
public enum SunModel {
    /// Römerberg. The shadow map is a Frankfurt feature (ADR 0003), and the
    /// sun moves too little across the Rhein-Main region to be worth a
    /// per-user coordinate here — under a tenth of a degree of elevation
    /// between Wiesbaden and Hanau.
    public static let frankfurt = CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6821)

    /// The scrubber's clock range, not the sun's day — those are different
    /// things and only one of them is constant. 05:00 to 22:00 contains every
    /// minute of daylight Frankfurt gets: the earliest sunrise is 05:16 and
    /// the latest sunset 21:39, both at the summer solstice.
    public static let dayStart: Double = 300  // 05:00
    public static let dayEnd: Double = 1320  // 22:00

    /// The highest the sun ever climbs over Frankfurt: 63.3° at solar noon on
    /// the summer solstice, rounded up so that nothing normalised against it
    /// can exceed 1. A real number about a real place, unlike the 58° it
    /// replaces.
    public static let peakElevation: Double = 63.4

    /// Sun at a wall-clock time on a given day.
    ///
    /// `minutes` is local clock time, which is what the scrubber speaks;
    /// `calendar` supplies the time zone, so summer time is handled by
    /// Foundation rather than by an offset this file would have to remember to
    /// apply.
    public static func sample(
        atMinutes minutes: Double,
        on day: Date = .now,
        at coordinate: CLLocationCoordinate2D = SunModel.frankfurt,
        calendar: Calendar = .current
    ) -> SunSample {
        let position = position(atMinutes: minutes, on: day, at: coordinate, calendar: calendar)
        return SunSample(
            elevation: max(0, Int(position.elevation.rounded())),
            // Shadows point away from the sun, so an eastern sun throws them
            // west. Azimuth is measured clockwise from north, which puts the
            // whole eastern half below 180°.
            westward: position.azimuth < 180,
            position: position
        )
    }

    public static func position(
        atMinutes minutes: Double,
        on day: Date = .now,
        at coordinate: CLLocationCoordinate2D = SunModel.frankfurt,
        calendar: Calendar = .current
    ) -> SolarPosition {
        let midnight = calendar.startOfDay(for: day)
        // Adding seconds to an absolute instant rather than rebuilding date
        // components: on the two days a year when the clocks move, a local
        // wall time can be missing or ambiguous, and this way the scrubber
        // still sweeps a continuous 17 hours instead of jumping or stalling.
        let instant = midnight.addingTimeInterval(minutes * 60)
        return SolarPosition.compute(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: instant
        )
    }

    /// Solar noon in local clock minutes — when the sun actually crosses the
    /// meridian, which is 13:27 in June and 12:23 in December, never the
    /// 13:20 the old model asserted year-round.
    public static func solarNoonMinutes(
        on day: Date = .now,
        at coordinate: CLLocationCoordinate2D = SunModel.frankfurt,
        calendar: Calendar = .current
    ) -> Double {
        // Coarse sweep then a one-minute refinement: the elevation curve has a
        // single maximum per day, so hill-climbing it cannot land on the wrong
        // peak, and this needs no separate equation-of-time inversion.
        var best = (minutes: dayStart, elevation: -Double.infinity)
        for step in stride(from: 0.0, through: 1440, by: 10) {
            let elevation = position(atMinutes: step, on: day, at: coordinate, calendar: calendar)
                .geometricElevation
            if elevation > best.elevation { best = (step, elevation) }
        }
        for step in stride(from: best.minutes - 10, through: best.minutes + 10, by: 1) {
            let elevation = position(atMinutes: step, on: day, at: coordinate, calendar: calendar)
                .geometricElevation
            if elevation > best.elevation { best = (step, elevation) }
        }
        return best.minutes
    }

    public static func clockLabel(minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return String(format: "%02d:%02d", h, m)
    }

    /// Now, clamped into the scrubber's range.
    public static func nowMinutes(_ date: Date = .now, calendar: Calendar = .current) -> Double {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let mins = Double((parts.hour ?? 12) * 60 + (parts.minute ?? 0))
        return min(max(mins, dayStart), dayEnd)
    }
}
