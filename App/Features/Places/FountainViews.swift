import BEMBELKit
import MapKit
import SwiftUI

/// The Trinkbrunnen segment's rendering: pin, filter bar and detail card.
/// The tab shell around them is `PlacesView` (ADR 0009); the seasonal rule and
/// the sampled/unsampled distinction live in the kit and are real (BEM-E02).
struct FountainPin: View {
    let fountain: Fountain
    let selected: Bool

    private var state: FountainState { fountain.state() }

    var body: some View {
        Circle()
            .fill(fill)
            .stroke(BEMColor.saltGlaze, lineWidth: selected ? 3 : 2)
            .frame(width: selected ? 38 : 26, height: selected ? 38 : 26)
            .overlay {
                // Untested water gets the question mark, always — the shape
                // says it before any colour or card does.
                Image(systemName: fountain.tested == true ? "drop.fill" : "questionmark")
                    .font(selected ? .body : .caption2)
                    .foregroundStyle(BEMColor.inkOnCobalt)
            }
            .shadow(color: .black.opacity(selected ? 0.5 : 0), radius: 6, y: 4)
            .accessibilityLabel(Text(verbatim: fountain.name))
            .accessibilityValue(Text(state.labelKey))
    }

    private var fill: Color {
        switch (state.hasWater, fountain.tested) {
        case (false, _): BEMColor.inkSecondary
        // Water now, but nobody samples it: not the same green as a tested one.
        case (true, false), (true, .none): BEMColor.caution
        case (true, .some(true)): BEMColor.good
        }
    }
}

/// Kind chips for the Trinkbrunnen segment, generated from the data in the
/// selected ring — the same rule as `MerkmalBar`.
struct FountainKindBar: View {
    @Bindable var model: PlacesModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BEMSpacing.s) {
                SelectionChip(
                    title: Text("places.merkmale.all"),
                    isSelected: model.selectedKinds.isEmpty,
                    glass: true
                ) {
                    model.selectedKinds = []
                }

                ForEach(model.availableKinds) { kind in
                    SelectionChip(
                        title: Text(kind.titleKey),
                        isSelected: model.selectedKinds.contains(kind),
                        glass: true
                    ) {
                        model.toggle(kind)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Text("water.kinds.a11y"))
    }
}

struct FountainDetailCard: View {
    let ranked: RankedFountain

    private var fountain: Fountain { ranked.fountain }
    private var state: FountainState { fountain.state() }

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
                    subtitle
                        .font(BEMFont.dataLabel)
                        .foregroundStyle(BEMColor.inkSecondary)
                }
                Spacer()
                StatusCapsule(
                    label: Text(state.labelKey), color: state.hasWater ? BEMColor.good : BEMColor.inkSecondary)
            }

            VStack(spacing: 1) {
                detailRow(icon: "calendar.badge.checkmark", label: "water.season", value: Text(seasonKey))
                Divider().overlay(BEMColor.glazeLine)
                detailRow(icon: "clock", label: "water.hours", value: Text(hoursKey))
                Divider().overlay(BEMColor.glazeLine)
                detailRow(icon: qualityIcon, label: "water.quality", value: Text(qualityKey))
            }
            .background(BEMColor.saltGlazeElevated)
            .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))

            // The one thing on this card somebody could get sick over.
            if fountain.tested != true {
                Text("water.quality.untested.note")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.ink)
                    .padding(BEMSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BEMColor.saltGlazeElevated, in: RoundedRectangle(cornerRadius: BEMRadius.control))
            }

            Text("water.season.note")
                .font(.footnote)
                .foregroundStyle(BEMColor.inkSecondary)

            HStack(spacing: BEMSpacing.s + 2) {
                CobaltButton(title: Text("water.route"), systemImage: "location.north.fill") {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: fountain.coordinate))
                    item.name = fountain.name
                    item.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
                    ])
                }
            }

            if let source = fountain.sources.first {
                Link(destination: source) {
                    SourceLine(systemImage: "link", text: Text("water.source"))
                }
            } else {
                SourceLine(systemImage: "link", text: Text("water.source"))
            }
        }
        .bemDetailCard()
    }

    /// Distance only when it is real. Without a fix the line names the kind
    /// instead of inventing "220 m".
    @ViewBuilder
    private var subtitle: some View {
        if let distance = ranked.distance {
            Text("water.distance \(distance.label) \(distance.walkMinutes)")
        } else {
            Text(fountain.kind.titleKey)
        }
    }

    private var seasonKey: LocalizedStringKey {
        switch state {
        case .running: "water.season.range"
        case .closedForWinter: "water.season.from"
        case .notYetInSeason: "water.season.easter"
        case .closedForNow, .closedForToday: "water.season.range"
        case .unknown: "water.season.shop"
        case .outOfService: "water.status.outofservice"
        }
    }

    private var hoursKey: LocalizedStringKey {
        switch fountain.kind {
        case .historisch: "water.hours.historic"
        case .refill: "water.hours.shop"
        default: "water.hours.always"
        }
    }

    private var qualityKey: LocalizedStringKey {
        switch fountain.tested {
        case .some(true): "water.quality.drinking"
        case .some(false): "water.quality.untested"
        case .none: "water.quality.unknown"
        }
    }

    private var qualityIcon: String {
        fountain.tested == true ? "checkmark.seal" : "questionmark.circle"
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
}

extension FountainState {
    var labelKey: LocalizedStringKey {
        switch self {
        case .running: "water.status.open"
        case .closedForWinter: "water.status.winter"
        case .notYetInSeason: "water.status.easter"
        case .closedForNow: "water.status.later"
        case .closedForToday: "water.status.tomorrow"
        case .unknown: "water.status.unknown"
        case .outOfService: "water.status.outofservice"
        }
    }
}

extension FountainKind {
    var titleKey: LocalizedStringKey {
        switch self {
        case .stadt: "water.kind.stadt"
        case .historisch: "water.kind.historisch"
        case .mainova: "water.kind.mainova"
        case .refill: "water.kind.refill"
        case .sonstige: "water.kind.sonstige"
        }
    }
}
