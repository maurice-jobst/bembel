#if DEBUG
import BEMBELKit
import SwiftUI

/// Acceptance surface for BEM-A02: every token, previewable in light, dark,
/// and accessibility text sizes. Lives in the app target because #Preview
/// requires Xcode's macro plugin, which plain-toolchain `swift build`/`test`
/// of the package doesn't have. Not shipped — DEBUG only.
struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BEMSpacing.xl) {
                DiamondRelief()
                    .stroke(BEMColor.cobalt, lineWidth: 1.5)
                    .frame(height: 44)
                    .clipped()

                section("Farben") {
                    swatch("saltGlaze", BEMColor.saltGlaze)
                    swatch("saltGlazeElevated", BEMColor.saltGlazeElevated)
                    swatch("glazeLine", BEMColor.glazeLine)
                    swatch("cobalt", BEMColor.cobalt)
                    swatch("cobaltDeep", BEMColor.cobaltDeep)
                    swatch("ink", BEMColor.ink)
                    swatch("inkSecondary", BEMColor.inkSecondary)
                    swatch("good", BEMColor.good)
                    swatch("caution", BEMColor.caution)
                    swatch("alert", BEMColor.alert)
                }

                section("Typografie") {
                    Text(verbatim: "Display").font(BEMFont.display)
                    Text(verbatim: "Title").font(BEMFont.title)
                    Text(verbatim: "Headline").font(BEMFont.headline)
                    Text(verbatim: "Body").font(BEMFont.body)
                    Text(verbatim: "Callout").font(BEMFont.callout)
                    Text(verbatim: "Caption").font(BEMFont.caption)
                    Text(verbatim: "10:47  S8  Wiesbaden").font(BEMFont.board)
                    Text(verbatim: "3,42 m · 24 °C").font(BEMFont.dataLabel)
                }
                .foregroundStyle(BEMColor.ink)
            }
            .padding(BEMSpacing.l)
        }
        .background(BEMColor.saltGlaze)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: BEMSpacing.s) {
            Text(verbatim: title)
                .font(BEMFont.caption)
                .foregroundStyle(BEMColor.inkSecondary)
            content()
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        HStack(spacing: BEMSpacing.m) {
            RoundedRectangle(cornerRadius: BEMRadius.control)
                .fill(color)
                .frame(width: 44, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: BEMRadius.control)
                        .stroke(BEMColor.glazeLine, lineWidth: 1)
                )
            Text(verbatim: name)
                .font(BEMFont.dataLabel)
                .foregroundStyle(BEMColor.ink)
        }
    }
}

#Preview("Hell") {
    DesignSystemPreview()
}

#Preview("Dunkel") {
    DesignSystemPreview()
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    DesignSystemPreview()
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
