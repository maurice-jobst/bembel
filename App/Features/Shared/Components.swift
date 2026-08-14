import BEMBELKit
import SwiftUI

// MARK: - Line badge

/// RMV line badge. S-Bahn lines fill cobaltDeep, U-Bahn lines outline in
/// cobalt, everything else (tram, bus) outlines in the hairline grey.
/// `LineKind` itself lives in the kit next to `Departure`.
struct LineBadge: View {
    let line: String
    let kind: LineKind
    var compact = false

    var body: some View {
        Text(verbatim: line)
            .font(.system(compact ? .caption : .footnote, design: .rounded).weight(.bold).monospacedDigit())
            .foregroundStyle(foreground)
            .frame(minWidth: compact ? 34 : 44, minHeight: compact ? 20 : 26)
            .background {
                let shape = RoundedRectangle(cornerRadius: 6)
                switch kind {
                case .sBahn: shape.fill(BEMColor.cobaltDeep)
                case .uBahn: shape.stroke(BEMColor.cobalt, lineWidth: 1.5)
                case .surface: shape.stroke(BEMColor.glazeLine, lineWidth: 1)
                }
            }
    }

    private var foreground: Color {
        switch kind {
        case .sBahn: .white
        case .uBahn: BEMColor.cobalt
        case .surface: BEMColor.inkSecondary
        }
    }
}

// MARK: - Map chrome

/// Round glass button floating over a map (locate, settings).
struct GlassCircleButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(BEMColor.cobalt)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: .circle)
                .overlay(Circle().stroke(BEMColor.glazeLine.opacity(0.5), lineWidth: 0.5))
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Capsule filter/selection chip used on Abfahrten and Trinkwasser.
struct SelectionChip: View {
    let title: Text
    let isSelected: Bool
    var glass = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            title
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? BEMColor.inkOnCobalt : (glass ? BEMColor.ink : BEMColor.inkSecondary))
                .padding(.horizontal, BEMSpacing.m)
                .padding(.vertical, 7)
                .background {
                    if isSelected {
                        Capsule().fill(BEMColor.cobalt)
                    } else if glass {
                        Capsule().fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(BEMColor.glazeLine.opacity(0.6), lineWidth: 0.5))
                    } else {
                        Capsule().stroke(BEMColor.glazeLine, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Status capsule: colored dot + label on a tinted background.
struct StatusCapsule: View {
    let label: Text
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            label
                .font(.footnote.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(color.opacity(0.16)))
    }
}

/// Primary filled action button (onboarding, fountain route).
struct CobaltButton: View {
    let title: Text
    var systemImage: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: BEMSpacing.s) {
                if let systemImage {
                    Image(systemName: systemImage).font(.body.weight(.semibold))
                }
                title.font(.body.weight(.semibold))
            }
            .foregroundStyle(BEMColor.inkOnCobalt)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: BEMRadius.control).fill(BEMColor.cobalt))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Source line

/// "Quelle · Stand"-footer under data surfaces. Every dataset surface names
/// its source; that rule comes from the operator-dataset harness.
struct SourceLine: View {
    let systemImage: String
    let text: Text

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(.caption)
            text.font(BEMFont.dataLabel)
        }
        .foregroundStyle(BEMColor.inkSecondary)
    }
}

// MARK: - Square action

/// 48pt secondary-action button used in the detail cards' action rows.
struct SquareActionButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(BEMColor.cobalt)
                .frame(width: 48, height: 48)
                .overlay(RoundedRectangle(cornerRadius: BEMRadius.control).stroke(BEMColor.glazeLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

// MARK: - Detail card chrome

/// The bottom detail-card shell shared by every place segment. One modifier,
/// so the cards cannot drift apart inside the same surface.
struct DetailCardChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
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
}

extension View {
    func bemDetailCard() -> some View { modifier(DetailCardChrome()) }
}
