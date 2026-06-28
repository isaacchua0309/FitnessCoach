//
//  OnboardingAlmostThereStepView.swift
//  Fitness Coach
//
//  Forma — Coach-waiting milestone before forma proof.
//

import SwiftUI

struct OnboardingAlmostThereStepView: View {
    @State private var didPlayAppearHaptic = false

    private let copy = FormaProductCopy.Onboarding.Flow.AlmostThere.self

    var body: some View {
        OnboardingVisionScreenShell(
            accessibilityLabel: OnboardingAlmostThereValues.accessibilitySummary,
            atmosphereStyle: .milestone,
            onAppear: playAppearHapticIfNeeded
        ) {
            OnboardingStageProgressHeader(currentStep: .almostThere, showsTitles: false)
        } content: {
            VStack(spacing: FormaTokens.Spacing.sm) {
                OnboardingIllustrationContainer(style: .coachWaiting)
                    .onboardingVisionZone(.hero)
                    .onboardingStageEntrance(.hero)

                OnboardingHeroSection(
                    headline: copy.headline,
                    supporting: copy.supporting
                )
                .onboardingVisionZone(.narrative)
                .onboardingStageEntrance(.headline)

                OnboardingTransformationCard(
                    benefits: OnboardingAlmostThereValues.benefits,
                    accessibilityLabel: OnboardingAlmostThereValues.benefitsAccessibilityLabel
                )
                .onboardingVisionZone(.benefits)
                .onboardingStageEntrance(.benefits)

                OnboardingFooterMessage(message: copy.trustFooter)
                    .onboardingVisionZone(.footer)
                    .onboardingStageEntrance(.footer)
            }
            .onboardingVisionZoneWeights(OnboardingVisionZoneWeights.almostThere)
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
#Preview("Almost There") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Almost There — Large Dynamic Type") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .dynamicTypeSize(.accessibility2)
}

#Preview("Almost There — Dark Mode") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .preferredColorScheme(.dark)
}
#endif
