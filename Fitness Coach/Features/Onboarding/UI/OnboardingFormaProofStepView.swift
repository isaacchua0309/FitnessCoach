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
            VStack(spacing: 0) {
                OnboardingHeroSection(
                    headline: displayState.visionHeadline,
                    headlineStyle: .vision
                )
                .onboardingVisionZone(.headline)
                .onboardingStageEntrance(.headline)
                .accessibilitySortPriority(90)

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
                .accessibilitySortPriority(85)

                Text(displayState.visionSupporting)
                    .font(OnboardingMarketingTypography.supporting)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .onboardingVisionZone(.narrative)
                    .onboardingStageEntrance(.supporting)
                    .accessibilitySortPriority(80)

                OnboardingBenefitGrid(
                    benefits: OnboardingFormaProofBuilder.benefitItems(from: displayState),
                    accessibilityLabel: displayState.benefitsAccessibilityLabel
                )
                .onboardingVisionZone(.benefits)
                .onboardingStageEntrance(.benefits)
                .accessibilitySortPriority(70)

                OnboardingFooterMessage(message: displayState.trustFooter)
                    .onboardingVisionZone(.footer)
                    .onboardingStageEntrance(.footer)
                    .accessibilitySortPriority(60)
            }
            .onboardingVisionScreen(.formaProof)
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

#Preview("Forma Proof — iPhone SE") {
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

#Preview("Forma Proof — Landscape") {
    OnboardingFormaProofStepView(
        formState: {
            var state = OnboardingFormState()
            OnboardingHeightWeightValues.setWeightKg(70, in: &state)
            OnboardingTargetWeightValues.setGoalFromDeltaKg(-5, in: &state)
            return state
        }()
    )
    .background(OnboardingTheme.background)
    .formaThemePreview()
    .previewInterfaceOrientation(.landscapeLeft)
}
#endif
