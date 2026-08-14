import Foundation

/// Stickers that ship at 1.0. The full Sammelalbum — city hotspots, Game
/// Center mirroring, seasonal drops — stays M4 (BEM-S01).
public enum Sticker: Hashable, Sendable, Identifiable {
    /// A merged bembel-data entry contribution.
    case datenspender
    /// A verification that flipped an entry to verified.
    case verifizierer
    /// The first rating on some entry.
    case ersteBewertung
    /// Visited a kiosk in person, detected on-device.
    case kioskStempel(entryID: String)

    public var id: String {
        switch self {
        case .datenspender: "datenspender"
        case .verifizierer: "verifizierer"
        case .ersteBewertung: "erste-bewertung"
        case .kioskStempel(let entryID): "stempel-\(entryID)"
        }
    }

    /// Data-linked stickers are earned in bembel-data and recognised by
    /// handle; stamps are earned on the phone and never leave it.
    public var isDataLinked: Bool {
        if case .kioskStempel = self { return false }
        return true
    }

    public var systemImage: String {
        switch self {
        case .datenspender: "square.and.arrow.up.on.square"
        case .verifizierer: "checkmark.seal"
        case .ersteBewertung: "star.circle"
        case .kioskStempel: "mappin.and.ellipse"
        }
    }

    /// The three data-linked stickers, in album order.
    public static let dataLinked: [Sticker] = [.datenspender, .verifizierer, .ersteBewertung]
}

/// Pure rules over (contributor tallies, on-device visits). No network, no
/// clock, no storage — the whole engine is this function, which is why it can
/// be tested exhaustively and trusted in the album.
public enum StickerRules {
    public static func awarded(
        login: String?,
        contributors: [Contributor],
        visitedEntryIDs: Set<String>
    ) -> Set<Sticker> {
        var earned = Set(visitedEntryIDs.map { Sticker.kioskStempel(entryID: $0) })

        guard
            let login = RatingFunnel.sanitizedLogin(login)?.lowercased(),
            let me = contributors.first(where: { $0.login.lowercased() == login })
        else { return earned }

        if me.entries > 0 { earned.insert(.datenspender) }
        if me.verifications > 0 { earned.insert(.verifizierer) }
        if !me.firstRatings.isEmpty { earned.insert(.ersteBewertung) }
        return earned
    }
}

/// On-device sticker state in the App Group store. Handle squatting is
/// accepted and harmless: the field only decides which public tallies the
/// album mirrors, and nothing is written back anywhere.
public enum StickerState {
    public static let loginKey = "sticker.githubLogin"
    public static let visitsKey = "sticker.visitedEntryIDs"
    public static let visitDetectionKey = "sticker.visitDetectionEnabled"

    public static func login(_ defaults: UserDefaults = AppGroup.defaults) -> String? {
        defaults.string(forKey: loginKey).flatMap(RatingFunnel.sanitizedLogin)
    }

    public static func visitedEntryIDs(_ defaults: UserDefaults = AppGroup.defaults) -> Set<String> {
        Set(defaults.stringArray(forKey: visitsKey) ?? [])
    }

    @discardableResult
    public static func recordVisit(entryID: String, _ defaults: UserDefaults = AppGroup.defaults) -> Bool {
        var visits = visitedEntryIDs(defaults)
        guard visits.insert(entryID).inserted else { return false }
        defaults.set(visits.sorted(), forKey: visitsKey)
        return true
    }

    public static func isVisitDetectionEnabled(_ defaults: UserDefaults = AppGroup.defaults) -> Bool {
        defaults.bool(forKey: visitDetectionKey)
    }
}
