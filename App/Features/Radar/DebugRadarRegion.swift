#if DEBUG

    import BEMBELKit
    import CoreLocation
    import Foundation

    /// Points the radar at somewhere other than Rhein-Main, so the overlay can
    /// be looked at on a day when it is not raining here.
    ///
    /// Rain over Frankfurt is the state this feature exists for and the state
    /// you cannot summon. Without this, "the overlay draws, and draws in the
    /// right place" is unverifiable for weeks at a time — and an overlay whose
    /// projection is wrong looks perfectly fine over an empty map. The
    /// coastline of a rainy region is the check: rain stops at the water.
    ///
    ///     xcrun simctl launch <device> de.mauricejobst.bembel \
    ///       -BEMRadarRegion "53.6,12.2,54.8,14.0"
    ///
    /// South, west, north, east. DEBUG only — it does not exist in a release
    /// build.
    enum DebugRadarRegion {
        static let bounds: RadarBounds? = {
            guard let raw = UserDefaults.standard.string(forKey: "BEMRadarRegion") else { return nil }
            let parts = raw.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 4, parts[0] < parts[2], parts[1] < parts[3] else { return nil }
            return RadarBounds(south: parts[0], west: parts[1], north: parts[2], east: parts[3])
        }()

        /// The centre of that box, so the headline describes the same weather
        /// the map is showing rather than Frankfurt's.
        static var coordinate: CLLocationCoordinate2D? {
            bounds.map {
                CLLocationCoordinate2D(
                    latitude: ($0.south + $0.north) / 2,
                    longitude: ($0.west + $0.east) / 2
                )
            }
        }
    }

#endif
