import CoreLocation
import Foundation
import Testing

@testable import BEMBELKit

private func instant(_ iso: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: iso))
}

private let frankfurt = SunModel.frankfurt

private func berlinCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}

/// The sun is one of the few things an app can check against the universe
/// rather than against itself.
///
/// Two independent kinds of evidence here, because a table of numbers produced
/// by the implementation under test proves only that it is consistent:
///
///  1. **Derivable facts.** At solar noon the sun's elevation is
///     `90° − latitude + declination`, and at an equinox the declination is
///     zero and the sun rises due east everywhere on Earth. Those follow from
///     the geometry, not from any code, and they pin the answer to within a
///     few hundredths of a degree.
///  2. **A second algorithm.** The reference table below was generated from
///     the Michalsky (1988) / Astronomical Almanac series — a different
///     formulation from the NOAA polynomials this implements. Agreement
///     between two derivations is evidence; agreement with yourself is not.
@Suite("Solar position")
struct SolarPositionTests {
    /// place, latitude, longitude, instant, elevation, azimuth.
    /// Elevations are geometric — refraction models differ between sources and
    /// mixing them would test the fudge, not the astronomy.
    static let reference: [(String, Double, Double, String, Double, Double)] = [
        ("Frankfurt", 50.1109, 8.6821, "2026-03-20T12:00:00Z", 39.5082, 188.8493),
        ("Frankfurt", 50.1109, 8.6821, "2026-06-21T11:00:00Z", 62.8049, 166.3058),
        ("Frankfurt", 50.1109, 8.6821, "2026-12-21T11:30:00Z", 16.4397, 181.5968),
        ("Frankfurt", 50.1109, 8.6821, "2026-08-19T16:45:00Z", 16.6469, 269.8528),
        ("Reykjavík", 64.1466, -21.9426, "2026-03-20T12:00:00Z", 23.4706, 153.8905),
        ("Reykjavík", 64.1466, -21.9426, "2026-06-21T11:00:00Z", 42.5134, 130.8905),
        ("Reykjavík", 64.1466, -21.9426, "2026-12-21T11:30:00Z", -0.4474, 153.6271),
        ("Reykjavík", 64.1466, -21.9426, "2026-08-19T16:45:00Z", 28.6112, 236.2460),
        ("Nairobi", -1.2921, 36.8219, "2026-03-20T12:00:00Z", 55.0246, 271.7718),
        ("Nairobi", -1.2921, 36.8219, "2026-06-21T11:00:00Z", 57.6996, 321.2737),
        ("Nairobi", -1.2921, 36.8219, "2026-12-21T11:30:00Z", 53.5989, 230.2272),
        ("Nairobi", -1.2921, 36.8219, "2026-08-19T16:45:00Z", -17.0399, 282.7909),
        ("Sydney", -33.8688, 151.2093, "2026-03-20T12:00:00Z", -45.5489, 226.7273),
        ("Sydney", -33.8688, 151.2093, "2026-06-21T11:00:00Z", -50.1195, 266.7753),
        ("Sydney", -33.8688, 151.2093, "2026-12-21T11:30:00Z", -23.3426, 215.7750),
        ("Sydney", -33.8688, 151.2093, "2026-08-19T16:45:00Z", -46.7110, 109.2207),
        ("Quito", -0.1807, -78.4678, "2026-03-20T12:00:00Z", 9.6666, 90.0133),
        ("Quito", -0.1807, -78.4678, "2026-06-21T11:00:00Z", -3.6701, 66.5264),
        ("Quito", -0.1807, -78.4678, "2026-12-21T11:30:00Z", 4.2179, 113.4875),
        ("Quito", -0.1807, -78.4678, "2026-08-19T16:45:00Z", 74.8919, 31.9011),
    ]

