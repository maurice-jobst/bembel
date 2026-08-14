/// The five v1.0 surfaces. Order is tab order. `places` carries all three
/// place datasets (Wasserhäuschen, Ebbelwei, Trinkbrunnen) so the hero gets
/// position one without pushing the tab bar into an overflow menu.
public enum BEMTab: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case places
    case departures
    case shadow
    case radar
    case city

    public var id: String { rawValue }
}
