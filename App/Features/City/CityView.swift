import BEMBELKit
import SwiftUI

/// Stadtzustand: warnings, Main level, air quality — every card names its
/// source and timestamp.
///
/// Each card renders its own source's state. There is deliberately no
/// screen-level "loading" or "error" branch: the four upstreams are unrelated,
/// and a screen-wide state would mean the warning card disappearing because a
/// river gauge timed out.
struct CityView: View {
    @Environment(Router.self) private var router
    @Environment(\.dependencies) private var dependencies
    @State private var model = CityModel()

    private var sources: CitySources { dependencies.citySources }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BEMSpacing.m) {
                    temperatureLine
                        .padding(.bottom, BEMSpacing.xs)

                    warningSection
                    gaugeSection
                    airSection

                    DiamondRelief()
                        .stroke(BEMColor.cobalt, lineWidth: 1.5)
                        .frame(height: 34)
                        .clipped()
                        .opacity(0.35)
                        .padding(.top, BEMSpacing.s)
                }
                .padding(.horizontal, BEMSpacing.l)
            }
            .background(BEMColor.saltGlaze)
            .refreshable { await model.refresh(from: sources) }
            .navigationTitle("tab.city")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.title", systemImage: "gear") {
                        router.isPresentingSettings = true
                    }
                }
            }
        }
        .task {
            await model.load(from: sources)
        }
    }

    // MARK: - Sections

    /// The header line degrades to a sentence rather than vanishing. A missing
    /// temperature is the least consequential failure on this screen, so it
    /// gets a line and not a card — but it still says so, because a header that
    /// silently disappears reads as a layout bug.
    @ViewBuilder private var temperatureLine: some View {
        Group {
            switch model.temperatureState {
            case .idle, .loading:
                Text("city.loading")
            case .loaded(let reading):
                Text(verbatim: reading.label)
            case .failed:
                Text("city.temperature.unavailable")
            }
        }
        .font(.subheadline)
        .foregroundStyle(BEMColor.inkSecondary)
    }

    @ViewBuilder private var warningSection: some View {
        switch model.warningState {
        case .idle, .loading:
            SourceLoadingCard(title: "city.warnings.title", icon: "exclamationmark.triangle")
        case .loaded(let warnings):
            // An empty list is an answer, and it is the reassuring one. Saying
            // it out loud is what keeps "nothing is wrong" distinguishable from
            // "we could not find out". Written as a plain branch rather than a
            // `case … where`: CI runs an older Swift than the dev machines and
            // has already rejected one pattern match this one accepted.
            if warnings.isEmpty {
                allClearRow
            } else {
                ForEach(warnings, id: \.self) { warningCard($0) }
            }
        case .failed:
            SourceFailureCard(
                title: "city.warnings.title",
                icon: "exclamationmark.triangle",
                sourceName: "NINA"
            ) {
                await model.retryWarnings(from: sources)
            }
        }
    }

    @ViewBuilder private var gaugeSection: some View {
        switch model.gaugeState {
        case .idle, .loading:
            SourceLoadingCard(title: "city.gauge.title", icon: "water.waves")
        case .loaded(let gauge):
            gaugeCard(gauge)
        case .failed:
            SourceFailureCard(title: "city.gauge.title", icon: "water.waves", sourceName: "PEGELONLINE") {
                await model.retryGauge(from: sources)
            }
        }
    }

    @ViewBuilder private var airSection: some View {
        switch model.airState {
        case .idle, .loading:
            SourceLoadingCard(title: "city.air.title", icon: "wind")
        case .loaded(let air):
            airCard(air)
        case .failed:
            SourceFailureCard(title: "city.air.title", icon: "wind", sourceName: "HLNUG") {
                await model.retryAir(from: sources)
            }
        }
    }

    private var allClearRow: some View {
        HStack(spacing: BEMSpacing.s) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(BEMColor.good)
            Text("city.warnings.none")
                .font(.footnote)
                .foregroundStyle(BEMColor.inkSecondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Loaded cards

    private func warningCard(_ warning: CityWarning) -> some View {
        HStack(alignment: .top, spacing: BEMSpacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(BEMColor.caution)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: warning.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BEMColor.ink)
                Text(verbatim: warning.body)
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
                Text(verbatim: warning.stampLabel)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(BEMColor.inkSecondary)
                    .padding(.top, 4)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(BEMColor.inkSecondary)
                .padding(.top, 4)
        }
        .bemStatusCard()
        .overlay(
            RoundedRectangle(cornerRadius: BEMRadius.card)
                .stroke(BEMColor.caution.opacity(0.35), lineWidth: 1)
        )
    }

    /// A steady river gets its own arrow and the neutral ink. Reusing the
    /// falling arrow would read as "going down" and reusing its green tint
    /// would read as reassurance, neither of which the data says.
    private static func trendSymbol(_ trend: GaugeTrend) -> String {
        switch trend {
        case .rising: "arrow.up"
        case .falling: "arrow.down"
        case .steady: "arrow.right"
        }
    }

    private static func trendTint(_ trend: GaugeTrend) -> Color {
        switch trend {
        case .rising: BEMColor.caution
        case .falling: BEMColor.good
        case .steady: BEMColor.inkSecondary
        }
    }

    private func gaugeCard(_ gauge: GaugeReading) -> some View {
        VStack(alignment: .leading, spacing: BEMSpacing.s + 2) {
            HStack {
                Label {
                    Text("city.gauge.title")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(BEMColor.ink)
                } icon: {
                    Image(systemName: "water.waves")
                        .foregroundStyle(BEMColor.cobalt)
                }
                Spacer()
                Text(verbatim: gauge.stationName)
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: BEMSpacing.s + 2) {
                Text(verbatim: gauge.levelLabel)
                    .font(BEMFont.boardLarge)
                    .foregroundStyle(BEMColor.ink)
                Text(verbatim: "m")
                    .font(.callout)
                    .foregroundStyle(BEMColor.inkSecondary)
                HStack(spacing: 3) {
                    Image(systemName: Self.trendSymbol(gauge.trend))
                        .font(.caption2.weight(.bold))
                    Text(verbatim: gauge.trendLabel)
                        .font(BEMFont.dataLabel)
                }
                .foregroundStyle(Self.trendTint(gauge.trend))
            }

            Sparkline(values: gauge.history)
                .frame(height: 52)

            HStack {
                Text("city.gauge.axis")
                Spacer()
                Text("city.gauge.source \(gauge.stampLabel)")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(BEMColor.inkSecondary)
        }
        .bemStatusCard()
    }

    private func airCard(_ air: AirQuality) -> some View {
        VStack(alignment: .leading, spacing: BEMSpacing.m) {
            HStack {
                Label {
                    Text("city.air.title")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(BEMColor.ink)
                } icon: {
                    Image(systemName: "wind")
                        .foregroundStyle(BEMColor.cobalt)
                }
                Spacer()
                StatusCapsule(label: Text("city.air.good"), color: BEMColor.good)
            }

            VStack(spacing: 9) {
                ForEach(air.values) { value in
                    HStack(spacing: 10) {
                        Text(verbatim: value.name)
                            .font(.footnote)
                            .foregroundStyle(BEMColor.inkSecondary)
                            .frame(width: 46, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(BEMColor.glazeLine)
                                Capsule()
                                    .fill(value.elevated ? BEMColor.caution : BEMColor.good)
                                    .frame(width: geo.size.width * value.fraction)
                            }
                        }
                        .frame(height: 6)
                        Text(verbatim: value.readingLabel)
                            .font(BEMFont.dataLabel)
                            .foregroundStyle(BEMColor.ink)
                            .frame(width: 84, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Text(verbatim: air.stampLabel)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(BEMColor.inkSecondary)
        }
        .bemStatusCard()
    }
}

/// Minimal filled line chart for the Pegel history.
struct Sparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let maxValue = (values.max() ?? 1) * 1.4
            let stepX = geo.size.width / Double(max(values.count - 1, 1))
            let points = values.enumerated().map { index, value in
                CGPoint(x: Double(index) * stepX, y: geo.size.height * (value / maxValue))
            }

            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(BEMColor.cobalt.opacity(0.12))

                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(BEMColor.cobalt, lineWidth: 1.6)
            }
        }
    }
}

