import Foundation
import Observation

/// App-wide navigation state. Per-tab `NavigationPath` storage arrives with
/// the first pushable detail screen (EPIC C) — until then there is nothing to
/// push, and speculative path plumbing is exactly what we said we'd delete.
@MainActor
@Observable
public final class Router {
    public var selectedTab: BEMTab = .departures
    public var isPresentingSettings = false

    /// Requested scrub time for the shadow map, set via deep link.
    /// `nil` means "now". Consumed by the Schattenkarte feature (BEM-E03).
    public var shadowDate: Date?

    public init() {}

    public func open(_ link: DeepLink) {
        switch link {
        case .tab(let tab):
            selectedTab = tab
        case .shadow(let date):
            shadowDate = date
            selectedTab = .shadow
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
