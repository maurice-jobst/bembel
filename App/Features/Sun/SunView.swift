import BEMBELKit
import MapKit
import SwiftUI

/// Sonnenstand: where the sun is over Frankfurt, on a draggable clock.
///
/// This was the Schattenkarte. ADR 0010 took the shadow rendering out of v1.0
/// (`BEM-D04`, now v1.2) and with it the flat cobalt wash that used to sit
/// over the map pretending to be the LoD2 shadow raster. What stays is the
/// part that was always real: the ephemeris from `BEM-D03`, cross-checked
/// against published sunrise and sunset times.
struct SunView: View {
    @Environment(Router.self) private var router
    @State private var model = SunScreenModel()
    @State private var isPresentingAccuracy = false
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6714),
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    )

    var body: some View {
        ZStack {
            Map(position: $position)
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .ignoresSafeArea()

            VStack {
                topControls
                Spacer()
                scrubberCard
            }
            .padding(.horizontal, BEMSpacing.m)
        }
        // `initial: true` so a cold launch straight into a deep link is handled
        // too — the value is already set by the time this view first appears.
        .onChange(of: router.sunDate, initial: true) { _, date in
            guard let date else { return }
            model.show(at: date)
            router.sunDate = nil
        }
        .sheet(isPresented: $isPresentingAccuracy) {
            SunAccuracyView(
                day: model.day,
                daylight: model.daylight,
                solarNoonMinutes: model.solarNoonMinutes,
                refractionLift: model.refractionLift
            )
        }
    }

    private var topControls: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.cobalt)
                Text(model.day, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BEMColor.ink)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .bemGlass(in: .capsule)

            Spacer()

            HStack(spacing: BEMSpacing.s) {
                GlassCircleButton(systemImage: "location", accessibilityLabel: "action.locate")
                GlassCircleButton(systemImage: "gear", accessibilityLabel: "settings.title") {
                    router.isPresentingSettings = true
                }
            }
        }
    }

    private var scrubberCard: some View {
        @Bindable var model = model
        return VStack(spacing: BEMSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: SunModel.clockLabel(minutes: model.minutes))
                    .font(BEMFont.boardLarge)
                    .foregroundStyle(BEMColor.ink)
                // Tappable on purpose: the elevation readout is the number the
                // accuracy screen is about, so it is where someone wondering
                // about it will reach first.
                Button {
                    isPresentingAccuracy = true
                } label: {
                    HStack(spacing: 4) {
                        Text(
                            "sun.elevation \(model.sun.elevation) \(String(localized: model.sun.westward ? "sun.direction.east" : "sun.direction.west"))"
                        )
                        Image(systemName: "info.circle")
                            .font(.caption2)
                    }
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("sun.accuracy.open")
                Spacer()
                Button {
                    model.resetToNow()
                } label: {
                    Text("sun.now")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BEMColor.cobalt)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .overlay(Capsule().stroke(BEMColor.cobalt, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            SunCurveScrubber(minutes: $model.minutes, curve: model.curve)
                .frame(height: 58)

            // Derived, not typed out: the scrubber's ends moved when the sun
            // model became real (BEM-D03), and a hardcoded axis would now be
            // labelling the wrong minutes.
            HStack {
                Text(verbatim: SunModel.clockLabel(minutes: SunModel.dayStart))
                Spacer()
                Text(verbatim: SunModel.clockLabel(minutes: model.solarNoonMinutes))
                Spacer()
                Text(verbatim: SunModel.clockLabel(minutes: SunModel.dayEnd))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(BEMColor.inkSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.top, BEMSpacing.m)
        .padding(.bottom, 14)
        .bemGlassCard()
        .padding(.bottom, BEMSpacing.s)
    }
}

/// Draggable sun-elevation curve: filled arc, marker line, dot riding the
/// curve.
///
/// The curve is the day's real elevation, handed in by the model. It used to
/// be a bezier copied out of the design file — one hump, the same on every day
/// of the year, under a readout that came from the ephemeris. In December the
/// dot rode high while the number beside it said 8°.
struct SunCurveScrubber: View {
    @Binding var minutes: Double
    let curve: [SunModel.CurvePoint]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let fraction = (minutes - SunModel.dayStart) / (SunModel.dayEnd - SunModel.dayStart)
            let x = fraction * width
            let dotY = y(forWeight: weight(atFraction: fraction), in: height)

            ZStack(alignment: .topLeading) {
                path(in: geo.size, closed: true)
                    .fill(BEMColor.cobalt.opacity(0.13))
                path(in: geo.size, closed: false)
                    .stroke(BEMColor.cobalt.opacity(0.7), lineWidth: 1.5)
                Rectangle()
                    .fill(BEMColor.glazeLine)
                    .frame(height: 1)
                    .offset(y: height - 1.5)

                Rectangle()
                    .fill(BEMColor.cobalt)
                    .frame(width: 2)
                    .shadow(color: BEMColor.cobalt.opacity(0.7), radius: 5)
                    .offset(x: x - 1)

                Circle()
                    .fill(BEMColor.cobalt)
                    .stroke(BEMColor.saltGlaze, lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .shadow(color: BEMColor.cobalt.opacity(0.9), radius: 6)
                    .offset(x: x - 7, y: dotY - 7)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let f = min(max(value.location.x / width, 0), 1)
                        minutes = (SunModel.dayStart + f * (SunModel.dayEnd - SunModel.dayStart)).rounded()
                    }
            )
        }
        .accessibilityRepresentation {
            Slider(value: $minutes, in: SunModel.dayStart...SunModel.dayEnd, step: 5) {
                Text("sun.scrubber")
            }
        }
    }

    /// Baseline sits 2pt off the bottom; a full-height sun stops 10pt short of
    /// the top so the dot never clips.
    private func y(forWeight weight: Double, in height: Double) -> Double {
        height - 2 - weight * (height - 10)
    }

    /// Linear interpolation between samples. 96 of them across 17 hours is a
    /// point every eleven minutes, and the curve has no feature finer than
    /// that.
    private func weight(atFraction fraction: Double) -> Double {
        guard curve.count > 1 else { return curve.first?.weight ?? 0 }
        let clamped = min(max(fraction, 0), 1)
        let scaled = clamped * Double(curve.count - 1)
        let lower = Int(scaled)
        guard lower < curve.count - 1 else { return curve[curve.count - 1].weight }
        let t = scaled - Double(lower)
        return curve[lower].weight * (1 - t) + curve[lower + 1].weight * t
    }

    private func path(in size: CGSize, closed: Bool) -> Path {
        var path = Path()
        guard let first = curve.first else { return path }
        path.move(to: CGPoint(x: 0, y: y(forWeight: first.weight, in: size.height)))
        for point in curve.dropFirst() {
            path.addLine(
                to: CGPoint(x: point.fraction * size.width, y: y(forWeight: point.weight, in: size.height))
            )
        }
        if closed {
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
        return path
    }
}
