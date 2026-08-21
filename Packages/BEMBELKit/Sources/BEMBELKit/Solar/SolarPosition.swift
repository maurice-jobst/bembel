import Foundation

/// Where the sun is, from the NOAA solar-position equations.
///
/// Pure arithmetic: no network, no ephemeris file, no third-party package
/// (repo rule). Everything is derived from the instant and the coordinate, so
/// the same inputs give the same answer on any device in any year.
///
/// Accurate to well under 0.1° for the years this app will plausibly run in.
/// NOAA states its own approximations hold to about ±0.5 minutes of sunrise
/// time between 1800 and 2100; the shadow map needs far less than that.
public struct SolarPosition: Sendable, Equatable {
    /// Degrees above the horizon, corrected for atmospheric refraction — the
    /// sun you would see. Negative when it is below the horizon; the value
    /// keeps going down rather than clamping, because "how far below" is what
    /// tells dusk from midnight.
    public let elevation: Double
    /// Degrees above the horizon ignoring refraction — where the sun
    /// geometrically is. Differs from `elevation` by half a degree at the
    /// horizon and by a hundredth of one overhead.
    public let geometricElevation: Double
    /// Compass bearing of the sun, degrees clockwise from true north.
    /// 90 is due east, 180 due south, 270 due west.
    public let azimuth: Double

    public init(elevation: Double, geometricElevation: Double, azimuth: Double) {
        self.elevation = elevation
        self.geometricElevation = geometricElevation
        self.azimuth = azimuth
    }

    /// True while any part of the disc is up. The −0.833° is the standard
    /// sunrise definition: half a degree of solar radius plus the refraction
    /// that lifts the disc into view before it geometrically clears the
    /// horizon.
    public var isUp: Bool { elevation > -0.833 }

    /// The bearing a shadow is cast towards — directly away from the sun.
    public var shadowBearing: Double { (azimuth + 180).truncatingRemainder(dividingBy: 360) }
}

// MARK: - The algorithm