    @Test("Twenty place/time pairs match a second algorithm inside 0.02°")
    func matchesIndependentAlgorithm() throws {
        // The ticket asks for 0.1°. These agree an order of magnitude better,
        // across both hemispheres, the equator, the Arctic edge, all four
        // seasons and the sun both up and well down.
        for (place, latitude, longitude, stamp, elevation, azimuth) in Self.reference {
            let position = SolarPosition.compute(
                latitude: latitude, longitude: longitude, date: try instant(stamp)
            )
            #expect(
                abs(position.geometricElevation - elevation) < 0.02,
                "\(place) \(stamp): elevation \(position.geometricElevation) vs \(elevation)"
            )
            let delta = abs(position.azimuth - azimuth)
            #expect(
                min(delta, 360 - delta) < 0.02,
                "\(place) \(stamp): azimuth \(position.azimuth) vs \(azimuth)"
            )
        }
    }

    @Test("Solar noon elevation is 90° − latitude + declination, by geometry")
    func noonElevationFollowsFromLatitude() throws {
        // Nothing here comes from the implementation: the declination extremes
        // are the Earth's axial tilt, and the rest is a right-angled triangle.
        let cases: [(day: String, declination: Double)] = [
            ("2026-03-20", 0),  // equinox
            ("2026-06-21", 23.44),  // solstice, sun over the Tropic of Cancer
            ("2026-12-21", -23.44),  // solstice, over the Tropic of Capricorn
        ]
        let calendar = berlinCalendar()
        for (day, declination) in cases {
            let date = try instant("\(day)T12:00:00Z")
            let noon = SunModel.solarNoonMinutes(on: date, calendar: calendar)
            let peak = SunModel.position(atMinutes: noon, on: date, calendar: calendar)
            let expected = 90 - frankfurt.latitude + declination
            #expect(
                abs(peak.geometricElevation - expected) < 0.4,
                "\(day): noon elevation \(peak.geometricElevation), geometry says \(expected)"
            )
        }
    }

    @Test("At an equinox the sun rises due east — everywhere")
    func equinoxSunriseIsDueEast() throws {
        // True of every latitude, which is what makes it a real check rather
        // than a Frankfurt-shaped one.
        for latitude in [50.1109, 0.0, -33.8688, 64.1466] {
            var best: (delta: Double, azimuth: Double) = (.infinity, 0)
            for minute in stride(from: 0.0, through: 1440, by: 1) {
                let position = SolarPosition.compute(
                    latitude: latitude,
                    longitude: 0,
                    date: try instant("2026-03-20T00:00:00Z").addingTimeInterval(minute * 60)
                )
                // The moment the disc's centre crosses the true horizon.
                if abs(position.geometricElevation) < best.delta {
                    best = (abs(position.geometricElevation), position.azimuth)
                }
            }
            #expect(
                abs(best.azimuth - 90) < 1.0 || abs(best.azimuth - 270) < 1.0,
                "latitude \(latitude): horizon crossing at azimuth \(best.azimuth)"
            )
        }
    }

    @Test("Refraction lifts the sun at the horizon and vanishes overhead")
    func refractionShrinksWithAltitude() {
        // Roughly half a degree at the horizon — which is why the sun you see
        // setting has geometrically already set.
        #expect(abs(SolarPosition.refraction(0) - 0.48) < 0.05)
        #expect(SolarPosition.refraction(0) > SolarPosition.refraction(10))
        #expect(SolarPosition.refraction(10) > SolarPosition.refraction(45))
        #expect(SolarPosition.refraction(90) == 0)
    }

    @Test("Shadows fall directly away from the sun")
    func shadowBearingIsOpposite() throws {
        let morning = SolarPosition.compute(
            latitude: frankfurt.latitude, longitude: frankfurt.longitude,
            date: try instant("2026-06-21T05:00:00Z")
        )
        #expect(abs(morning.shadowBearing - (morning.azimuth + 180)) < 0.001)
        let evening = SolarPosition(elevation: 10, geometricElevation: 10, azimuth: 270)
        #expect(evening.shadowBearing == 90)
        let south = SolarPosition(elevation: 60, geometricElevation: 60, azimuth: 200)
        #expect(south.shadowBearing == 20)
    }

    @Test("Sunrise counts the disc's edge, not its centre")
    func upIncludesTheDisc() {
        // −0.833° is half the solar diameter plus the refraction that lifts it
        // into view. Testing `> 0` instead would call sunrise several minutes
        // late every day of the year.
        #expect(SolarPosition(elevation: -0.5, geometricElevation: -0.5, azimuth: 90).isUp)
        #expect(!SolarPosition(elevation: -1, geometricElevation: -1, azimuth: 90).isUp)
    }
}

