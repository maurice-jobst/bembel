import CoreLocation
import Foundation

/// Kiosk visit stamps: on-device region monitoring, opt-in, nothing leaves the
/// phone. iOS caps simultaneously monitored regions, so the app watches the
/// nearest few verified entries and re-selects as the user moves.
public enum VisitMonitor {
    /// Apple's per-app region limit is 20; leave headroom for future layers.
    public static let regionLimit = 16
    public static let radius: CLLocationDistance = 75

    /// The entries worth watching right now: verified ones only (a candidate
    /// may not exist), nearest first, capped at `limit`.
    public static func candidates(
        from entries: [RegisterEntry],
        near location: CLLocationCoordinate2D,
        limit: Int = regionLimit
    ) -> [RegisterEntry] {
        let origin = CLLocation(latitude: location.latitude, longitude: location.longitude)
        return
            entries
            .filter(\.verified)
            .map { ($0, CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: origin)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}

#if os(iOS)
    /// Thin wrapper over `CLMonitor`. Untested by design — CoreLocation is not
    /// something a unit test can honestly exercise; the rule that decides
    /// *what* to monitor is `VisitMonitor.candidates`, and that is tested.
    @MainActor
    public final class KioskVisitMonitor {
        private static let monitorName = "de.mauricejobst.bembel.kiosks"

        private var monitor: CLMonitor?
        private var task: Task<Void, Never>?

        public init() {}

        /// Starts monitoring the given entries. `onVisit` fires once per entry
        /// per install — `StickerState.recordVisit` is the idempotence gate.
        public func start(for entries: [RegisterEntry], onVisit: @escaping @MainActor (String) -> Void) async {
            task?.cancel()
            task = nil
            let monitor = await CLMonitor(Self.monitorName)
            self.monitor = monitor

            for identifier in await monitor.identifiers {
                await monitor.remove(identifier)
            }
            for entry in entries {
                await monitor.add(
                    CLMonitor.CircularGeographicCondition(
                        center: entry.coordinate,
                        radius: VisitMonitor.radius
                    ),
                    identifier: entry.id
                )
            }

            task = Task { [weak self] in
                guard let events = await self?.monitor?.events else { return }
                // Monitor errors are swallowed on purpose: a failed stamp is
                // not worth an error state.
                do {
                    for try await event in events where event.state == .satisfied {
                        onVisit(event.identifier)
                    }
                } catch {}
            }
        }

        /// Tears the monitoring down completely: CLMonitor conditions persist
        /// across launches under the monitor's name, so an opt-out must remove
        /// them — cancelling the event loop alone would leave the geofences
        /// registered against the user's explicit choice.
        public func stop() {
            task?.cancel()
            task = nil
            let held = monitor
            monitor = nil
            Task {
                let monitor: CLMonitor
                if let held {
                    monitor = held
                } else {
                    monitor = await CLMonitor(Self.monitorName)
                }
                for identifier in await monitor.identifiers {
                    await monitor.remove(identifier)
                }
            }
        }
    }
#endif
