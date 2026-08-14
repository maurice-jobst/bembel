import BEMBELKit
import SwiftUI

/// Every entry says who stands behind it. Verified date, last editor, one tap
/// to the full git history — the difference between this register and an
/// anonymous star average.
struct ProvenanceByline: View {
    let provenance: Provenance
    let verified: Bool

    private static let dateStyle = Date.FormatStyle.dateTime.day().month(.abbreviated).year()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: verified ? "checkmark.seal.fill" : "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(verified ? BEMColor.good : BEMColor.inkSecondary)
                if verified, let verifiedAt = provenance.verifiedAt {
                    Text("entry.provenance.verified \(verifiedAt.formatted(Self.dateStyle))")
                } else {
                    Text("entry.provenance.unverified")
                }
            }
            .font(BEMFont.dataLabel)
            .foregroundStyle(verified ? BEMColor.ink : BEMColor.inkSecondary)

            if let editor = provenance.lastEditor {
                Text("entry.provenance.editor \(editor)")
                    .font(BEMFont.dataLabel)
                    .foregroundStyle(BEMColor.inkSecondary)
            }

            Link(destination: provenance.historyURL) {
                HStack(spacing: 4) {
                    Text("entry.provenance.history")
                    Image(systemName: "arrow.up.right")
                }
                .font(BEMFont.dataLabel)
                .foregroundStyle(BEMColor.cobalt)
            }
        }
    }
}
