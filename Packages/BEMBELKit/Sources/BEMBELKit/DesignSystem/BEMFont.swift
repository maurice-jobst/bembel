import SwiftUI

/// Typography tokens. Every token is built on a Dynamic Type text style —
/// no fixed point sizes anywhere, so 200% scaling works by construction.
public enum BEMFont {
    public static let display = Font.largeTitle.weight(.bold)
    public static let title = Font.title2.weight(.semibold)
    public static let headline = Font.headline
    public static let body = Font.body
    public static let callout = Font.callout
    public static let caption = Font.caption

    /// Departure boards and measurements: tabular digits so columns of
    /// times/values don't jitter as they update.
    public static let board = Font.system(.title3, design: .rounded).weight(.semibold).monospacedDigit()
    public static let dataLabel = Font.footnote.monospacedDigit()
}
