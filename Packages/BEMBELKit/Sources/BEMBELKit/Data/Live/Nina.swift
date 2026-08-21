import Foundation

// NINA / warnung.bund.de api31 (BBK). No key, no registration, DL-DE/BY 2.0
// with attribution. Two endpoints:
//
//   dashboard/<ars>.json      the warnings in force for one region, already
//                             filtered by BBK — headline, provider, severity
//   warnings/<id>.json        the full CAP message: description, instruction,
//                             the areas it actually covers
//
// The dashboard aggregates every provider BBK carries — MOWAS, KATWARN,
// BIWAPP, LHP *and* DWD's weather warnings — so this one client covers the
// civil-protection card without also polling DWD's JSONP feed.
//
// Two facts that cost a live probe each:
//
//   * The region key is the **12-digit Regionalschlüssel**, not the 8-digit
//     AGS. `dashboard/06412000.json` answers HTTP 400; `064120000000.json`
//     answers 200. And ARS is not AGS with zeros appended — the two lay their
//     digits out differently below Kreis level (ARS carries four
//     Verbandsgemeinde digits the AGS does not), so `150853700000` for
//     Wernigerode is not a key at all. Only the *Kreis* form is derivable from
//     an AGS by string surgery: first five digits plus seven zeros. That is
//     what this client queries, which is also what keeps the request count at
//     26 for the widest ring instead of 475.
//   * `/api31/mowas/mapData.json` is the nationwide feed and carries no
//     geocode whatsoever, so filtering it to a region means fetching the
//     GeoJSON of every warning in Germany and doing point-in-polygon. The
//     dashboard does that server-side, and it is BBK's own answer to "what
//     applies here".

/// One row of `dashboard/<ars>.json`.
struct NinaDashboardItem: Decodable, Sendable {
    struct Payload: Decodable, Sendable {
        /// Named `Content` rather than `Data`, which the wire calls it, so the
        /// type does not shadow `Foundation.Data` inside this file.
        struct Content: Decodable, Sendable {
            let headline: String?
            /// MOWAS, KATWARN, BIWAPP, LHP or DWD — who actually issued it.
            let provider: String?
            let severity: String?
            let msgType: String?
            let valid: Bool?
        }

        let id: String
        let data: Content
    }

    let id: String
    let payload: Payload
    let sent: String?
}

/// `warnings/<id>.json` — the CAP message behind a dashboard row.
struct NinaWarningDetail: Decodable, Sendable {
    struct Info: Decodable, Sendable {
        struct Area: Decodable, Sendable {
            let areaDesc: String?
        }

        let language: String?
        let event: String?
        let headline: String?
        let description: String?
        let instruction: String?
        let severity: String?
        let expires: String?
        let area: [Area]?
    }

    let identifier: String
    let status: String?
    let msgType: String?
    let sent: String?
    let info: [Info]
}

/// Wire values in, card text out. Pure, so the fixtures can pin the parts that
/// are easy to get subtly wrong — which language block is the German one, what
/// counts as still in force, and how the two providers' markup differs.
public enum NinaRules {
    /// The 12-digit Regionalschlüssel of a Kreis: its five AGS digits, then
    /// seven zeros. Only valid at Kreis level — see the note at the top of
    /// this file for why the Gemeinde form cannot be derived this way.
    static func kreisRegionalKey(_ kreis: String) -> String? {
        guard kreis.utf8.count == 5, kreis.utf8.allSatisfy({ (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) })
        else { return nil }
        return kreis + "0000000"
    }

    /// The German block of a CAP message.
    ///
    /// MOWAS tags it `de`, DWD tags it `de-DE`, and both ship a **`DE-LS`**
    /// block as well — that is *Leichte Sprache*, a rewritten simplification,
    /// and any match that merely tests for a `de` prefix picks it about half
    /// the time. It is the right text for a different app, not for this card,
    /// and the user never asked for it.
    static func germanInfo(_ infos: [NinaWarningDetail.Info]) -> NinaWarningDetail.Info? {
        infos.first { info in
            switch info.language?.lowercased() {
            case "de", "de-de", "de_de": true
            default: false
            }
        } ?? infos.first
    }

