//
//  OnboardingPersonalizationSummaryStepView.swift
//  Fitness Coach
//
//  Forma — Fixed-viewport plan blueprint screen before generation.
//

import SwiftUI

struct OnboardingPersonalizationSummaryStepView: View {
    let formState: OnboardingFormState
    let validationMessage: String?

    @State private var launchReady = false
    @State private var didPlayAppearHaptic = false

    private var displayState: OnboardingPlanBlueprintState {
        OnboardingPlanBlueprintBuilder.build(from: formState)
    }

    private var showsValidationBanner: Bool {
        validationMessage != nil
            || !OnboardingPersonalizationSummaryBuilder.isReadyToGenerate(for: formState)
    }

    private var bannerMessage: String {
        validationMessage
            ?? OnboardingPersonalizationSummaryBuilder.validationMessage(for: formState)
            ?? FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
    }

    var body: some View {
        OnboardingVisionScreenShell(
            accessibilityLabel: displayState.accessibilityLabel,
            atmosphereStyle: .milestone,
            onAppear: {
                playAppearHapticIfNeeded()
                scheduleLaunchReady()
            }
        ) {
            OnboardingStageProgressHeader(
                currentStep: .review,
                showsTitles: false,
                emphasizesLaunch: true,
                launchReady: launchReady
            )
        } content: {
            VStack(spacing: 0) {
                headlineZone
                    .onboardingVisionZone(.headline)
                    .onboardingStageEntrance(.headline)
                    .accessibilitySortPriority(95)

                OnboardingPlanBlueprintVisualCanvas(
                    profile: displayState.visualProfile,
                    launchReady: launchReady
                )
                .onboardingVisionZone(.hero)
                .onboardingStageEntrance(.hero)
                .accessibilitySortPriority(90)

                OnboardingPlanBlueprintGoalHeroCard(
                    state: displayState.goalCard,
                    launchReady: launchReady
                )
                .onboardingVisionZone(.narrative)
                .onboardingStageEntrance(.supporting)
                .accessibilitySortPriority(85)

                OnboardingPlanBlueprintPremiumFeatureRow(
                    features: displayState.premiumFeatures,
                    accessibilityLabel: FormaProductCopy.Onboarding.Flow.Summary.PremiumFeatures.accessibilityLabel
                )
                .onboardingVisionZone(.benefits)
                .onboardingStageEntrance(.benefits)
                .accessibilitySortPriority(80)

                OnboardingPlanBlueprintPersonalizationSignalStrip(
                    signals: displayState.generatedSignals,
                    launchReady: launchReady
                )
                .onboardingVisionZone(.footer)
                .onboardingStageEntrance(.footer)
                .accessibilitySortPriority(75)
            }
            .onboardingVisionScreen(.planBlueprint)
        }
    }

    private var headlineZone: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            if showsValidationBanner {
                OnboardingWarningBanner(message: bannerMessage)
                    .accessibilitySortPriority(96)
            }

            Text(displayState.heroTitle)
                .font(OnboardingMarketingTypography.visionHeadline)
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .lineLimit(showsValidationBanner ? 1 : 2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func scheduleLaunchReady() {
        guard !UIAccessibility.isReduceMotionEnabled else {
            launchReady = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingPlanBlueprintLaunchTiming.readyDelay) {
            launchReady = true
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
#Preview("Maintain") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingPreviewData.formState
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
            state.goalWeightKgText = state.currentWeightKgText
            return state
        }(),
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Loss") {
    OnboardingPersonalizationSummaryStepView(
        formState: {
            var state = OnboardingPreviewData.formState
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &state)
            return state
        }(),
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Small iPhone") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Landscape") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("Accessibility Type") {
    OnboardingPersonalizationSummaryStepView(
        formState: OnboardingPreviewData.formState,
        validationMessage: nil
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
