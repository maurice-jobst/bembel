import Foundation

/// The live tier is deliberately thin (ADR 0002): a typed GET with a timeout.
/// Per-API behavior — auth headers, retry, response shapes — belongs to the
/// feature clients built on top of this (EPIC C, F, G), not here.
public struct HTTPClient: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// The raw body, status-checked. JSON is the common case but not the only
    /// one: DWD publishes its station observations as CSV, and the radar as a
    /// bzip2 archive.
    public func data(
        from url: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval = 15
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HTTPClientError.nonHTTPResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPClientError.status(http.statusCode)
        }
        return data
    }

    /// UTF-8, falling back to ISO-8859-1 — DWD's open-data files are Latin-1
    /// where they carry umlauts at all. Latin-1 accepts every byte sequence,
    /// so the throw is a formality that keeps a force-unwrap out of the
    /// happy path rather than a failure any real response can reach.
    public func text(
        from url: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval = 15
    ) async throws -> String {
        let body = try await data(from: url, headers: headers, timeout: timeout)
        guard let text = String(data: body, encoding: .utf8) ?? String(data: body, encoding: .isoLatin1)
        else {
            throw HTTPClientError.undecodableBody
        }
        return text
    }

    public func get<T: Decodable & Sendable>(
        _ type: T.Type,
        from url: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval = 15
    ) async throws -> T {
        let body = try await data(from: url, headers: headers, timeout: timeout)
        return try JSONDecoder().decode(T.self, from: body)
    }
}

public enum HTTPClientError: Error, Equatable, Sendable {
    case nonHTTPResponse
    case status(Int)
    /// The body is neither UTF-8 nor Latin-1.
    case undecodableBody
}
