import Foundation

/// Widget kind identifiers. They live in the kit because both sides need the
/// exact same string: the extension declares it, and the app passes it to
/// `WidgetCenter.reloadTimelines(ofKind:)` — a typo there fails silently,
/// which is the worst failure mode available.
public enum WidgetKind {
    public static let departures = "de.mauricejobst.bembel.departures"
    public static let nearestCandidate = "de.mauricejobst.bembel.nearestCandidate"
}
