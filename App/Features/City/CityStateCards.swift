import BEMBELKit
import SwiftUI

/// The two cards a Stadtzustand source shows when it is not showing data.
///
/// They carry the same chrome and roughly the same height as the loaded card
/// so a failing source does not make the screen jump, and they always name the
/// source. "Etwas ist schiefgelaufen" tells a user nothing they can act on;
/// "PEGELONLINE antwortet gerade nicht" tells them the river gauge is down and
/// the warning card beside it is still trustworthy.

/// A source that is being fetched. Not a spinner on its own — a spinner with
/// the card's title, so the screen never shows an unlabelled wait.
struct SourceLoadingCard: View {
    let title: LocalizedStringKey
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: BEMSpacing.s) {
            Label {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BEMColor.ink)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(BEMColor.cobalt)
            }
            HStack(spacing: BEMSpacing.s) {
                ProgressView()
                    .controlSize(.small)
                Text("city.loading")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bemStatusCard()
        .accessibilityElement(children: .combine)
    }
}

/// A source that answered with a failure. Retryable by design — `Loadable`
/// keeps `failed` distinct from `idle` precisely so this button means something.
struct SourceFailureCard: View {
    let title: LocalizedStringKey
    let icon: String
    /// The upstream's own name, as the user would search for it. Not localized.
    let sourceName: String
    let retry: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BEMSpacing.s) {
            Label {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BEMColor.ink)
            } icon: {
                // The card keeps its own icon, dimmed — so it stays
                // recognisable while scrolling and the words carry the
                // failure. Not a `.slash` variant: `water.waves.slash` exists
                // but `wind.slash` and `exclamationmark.triangle.slash` do not,
                // and a synthesised symbol name renders as nothing at all.
                // Deliberately not the warning triangle either: this card sits
                // beside a real civil-protection warning, and a second
                // triangle would make a dead sensor look like an emergency.
                Image(systemName: icon)
                    .foregroundStyle(BEMColor.inkSecondary)
            }

            Text("city.source.unavailable \(sourceName)")
                .font(.footnote)
                .foregroundStyle(BEMColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("city.retry", systemImage: "arrow.clockwise") {
                Task { await retry() }
            }
            .font(.footnote.weight(.medium))
            .buttonStyle(.borderless)
            .tint(BEMColor.cobalt)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .bemStatusCard()
        .overlay(
            RoundedRectangle(cornerRadius: BEMRadius.card)
                .stroke(BEMColor.glazeLine, lineWidth: 1)
        )
    }
}