@Suite("Sun model")
struct SunModelTests {
    @Test("The peak constant is a fact about Frankfurt, and nothing exceeds it")
    func peakElevationHoldsAllYear() throws {
        // Sampled every third day for a year: the normaliser the shadow
        // overlay divides by must never be overshot, or the wash inverts.
        let calendar = berlinCalendar()
        let start = try instant("2026-01-01T12:00:00Z")
        var highest = 0.0
        for day in stride(from: 0, through: 364, by: 3) {
            let date = start.addingTimeInterval(Double(day) * 86400)
            let noon = SunModel.solarNoonMinutes(on: date, calendar: calendar)
            highest = max(highest, SunModel.position(atMinutes: noon, on: date, calendar: calendar).elevation)
        }
        #expect(highest <= SunModel.peakElevation)
        // And it is not slack: the constant sits just above the real maximum.
        #expect(highest > SunModel.peakElevation - 0.5)
    }

    @Test("Solar noon moves across the year — it is not a constant")
    func solarNoonMoves() throws {
        // The old model asserted 13:20 every day of the year. The real spread
        // is over an hour, most of it summer time and the rest the equation of
        // time.
        let calendar = berlinCalendar()
        let june = SunModel.solarNoonMinutes(on: try instant("2026-06-21T12:00:00Z"), calendar: calendar)
        let december = SunModel.solarNoonMinutes(
            on: try instant("2026-12-21T12:00:00Z"), calendar: calendar
        )
        #expect(abs(june - (13 * 60 + 27)) <= 2)
        #expect(abs(december - (12 * 60 + 23)) <= 2)
        #expect(june - december > 55)
    }

    @Test("The scrubber's range contains every minute of Frankfurt daylight")
    func scrubberRangeCoversTheYear() throws {
        // Earliest sunrise 05:16, latest sunset 21:39, both at the summer
        // solstice. The old 05:30–21:30 range clipped both ends.
        let calendar = berlinCalendar()
        let solstice = try instant("2026-06-21T12:00:00Z")
        #expect(!SunModel.sample(atMinutes: SunModel.dayStart, on: solstice, calendar: calendar).isUp)
        #expect(!SunModel.sample(atMinutes: SunModel.dayEnd, on: solstice, calendar: calendar).isUp)
        #expect(SunModel.sample(atMinutes: 5 * 60 + 20, on: solstice, calendar: calendar).isUp)
        #expect(SunModel.sample(atMinutes: 21 * 60 + 35, on: solstice, calendar: calendar).isUp)
    }

    @Test("Winter noon is low, summer noon is high, and the model knows which")
    func seasonsDiffer() throws {
        let calendar = berlinCalendar()
        let june = SunModel.sample(atMinutes: 13 * 60 + 27, on: try instant("2026-06-21T12:00:00Z"), calendar: calendar)
        let december = SunModel.sample(
            atMinutes: 12 * 60 + 23, on: try instant("2026-12-21T12:00:00Z"), calendar: calendar
        )
        #expect(june.elevation == 63)
        // 16, geometrically — but `SunSample.elevation` is the sun you can
        // see, and half a tenth of a degree of refraction is enough to carry
        // 16.45 over the rounding line. Worth pinning: it is exactly the kind
        // of off-by-one that looks like a bug and is not.
        #expect(december.elevation == 17)
        #expect(
            abs(december.position.geometricElevation - 16.45) < 0.05,
            "geometric winter noon \(december.position.geometricElevation)"
        )
        // The parabola this replaced would have said 58 on both days.
    }

    @Test("Below the horizon reads as zero, not as a negative bar")
    func elevationIsFlooredForTheUI() throws {
        let calendar = berlinCalendar()
        let night = SunModel.sample(atMinutes: 5 * 60, on: try instant("2026-12-21T12:00:00Z"), calendar: calendar)
        #expect(night.elevation == 0)
        #expect(!night.isUp)
        // Floored for the bar, intact underneath.
        #expect(night.position.elevation < -10)
    }

    @Test("Shadows point west in the morning and east in the afternoon")
    func shadowDirectionFlipsAtSolarNoon() throws {
        let calendar = berlinCalendar()
        let day = try instant("2026-08-19T12:00:00Z")
        let noon = SunModel.solarNoonMinutes(on: day, calendar: calendar)
        #expect(SunModel.sample(atMinutes: noon - 120, on: day, calendar: calendar).westward)
        #expect(!SunModel.sample(atMinutes: noon + 120, on: day, calendar: calendar).westward)
    }

    @Test func clockLabelPadsZeros() {
        #expect(SunModel.clockLabel(minutes: 300) == "05:00")
        #expect(SunModel.clockLabel(minutes: 885) == "14:45")
        #expect(SunModel.clockLabel(minutes: 1320) == "22:00")
    }

    @Test("Now is clamped into the scrubber's range")
    func nowClamped() {
        let calendar = berlinCalendar()
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 0, minute: 5))!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 12, minute: 0))!
        #expect(SunModel.nowMinutes(midnight, calendar: calendar) == SunModel.dayStart)
        #expect(SunModel.nowMinutes(noon, calendar: calendar) == 720)
    }
}

