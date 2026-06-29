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
            VStack(spacing: 0) {
                OnboardingIllustrationContainer(style: .coachWaiting)
                    .onboardingVisionZone(.hero)
                    .onboardingStageEntrance(.hero)
                    .accessibilitySortPriority(90)

                OnboardingHeroSection(
                    headline: copy.headline,
                    supporting: copy.supporting
                )
                .onboardingVisionZone(.narrative)
                .onboardingStageEntrance(.headline)
                .accessibilitySortPriority(80)

                OnboardingTransformationCard(
                    benefits: OnboardingAlmostThereValues.benefits,
                    accessibilityLabel: OnboardingAlmostThereValues.benefitsAccessibilityLabel
                )
                .onboardingVisionZone(.benefits)
                .onboardingStageEntrance(.benefits)
                .accessibilitySortPriority(70)

                OnboardingFooterMessage(message: copy.trustFooter)
                    .onboardingVisionZone(.footer)
                    .onboardingStageEntrance(.footer)
                    .accessibilitySortPriority(60)
            }
            .onboardingVisionScreen(.almostThere)
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

#Preview("Almost There — iPhone SE") {
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

#Preview("Almost There — Landscape") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("Almost There — Dark Mode") {
    OnboardingAlmostThereStepView()
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .preferredColorScheme(.dark)
}
#endif
