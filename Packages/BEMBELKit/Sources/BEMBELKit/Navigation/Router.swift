import Foundation
import Observation

/// App-wide navigation state. Per-tab `NavigationPath` storage arrives with
/// the first pushable detail screen (EPIC C) — until then there is nothing to
/// push, and speculative path plumbing is exactly what we said we'd delete.
@MainActor
@Observable
public final class Router {
    public var selectedTab: BEMTab = .places
    public var selectedRegister: PlaceRegister = .wasserhaeuschen
    public var isPresentingSettings = false

    /// Requested scrub time for the Sonnenstand screen, set via deep link.
    /// `nil` means "now". Consumed by `SunView`, which clears it once it has
    /// taken ownership — same nil→value discipline as `pendingEntryID`, so the
    /// same link opening twice is two distinct changes and not a dropped no-op.
    public var sunDate: Date?

    /// An entry a deep link asked for, not yet handed to the Orte tab. Orte
    /// clears it once it has taken ownership, so the same link opening twice
    /// is two distinct nil→id transitions and never a dropped no-op change.
    public var pendingEntryID: String?

    public init() {}

    public func open(_ link: DeepLink) {
        switch link {
        case .tab(let tab):
            selectedTab = tab
        case .places(let register):
            if let register { selectedRegister = register }
            selectedTab = .places
        case .entry(let register, let id):
            selectedRegister = register
            pendingEntryID = id
            selectedTab = .places
        case .sun(let date):
            sunDate = date
            selectedTab = .sun
        case .settings:
            isPresentingSettings = true
        }
    }

    /// Unknown or malformed URLs are ignored — the app stays where it is.
    public func handle(_ url: URL) {
        guard let link = DeepLink.parse(url) else { return }
        open(link)
    }
}