    /// CAP text is a plain-text field into which DWD writes `<br/>`. Turning
    /// those into real line breaks and resolving the five XML entities is
    /// rendering, not rewriting: no word changes, and nothing is translated or
    /// summarised.
    static func plainText(_ raw: String) -> String {
        var text = raw
        for tag in ["<br/>", "<br />", "<br>", "<BR/>", "<BR>"] {
            text = text.replacingOccurrences(of: tag, with: "\n")
        }
        for (entity, character) in [
            ("&nbsp;", "\u{00A0}"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"),
            ("&amp;", "&"),  // last, or it would re-decode the ones above
        ] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Description and Handlungsempfehlungen, in that order, both verbatim.
    static func body(_ info: NinaWarningDetail.Info) -> String {
        [info.description, info.instruction]
            .compactMap { $0.map(plainText) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// How many Gemeinden a card names before it stops listing them. DWD
    /// warnings routinely cover thirty Landkreise, and a card that prints all
    /// thirty buries the warning itself.
    static let areaNamesShown = 3

    /// Where the warning applies, in the issuer's own words.
    ///
    /// Load-bearing, not decoration: this client filters at **Kreis**
    /// granularity, so a user on the kernraum ring can be shown a warning for
    /// a Gemeinde at the far edge of a Landkreis their ring only partly
    /// contains. Without this line the card would let them read it as local.
    static func areaLabel(_ info: NinaWarningDetail.Info) -> String? {
        var seen = Set<String>()
        let names =
            (info.area ?? [])
            .compactMap { $0.areaDesc?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        guard !names.isEmpty else { return nil }
        guard names.count > areaNamesShown else { return names.joined(separator: ", ") }
        return names.prefix(areaNamesShown).joined(separator: ", ") + " …"
    }

    /// CAP severity, ordered. Unknown spellings sort below `Minor` rather than
    /// above `Extreme` — an unrecognised value must never jump the queue.
    static func severityRank(_ severity: String?) -> Int {
        switch severity?.lowercased() {
        case "extreme": 4
        case "severe": 3
        case "moderate": 2
        case "minor": 1
        default: 0
        }
    }

    /// A warning the dashboard still lists but that has run out, been
    /// withdrawn, or was never a live alert to begin with.
    ///
    /// The dashboard is meant to serve only what is in force. This is the
    /// belt-and-braces read of the CAP message itself, because the failure
    /// this guards against — yesterday's Sturmwarnung presented as current —
    /// is the one that costs the card its credibility.
    static func isInForce(_ detail: NinaWarningDetail, expires: Date?, now: Date) -> Bool {
        if let status = detail.status?.lowercased(), status != "actual" { return false }
        if let msgType = detail.msgType?.lowercased(), msgType == "cancel" { return false }
        if let expires, expires <= now { return false }
        return true
    }

    /// `NINA · 09:12`, or `NINA · DWD · 09:12` when BBK is relaying somebody
    /// else's warning. MOWAS is NINA's own system, so naming it twice would
    /// say nothing.
    static func stampLabel(provider: String?, sentAt: Date?, clock: DateFormatter) -> String {
        let time = sentAt.map(clock.string(from:))
        let relay = provider.flatMap { name -> String? in
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.uppercased() != "MOWAS" else { return nil }
            return trimmed
        }
        return ["NINA", relay, time].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Live civil-protection warnings for the Stadtzustand card.
///
/// Read-only and poll-on-view. There is no push and no background delivery:
/// both need a server, and BEMBEL has none (ADR 0001). The card is honest
/// about that by carrying the fetch time.
public actor NinaWarningProvider: CityWarningProviding {
    private static let base = URL(string: "https://warnung.bund.de/api31/")!

    /// Deliberately shorter than the registry's 15-minute upstream cadence for
    /// NINA. The cache window adds to the upstream's own lag, and half an hour
    /// between a Hochwasserwarnung being issued and this card showing it is
    /// not a trade this screen gets to make.
    private static let staleness = Staleness(maxAge: 5 * 60)

    private let table: RegionTable?
    private let client: HTTPClient
    private let selectedRing: @Sendable () -> Ring
    /// Keyed on the ring it was fetched for — changing the ring must not be
    /// answered out of a cache built for a different region.
    private var cached: (ring: Ring, warnings: [CityWarning], fetchedAt: Date)?

    /// `table` is optional and a missing one is an error, not a fallback.
    /// There is no sample warning to degrade to: fabricated civil-protection
    /// text on this card would be worse than the card failing, which at least
    /// says so and offers a retry.
    public init(
        table: RegionTable?,
        client: HTTPClient = HTTPClient(),
        selectedRing: @escaping @Sendable () -> Ring = { RegionSettings.selectedRing() }
    ) {
        self.table = table
        self.client = client
        self.selectedRing = selectedRing
    }

    public enum Failure: Error, Equatable, Sendable {
        /// rings.json could not be read, so there is nothing to filter against.
        case missingRegionTable
        case unreadableRegion(String)
    }

    public func invalidate() {
        cached = nil
    }

    public func warnings() async throws -> [CityWarning] {
        let ring = selectedRing()
        if let cached, cached.ring == ring, !Self.staleness.isStale(fetchedAt: cached.fetchedAt) {
            return cached.warnings
        }
        guard let table else { throw Failure.missingRegionTable }

        let keys = try table.kreisKeys(in: ring).map { kreis -> String in
            guard let key = NinaRules.kreisRegionalKey(kreis) else {
                throw Failure.unreadableRegion(kreis)
            }
            return key
        }

        // One dashboard request per Kreis, concurrently. Any of them failing
        // fails the whole fetch: a warning list quietly missing the Kreis whose
        // request timed out reads exactly like a region with no warnings, and
        // that is the one wrong answer this card must never give.
        let rows = try await withThrowingTaskGroup(of: [NinaDashboardItem].self) { group in
            for key in keys {
                group.addTask { [client] in
                    try await client.get(
                        [NinaDashboardItem].self,
                        from: Self.base.appending(path: "dashboard/\(key).json")
                    )
                }
            }
            var all = [NinaDashboardItem]()
            for try await batch in group { all += batch }
            return all
        }

        // The same warning is listed by every Kreis it touches.
        var byID = [String: NinaDashboardItem]()
        for row in rows where row.payload.data.valid != false {
            byID[row.id] = byID[row.id] ?? row
        }

        let now = Date()
        let sortable = try await withThrowingTaskGroup(of: SortableWarning?.self) { group in
            for item in byID.values {
                group.addTask { [client] in
                    let detail = try await client.get(
                        NinaWarningDetail.self,
                        from: Self.base.appending(path: "warnings/\(item.id).json")
                    )
                    return Self.warning(from: detail, dashboard: item, now: now)
                }
            }
            var found = [SortableWarning]()
            for try await warning in group {
                if let warning { found.append(warning) }
            }
            return found
        }
        let warnings = Self.ordered(sortable)

        cached = (ring, warnings, Date())
        return warnings
    }

    /// Pure from here down. `nil` means the message is no longer in force, or
    /// carries no text worth a card.
    static func warning(
        from detail: NinaWarningDetail,
        dashboard: NinaDashboardItem,
        now: Date
    ) -> SortableWarning? {
        guard let info = NinaRules.germanInfo(detail.info) else { return nil }
        let expires = info.expires.flatMap(Self.date(from:))
        guard NinaRules.isInForce(detail, expires: expires, now: now) else { return nil }

        let title = [info.headline, dashboard.payload.data.headline, info.event]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let title else { return nil }

        let sentAt = detail.sent.flatMap(Self.date(from:)) ?? dashboard.sent.flatMap(Self.date(from:))
        return SortableWarning(
            warning: CityWarning(
                title: NinaRules.plainText(title),
                body: NinaRules.body(info),
                areaLabel: NinaRules.areaLabel(info),
                stampLabel: NinaRules.stampLabel(
                    provider: dashboard.payload.data.provider,
                    sentAt: sentAt,
                    clock: DateFormatter.berlinClock
                )
            ),
            severityRank: NinaRules.severityRank(info.severity ?? dashboard.payload.data.severity),
            sentAt: sentAt
        )
    }

    /// A warning plus the two wire fields that only decide its position in the
    /// list. Neither belongs on `CityWarning`, which is what the card renders.
    struct SortableWarning: Sendable {
        let warning: CityWarning
        let severityRank: Int
        let sentAt: Date?
    }

    /// Most severe first, newest first within a severity. A task group hands
    /// its results back in completion order, so without this the list would be
    /// ordered by whichever CAP message the network answered first.
    static func ordered(_ warnings: [SortableWarning]) -> [CityWarning] {
        warnings
            .sorted { lhs, rhs in
                if lhs.severityRank != rhs.severityRank { return lhs.severityRank > rhs.severityRank }
                return (lhs.sentAt ?? .distantPast) > (rhs.sentAt ?? .distantPast)
            }
            .map(\.warning)
    }

    /// CAP stamps carry an offset; DWD sometimes adds fractional seconds.
    static func date(from raw: String) -> Date? {
        ISO8601DateFormatter.internetDateTime.date(from: raw) ?? ISO8601DateFormatter.ninaFractional.date(from: raw)
    }
}

extension ISO8601DateFormatter {
    /// DWD's CAP variant: `.withFractionalSeconds` on top of the shared
    /// `internetDateTime` options.
    nonisolated(unsafe) static let ninaFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
