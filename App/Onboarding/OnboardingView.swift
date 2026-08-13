import BEMBELKit
import CoreLocation
import SwiftUI

/// First launch: one screen of stance, one screen of region + location.
/// Completion is stored in the App Group so widgets know the app is set up.
struct OnboardingView: View {
    @AppStorage(OnboardingState.completedKey, store: AppGroup.defaults)
    private var completed = false
    @AppStorage(RegionSettings.selectedRingKey, store: AppGroup.defaults)
    private var selectedRingRaw = RegionSettings.defaultRing.rawValue
    @State private var page = 0

    var body: some View {
        ZStack {
            BEMColor.saltGlaze.ignoresSafeArea()
            if page == 0 {
                welcomePage
            } else {
                regionPage
            }
        }
        .animation(.easeInOut(duration: 0.25), value: page)
    }

    // MARK: Page 1 — stance

    private var welcomePage: some View {
        VStack(alignment: .leading, spacing: 0) {
            reliefHeader
            VStack(alignment: .leading, spacing: BEMSpacing.m) {
                Text(verbatim: "BEMBEL")
                    .font(.system(.largeTitle, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(BEMColor.ink)
                Text("onboarding.claim")
                    .font(.title3)
                    .foregroundStyle(BEMColor.ink)
                    .frame(maxWidth: 320, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    featureRow(icon: "building.2.fill", title: "onboarding.shadow.title", body: "onboarding.shadow.body")
                    featureRow(icon: "drop.fill", title: "onboarding.water.title", body: "onboarding.water.body")
                    featureRow(icon: "tram.fill", title: "onboarding.rest.title", body: "onboarding.rest.body")
                }
                .padding(.top, BEMSpacing.s)
            }
            .padding(.horizontal, BEMSpacing.xl)

            Spacer()

            VStack(alignment: .leading, spacing: BEMSpacing.m) {
                Text("onboarding.promise")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
                CobaltButton(title: Text("onboarding.continue")) {
                    page = 1
                }
            }
            .padding(.horizontal, BEMSpacing.xl)
            .padding(.bottom, BEMSpacing.m)
        }
    }

    private var reliefHeader: some View {
        DiamondRelief()
            .stroke(BEMColor.cobalt, lineWidth: 1.5)
            .frame(height: 132)
            .clipped()
            .opacity(0.5)
            .mask(
                LinearGradient(
                    colors: [.black, .black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .padding(.bottom, BEMSpacing.xl)
            .accessibilityHidden(true)
    }

    private func featureRow(icon: String, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: BEMSpacing.m) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(BEMColor.cobalt)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BEMColor.ink)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
        }
    }

    // MARK: Page 2 — region + location

    private var regionPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: BEMSpacing.s) {
                Text("onboarding.region.title")
                    .font(.title.weight(.bold))
                    .foregroundStyle(BEMColor.ink)
                Text("onboarding.region.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
            .padding(.top, BEMSpacing.xxl)

            VStack(spacing: 10) {
                ForEach(Ring.allCases) { ring in
                    ringCard(ring)
                }
            }
            .padding(.top, BEMSpacing.l)

            locationCard
                .padding(.top, BEMSpacing.xl)

            Spacer()

            VStack(spacing: BEMSpacing.s) {
                CobaltButton(title: Text("onboarding.location.allow")) {
                    LocationPermission.shared.request()
                    completed = true
                }
                Button {
                    completed = true
                } label: {
                    Text("onboarding.location.skip")
                        .font(.body.weight(.medium))
                        .foregroundStyle(BEMColor.cobalt)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, BEMSpacing.m)
        }
        .padding(.horizontal, BEMSpacing.xl)
    }

    private func ringCard(_ ring: Ring) -> some View {
        let isSelected = ring.rawValue == selectedRingRaw
        return Button {
            selectedRingRaw = ring.rawValue
        } label: {
            HStack(spacing: BEMSpacing.m) {
                Image(systemName: isSelected ? "checkmark.seal.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? BEMColor.cobalt : BEMColor.inkSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ring.titleKey)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(BEMColor.ink)
                    Text(ring.onboardingDetailKey)
                        .font(.footnote)
                        .foregroundStyle(BEMColor.inkSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, BEMSpacing.l)
            .padding(.vertical, 14)
            .background(BEMColor.saltGlazeElevated)
            .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: BEMRadius.card)
                    .stroke(isSelected ? BEMColor.cobalt : BEMColor.glazeLine, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var locationCard: some View {
        HStack(alignment: .top, spacing: BEMSpacing.m) {
            Image(systemName: "location.viewfinder")
                .font(.title3)
                .foregroundStyle(BEMColor.cobalt)
            VStack(alignment: .leading, spacing: 2) {
                Text("onboarding.location.title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BEMColor.ink)
                Text("onboarding.location.body")
                    .font(.footnote)
                    .foregroundStyle(BEMColor.inkSecondary)
            }
        }
        .padding(BEMSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BEMColor.saltGlazeElevated)
        .clipShape(RoundedRectangle(cornerRadius: BEMRadius.card))
    }
}

enum OnboardingState {
    static let completedKey = "onboarding.completed"
}

extension Ring {
    var onboardingDetailKey: LocalizedStringKey {
        switch self {
        case .frankfurt: "onboarding.ring.frankfurt"
        case .kernraum: "onboarding.ring.kernraum"
        case .rheinmain: "onboarding.ring.rheinmain"
        }
    }
}

/// Retains the CLLocationManager across the authorization prompt.
@MainActor
final class LocationPermission {
    static let shared = LocationPermission()
    private let manager = CLLocationManager()

    func request() {
        manager.requestWhenInUseAuthorization()
    }
}
