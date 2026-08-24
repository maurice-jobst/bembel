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

    /// One point of the day's elevation curve, normalised for drawing.
    ///
    /// `weight` is elevation over `peakElevation`, so 1.0 is the highest the
    /// sun ever gets over Frankfurt, not the highest it gets today — a June
    /// curve towers over a December one, which is the entire point of drawing
    /// it from the ephemeris instead of from a fixed bezier.
    public struct CurvePoint: Sendable, Equatable {
        /// 0…1 across the scrubber's clock range.
        public let fraction: Double
        /// 0…1 of `peakElevation`, floored at zero below the horizon.
        public let weight: Double

        public init(fraction: Double, weight: Double) {
            self.fraction = fraction
            self.weight = weight
        }
    }

    /// The day's sun-elevation curve across the scrubber's clock range.
    ///
    /// The screen drew a fixed bezier until ADR 0010: one hand-drawn hump,
    /// identical on every day of the year, sitting under a scrubber whose
    /// readout came from the real ephemeris. On a December afternoon the dot
    /// rode high on a curve while the number beside it said 8°. This returns
    /// what the sun actually did.
    ///
    /// `samples` is clamped to at least two so the caller always gets both
    /// ends of the range.
    public static func elevationCurve(
        on day: Date = .now,
        at coordinate: CLLocationCoordinate2D = SunModel.frankfurt,
        calendar: Calendar = .current,
        samples: Int = 96
    ) -> [CurvePoint] {
        let count = max(2, samples)
        return (0..<count).map { index in
            let fraction = Double(index) / Double(count - 1)
            let minutes = dayStart + fraction * (dayEnd - dayStart)
            let elevation = position(atMinutes: minutes, on: day, at: coordinate, calendar: calendar).elevation
            return CurvePoint(
                fraction: fraction,
                weight: min(1, max(0, elevation / peakElevation))
            )
        }
    }

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

    /// The standard sunrise/sunset criterion, applied to the sun's **true**
    /// (unrefracted) elevation: 0.267° of solar radius plus 0.567° of
    /// atmospheric refraction. `SolarPosition.isUp` tests against this, and so
    /// does `daylight` — named once so the screen that discloses the
    /// convention and the code that applies it cannot drift apart.
    public static let horizonElevation = -0.833

    /// Sunrise and sunset in local clock minutes, or `nil` for a day the sun
    /// does not cross the horizon at all.
    ///
    /// `nil` is a real answer, not a failure: above the Arctic circle there are
    /// days with no sunrise and days with no sunset, and a number there would
    /// be a lie rather than an approximation. Frankfurt never sees one, which
    /// is exactly why it would go unnoticed.
    ///
    /// Coarse sweep then bisection, like `solarNoonMinutes` — the elevation
    /// crosses the horizon at most once each way per day, so there is no
    /// wrong crossing to land on, and this needs no separate inversion of the
    /// equation of time.
    public static func daylight(
        on day: Date = .now,
        at coordinate: CLLocationCoordinate2D = SunModel.frankfurt,
        calendar: Calendar = .current
    ) -> (sunrise: Double, sunset: Double)? {
        // Geometric, not refracted: see `horizonElevation`. Sweeping the
        // refracted elevation against the same threshold double-counts
        // refraction and stretches the day by about four minutes.
        func elevation(_ minutes: Double) -> Double {
            position(atMinutes: minutes, on: day, at: coordinate, calendar: calendar)
                .geometricElevation
        }

        var crossings: [(minutes: Double, rising: Bool)] = []
        var previous = elevation(0)
        for step in stride(from: 5.0, through: 1440, by: 5) {
            let current = elevation(step)
            let wasUp = previous > horizonElevation
            let isUp = current > horizonElevation
            if wasUp != isUp {
                crossings.append((bisect(from: step - 5, to: step, rising: isUp, elevation: elevation), isUp))
            }
            previous = current
        }

        guard
            let sunrise = crossings.first(where: { $0.rising })?.minutes,
            let sunset = crossings.last(where: { !$0.rising })?.minutes,
            sunrise < sunset
        else { return nil }
        return (sunrise, sunset)
    }

    /// Where the elevation crosses the horizon between two minutes that
    /// straddle it, to a tenth of a minute.
    private static func bisect(
        from low: Double, to high: Double, rising: Bool, elevation: (Double) -> Double
    ) -> Double {
        var low = low
        var high = high
        while high - low > 0.1 {
            let middle = (low + high) / 2
            let isUp = elevation(middle) > horizonElevation
            if isUp == rising {
                high = middle
            } else {
                low = middle
            }
        }
        return (low + high) / 2
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
