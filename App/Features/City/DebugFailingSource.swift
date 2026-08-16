#if DEBUG

    import BEMBELKit
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
    /// Recognised names: `temperature`, `gauge`, `air`, `warnings`, or `all`.
    /// DEBUG only — it does not exist in a release build.
    struct DebugFailingSource:
        TemperatureProviding, GaugeProviding, AirQualityProviding, CityWarningProviding
    {
        struct Injected: LocalizedError {
            var errorDescription: String? { "Debug: source forced to fail" }
        }

        static let names = ["temperature", "gauge", "air", "warnings"]

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
        func airQuality() async throws -> AirQuality { throw Injected() }
        func warnings() async throws -> [CityWarning] { throw Injected() }
    }

#endif
