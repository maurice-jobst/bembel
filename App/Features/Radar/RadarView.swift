import BEMBELKit
import MapKit
import SwiftUI

/// Regenradar: Rhein-Main map, nowcast headline, 90-minute timeline.
/// Rain cells and times are sample values until DWD RADOLAN is wired.
struct RadarView: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.11, longitude: 8.63),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    )

    var body: some View {
        ZStack {
            Map(position: $position)
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .overlay { SampleRainCells().allowsHitTesting(false) }
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                topRow
                Spacer()
                legend
                    .padding(.bottom, BEMSpacing.m)
                timelineCard
            }
            .padding(.horizontal, BEMSpacing.m)
        }
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: SampleData.radarHeadline)
                    .font(.body.weight(.bold))
                    .foregroundStyle(BEMColor.ink)
                Text(verbatim: SampleData.radarDetail)
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BEMRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: BEMRadius.card)
                    .stroke(BEMColor.glazeLine.opacity(0.5), lineWidth: 0.5)
            )

            Spacer()

            GlassCircleButton(systemImage: "location", accessibilityLabel: "action.locate")
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("radar.legend.unit")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(BEMColor.inkSecondary)
            legendRow(color: BEMColor.cobaltDeep.opacity(0.4), value: "0,3")
            legendRow(color: BEMColor.cobaltDeep, value: "2")
            legendRow(color: BEMColor.cobalt, value: "10")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BEMColor.glazeLine.opacity(0.5), lineWidth: 0.5))
    }

    private func legendRow(color: Color, value: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 26, height: 8)
            Text(verbatim: value)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(BEMColor.inkSecondary)
        }
    }

    private var timelineCard: some View {
        VStack(spacing: BEMSpacing.s + 2) {
            HStack(spacing: BEMSpacing.m) {
                Button {} label: {
                    Circle()
                        .fill(BEMColor.cobalt)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.body)
                                .foregroundStyle(BEMColor.inkOnCobalt)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("radar.play")

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: BEMSpacing.s) {
                        Text(verbatim: SampleData.radarClock)
                            .font(BEMFont.board)
                            .foregroundStyle(BEMColor.ink)
                        Text("radar.now")
                            .font(BEMFont.dataLabel)
                            .foregroundStyle(BEMColor.cobalt)
                    }
                    timelineTrack
                }
            }

            HStack {
                Text(verbatim: "−60")
                Spacer()
                Text(verbatim: "−30")
                Spacer()
                Text("radar.now")
                Spacer()
                Text(verbatim: "+45")
                Spacer()
                Text(verbatim: "+90 Min")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(BEMColor.inkSecondary)

            SourceLine(systemImage: "arrow.trianglehead.2.clockwise", text: Text("radar.source \(SampleData.radarStamp)"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BEMRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: BEMRadius.card)
                .stroke(BEMColor.glazeLine.opacity(0.5), lineWidth: 0.5)
        )
        .padding(.bottom, BEMSpacing.s)
    }

    private var timelineTrack: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(BEMColor.glazeLine)
                    .frame(height: 4)
                Capsule()
                    .fill(BEMColor.cobaltDeep)
                    .frame(width: width * 0.4, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(BEMColor.cobalt)
                    .frame(width: 3, height: 18)
                    .shadow(color: BEMColor.cobalt.opacity(0.8), radius: 5)
                    .offset(x: width * 0.4)
            }
            .frame(height: geo.size.height)
        }
        .frame(height: 18)
    }
}

/// Decorative sample rain cells; DWD RADOLAN tiles replace this overlay.
struct SampleRainCells: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                cell(x: 0.33, y: 0.37, size: 0.52, color: BEMColor.cobaltDeep, opacity: 0.5, in: geo.size)
                cell(x: 0.36, y: 0.38, size: 0.26, color: BEMColor.cobalt, opacity: 0.85, in: geo.size)
                cell(x: 0.73, y: 0.54, size: 0.34, color: BEMColor.cobaltDeep, opacity: 0.4, in: geo.size)
                cell(x: 0.18, y: 0.6, size: 0.27, color: BEMColor.cobaltDeep, opacity: 0.32, in: geo.size)

                Circle()
                    .fill(BEMColor.ink)
                    .stroke(BEMColor.cobalt, lineWidth: 3)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(BEMColor.cobalt.opacity(0.22)).frame(width: 26, height: 26))
                    .position(x: w * 0.48, y: h * 0.43)
            }
        }
    }

    private func cell(x: Double, y: Double, size: Double, color: Color, opacity: Double, in canvas: CGSize) -> some View {
        Ellipse()
            .fill(color)
            .opacity(opacity * 0.75)
            .frame(width: canvas.width * size, height: canvas.width * size * 0.72)
            .blur(radius: 22)
            .position(x: canvas.width * x, y: canvas.height * y)
    }
}
