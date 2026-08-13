import BEMBELKit
import MapKit
import SwiftUI

/// Trinkwasser: fountain map with filter chips, detail as a persistent
/// bottom card. Renders whatever the injected `FountainProviding` returns;
/// the seasonal rule lives in the kit and is real.
struct WaterView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var model = WaterModel()
    @State private var selectedFilter = WaterFilter.fountains
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.1122, longitude: 8.6780),
            span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)
        )
    )

    var body: some View {
        ZStack {
            Map(position: $position) {
                ForEach(model.fountains) { fountain in
                    Annotation(fountain.name, coordinate: fountain.coordinate) {
                        FountainPin(featured: fountain.id == model.selectedFountain?.id)
                            .onTapGesture { model.selectedFountain = fountain }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea()

            VStack(spacing: BEMSpacing.m) {
                searchRow
                filterChips
                Spacer()
                if let fountain = model.selectedFountain {
                    FountainDetailCard(fountain: fountain)
                }
            }
            .padding(.horizontal, BEMSpacing.m)
        }
        .task {
            await model.load(from: dependencies.fountains)
        }
    }

    private var searchRow: some View {
        HStack(spacing: BEMSpacing.s) {
            HStack(spacing: BEMSpacing.s) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                Text("water.search")
                    .font(.subheadline)
            }
            .foregroundStyle(BEMColor.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: .capsule)
            .overlay(Capsule().stroke(BEMColor.glazeLine.opacity(0.5), lineWidth: 0.5))

            GlassCircleButton(systemImage: "location", accessibilityLabel: "action.locate")
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BEMSpacing.s) {
                ForEach(WaterFilter.allCases) { filter in
                    SelectionChip(title: Text(filter.titleKey), isSelected: filter == selectedFilter, glass: true) {
                        selectedFilter = filter
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum WaterFilter: CaseIterable, Identifiable {
    case fountains
    case refill
    case openOnly

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .fountains: "water.filter.fountains"
        case .refill: "water.filter.refill"
        case .openOnly: "water.filter.open"
        }
    }
}

struct FountainPin: View {
    let featured: Bool

    var body: some View {
        if featured {
            Circle()
                .fill(BEMColor.cobalt)
                .stroke(BEMColor.saltGlaze, lineWidth: 2.5)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "drop.fill")
                        .font(.body)
                        .foregroundStyle(BEMColor.inkOnCobalt)
                }
                .shadow(color: .black.opacity(0.5), radius: 6, y: 4)
        } else {
            Circle()
                .fill(FountainSeason.isOpen() ? BEMColor.good : BEMColor.inkSecondary)
                .stroke(BEMColor.saltGlaze, lineWidth: 2)
                .frame(width: 26, height: 26)
        }
    }
}

struct FountainDetailCard: View {
    let fountain: Fountain
    private let open = FountainSeason.isOpen()

    var body: some View {
        VStack(alignment: .leading, spacing: BEMSpacing.m) {
            Capsule()
                .fill(BEMColor.glazeLine)
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: BEMSpacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: fountain.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BEMColor.ink)
                    Text("water.distance \(fountain.distanceLabel) \(fountain.walkMinutes)")
                        .font(BEMFont.dataLabel)
                        .foregroundStyle(BEMColor.inkSecondary)
                }
                Spacer()
                StatusCapsule(
                    label: Text(open ? "water.status.open" : "water.status.closed"),
                    color: open ? BEMColor.good : BEMColor.inkSecondary
                )
            }

            VStack(spacing: 1) {
                detailRow(
                    icon: "calendar.badge.checkmark", label: "water.season",
                    value: Text(open ? "water.season.range" : "water.season.from"))
                Divider().overlay(BEMColor.glazeLine)
                detailRow(icon: "clock", label: "water.hours", value: Text("water.hours.always"))
                Divider().overlay(BEMColor.glazeLine)
                detailRow(icon: "drop.halffull", label: "water.quality", value: Text("water.quality.drinking"))
            }
            .background(BEMColor.saltGlazeElevated)
            .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))

            Text("water.season.note")
                .font(.footnote)
                .foregroundStyle(BEMColor.inkSecondary)

            HStack(spacing: BEMSpacing.s + 2) {
                CobaltButton(title: Text("water.route"), systemImage: "location.north.fill") {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: fountain.coordinate))
                    item.name = fountain.name
                    item.openInMaps()
                }
                squareAction(icon: "bookmark", label: "water.bookmark")
                squareAction(icon: "square.and.arrow.up", label: "water.share")
            }

            SourceLine(systemImage: "link", text: Text("water.source"))
        }
        .padding(.horizontal, BEMSpacing.l)
        .padding(.top, BEMSpacing.s)
        .padding(.bottom, BEMSpacing.l)
        .background(BEMColor.saltGlaze, in: RoundedRectangle(cornerRadius: BEMRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: BEMRadius.card)
                .stroke(BEMColor.glazeLine.opacity(0.6), lineWidth: 0.5)
        )
        .padding(.bottom, BEMSpacing.s)
    }

    private func detailRow(icon: String, label: LocalizedStringKey, value: Text) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(BEMColor.inkSecondary)
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(BEMColor.ink)
            Spacer()
            value
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(BEMColor.inkSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, BEMSpacing.m)
        .background(BEMColor.saltGlazeElevated)
    }

    private func squareAction(icon: String, label: LocalizedStringKey) -> some View {
        Button {
        } label: {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(BEMColor.cobalt)
                .frame(width: 48, height: 48)
                .overlay(RoundedRectangle(cornerRadius: BEMRadius.control).stroke(BEMColor.glazeLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
