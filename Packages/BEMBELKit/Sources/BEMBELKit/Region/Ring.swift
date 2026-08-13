/// Concentric region rings; a selection includes all inner rings.
/// Definitions (ADR 0003): kernraum = Regionalverband FrankfurtRheinMain,
/// rheinmain = Metropolregion FrankfurtRheinMain.
public enum Ring: String, CaseIterable, Codable, Hashable, Identifiable, Sendable, Comparable {
    case frankfurt
    case kernraum
    case rheinmain

    public var id: String { rawValue }

    public static func < (lhs: Ring, rhs: Ring) -> Bool {
        guard
            let lhsIndex = allCases.firstIndex(of: lhs),
            let rhsIndex = allCases.firstIndex(of: rhs)
        else { return false }
        return lhsIndex < rhsIndex
    }
}
