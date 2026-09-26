import Foundation
import Testing

@testable import BEMBELKit

/// The rain widget's timeline (BEM-F04). The rules live here so the widget's
/// view has nothing to decide — and so "stale beats wrong" is a test, not a
/// hope about a view nobody runs in CI.
@Suite("Rain widget timeline")
struct RainWidgetTimelineTests {
    private let measuredAt = Date(timeIntervalSince1970: 1_790_000_000)

    /// Two hours in fives: dry until `wetFrom`, then `millimetres` to the end.
    private func nowcast(wetFrom: Int? = nil, millimetres: Double = 1.0) -> RadarNowcast {
        let series = stride(from: 0, through: 120, by: 5).map { minute in
            RadarSample(minute: minute, millimetres: wetFrom.map { minute >= $0 ? millimetres : 0 } ?? 0)
        }
        return RadarNowcastRules.nowcast(series: series, measuredAt: measuredAt)
    }

    private func minutes(_ value: Double) -> Date { measuredAt.addingTimeInterval(value * 60) }

    @Test("At the moment of measurement it says what the Radar tab says")
    func matchesTheTab() {
        let cast = nowcast(wetFrom: 15)
        #expect(RainWidgetTimeline.state(for: cast, at: measuredAt) == .forecast(cast.outlook, measuredAt: measuredAt))
    }

    @Test("Rain in 15 minutes is rain in 5 minutes ten minutes later, then rain now")
    func countsDown() {
        let cast = nowcast(wetFrom: 15)
        guard
            case .forecast(.rainStarting(let inMinutes, _, _), _) = RainWidgetTimeline.state(for: cast, at: minutes(10))
        else {
            Issue.record("expected rain starting")
            return
        }
        #expect(inMinutes == 5)
        guard case .forecast(.rainingNow, _) = RainWidgetTimeline.state(for: cast, at: minutes(15)) else {
            Issue.record("expected rain now")
            return
        }
    }

    @Test("Between steps it reads from the step already passed, never ahead of the radar")
    func roundsDown() {
        let cast = nowcast(wetFrom: 15)
        guard
            case .forecast(.rainStarting(let inMinutes, _, _), _) = RainWidgetTimeline.state(for: cast, at: minutes(9))
        else {
            Issue.record("expected rain starting")
            return
        }
        #expect(inMinutes == 10)
    }

    @Test("A dry horizon shrinks as the forecast ages — it cannot see further by waiting")
    func dryHorizonShrinks() {
        #expect(
            RainWidgetTimeline.state(for: nowcast(), at: minutes(30))
                == .forecast(.dry(horizonMinutes: 90), measuredAt: measuredAt))
    }

    @Test("The bars and the sentence are cut from the same place")
    func remainingMatchesState() throws {
        let cast = nowcast(wetFrom: 15)
        let remaining = try #require(RainWidgetTimeline.remaining(cast, at: minutes(12)))
        #expect(remaining.first?.minute == 0)
        #expect(remaining.count == 23)
        #expect(
            RainWidgetTimeline.state(for: cast, at: minutes(12))
                == .forecast(RadarNowcastRules.outlook(series: remaining), measuredAt: measuredAt))
        #expect(RainWidgetTimeline.remaining(cast, at: minutes(60)) == nil)
    }

    @Test("An hour after measurement the widget stops forecasting")
    func goesStale() {
        let cast = nowcast()
        #expect(RainWidgetTimeline.state(for: cast, at: minutes(59)) != .stale(measuredAt: measuredAt))
        #expect(RainWidgetTimeline.state(for: cast, at: minutes(60)) == .stale(measuredAt: measuredAt))
    }

    @Test("A device clock behind DWD's reads the forecast from its start, not from before it")
    func clockSkew() {
        let cast = nowcast(wetFrom: 15)
        #expect(
            RainWidgetTimeline.state(for: cast, at: minutes(-3)) == RainWidgetTimeline.state(for: cast, at: measuredAt))
    }

    @Test("A composite without a timestamp cannot be aged, so it is not trusted")
    func noTimestamp() {
        let cast = RadarNowcastRules.nowcast(series: [RadarSample(minute: 0, millimetres: 0)], measuredAt: nil)
        #expect(RainWidgetTimeline.state(for: cast, at: measuredAt) == .stale(measuredAt: nil))
        #expect(RainWidgetTimeline.entries(for: cast, now: measuredAt).map(\.state) == [.stale(measuredAt: nil)])
    }

    @Test("One download fills an hour in fives and ends on a stale entry")
    func entriesCoverTheHour() {
        let now = minutes(7)
        let entries = RainWidgetTimeline.entries(for: nowcast(), now: now)
        // 7, 12, … 57 minutes: eleven forecasts, then the stale one at 60.
        #expect(entries.count == 12)
        #expect(entries.first?.date == now)
        #expect(zip(entries, entries.dropFirst()).dropLast().allSatisfy { $1.date.timeIntervalSince($0.date) == 300 })
        #expect(entries.last?.date == minutes(60))
        #expect(entries.last?.state == .stale(measuredAt: measuredAt))
        #expect(entries.dropLast().allSatisfy { if case .forecast = $0.state { true } else { false } })
    }

    @Test("A forecast already too old yields one stale entry, dated now")
    func alreadyStale() {
        let now = minutes(90)
        let entries = RainWidgetTimeline.entries(for: nowcast(), now: now)
        #expect(entries.count == 1)
        #expect(entries.first?.date == now)
        #expect(entries.first?.state == .stale(measuredAt: measuredAt))
    }

    @Test("Reloads come before the forecast can go stale")
    func reloadBeatsExpiry() {
        #expect(RainWidgetTimeline.reloadInterval < RainWidgetTimeline.maxAge)
        #expect(RainWidgetTimeline.retryInterval <= RainWidgetTimeline.reloadInterval)
    }
}
