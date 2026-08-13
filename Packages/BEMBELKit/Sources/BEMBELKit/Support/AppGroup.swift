import Foundation

public enum AppGroup {
    /// Must match the App Groups entitlement in both targets.
    public static let identifier = "group.de.mauricejobst.bembel"

    /// Defaults shared between app and widgets. Falls back to standard
    /// defaults where the group container is unavailable (unit tests,
    /// unsigned simulator builds).
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
