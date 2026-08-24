import Foundation

/// A lat/lon box, the way a map wants one.
public struct RadarBounds: Sendable, Equatable {
    public let south: Double
    public let west: Double
    public let north: Double
    public let east: Double

    public init(south: Double, west: Double, north: Double, east: Double) {
        self.south = south
        self.west = west
        self.north = north
        self.east = east
    }

    /// What the Regenradar draws. Wider than the screen's opening region so
    /// panning a little does not run off the edge of the data, and clipped to
    /// Rhein-Main rather than the national composite because 1100×1200 cells of
    /// Germany is 10 MB per frame and the app is regional.
    public static let rheinMain = RadarBounds(south: 49.70, west: 8.10, north: 50.50, east: 9.20)

    public var latitudeSpan: Double { north - south }
    public var longitudeSpan: Double { east - west }
}

/// One radar frame, resampled onto `RadarBounds` and ready to draw as an image.
///
/// The resampling is the point. RADOLAN is polar stereographic, so its rows do
/// not run east–west: at Frankfurt the grid is rotated about 1.3° from true
/// north, which is nearly a kilometre of displacement across a box this size.
/// Stretching the raw grid into a lat/lon rectangle would put rain on the wrong
/// side of the river, so the frame is built the other way round — every output
/// pixel asks the projection which cell covers it.
public struct RadarFrame: Sendable, Identifiable, Equatable {
    /// Minutes ahead of the composite's measurement time. 0 is "now".
    public let minute: Int
    public let width: Int
    public let height: Int
    /// Row-major from the **north-west** corner, which is how an image is laid
    /// out — the opposite of the composite's south-first rows.
    ///
    /// Millimetres in the product's five-minute interval, `NaN` where the radar
    /// cannot see. A flat `[Float]` rather than `[Double?]`: at 25 frames this
    /// is the difference between 1.6 MB and roughly 6 MB for a value nobody
    /// reads except a colour ramp.
    public let millimetres: [Float]

    public var id: Int { minute }

    public init(minute: Int, width: Int, height: Int, millimetres: [Float]) {
        self.minute = minute
        self.width = width
        self.height = height
        self.millimetres = millimetres
    }

    /// `nil` outside the frame or where the radar has no reading.
    public func value(x: Int, y: Int) -> Float? {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
        let value = millimetres[y * width + x]
        return value.isNaN ? nil : value
    }

    /// True when every cell is no-data. A frame the radar could not see at all
    /// must not be drawn as "no rain".
    public var isEmpty: Bool {
        millimetres.allSatisfy(\.isNaN)
    }
}

/// How the drawn frames are sized. One output pixel is roughly 600 m, which
/// oversamples RADOLAN's 1 km cells about 1.7×. Nearest-neighbour sampling
/// keeps the cell edges visible instead of smoothing them: the data really is
/// square kilometres, and a soft gradient would claim a precision the radar
/// does not have.
public enum RadarRaster {
    public static let width = 128
    public static let height = 128

    /// Millimetres per five-minute step → millimetres per hour, the unit the
    /// legend has always claimed.
    public static let stepsPerHour: Float = 12

    /// Lower bound of each drawn intensity band, in **millimetres per hour**.
    ///
    /// Here rather than next to the colours because "which band is this" is a
    /// claim about the data and the app has to be able to test it; which blue
    /// that band gets is a claim about the design system and lives with it.
    public static let bands: [Float] = [0.5, 1, 2, 5, 10, 20]

    /// Under the first band the radar is seeing something, but not something a
    /// person would call rain. Drawn as nothing rather than as a faint wash
    /// that reads like drizzle.
    public static var visibleFloor: Float { bands[0] }

    /// Band index for a rate in mm/h, or `nil` when it is under the floor.
    public static func band(millimetresPerHour rate: Float) -> Int? {
        guard rate >= visibleFloor, !rate.isNaN else { return nil }
        return bands.lastIndex { rate >= $0 }
    }

    /// Band index for a raw frame value, which is millimetres per five-minute
    /// step. The conversion is the step everyone forgets: 0.1 mm per step is
    /// 1.2 mm/h, not 0.1.
    public static func band(millimetresPerStep value: Float) -> Int? {
        guard !value.isNaN else { return nil }
        return band(millimetresPerHour: value * stepsPerHour)
    }
}
