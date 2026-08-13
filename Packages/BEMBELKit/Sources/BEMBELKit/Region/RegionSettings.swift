import Foundation

/// The user's ring selection, shared with the widget extension via the App
/// Group. Departures ignore this entirely — RMV is regional by nature.
public enum RegionSettings {
    public static let selectedRingKey = "region.selectedRing"
    public static let defaultRing: Ring = .kernraum

    public static func selectedRing(from defaults: UserDefaults = AppGroup.defaults) -> Ring {
        defaults.string(forKey: selectedRingKey).flatMap(Ring.init(rawValue:)) ?? defaultRing
    }
}
