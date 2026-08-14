import BEMBELKit
import MapKit
import SwiftUI

/// Detail card for a register entry. Structure and chrome deliberately mirror
/// `FountainDetailCard` (same card shape, same radius, same padding scale) so
/// the segments feel like one surface.
struct EntryDetailCard: View {
    let entry: RegisterEntry
    @AppStorage(StickerState.loginKey, store: AppGroup.defaults) private var login = ""
    @State private var isRating = false

    var body: some View {
        VStack(alignment: .leading, spacing: BEMSpacing.m) {
            Capsule()
                .fill(BEMColor.glazeLine)
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)

            header
            if !entry.merkmale.isEmpty { merkmale }
            if let note = entry.note {
                Text(verbatim: note)
                    .font(.subheadline)
                    .foregroundStyle(BEMColor.ink)
            }
            ratings
            ProvenanceByline(provenance: entry.provenance, verified: entry.verified)
            if entry.isCandidate { candidateCallout }
            actions
            sources
        }
        .bemDetailCard()
        .sheet(isPresented: $isRating) {
            RatingSheet(entry: entry, login: login)
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: BEMSpacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: entry.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BEMColor.ink)
                Text(verbatim: entry.addressLine)
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
            Spacer()
            if let rating = entry.rating {
                StatusCapsule(
                    label: Text(verbatim: rating.average.formatted(.number.precision(.fractionLength(1)))),
                    color: BEMColor.cobalt
                )
            }
        }
    }

    private var merkmale: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BEMSpacing.s) {
                ForEach(entry.merkmale) { merkmal in
                    HStack(spacing: 5) {
                        Image(systemName: merkmal.systemImage).font(.caption2)
                        Text(verbatim: merkmal.displayName).font(.caption.weight(.medium))
                    }
                    .foregroundStyle(BEMColor.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(BEMColor.glazeLine, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private var ratings: some View {
        if let rating = entry.rating {
            VStack(alignment: .leading, spacing: BEMSpacing.s) {
                Text("entry.rating.count \(rating.count)")
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
                ForEach(rating.ratings.prefix(3)) { single in
                    HStack(alignment: .top, spacing: BEMSpacing.s) {
                        Text(verbatim: String(repeating: "★", count: single.stars))
                            .font(.footnote)
                            .foregroundStyle(BEMColor.cobalt)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: "@\(single.login)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BEMColor.ink)
                            if let comment = single.comment {
                                Text(verbatim: comment)
                                    .font(.caption)
                                    .foregroundStyle(BEMColor.inkSecondary)
                            }
                        }
                    }
                }
            }
        } else {
            Text("entry.rating.none")
                .font(BEMFont.dataLabel)
                .foregroundStyle(BEMColor.inkSecondary)
        }
    }

    private var candidateCallout: some View {
        VStack(alignment: .leading, spacing: BEMSpacing.s) {
            Text("entry.candidate.cta")
                .font(.footnote.weight(.medium))
                .foregroundStyle(BEMColor.ink)
            Link(destination: RatingFunnel.verify(entryID: entry.id, name: entry.name) ?? RatingFunnel.repository) {
                HStack(spacing: 4) {
                    Text("entry.candidate.action")
                    Image(systemName: "arrow.up.right")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BEMColor.cobalt)
            }
        }
        .padding(BEMSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BEMColor.saltGlazeElevated, in: RoundedRectangle(cornerRadius: BEMRadius.control))
    }

    private var actions: some View {
        HStack(spacing: BEMSpacing.s + 2) {
            CobaltButton(title: Text("entry.action.rate"), systemImage: "star") {
                isRating = true
            }
            SquareActionButton(systemImage: "location.north.fill", accessibilityLabel: "entry.action.route") {
                let item = MKMapItem(placemark: MKPlacemark(coordinate: entry.coordinate))
                item.name = entry.name
                item.openInMaps()
            }
        }
    }

    @ViewBuilder
    private var sources: some View {
        if let source = entry.sources.first {
            Link(destination: source) {
                SourceLine(systemImage: "link", text: Text("entry.sources"))
            }
        }
    }
}

/// Picking stars, then handing off to GitHub. The sheet never posts anything —
/// it builds a URL and opens it, which is the entire write path of this app.
struct RatingSheet: View {
    let entry: RegisterEntry
    let login: String
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var stars = 5

    var body: some View {
        VStack(spacing: BEMSpacing.l) {
            Text(verbatim: entry.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(BEMColor.ink)

            HStack(spacing: BEMSpacing.s) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        stars = value
                    } label: {
                        Image(systemName: value <= stars ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(BEMColor.cobalt)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("entry.rating.stars \(value)"))
                }
            }

            Text("funnel.hint")
                .font(.footnote)
                .foregroundStyle(BEMColor.inkSecondary)
                .multilineTextAlignment(.center)

            CobaltButton(title: Text("entry.action.rate.open"), systemImage: "arrow.up.right") {
                if let url = RatingFunnel.rate(entryID: entry.id, stars: stars, login: login) {
                    openURL(url)
                }
                dismiss()
            }
        }
        .padding(BEMSpacing.l)
    }
}
