import CoreLocation
import Foundation

public struct Fountain: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    /// Preformatted distance from the user ("220 m").
    public let distanceLabel: String
    public let walkMinutes: Int
    /// The highlighted nearest fountain gets the big cobalt pin.
    public let featured: Bool

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        distanceLabel: String,
        walkMinutes: Int,
        featured: Bool = false
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.distanceLabel = distanceLabel
        self.walkMinutes = walkMinutes
        self.featured = featured
    }
}

/// The real seasonal rule: city fountains run from World Water Day
/// (22 March) until they're winterized at the end of September.
public enum FountainSeason {
    public static func isOpen(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return false }
        if month < 3 || month > 9 { return false }
        if month == 3 { return day >= 22 }
        return true
    }
}
