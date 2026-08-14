import Foundation

public enum AppGroup {
    /// Must match the App Groups entitlement in both targets.
    public static let identifier = "group.de.mauricejobst.bembel"

    /// Defaults shared between app and widgets. A single cached instance:
    /// @AppStorage observes the exact UserDefaults object it was given, so
    /// every view must see the same one. Falls back to standard defaults
    /// where the group container is unavailable (unit tests, unsigned
    /// simulator builds) — UserDefaults(suiteName:) alone won't tell you,
    /// it returns a suite whose writes go nowhere.
    // UserDefaults is documented thread-safe; it just predates Sendable.
    public nonisolated(unsafe) static let defaults: UserDefaults = {
        let hasContainer =
            FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
        guard hasContainer, let suite = UserDefaults(suiteName: identifier) else {
            return .standard
        }
        return suite
    }()
}

extension Bundle {
    /// The kit's own resource bundle. `@testable` tests need this: inside the
    /// test target `Bundle.module` resolves to the *test* target's fixtures,
    /// so asserting anything about a shipped resource needs the real one —
    /// otherwise the only way to test the bundled layer is a third copy of it.
    static var kitResources: Bundle { .module }
}
