#if DEBUG

    import BEMBELKit
    import CoreLocation
    import Foundation

    /// Makes a Stadtzustand source fail on demand, so the designed failure
    /// states can be looked at in a running simulator rather than only in a
    /// preview canvas.
    ///
    /// Waiting for a real outage is not a test plan, and the state that matters
    /// most here — PEGELONLINE down while the NINA warning is still on screen —
    /// is exactly the one that never happens while you are watching.
    ///
    ///     xcrun simctl launch <device> de.mauricejobst.bembel -BEMFailSources gauge
    ///     xcrun simctl launch <device> de.mauricejobst.bembel -BEMFailSources gauge,air
    ///
    /// Recognised names: `temperature`, `gauge`, `air`, `warnings`, `pollen`,
    /// or `all`. DEBUG only — it does not exist in a release build.
    struct DebugFailingSource:
        TemperatureProviding, GaugeProviding, AirQualityProviding, CityWarningProviding, PollenProviding
    {
        struct Injected: LocalizedError {
            var errorDescription: String? { "Debug: source forced to fail" }
        }

        static let names = ["temperature", "gauge", "air", "warnings", "pollen"]

        /// Parsed once. `UserDefaults` picks up `-BEMFailSources x,y` from the
        /// launch arguments, which is how this stays a launch flag rather than
        /// a build to remember to revert.
        static let requested: Set<String> = {
            guard let raw = UserDefaults.standard.string(forKey: "BEMFailSources") else { return [] }
            let requested = Set(
                raw.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces).lowercased()
                }
            )
            return requested.contains("all") ? Set(names) : requested.intersection(names)
        }()

        func temperature() async throws -> TemperatureReading { throw Injected() }
        func reading() async throws -> GaugeReading { throw Injected() }
        func airQuality(near coordinate: CLLocationCoordinate2D?) async throws -> AirQuality {
            throw Injected()
        }
        func warnings() async throws -> [CityWarning] { throw Injected() }
        func pollen() async throws -> PollenReading { throw Injected() }

        /// Written out although there is nothing to drop: with five protocols
        /// each carrying a defaulted `invalidate()`, the compiler finds five
        /// candidate witnesses and calls the conformance ambiguous — one
        /// explicit method settles all five.
        func invalidate() async {}
    }

    /// Points the NINA client at somebody else's Kreis, so a populated warning
    /// card can be looked at without waiting for a disaster in Frankfurt.
    ///
    /// Same problem as `DebugFailingSource`, opposite direction: the state that
    /// matters is the one that is almost never true here. Rhein-Main went a
    /// whole day with zero warnings in force while this was built, and "no
    /// warnings" is the *only* rendering a live run in Frankfurt can show.
    ///
    ///     xcrun simctl launch <device> de.mauricejobst.bembel -BEMWarningAGS 15085000
    ///
    /// Takes an eight-digit AGS; only its Kreis prefix is used, because that is
    /// all NINA's region key can express. DEBUG only.
    enum DebugWarningRegion {
        /// A one-municipality stand-in for rings.json. The provider derives its
        /// Kreis key from this exactly as it would from the real table, so the
        /// path under test is the shipping one.
        static var table: RegionTable? {
            guard
                let raw = UserDefaults.standard.string(forKey: "BEMWarningAGS"),
                let ags = AGS(rawValue: raw.trimmingCharacters(in: .whitespaces))
            else { return nil }
            return RegionTable(municipalities: [.init(ags: ags, name: "Debug", ring: .frankfurt)])
        }
    }

#endif