/// The curve the scrubber draws. It replaced a fixed bezier that was the same
/// shape on every day of the year (ADR 0010), so the tests that matter are the
/// ones a fixed shape would fail.
@Suite("Sun elevation curve")
struct SunCurveTests {
    private func curve(_ iso: String) throws -> [SunModel.CurvePoint] {
        try SunModel.elevationCurve(on: instant(iso), calendar: berlinCalendar())
    }

    @Test("Spans the scrubber's range end to end")
    func spansRange() throws {
        let points = try curve("2026-06-21T12:00:00Z")
        #expect(points.count == 96)
        #expect(points.first?.fraction == 0)
        #expect(points.last?.fraction == 1)
    }

    @Test("Weights stay inside 0…1")
    func normalised() throws {
        for day in ["2026-06-21T12:00:00Z", "2026-12-21T12:00:00Z", "2026-03-20T12:00:00Z"] {
            for point in try curve(day) {
                #expect(point.weight >= 0)
                #expect(point.weight <= 1)
            }
        }
    }

    /// The whole reason the bezier had to go: in June the sun reaches 63°, in
    /// December 16°, and one hand-drawn hump cannot be both.
    @Test("Summer towers over winter")
    func seasonalAmplitude() throws {
        let summer = try #require(curve("2026-06-21T12:00:00Z").map(\.weight).max())
        let winter = try #require(curve("2026-12-21T12:00:00Z").map(\.weight).max())
        #expect(summer > 0.97)
        #expect(winter < 0.3)
        #expect(summer > winter * 3)
    }

    /// Elevation has exactly one maximum per day, so the drawn curve must rise
    /// then fall — never wobble. A single direction change is the assertion.
    @Test("Rises once and falls once")
    func unimodal() throws {
        let weights = try curve("2026-09-15T12:00:00Z").map(\.weight)
        var reversals = 0
        var rising = true
        for (previous, next) in zip(weights, weights.dropFirst()) where next != previous {
            let nowRising = next > previous
            if nowRising != rising {
                reversals += 1
                rising = nowRising
            }
        }
        // One reversal at the peak. The run starts flat at zero before sunrise,
        // which is why the first comparison is skipped by `next != previous`.
        #expect(reversals == 1)
    }

    /// Winter mornings and evenings sit below the horizon inside the 05:00–22:00
    /// clock range, and `SunSample` floors those at zero rather than drawing a
    /// curve underground.
    @Test("Night is flat, not negative")
    func nightIsFloored() throws {
        let winter = try curve("2026-12-21T12:00:00Z")
        #expect(winter.first?.weight == 0)
        #expect(winter.last?.weight == 0)
    }

    @Test("Sample count is clamped to something drawable")
    func clampedSamples() {
        #expect(SunModel.elevationCurve(samples: 0).count == 2)
        #expect(SunModel.elevationCurve(samples: 1).count == 2)
    }
}
