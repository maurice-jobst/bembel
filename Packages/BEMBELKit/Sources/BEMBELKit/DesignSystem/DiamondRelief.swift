import SwiftUI

/// The cobalt diamond relief from the Bembel jug, as a tileable Shape.
/// Stroke or fill it in `BEMColor.cobalt`; typical use is a decorative band:
///
///     DiamondRelief()
///         .stroke(BEMColor.cobalt, lineWidth: 1.5)
///         .frame(height: 44)
///         .clipped()
public struct DiamondRelief: Shape {
    public var diamondWidth: CGFloat
    /// Height of each diamond relative to its width; the jug relief runs tall.
    public var aspect: CGFloat

    public init(diamondWidth: CGFloat = 22, aspect: CGFloat = 1.5) {
        self.diamondWidth = diamondWidth
        self.aspect = aspect
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = diamondWidth
        let h = diamondWidth * aspect
        guard w > 0, h > 0 else { return path }

        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                path.move(to: CGPoint(x: x + w / 2, y: y))
                path.addLine(to: CGPoint(x: x + w, y: y + h / 2))
                path.addLine(to: CGPoint(x: x + w / 2, y: y + h))
                path.addLine(to: CGPoint(x: x, y: y + h / 2))
                path.closeSubpath()
                x += w
            }
            y += h
        }
        return path
    }
}
