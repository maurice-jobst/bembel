import BEMBELKit
import SwiftUI

/// "Deine Sammlung" — the data-linked stickers plus the kiosk stamps. Earned
/// in bembel-data and recognised by handle; the full Sammelalbum (city
/// hotspots, Game Center, seasonal drops) is M4.
struct StickerAlbumView: View {
    let model: PlacesModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StickerState.loginKey, store: AppGroup.defaults) private var login = ""

    private var earned: Set<Sticker> {
        StickerRules.awarded(
            login: login,
            contributors: model.snapshot.contributors,
            visitedEntryIDs: StickerState.visitedEntryIDs()
        )
    }

    private var stamps: [Sticker] {
        earned.filter { !$0.isDataLinked }.sorted { $0.id < $1.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Sticker.dataLinked, id: \.id) { sticker in
                        StickerRow(sticker: sticker, unlocked: earned.contains(sticker), title: sticker.title)
                    }
                } header: {
                    Text("stickers.contributions")
                } footer: {
                    Text(RatingFunnel.sanitizedLogin(login) == nil ? "stickers.locked.hint" : "stickers.unlocked.hint")
                }

                Section {
                    if stamps.isEmpty {
                        Text("stickers.stamps.empty")
                            .font(.subheadline)
                            .foregroundStyle(BEMColor.inkSecondary)
                    } else {
                        ForEach(stamps, id: \.id) { stamp in
                            StickerRow(sticker: stamp, unlocked: true, title: name(for: stamp))
                        }
                    }
                } header: {
                    Text("stickers.stamps")
                } footer: {
                    Text("stickers.stamps.footer")
                }
            }
            .navigationTitle("stickers.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                }
            }
        }
    }

    /// A stamp names its place; an entry that has since left the register
    /// keeps its stamp under the raw id rather than vanishing.
    private func name(for sticker: Sticker) -> String {
        guard case .kioskStempel(let entryID) = sticker else { return sticker.id }
        return model.snapshot.entries.first { $0.id == entryID }?.name ?? entryID
    }
}

struct StickerRow: View {
    let sticker: Sticker
    let unlocked: Bool
    let title: String

    var body: some View {
        HStack(spacing: BEMSpacing.m) {
            Image(systemName: sticker.systemImage)
                .font(.title3)
                .foregroundStyle(unlocked ? BEMColor.inkOnCobalt : BEMColor.inkSecondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(unlocked ? BEMColor.cobalt : BEMColor.saltGlazeElevated)
                )
                .overlay(Circle().stroke(BEMColor.glazeLine, lineWidth: unlocked ? 0 : 1))
            Text(verbatim: title)
                .font(.body.weight(unlocked ? .semibold : .regular))
                .foregroundStyle(unlocked ? BEMColor.ink : BEMColor.inkSecondary)
            Spacer()
            if !unlocked {
                Image(systemName: "lock")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension Sticker {
    var title: String {
        switch self {
        case .datenspender: String(localized: "stickers.datenspender")
        case .verifizierer: String(localized: "stickers.verifizierer")
        case .ersteBewertung: String(localized: "stickers.erste-bewertung")
        case .kioskStempel(let entryID): entryID
        }
    }
}
