import Foundation

/// The app is the top of the rating funnel — and nothing more than that.
/// Every "contribute" action is a URL into bembel-data: no auth, no API, no
/// token, no BEMBEL account. What travels is what is already public.
///
/// The query field ids are a contract with bembel-data's issue forms,
/// documented in that repo's `docs/app-funnel.md` and checked in its CI by
/// `scripts/check_funnel.py`. Renaming one there breaks the prefill here.
public enum RatingFunnel {
    public static let repository = URL(string: "https://github.com/maurice-jobst/bembel-data")!
    /// Shown in the filename when no handle is configured — GitHub lets the
    /// contributor fix it in the browser before opening the PR.
    public static let placeholderLogin = "DEIN-LOGIN"

    /// GitHub logins: alphanumerics and single hyphens, at most 39 characters.
    /// This value lands in a URL path, so anything else is rejected outright
    /// rather than escaped — the Settings field is user input.
    public static func sanitizedLogin(_ raw: String?) -> String? {
        guard var candidate = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty else {
            return nil
        }
        if candidate.hasPrefix("@") { candidate.removeFirst() }
        guard candidate.count <= 39,
            candidate.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }),
            !candidate.hasPrefix("-"), !candidate.hasSuffix("-"), !candidate.contains("--")
        else { return nil }
        return candidate
    }

    /// Opens GitHub's "create new file" flow with the rating file prefilled.
    /// GitHub forks the repo and opens the pull request; the file's name is
    /// the account that opened it, which is the whole trust model.
    public static func rate(entryID: String, stars: Int, login: String?, date: Date = Date()) -> URL? {
        guard isValidEntryID(entryID) else { return nil }
        let handle = sanitizedLogin(login) ?? placeholderLogin
        let clamped = min(max(stars, 1), 5)

        let body = """
            {
              "entry": "\(entryID)",
              "login": "\(handle)",
              "stars": \(clamped),
              "date": "\(day(date))"
            }
            """

        return url(
            path: "new/main",
            items: [
                "filename": "data/bewertungen/\(entryID)/\(handle).json",
                "value": body,
            ]
        )
    }

    /// "Ein Eintrag fehlt" — the register's issue form, prefilled with a name.
    public static func report(register: PlaceRegister, name: String? = nil) -> URL? {
        guard register.isCommunity else { return nil }
        let label = register == .ebbelwei ? "Ebbelwei" : "Wasserhäuschen"
        var items = ["template": "\(register.rawValue).yml", "title": "[\(label)] \(name ?? "")"]
        if let name { items["name"] = name }
        return url(path: "issues/new", items: items)
    }

    /// "Hilf mit, verifizieren" — the coverage game's call to action, and the
    /// correction link on every entry.
    public static func verify(entryID: String, name: String) -> URL? {
        guard isValidEntryID(entryID) else { return nil }
        return url(
            path: "issues/new",
            items: [
                "template": "verifizierung.yml",
                "title": "[Verifizierung] \(name)",
                "eintrag": entryID,
            ]
        )
    }

    private static func isValidEntryID(_ id: String) -> Bool {
        !id.isEmpty
            && id.allSatisfy { $0.isASCII && ($0.isLowercase && $0.isLetter || $0.isNumber || $0 == "-") }
    }

    private static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func url(path: String, items: [String: String]) -> URL? {
        guard
            var components = URLComponents(
                url: repository.appending(path: path),
                resolvingAgainstBaseURL: false
            )
        else { return nil }
        components.queryItems = items.sorted { $0.key < $1.key }.map {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        return components.url
    }
}
