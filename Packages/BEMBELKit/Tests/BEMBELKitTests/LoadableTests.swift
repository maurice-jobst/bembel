import Foundation
import Testing

@testable import BEMBELKit

private struct Boom: Error {}

@Suite("Loadable")
struct LoadableTests {
    @Test("idle and loading have answered nothing")
    func unsettled() {
        let idle = Loadable<Int>.idle
        #expect(idle.value == nil)
        #expect(idle.error == nil)
        #expect(!idle.hasLoaded)
        #expect(!idle.isLoading)

        let loading = Loadable<Int>.loading
        #expect(loading.isLoading)
        #expect(!loading.hasLoaded)
    }

    @Test("A successful *empty* load has answered — this is the bug the type exists for")
    func emptySuccessSettles() {
        // The models this replaced guarded on `stations.isEmpty`, so a
        // legitimately empty answer re-hit the provider on every appearance.
        let state = Loadable<[String]>.loaded([])
        #expect(state.hasLoaded)
        #expect(state.value == [])
        #expect(state.error == nil)
    }

    @Test("A failure has not loaded, so the next appearance retries it")
    func failureStaysRetryable() {
        let state = Loadable<Int>.failed(Boom())
        #expect(!state.hasLoaded)
        #expect(state.value == nil)
        #expect(state.error is Boom)
    }

    @Test("A throwing operation becomes .failed, carrying the error")
    func resultCatches() async {
        let state = await Loadable<Int>.result { throw Boom() }
        #expect(state.error is Boom)
        #expect(!state.hasLoaded)
    }

    @Test("A returning operation becomes .loaded, carrying the value")
    func resultLoads() async {
        let state = await Loadable<Int>.result { 42 }
        #expect(state.value == 42)
        #expect(state.hasLoaded)
    }

    @Test("Cancellation is a failure, not a silent success")
    func cancellationFails() async {
        // A cancelled load must stay retryable: the tab was left mid-flight,
        // and coming back has to ask again rather than render nothing forever.
        let task = Task {
            await Loadable<Int>.result {
                try await Task.sleep(for: .seconds(60))
                return 1
            }
        }
        task.cancel()
        let state = await task.value
        #expect(!state.hasLoaded)
        #expect(state.error is CancellationError)
    }
}
