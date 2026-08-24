import BEMBELKit
import CoreGraphics
import SwiftUI

/// The colour scale for rain intensity, and the image it paints.
///
/// **Colourblind-safe by construction.** The meteorological convention —
/// green through yellow to red — is the single worst palette for the most
/// common form of colour blindness, and radar apps use it anyway. This is one
/// hue with a monotone ramp in lightness and opacity, so the ordering survives
/// any form of colour vision, in greyscale, and in bright sun. The legend
/// prints the same six boundaries in mm/h, so the picture can also just be
/// read off a number.
///
/// The bands are discrete rather than a gradient on purpose: a reader matching
/// a patch on the map to a row in the legend needs the two to be the same
/// colour, not two samples of a continuum.
enum RadarRainScale {
    /// The boundaries live in `RadarRaster.bands` — one list, tested there, so
    /// the legend and the pixels cannot drift apart.
    static var boundaries: [Float] { RadarRaster.bands }

    /// Cobalt from pale to deep in light mode; pale to bright in dark. Both
    /// run monotonically *away* from the map underneath them, which is what
    /// keeps "more rain looks like more" true in either scheme.
    static func colour(band: Int, scheme: ColorScheme) -> Color {
        let (red, green, blue, alpha) = components(band: band, scheme: scheme)
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    private static func components(
        band: Int, scheme: ColorScheme
    )
        -> (Double, Double, Double, Double)
    {
        // Hand-picked rather than interpolated: an even ramp in sRGB is not an
        // even ramp to the eye, and these six were checked against the map's
        // own greys in both schemes.
        let light: [(Double, Double, Double, Double)] = [
            (0.62, 0.74, 0.91, 0.55),
            (0.44, 0.61, 0.86, 0.65),
            (0.28, 0.47, 0.79, 0.74),
            (0.16, 0.34, 0.66, 0.82),
            (0.08, 0.23, 0.52, 0.89),
            (0.04, 0.13, 0.36, 0.94),
        ]
        // The dark ramp starts much lighter than the light ramp's mirror would
        // suggest: the map's water in dark mode is already a deep blue, and a
        // dark first band disappeared into it — checked on the Baltic, which is
        // the least forgiving background this overlay has.
        let dark: [(Double, Double, Double, Double)] = [
            (0.42, 0.55, 0.78, 0.55),
            (0.50, 0.64, 0.87, 0.65),
            (0.58, 0.72, 0.94, 0.74),
            (0.68, 0.80, 0.98, 0.82),
            (0.79, 0.88, 1.00, 0.89),
            (0.90, 0.95, 1.00, 0.95),
        ]
        let ramp = scheme == .dark ? dark : light
        return ramp[min(max(band, 0), ramp.count - 1)]
    }

    /// One frame as an image, ready to stretch over the map's `RadarBounds`.
    ///
    /// `nil` when the frame has nothing to draw — an empty overlay is a
    /// different thing from a transparent one and the caller says so in words.
    static func image(for frame: RadarFrame, scheme: ColorScheme) -> CGImage? {
        guard !frame.isEmpty else { return nil }

        var pixels = [UInt8](repeating: 0, count: frame.width * frame.height * 4)
        var drew = false
        for index in 0..<(frame.width * frame.height) {
            let value = frame.millimetres[index]
            guard let band = RadarRaster.band(millimetresPerStep: value) else { continue }
            let (red, green, blue, alpha) = components(band: band, scheme: scheme)
            // Premultiplied, which is what `.premultipliedLast` means and what
            // Core Graphics will otherwise silently misread as oversaturation.
            let offset = index * 4
            pixels[offset] = UInt8(red * alpha * 255)
            pixels[offset + 1] = UInt8(green * alpha * 255)
            pixels[offset + 2] = UInt8(blue * alpha * 255)
            pixels[offset + 3] = UInt8(alpha * 255)
            drew = true
        }
        guard drew else { return nil }

        guard
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let image = CGImage(
                width: frame.width,
                height: frame.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: frame.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else { return nil }
        return image
    }
}
