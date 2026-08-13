import SwiftUI

/// The Bembel palette: grey salt-glazed stoneware carrying cobalt relief.
/// Every color is appearance-dynamic; nothing else in the app defines colors.
public enum BEMColor {
    // Stoneware — surfaces
    public static let saltGlaze = Color(light: 0xEDEDEA, dark: 0x1B1B1D)
    public static let saltGlazeElevated = Color(light: 0xF8F8F6, dark: 0x2A2A2D)
    public static let glazeLine = Color(light: 0xD6D6D1, dark: 0x3B3B3F)

    // Cobalt — accent, interactive elements, the diamond relief
    public static let cobalt = Color(light: 0x1D4E9E, dark: 0x5B8DEF)
    public static let cobaltDeep = Color(light: 0x143A78, dark: 0x3E6BC4)

    // Ink — text
    public static let ink = Color(light: 0x1A1A1C, dark: 0xF2F2F4)
    public static let inkSecondary = Color(light: 0x56565C, dark: 0xA6A6AE)

    // Status — Stadtzustand levels, fountain seasons, warnings
    public static let good = Color(light: 0x2E7D4F, dark: 0x4CAF7A)
    public static let caution = Color(light: 0xB26A00, dark: 0xE8A33D)
    public static let alert = Color(light: 0xB3261E, dark: 0xE5695F)
}
