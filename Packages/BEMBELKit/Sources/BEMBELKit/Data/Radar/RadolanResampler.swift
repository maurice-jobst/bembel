import CoreLocation
import Foundation

/// Turns a national RADOLAN composite into one map-aligned `RadarFrame` over
/// Rhein-Main.
///
/// Pure and free of MapKit on purpose: the arithmetic that decides *where* rain
/// is drawn is exactly the part that must be testable without a simulator, and
/// the view should receive pixels it can only stretch into a rectangle, not a
/// projection it could get wrong a second time.
enum RadolanResampler {
    /// Nearest-neighbour, output-driven. Every output pixel centre is turned
    /// into a coordinate, projected into the grid, and read — so the rotation
    /// between grid north and true north is handled by construction rather
    /// than approximated away.
    ///
    /// 16384 projections per frame, 25 frames per archive. That is a few
    /// milliseconds, and it happens inside the provider's actor, never on the
    /// main thread.
    static func frame(
        from composite: RadolanComposite,
        grid: RadolanGrid,
        bounds: RadarBounds = .rheinMain,
        width: Int = RadarRaster.width,
        height: Int = RadarRaster.height
    ) -> RadarFrame {
        var pixels = [Float](repeating: .nan, count: width * height)

        for y in 0..<height {
            // Pixel centres, not edges: sampling the corner of a pixel shifts
            // the whole image half a cell north-west.
            let latitude = bounds.north - (Double(y) + 0.5) / Double(height) * bounds.latitudeSpan
            for x in 0..<width {
                let longitude = bounds.west + (Double(x) + 0.5) / Double(width) * bounds.longitudeSpan
                guard
                    let cell = grid.cell(
                        for: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)),
                    let value = composite.value(row: cell.row, column: cell.column)
                else { continue }
                pixels[y * width + x] = Float(value)
            }
        }

        return RadarFrame(
            minute: composite.forecastMinute,
            width: width,
            height: height,
            millimetres: pixels
        )
    }
}
