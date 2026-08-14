import CoreLocation
import Foundation

/// Geography → grid cell for DWD's DE1200 composite.
///
/// RADOLAN uses a polar stereographic projection on a sphere, with the grid's
/// south-west corner pinned to a published lat/lon. Everything below is the
/// projection from DWD's format description; the constants are theirs, not
/// fitted by us. `RadolanGridTests` checks that the corner round-trips to
/// (0, 0) and that Frankfurt lands where the real composite has coverage.
public struct RadolanGrid: Sendable {
    /// Sphere radius RADOLAN is defined on, in kilometres — not WGS84's
    /// ellipsoid, and using the wrong one puts you kilometres off.
    public static let earthRadius = 6370.04
    public static let originLongitude = 10.0
    public static let standardParallel = 60.0

    /// DE1200: 1100 columns × 1200 rows at 1 km, south-west corner as published.
    public static let de1200 = RadolanGrid(
        columns: 1100,
        rows: 1200,
        cornerLatitude: 45.68606067,
        cornerLongitude: 3.566994635,
        cellSize: 1.0
    )

    public let columns: Int
    public let rows: Int
    public let cellSize: Double
    private let originX: Double
    private let originY: Double

    public init(columns: Int, rows: Int, cornerLatitude: Double, cornerLongitude: Double, cellSize: Double) {
        self.columns = columns
        self.rows = rows
        self.cellSize = cellSize
        let corner = Self.project(latitude: cornerLatitude, longitude: cornerLongitude)
        originX = corner.x
        originY = corner.y
    }

    static func project(latitude: Double, longitude: Double) -> (x: Double, y: Double) {
        let phi = latitude * .pi / 180
        let lambda = longitude * .pi / 180
        let phi0 = standardParallel * .pi / 180
        let lambda0 = originLongitude * .pi / 180
        let m = (1 + sin(phi0)) / (1 + sin(phi))
        return (
            x: earthRadius * m * cos(phi) * sin(lambda - lambda0),
            y: -earthRadius * m * cos(phi) * cos(lambda - lambda0)
        )
    }

    /// Grid cell containing this coordinate, or `nil` outside the grid.
    /// Row 0 is the southernmost, matching the byte order in the composite.
    public func cell(for coordinate: CLLocationCoordinate2D) -> (row: Int, column: Int)? {
        let point = Self.project(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let column = Int(((point.x - originX) / cellSize).rounded())
        let row = Int(((point.y - originY) / cellSize).rounded())
        guard (0..<columns).contains(column), (0..<rows).contains(row) else { return nil }
        return (row, column)
    }
}
