import BEMBELKit
import SwiftUI

/// Stadtzustand: warnings, Main level, air quality — every card names its
/// source and timestamp. Renders whatever the injected `CityStatusProviding`
/// returns.
struct CityView: View {
    @Environment(Router.self) private var router
    @Environment(\.dependencies) private var dependencies
    @State private var model = CityModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if let status = model.status {
                    VStack(alignment: .leading, spacing: BEMSpacing.m) {
                        Text(verbatim: status.temperatureLabel)
                            .font(.subheadline)
                            .foregroundStyle(BEMColor.inkSecondary)
                            .padding(.bottom, BEMSpacing.xs)

                        if let warning = status.warning {
                            warningCard(warning)
                        }
                        gaugeCard(status.gauge)
                        airCard(status)

                        DiamondRelief()
                            .stroke(BEMColor.cobalt, lineWidth: 1.5)
                            .frame(height: 34)
                            .clipped()
                            .opacity(0.35)
                            .padding(.top, BEMSpacing.s)
                    }
                    .padding(.horizontal, BEMSpacing.l)
                }
            }
            .background(BEMColor.saltGlaze)
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
            await model.load(from: dependencies.cityStatus)
        }
    }

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
        .padding(14)
        .background(BEMColor.saltGlazeElevated)
        .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))
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
        .padding(14)
        .background(BEMColor.saltGlazeElevated)
        .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))
    }

    private func airCard(_ status: CityStatus) -> some View {
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
                ForEach(status.airValues) { value in
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

            Text(verbatim: status.airStampLabel)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(BEMColor.inkSecondary)
        }
        .padding(14)
        .background(BEMColor.saltGlazeElevated)
        .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))
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