// MARK: - Previews

// Failing sources come from `DebugFailingSource`, the same hook the simulator
// uses via `-BEMFailSources`. One way to fail, so what a preview shows and what
// a running app shows cannot drift apart.

private struct QuietWarnings: CityWarningProviding {
    func warnings() async throws -> [CityWarning] { [] }
}

private func previewDependencies(
    temperature: any TemperatureProviding = SampleTemperatureProvider(),
    gauge: any GaugeProviding = SampleGaugeProvider(),
    air: any AirQualityProviding = SampleAirQualityProvider(),
    warnings: any CityWarningProviding = SampleCityWarningProvider()
) -> AppDependencies {
    var dependencies = AppDependencies()
    dependencies.temperature = temperature
    dependencies.gauge = gauge
    dependencies.air = air
    dependencies.cityWarnings = warnings
    return dependencies
}

#Preview("Alles geladen") {
    CityView()
        .environment(Router())
        .environment(\.dependencies, previewDependencies())
}

#Preview("Pegel tot, Warnung lebt") {
    // The state this whole split exists for: PEGELONLINE is down and the
    // civil-protection warning is still on screen.
    CityView()
        .environment(Router())
        .environment(\.dependencies, previewDependencies(gauge: DebugFailingSource()))
}

#Preview("Keine Warnung in Kraft") {
    CityView()
        .environment(Router())
        .environment(\.dependencies, previewDependencies(warnings: QuietWarnings()))
}

#Preview("Alle Quellen tot") {
    let failing = DebugFailingSource()
    CityView()
        .environment(Router())
        .environment(
            \.dependencies,
            previewDependencies(temperature: failing, gauge: failing, air: failing, warnings: failing)
        )
}
