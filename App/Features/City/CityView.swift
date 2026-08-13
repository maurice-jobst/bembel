import BEMBELKit
import SwiftUI

/// Stadtzustand: warnings, Main level, air quality — every card names its
/// source and timestamp. Values are sample fixtures until PEGELONLINE,
/// HLNUG and NINA are wired.
struct CityView: View {
    @Environment(Router.self) private var router

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BEMSpacing.m) {
                    Text(verbatim: SampleData.cityTemperature)
                        .font(.subheadline)
                        .foregroundStyle(BEMColor.inkSecondary)
                        .padding(.bottom, BEMSpacing.xs)

                    warningCard
                    gaugeCard
                    airCard

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
            .navigationTitle("tab.city")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings.title", systemImage: "gear") {
                        router.isPresentingSettings = true
                    }
                }
            }
        }
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: BEMSpacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(BEMColor.caution)
            VStack(alignment: .leading, spacing: 2) {
                Text("city.warning.title")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BEMColor.ink)
                Text("city.warning.body")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
                Text(verbatim: SampleData.warningStamp)
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

    private var gaugeCard: some View {
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
                Text(verbatim: SampleData.gaugeStation)
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: BEMSpacing.s + 2) {
                Text(verbatim: SampleData.gaugeLevel)
                    .font(BEMFont.boardLarge)
                    .foregroundStyle(BEMColor.ink)
                Text(verbatim: "m")
                    .font(.callout)
                    .foregroundStyle(BEMColor.inkSecondary)
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.caption2.weight(.bold))
                    Text(verbatim: SampleData.gaugeTrend)
                        .font(BEMFont.dataLabel)
                }
                .foregroundStyle(BEMColor.good)
            }

            Sparkline(values: SampleData.gaugeHistory)
                .frame(height: 52)

            HStack {
                Text("city.gauge.axis")
                Spacer()
                Text("city.gauge.source \(SampleData.gaugeStamp)")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(BEMColor.inkSecondary)
        }
        .padding(14)
        .background(BEMColor.saltGlazeElevated)
        .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))
    }

    private var airCard: some View {
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
                ForEach(SampleData.airValues) { value in
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
                        Text(verbatim: value.reading)
                            .font(BEMFont.dataLabel)
                            .foregroundStyle(BEMColor.ink)
                            .frame(width: 84, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Text(verbatim: SampleData.airStamp)
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
