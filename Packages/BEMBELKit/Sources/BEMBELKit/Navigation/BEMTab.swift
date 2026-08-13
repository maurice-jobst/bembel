/// The five v1.0 surfaces. Order is tab order.
public enum BEMTab: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case departures
    case shadow
    case water
    case radar
    case city

    public var id: String { rawValue }
}
