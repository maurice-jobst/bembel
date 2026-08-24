import BEMBELKit
import MapKit
import SwiftUI

/// Regenradar: Rhein-Main map with the real DWD nowcast painted over it, and a
/// timeline that plays the next two hours.
///
/// The overlay used to be four blurred ellipses — a picture of weather that was
/// not happening, drawn over a real map at real coordinates while the headline
/// above it came from the actual radar. It is now the composite itself.
struct RadarView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.colorScheme) private var colorScheme
    @State private var model = RadarModel()
    @State private var position: MapCameraPosition = .region(RadarView.openingRegion)

    /// Rhein-Main, unless `DebugRadarRegion` has moved the drawn box — a debug
    /// overlay you cannot see is not a debug overlay.
    private static var openingRegion: MKCoordinateRegion {
        #if DEBUG
            if let bounds = DebugRadarRegion.bounds {
                return MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: (bounds.south + bounds.north) / 2,
                        longitude: (bounds.west + bounds.east) / 2
                    ),
                    span: MKCoordinateSpan(
                        latitudeDelta: bounds.latitudeSpan, longitudeDelta: bounds.longitudeSpan)
                )
            }
        #endif
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.11, longitude: 8.63),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    }

    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $position)
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .overlay { rainOverlay(proxy).allowsHitTesting(false) }
                    .ignoresSafeArea()
            }

            VStack(alignment: .leading, spacing: 0) {
                topRow
                Spacer()
                // A key to a scale nothing is drawn on is furniture. When the
                // radar failed there is no scale, so there is no key either.
                if !model.frames.isEmpty {
                    legend
                        .padding(.bottom, BEMSpacing.m)
                }
                timelineCard
            }
            .padding(.horizontal, BEMSpacing.m)
        }
        .task {
            await model.load(from: dependencies.radar, scheme: colorScheme)
        }
        .onChange(of: colorScheme) { _, scheme in
            model.repaint(for: scheme)
        }
        .onDisappear { model.pause() }
    }

    // MARK: - Overlay

    /// The frame stretched across its `RadarBounds`.
    ///
    /// A lat/lon box is an axis-aligned rectangle in the map's Mercator
    /// projection, so the two corners are enough — but Mercator's latitude
    /// spacing is not linear, and a straight stretch puts the middle of this
    /// box about 186 m off. That is under a fifth of the radar's own 1 km cell,
    /// which is why it is a comment rather than a correction. Resample the
    /// frame in Mercator-y if the box ever grows past a degree or so.
    @ViewBuilder private func rainOverlay(_ proxy: MapProxy) -> some View {
        if let image = model.currentImage, let bounds = model.nowcast.value?.bounds {
            let northWest = proxy.convert(
                CLLocationCoordinate2D(latitude: bounds.north, longitude: bounds.west), to: .local)
            let southEast = proxy.convert(
                CLLocationCoordinate2D(latitude: bounds.south, longitude: bounds.east), to: .local)

            if let northWest, let southEast {
                let width = southEast.x - northWest.x
                let height = southEast.y - northWest.y
                if width > 0, height > 0 {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)  // 1 km cells stay 1 km cells
                        .resizable()
                        .frame(width: width, height: height)
                        .position(x: northWest.x + width / 2, y: northWest.y + height / 2)
                        .animation(.linear(duration: 0.12), value: model.playhead)
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                switch model.nowcast {
                case .idle, .loading:
                    Text("radar.loading")
                        .font(.body.weight(.bold))
                        .foregroundStyle(BEMColor.ink)
                case .loaded(let nowcast):
                    Text(outlookHeadline(nowcast.outlook))
                        .font(.body.weight(.bold))
                        .foregroundStyle(BEMColor.ink)
                    Text(outlookDetail(nowcast.outlook))
                        .font(.footnote)
                        .foregroundStyle(BEMColor.inkSecondary)
                case .failed:
                    Text("radar.unavailable")
                        .font(.body.weight(.bold))
                        .foregroundStyle(BEMColor.ink)
                    Text("city.source.unavailable \("DWD")")
                        .font(.footnote)
                        .foregroundStyle(BEMColor.inkSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .bemGlassCard()

            Spacer()

            GlassCircleButton(systemImage: "location", accessibilityLabel: "action.locate")
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("radar.legend.unit")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(BEMColor.inkSecondary)
            // Every band the map can draw, in the order it draws them. A legend
            // that lists three of six is a legend you cannot read a map with.
            ForEach(Array(RadarRainScale.boundaries.enumerated()), id: \.offset) { index, boundary in
                legendRow(
                    color: RadarRainScale.colour(band: index, scheme: colorScheme),
                    value: boundaryLabel(index: index, boundary: boundary)
                )
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        // Was a hardcoded 12, which matches no token. This is a small floating
        // control, so it takes the control radius rather than the card one.
        .bemGlassCard(cornerRadius: BEMRadius.control)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("radar.legend.accessibility")
    }

    /// "0,5", "1", … and "20+" on the open-ended top band.
    private func boundaryLabel(index: Int, boundary: Float) -> String {
        let number = Self.rateFormatter.string(from: boundary as NSNumber) ?? "—"
        return index == RadarRainScale.boundaries.count - 1 ? "\(number)+" : number
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

    @ViewBuilder private var timelineCard: some View {
        if let nowcast = model.nowcast.value, !model.frames.isEmpty {
            VStack(spacing: BEMSpacing.s + 2) {
                HStack(spacing: BEMSpacing.m) {
                    playButton
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: BEMSpacing.s) {
                            Text(verbatim: nowcast.clockLabel(atMinute: model.currentMinute) ?? "—")
                                .font(BEMFont.board)
                                .foregroundStyle(BEMColor.ink)
                                .contentTransition(.numericText())
                            Text(playheadCaption)
                                .font(BEMFont.dataLabel)
                                .foregroundStyle(BEMColor.cobalt)
                        }
                        timelineTrack
                    }
                }

                axis(horizon: nowcast.horizonMinutes)

                SourceLine(
                    systemImage: "arrow.trianglehead.2.clockwise",
                    text: Text("radar.source \(nowcast.stampLabel)")
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .bemGlassCard()
            .padding(.bottom, BEMSpacing.s)
        }
    }

    private var playButton: some View {
        Button {
            model.togglePlayback()
        } label: {
            Circle()
                .fill(BEMColor.cobalt)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.body)
                        .foregroundStyle(BEMColor.inkOnCobalt)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.isPlaying ? "radar.pause" : "radar.play")
    }

    /// "jetzt" at the head of the forecast, "+25 Min" anywhere else.
    private var playheadCaption: LocalizedStringKey {
        model.currentMinute == 0 ? "radar.now" : "radar.ahead \(model.currentMinute)"
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
                    .frame(width: width * model.progress, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(BEMColor.cobalt)
                    .frame(width: 3, height: 18)
                    .shadow(color: BEMColor.cobalt.opacity(0.8), radius: 5)
                    .offset(x: width * model.progress)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard width > 0 else { return }
                        model.scrub(to: value.location.x / width)
                    }
            )
        }
        .frame(height: 18)
        .accessibilityElement()
        .accessibilityLabel("radar.timeline")
        .accessibilityValue(Text("radar.ahead \(model.currentMinute)"))
        .accessibilityAdjustableAction { direction in
            model.step(by: direction == .increment ? 1 : -1)
        }
    }

    /// The axis is the data's own horizon, read from the composite.
    ///
    /// It used to read −60…+90, which was the design's guess and matched
    /// nothing: RV is a *nowcast*, it starts at the measurement and runs
    /// forward two hours. There is no past hour in this product, so the axis
    /// no longer draws one. Showing where the rain has been needs RADOLAN's
    /// observation series, which is a different product and its own ticket.
    private func axis(horizon: Int) -> some View {
        HStack {
            Text("radar.now")
            Spacer()
            Text(verbatim: "+\(horizon / 4)")
            Spacer()
            Text(verbatim: "+\(horizon / 2)")
            Spacer()
            Text(verbatim: "+\(horizon * 3 / 4)")
            Spacer()
            Text("radar.axis.end \(horizon)")
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(BEMColor.inkSecondary)
    }

    private nonisolated(unsafe) static let rateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    // MARK: - Outlook wording

    private func outlookHeadline(_ outlook: RainOutlook) -> LocalizedStringKey {
        switch outlook {
        case .rainingNow: "radar.outlook.now"
        case .rainStarting(let minutes, _, _): "radar.outlook.starting \(minutes)"
        case .dry: "radar.outlook.dry"
        case .noData: "radar.outlook.nodata"
        }
    }

    private func outlookDetail(_ outlook: RainOutlook) -> LocalizedStringKey {
        switch outlook {
        case .rainingNow(let intensity, let remaining):
            if let remaining {
                "radar.detail.now \(intensityWord(intensity)) \(remaining)"
            } else {
                // The rain runs past the end of the composite. "Two more hours"
                // would be a promise the radar never made.
                "radar.detail.now.beyond \(intensityWord(intensity))"
            }
        case .rainStarting(_, let intensity, let lasting):
            "radar.detail.starting \(intensityWord(intensity)) \(lasting)"
        case .dry(let horizon):
            "radar.detail.dry \(horizon)"
        case .noData:
            "radar.detail.nodata"
        }
    }

    /// The intensity words are their own keys so a translator sees them as
    /// words, not as a fragment glued into a sentence at runtime.
    private func intensityWord(_ intensity: RainIntensity) -> String {
        switch intensity {
        case .light: String(localized: "radar.intensity.light")
        case .moderate: String(localized: "radar.intensity.moderate")
        case .heavy: String(localized: "radar.intensity.heavy")
        }
    }
}
