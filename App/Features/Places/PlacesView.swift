import BEMBELKit
import MapKit
import SwiftUI

/// Orte: the community registers plus the drinking fountains, one map, one
/// segmented control. The hero surface — Merkmale are the navigation, not a
/// filter buried in a sheet.
struct PlacesView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(Router.self) private var router
    @State private var model = PlacesModel()
    @State private var isShowingCoverage = false
    @State private var isShowingAlbum = false
    @AppStorage(StickerState.visitDetectionKey, store: AppGroup.defaults) private var visitDetection = false
    @State private var visitMonitor = KioskVisitMonitor()
    @State private var location = UserLocation()
    @AppStorage(RegionSettings.selectedRingKey, store: AppGroup.defaults)
    private var selectedRingRaw = RegionSettings.defaultRing.rawValue
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: PlacesView.frankfurtCenter,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    /// Where the user is actually looking. `position.region` only answers for
    /// camera positions this view set itself — after a pan it is stale, and
    /// both the visit monitor and the widget digest need the real centre.
    @State private var visibleCenter = PlacesView.frankfurtCenter

    var body: some View {
        ZStack {
            map
            VStack(spacing: BEMSpacing.m) {
                HStack(spacing: BEMSpacing.s) {
                    Spacer()
                    GlassCircleButton(systemImage: "seal", accessibilityLabel: "stickers.title") {
                        isShowingAlbum = true
                    }
                    GlassCircleButton(systemImage: "chart.bar.doc.horizontal", accessibilityLabel: "coverage.title") {
                        isShowingCoverage = true
                    }
                }
                registerPicker
                if model.selectedRegister.isCommunity {
                    MerkmalBar(model: model)
                } else {
                    FountainKindBar(model: model)
                }
                Spacer()
                detailCard
            }
            .padding(.horizontal, BEMSpacing.m)
        }
        .task {
            await model.load(register: dependencies.register, fountains: dependencies.fountains)
            location.refresh()
        }
        // The ring lives in Settings and is shared with the widgets; reading it
        // here means switching it re-filters map and list with no relaunch.
        .onChange(of: selectedRingRaw, initial: true) { _, raw in
            model.selectedRing = Ring(rawValue: raw) ?? RegionSettings.defaultRing
        }
        .onChange(of: location.fix, initial: true) { _, fix in
            model.userCoordinate = fix?.coordinate
        }
        // Keyed on toggle *and* data: re-arms once the snapshot arrives, and
        // an empty snapshot never wipes previously registered conditions.
        .task(id: visitMonitorKey) {
            guard visitDetection else {
                visitMonitor.stop()
                return
            }
            let entries = VisitMonitor.candidates(
                from: model.snapshot.entries(in: .wasserhaeuschen),
                near: visibleCenter
            )
            guard !entries.isEmpty else { return }
            await visitMonitor.start(for: entries) { entryID in
                StickerState.recordVisit(entryID: entryID)
            }
        }
        // Same keying rule as the monitor: data plus a coarse centre, so a pan
        // across the street does not rewrite the widget's payload.
        .task(id: digestKey) {
            model.publishCandidateDigest(near: visibleCenter)
        }
        // `initial: true` covers the cold-start deep link — the router may
        // already carry a register before this view ever appears.
        .onChange(of: router.selectedRegister, initial: true) { _, new in
            model.select(register: new)
        }
        // Consumed, not observed: the id is handed over once and cleared, so
        // opening the same link twice is two distinct nil→id transitions.
        .onChange(of: router.pendingEntryID, initial: true) { _, pending in
            guard let pending else { return }
            model.focus(entryID: pending)
            router.pendingEntryID = nil
        }
        .onChange(of: model.focus) { _, focus in
            guard let focus else { return }
            // The entry may live in another register than the link named.
            router.selectedRegister = model.selectedRegister
            withAnimation {
                position = .region(
                    MKCoordinateRegion(
                        center: focus.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
                    )
                )
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleCenter = context.region.center
        }
        .sheet(isPresented: $isShowingCoverage) {
            CoverageView(model: model)
        }
        .sheet(isPresented: $isShowingAlbum) {
            StickerAlbumView(model: model)
        }
    }

    @ViewBuilder
    private var map: some View {
        Map(position: $position) {
            if model.selectedRegister == .trinkbrunnen {
                ForEach(model.visibleFountains) { ranked in
                    Annotation(ranked.fountain.name, coordinate: ranked.fountain.coordinate) {
                        FountainPin(
                            fountain: ranked.fountain,
                            selected: ranked.id == model.selectedFountain?.id
                        )
                        .onTapGesture { model.selectedFountain = ranked.fountain }
                    }
                    .annotationTitles(.hidden)
                }
            } else {
                ForEach(model.visibleEntries) { entry in
                    Annotation(entry.name, coordinate: entry.coordinate) {
                        EntryPin(entry: entry, selected: entry.id == model.selectedEntry?.id)
                            .onTapGesture { model.selectedEntry = entry }
                    }
                    .annotationTitles(.hidden)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .ignoresSafeArea()
    }

    private var registerPicker: some View {
        Picker("places.register.picker", selection: registerBinding) {
            ForEach(PlaceRegister.allCases) { register in
                Text(register.titleKey).tag(register)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// The router is the single source of truth for the selected register —
    /// segment taps write back to it, so a later deep link to the "same"
    /// value cannot be silently dropped by an unchanged-value `onChange`.
    private var registerBinding: Binding<PlaceRegister> {
        Binding(
            get: { model.selectedRegister },
            set: { new in
                model.select(register: new)
                router.selectedRegister = new
            }
        )
    }

    private var visitMonitorKey: String {
        visitDetection ? "on-\(model.snapshot.entries.count)" : "off"
    }

    /// ~100 m of pan resolution. Finer than that is churn: the digest exists to
    /// name a candidate worth walking to, not to track the camera.
    private var digestKey: String {
        let latitude = (visibleCenter.latitude * 1000).rounded()
        let longitude = (visibleCenter.longitude * 1000).rounded()
        return "\(model.snapshot.entries.count)-\(latitude)-\(longitude)"
    }

    static let frankfurtCenter = CLLocationCoordinate2D(latitude: 50.1122, longitude: 8.6780)

    @ViewBuilder
    private var detailCard: some View {
        if model.selectedRegister == .trinkbrunnen {
            if let ranked = model.visibleFountains.first(where: { $0.id == model.selectedFountain?.id }) {
                FountainDetailCard(ranked: ranked)
            }
        } else if let entry = model.selectedEntry {
            EntryDetailCard(entry: entry)
        }
    }
}

/// Pin for a register entry. A candidate — an entry nobody has verified yet —
/// is deliberately grey and hollow: it reads as an invitation, not as data.
struct EntryPin: View {
    let entry: RegisterEntry
    let selected: Bool

    var body: some View {
        Circle()
            .fill(entry.isCandidate ? BEMColor.saltGlazeElevated : BEMColor.cobalt)
            .stroke(entry.isCandidate ? BEMColor.glazeLine : BEMColor.saltGlaze, lineWidth: selected ? 3 : 2)
            .frame(width: selected ? 38 : 28, height: selected ? 38 : 28)
            .overlay {
                Image(systemName: entry.register == .ebbelwei ? "wineglass.fill" : "cup.and.saucer.fill")
                    .font(.footnote)
                    .foregroundStyle(entry.isCandidate ? BEMColor.inkSecondary : BEMColor.inkOnCobalt)
            }
            .shadow(color: .black.opacity(selected ? 0.5 : 0), radius: 6, y: 4)
    }
}

extension PlaceRegister {
    var titleKey: LocalizedStringKey {
        switch self {
        case .wasserhaeuschen: "places.register.wasserhaeuschen"
        case .ebbelwei: "places.register.ebbelwei"
        case .trinkbrunnen: "places.register.trinkbrunnen"
        }
    }
}

#Preview {
    PlacesView()
        .environment(Router())
}
