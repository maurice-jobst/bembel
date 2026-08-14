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
    @AppStorage(StickerState.visitDetectionKey, store: AppGroup.defaults) private var visitDetection = false
    @State private var visitMonitor = KioskVisitMonitor()
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.1122, longitude: 8.6780),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    var body: some View {
        ZStack {
            map
            VStack(spacing: BEMSpacing.m) {
                HStack {
                    Spacer()
                    GlassCircleButton(systemImage: "chart.bar.doc.horizontal", accessibilityLabel: "coverage.title") {
                        isShowingCoverage = true
                    }
                }
                registerPicker
                if model.selectedRegister.isCommunity {
                    MerkmalBar(model: model)
                }
                Spacer()
                detailCard
            }
            .padding(.horizontal, BEMSpacing.m)
        }
        .task {
            await model.load(register: dependencies.register, fountains: dependencies.fountains)
        }
        .task(id: visitDetection) {
            guard visitDetection else {
                visitMonitor.stop()
                return
            }
            let entries = VisitMonitor.candidates(
                from: model.snapshot.entries(in: .wasserhaeuschen),
                near: position.region?.center ?? CLLocationCoordinate2D(latitude: 50.1122, longitude: 8.6780)
            )
            await visitMonitor.start(for: entries) { entryID in
                StickerState.recordVisit(entryID: entryID)
            }
        }
        .onChange(of: router.selectedRegister) { _, new in
            model.select(register: new)
        }
        .sheet(isPresented: $isShowingCoverage) {
            CoverageView(model: model)
        }
    }

    @ViewBuilder
    private var map: some View {
        Map(position: $position) {
            if model.selectedRegister == .trinkbrunnen {
                ForEach(model.fountains) { fountain in
                    Annotation(fountain.name, coordinate: fountain.coordinate) {
                        FountainPin(featured: fountain.id == model.selectedFountain?.id)
                            .onTapGesture { model.selectedFountain = fountain }
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

    private var registerBinding: Binding<PlaceRegister> {
        Binding(get: { model.selectedRegister }, set: { model.select(register: $0) })
    }

    @ViewBuilder
    private var detailCard: some View {
        if model.selectedRegister == .trinkbrunnen {
            if let fountain = model.selectedFountain {
                FountainDetailCard(fountain: fountain)
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
