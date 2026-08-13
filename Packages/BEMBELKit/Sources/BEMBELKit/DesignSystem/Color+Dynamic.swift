import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// A color that resolves per appearance. AppKit branch exists only so the
    /// package compiles for `swift test` on macOS (ADR 0004).
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
            self.init(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(Color(hex: dark))
                        : UIColor(Color(hex: light))
                })
        #elseif canImport(AppKit)
            self.init(
                nsColor: NSColor(name: nil) { appearance in
                    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        ? NSColor(Color(hex: dark))
                        : NSColor(Color(hex: light))
                })
        #else
            self.init(hex: light)
        #endif
    }
}
