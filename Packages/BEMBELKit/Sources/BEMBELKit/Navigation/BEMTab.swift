/// The four v1.0 surfaces. Order is tab order. `places` carries all three
/// place datasets (Wasserhäuschen, Ebbelwei, Trinkbrunnen) so the hero gets
/// position one without pushing the tab bar into an overflow menu.
///
/// `sun` was `shadow` until ADR 0010 took the Schattenkarte's rendering out of
/// v1.0. What is left is the real ephemeris, so the surface says what it
/// actually knows. Nothing persists a raw value — the selected tab lives only
/// in `Router` for the life of the process — so the rename needs no migration.
/// If tab restoration ever arrives, it decodes an unknown value to `.places`.
public enum BEMTab: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case places
    case departures
    case sun
    case radar
    case city

    public var id: String { rawValue }
}
