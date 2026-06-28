//
//  OnboardingFormaProofStepView.swift
//  Fitness Coach
//
//  Forma — Future-vision screen before plan review.
//

import SwiftUI

struct OnboardingFormaProofStepView: View {
    let formState: OnboardingFormState

    @State private var didPlayAppearHaptic = false

    private var displayState: OnboardingFormaProofState {
        OnboardingFormaProofBuilder.build(from: formState)
    }

    var body: some View {
        OnboardingVisionScreenShell(
            accessibilityLabel: displayState.accessibilityLabel,
            atmosphereStyle: .futureVision,
            onAppear: playAppearHapticIfNeeded
        ) {
            OnboardingStageProgressHeader(currentStep: .formaProof, showsTitles: false)
        } content: {
            VStack(spacing: FormaTokens.Spacing.sm) {
                OnboardingHeroSection(
                    headline: displayState.visionHeadline,
                    headlineStyle: .vision
                )
                .onboardingVisionZone(.headline)
                .onboardingStageEntrance(.headline)

                OnboardingIllustrationContainer(
                    style: .targetRing(
                        intentLabel: displayState.goalIntentLabel,
                        weightLabel: displayState.targetWeightLabel,
                        pathStyle: displayState.pathStyle,
                        ringProgress: displayState.ringProgress
                    )
                )
                .onboardingVisionZone(.hero)
                .onboardingStageEntrance(.hero)

                Text(displayState.visionSupporting)
                    .font(OnboardingMarketingTypography.supporting)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .onboardingVisionZone(.narrative)
                    .onboardingStageEntrance(.supporting)

                OnboardingBenefitGrid(
                    benefits: OnboardingFormaProofBuilder.benefitItems(from: displayState),
                    accessibilityLabel: displayState.benefitsAccessibilityLabel
                )
                .onboardingVisionZone(.benefits)
                .onboardingStageEntrance(.benefits)

                OnboardingFooterMessage(message: displayState.trustFooter)
                    .onboardingVisionZone(.footer)
                    .onboardingStageEntrance(.footer)
            }
            .onboardingVisionZoneWeights(OnboardingVisionZoneWeights.formaProof)
        }
    }

    private func playAppearHapticIfNeeded() {
        guard !didPlayAppearHaptic else { return }
        didPlayAppearHaptic = true
        OnboardingHaptics.selectionChanged()
    }
}

#if DEBUG
#Preview("Forma Proof — Loss") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(90, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(-15, in: &state)
            state.unitSystem = .metric
            return state
        }()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Forma Proof — Gain") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(8, in: &state)
            state.unitSystem = .metric
            return state
        }()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Forma Proof — Maintain") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(0, in: &state)
            return state
        }()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Forma Proof — Fallback") {
    OnboardingFormaProofStepView(formState: OnboardingFormState())
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Forma Proof — Large Dynamic Type") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(0, in: &state)
            return state
        }()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .dynamicTypeSize(.accessibility2)
}
#endif
