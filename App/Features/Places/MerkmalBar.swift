import BEMBELKit
import SwiftUI

/// Merkmale as primary navigation. The chips come from the data — whatever
/// the current register actually carries, most common first — so a new tag
/// published in bembel-data appears here without an app update.
struct MerkmalBar: View {
    @Bindable var model: PlacesModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BEMSpacing.s) {
                SelectionChip(
                    title: Text("places.merkmale.all"),
                    isSelected: model.selectedMerkmale.isEmpty,
                    glass: true
                ) {
                    model.selectedMerkmale = []
                }

                ForEach(model.availableMerkmale) { merkmal in
                    SelectionChip(
                        title: Text(merkmal.displayName),
                        isSelected: model.selectedMerkmale.contains(merkmal),
                        glass: true
                    ) {
                        model.toggle(merkmal)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Text("places.merkmale.a11y"))
    }
}

extension Merkmal {
    /// Known Merkmale are localised; an unknown one shows its raw slug, which
    /// is readable by construction and better than hiding the entry.
    var displayName: String {
        let localized = String(localized: String.LocalizationValue(localizationKey))
        return localized == localizationKey ? rawValue : localized
    }
}
