import BEMBELKit
import MapKit
import SwiftUI

/// Schattenkarte: map with a cobalt-tinted shadow layer that follows the
/// time scrubber. The scrubber sits on a sun-elevation curve (variant 1d of
/// the design doc). The tint uses a crude solar model; the real LoD2 shadow
/// index replaces both at BEM-D02.
struct ShadowView: View {
    @Environment(Router.self) private var router
    @State private var minutes: Double = 885
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.1109, longitude: 8.6714),
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    )

    private var sun: SunSample { SunModel.sample(atMinutes: minutes) }

    var body: some View {
        ZStack {
            Map(position: $position)
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .overlay {
                    // Stand-in for the LoD2 shadow raster: a flat cobalt wash
                    // whose weight follows the sun. BEM-D02 replaces this.
                    BEMColor.cobaltDeep
                        .opacity(0.32 * (1 - Double(sun.elevation) / 58))
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()

            VStack {
                topControls
                Spacer()
                scrubberCard
            }
            .padding(.horizontal, BEMSpacing.m)
        }
    }

    private var topControls: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.cobalt)
                Text(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BEMColor.ink)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: .capsule)
            .overlay(Capsule().stroke(BEMColor.glazeLine.opacity(0.5), lineWidth: 0.5))

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
        VStack(spacing: BEMSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: SunModel.clockLabel(minutes: minutes))
                    .font(BEMFont.boardLarge)
                    .foregroundStyle(BEMColor.ink)
                Text("shadow.sun \(sun.elevation) \(String(localized: sun.westward ? "shadow.direction.west" : "shadow.direction.east"))")
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
                Spacer()
                Button {
                    minutes = SunModel.nowMinutes()
                } label: {
                    Text("shadow.now")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BEMColor.cobalt)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .overlay(Capsule().stroke(BEMColor.cobalt, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            SunCurveScrubber(minutes: $minutes)
                .frame(height: 58)

            HStack {
                Text(verbatim: "05:30")
                Spacer()
                Text(verbatim: "13:00")
                Spacer()
                Text(verbatim: "21:30")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(BEMColor.inkSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.top, BEMSpacing.m)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BEMRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: BEMRadius.card)
                .stroke(BEMColor.glazeLine.opacity(0.5), lineWidth: 0.5)
        )
        .padding(.bottom, BEMSpacing.s)
    }
}

/// Draggable sun-elevation curve: filled arc, marker line, dot riding the
/// curve.
struct SunCurveScrubber: View {
    @Binding var minutes: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let fraction = (minutes - SunModel.dayStart) / (SunModel.dayEnd - SunModel.dayStart)
            let x = fraction * width
            let dotY = height - 2 - (Double(SunModel.sample(atMinutes: minutes).elevation) / 58) * (height - 10)

            ZStack(alignment: .topLeading) {
                curve(in: geo.size, closed: true)
                    .fill(BEMColor.cobalt.opacity(0.13))
                curve(in: geo.size, closed: false)
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
                Text("shadow.scrubber")
            }
        }
    }

    private func curve(in size: CGSize, closed: Bool) -> Path {
        let w = size.width
        let h = size.height
        // The design's curve, normalized from its 340×58 viewBox.
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h * 0.965))
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.138),
            control1: CGPoint(x: w * 0.135, y: h * 0.965),
            control2: CGPoint(x: w * 0.182, y: h * 0.172)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.965),
            control1: CGPoint(x: w * 0.818, y: h * 0.172),
            control2: CGPoint(x: w * 0.865, y: h * 0.965)
        )
        if closed {
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.closeSubpath()
        }
        return path
    }
}

struct SunSample {
    let elevation: Int
    let westward: Bool
}

/// Crude solar model for Frankfurt in summer, elevation peaking early
/// afternoon — enough to drive the UI honestly until real ephemeris and the
/// LoD2 index land (BEM-D02).
enum SunModel {
    static let dayStart: Double = 330 // 05:30
    static let dayEnd: Double = 1290 // 21:30

    static func sample(atMinutes minutes: Double) -> SunSample {
        let t = (minutes - 800) / 470
        let elevation = max(2, Int((58 * (1 - t * t)).rounded()))
        return SunSample(elevation: elevation, westward: minutes < 800)
    }

    static func clockLabel(minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return String(format: "%02d:%02d", h, m)
    }

    static func nowMinutes() -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: .now)
        let mins = Double((parts.hour ?? 12) * 60 + (parts.minute ?? 0))
        return min(max(mins, dayStart), dayEnd)
    }
}
