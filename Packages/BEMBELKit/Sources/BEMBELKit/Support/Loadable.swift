import Foundation

/// The four states a provider-backed screen actually has.
///
/// Every feature model used to hand-roll this, and each picked a different
/// proxy for "have I loaded already": `nowcast == nil`, `status == nil`,
/// `stations.isEmpty`. The emptiness proxies are wrong — an empty result is a
/// legitimate answer, so the model re-hit its provider on every view
/// appearance, forever. Naming the states makes that mistake unavailable.
///
/// Deliberately not `Equatable`: `failed` carries `any Error`, and a state
/// type that swallowed the error to gain `==` would be worth less than the
/// synthesised conformance is worth.
public enum Loadable<Value> {
    /// Nothing has been asked for yet.
    case idle
    case loading
    /// Answered. An *empty* value is an answer, not a reason to ask again.
    case loaded(Value)
    /// Answered with a failure. Stays retryable — that is the whole point of
    /// keeping it distinct from `idle`.
    case failed(any Error)

    public var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }

    public var error: (any Error)? {
        if case .failed(let error) = self { error } else { nil }
    }

    public var isLoading: Bool {
        if case .loading = self { true } else { false }
    }

    /// True only for a settled *success*. The load-once guard reads this, so a
    /// failure is tried again on the next appearance and a successful empty
    /// result is not.
    public var hasLoaded: Bool {
        if case .loaded = self { true } else { false }
    }

}

extension Loadable: Sendable where Value: Sendable {}

extension Loadable where Value: Sendable {
    /// Runs `operation` and reports it as a state. The load-once guard stays
    /// at the call site: only the model knows what else has to happen once the
    /// value is in — selecting a default, resolving a pending deep link.
    ///
    /// `@Sendable` because the models calling this are `@MainActor` and the
    /// provider work is not — the closure crosses that boundary.
    public static func result(of operation: @Sendable () async throws -> Value) async -> Loadable {
        do {
            return .loaded(try await operation())
        } catch {
            return .failed(error)
        }
    }
}
