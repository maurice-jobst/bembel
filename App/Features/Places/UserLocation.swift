import CoreLocation
import Observation
import SwiftUI

/// The user's position, or the honest absence of it.
///
/// Deliberately thin: one coarse fix, no tracking, no background updates,
/// nothing stored and nothing sent anywhere. The only question the Orte tab
/// asks is "how far is that fountain from here", and a `nil` answer is a
/// supported answer — the list falls back to alphabetical (BEM-E03 AC).
@MainActor
@Observable
final class UserLocation: NSObject, CLLocationManagerDelegate {
    /// Equatable on purpose: `CLLocationCoordinate2D` is not, and a view that
    /// wants to react to "the fix moved" needs a value it can compare.
    struct Fix: Equatable {
        let latitude: Double
        let longitude: Double

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    private(set) var fix: Fix?
    private(set) var authorization: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        // Hundred-metre accuracy is plenty to sort a list of fountains, and it
        // is the cheapest fix the device can give us.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    /// Asks for one fix if we are allowed to. Never prompts by itself — the
    /// onboarding screen owns the permission conversation, and a map that
    /// prompts on appear is the thing everyone hates.
    func refresh() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else { return }
        manager.requestLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorization = status
            refresh()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let fix = Fix(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        Task { @MainActor in
            self.fix = fix
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // A failed fix is not an error state: the list simply stays in its
        // location-free order.
    }
}
