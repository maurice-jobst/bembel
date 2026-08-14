import Foundation

/// The live tier is deliberately thin (ADR 0002): a typed GET with a timeout.
/// Per-API behavior — auth headers, retry, response shapes — belongs to the
/// feature clients built on top of this (EPIC C, F, G), not here.
public struct HTTPClient: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get<T: Decodable & Sendable>(
        _ type: T.Type,
        from url: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval = 15
    ) async throws -> T {
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
        return try JSONDecoder().decode(T.self, from: data)
    }
}

public enum HTTPClientError: Error, Equatable, Sendable {
    case nonHTTPResponse
    case status(Int)
}