extension SolarPosition {
    /// Sun position for one instant at one place.
    ///
    /// `date` is an absolute instant, so the whole calculation runs in UTC and
    /// never touches a time zone. Time-zone handling is where solar code
    /// usually goes wrong — an offset applied twice, or applied to a
    /// standard-time zone during summer time — and the honest way to avoid it
    /// is to have no offset to apply.
    public static func compute(latitude: Double, longitude: Double, date: Date) -> SolarPosition {
        let julianCentury = Self.julianCentury(date)

        // Geometric mean longitude and anomaly of the sun, degrees.
        let meanLongitude = wrap360(
            280.46646 + julianCentury * (36000.76983 + julianCentury * 0.0003032)
        )
        let meanAnomaly = 357.52911 + julianCentury * (35999.05029 - 0.0001537 * julianCentury)
        let eccentricity = 0.016708634 - julianCentury * (0.000042037 + 0.0000001267 * julianCentury)

        // Equation of the centre: the correction from a circular orbit to the
        // real elliptical one.
        let centre =
            sin(radians(meanAnomaly)) * (1.914602 - julianCentury * (0.004817 + 0.000014 * julianCentury))
            + sin(radians(2 * meanAnomaly)) * (0.019993 - 0.000101 * julianCentury)
            + sin(radians(3 * meanAnomaly)) * 0.000289

        let trueLongitude = meanLongitude + centre
        // Apparent longitude folds in nutation and aberration.
        let omega = 125.04 - 1934.136 * julianCentury
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sin(radians(omega))

        let meanObliquity =
            23
            + (26
                + (21.448
                    - julianCentury
                    * (46.815 + julianCentury * (0.00059 - julianCentury * 0.001813))) / 60)
            / 60
        let obliquity = meanObliquity + 0.00256 * cos(radians(omega))

        let declination = degrees(
            asin(sin(radians(obliquity)) * sin(radians(apparentLongitude)))
        )

        // Equation of time, in minutes: how far true solar time runs ahead of
        // or behind mean clock time on this date.
        let y = pow(tan(radians(obliquity / 2)), 2)
        let equationOfTime =
            4
            * degrees(
                y * sin(radians(2 * meanLongitude))
                    - 2 * eccentricity * sin(radians(meanAnomaly))
                    + 4 * eccentricity * y * sin(radians(meanAnomaly)) * cos(radians(2 * meanLongitude))
                    - 0.5 * y * y * sin(radians(4 * meanLongitude))
                    - 1.25 * eccentricity * eccentricity * sin(radians(2 * meanAnomaly))
            )

        // True solar time, minutes past solar midnight. Working from UTC means
        // the longitude term is the only place east/west enters.
        let utcMinutes = Self.minutesPastUTCMidnight(date)
        let trueSolarTime = (utcMinutes + equationOfTime + 4 * longitude).truncatingRemainder(
            dividingBy: 1440
        )
        // Hour angle: zero when the sun crosses the meridian, negative before.
        var hourAngle = trueSolarTime / 4 - 180
        if hourAngle < -180 { hourAngle += 360 }

        let latitudeRadians = radians(latitude)
        let declinationRadians = radians(declination)
        let cosZenith =
            sin(latitudeRadians) * sin(declinationRadians)
            + cos(latitudeRadians) * cos(declinationRadians) * cos(radians(hourAngle))
        let zenith = degrees(acos(min(1, max(-1, cosZenith))))
        let geometricElevation = 90 - zenith

        // Azimuth from the spherical triangle. Both branches are needed: acos
        // only ever answers 0…180, so the morning and afternoon halves of the
        // sky map onto the same value and the hour angle is what separates
        // them.
        let denominator = cos(latitudeRadians) * sin(radians(zenith))
        let azimuth: Double
        if abs(denominator) < 1e-9 {
            // The sun is exactly overhead or the observer is at a pole; the
            // bearing is undefined rather than wrong, and due south is the
            // least surprising thing to say in the northern hemisphere.
            azimuth = latitude >= 0 ? 180 : 0
        } else {
            let cosAzimuth =
                (sin(latitudeRadians) * cos(radians(zenith)) - sin(declinationRadians)) / denominator
            let base = degrees(acos(min(1, max(-1, cosAzimuth))))
            azimuth = hourAngle > 0 ? wrap360(base + 180) : wrap360(540 - base)
        }

        return SolarPosition(
            elevation: geometricElevation + refraction(geometricElevation),
            geometricElevation: geometricElevation,
            azimuth: azimuth
        )
    }

    /// How much the atmosphere lifts the apparent sun above its true position.
    /// Degrees; NOAA's piecewise fit, which is in arcseconds until the last
    /// step. Largest at the horizon — the sun you see setting has already set.
    static func refraction(_ geometricElevation: Double) -> Double {
        if geometricElevation > 85 { return 0 }
        let tangent = tan(radians(geometricElevation))
        let arcseconds: Double
        if geometricElevation > 5 {
            arcseconds = 58.1 / tangent - 0.07 / pow(tangent, 3) + 0.000086 / pow(tangent, 5)
        } else if geometricElevation > -0.575 {
            arcseconds =
                1735
                + geometricElevation
                * (-518.2
                    + geometricElevation
                    * (103.4 + geometricElevation * (-12.79 + geometricElevation * 0.711)))
        } else {
            arcseconds = -20.772 / tangent
        }
        return arcseconds / 3600
    }

    /// Centuries since J2000.0, the time variable every term above is a
    /// polynomial in.
    static func julianCentury(_ date: Date) -> Double {
        // Unix epoch is JD 2440587.5, and a Julian century is 36525 days.
        let julianDay = date.timeIntervalSince1970 / 86400 + 2_440_587.5
        return (julianDay - 2_451_545.0) / 36525
    }

    static func minutesPastUTCMidnight(_ date: Date) -> Double {
        let seconds = date.timeIntervalSince1970
        let dayFraction = seconds - (seconds / 86400).rounded(.down) * 86400
        return dayFraction / 60
    }

    static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    static func wrap360(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}
