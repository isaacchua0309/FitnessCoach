//
//  OnboardingV4TargetWeightStepView.swift
//  Fitness Coach
//
//  Forma — V4 target weight via horizontal loss ruler.
//

import SwiftUI

struct OnboardingV4TargetWeightStepView: View {
    @Binding var formState: OnboardingFormState

    private var showsGoalBMITooLowWarning: Bool {
        guard let goal = OnboardingV4TargetWeightValues.resolvedGoalKg(from: formState),
              let height = formState.parsedHeightCm else {
            return false
        }
        return OnboardingGoalProjectionBuilder.isGoalBMITooLow(
            goalWeightKg: goal,
            heightCm: height
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if showsGoalBMITooLowWarning {
                OnboardingWarningBanner(message: FormaProductCopy.Onboarding.V2.Goal.bmiWarning)
            }

            if formState.parsedCurrentWeightKg != nil {
                lossRuler

                if let summary = OnboardingV4TargetWeightValues.currentToTargetSummary(for: formState) {
                    Text(summary)
                        .font(FormaTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel(summary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        }
    }

    @ViewBuilder
    private var lossRuler: some View {
        let centerLabel = OnboardingV4TargetWeightValues.targetWeightCenterLabel(for: formState)
        let accessibilityTarget = centerLabel

        if formState.unitSystem == .metric {
            if let current = formState.parsedCurrentWeightKg {
                let range = OnboardingV4TargetWeightValues.lossRangeDisplay(
                    currentWeightKg: current,
                    heightCm: formState.parsedHeightCm,
                    unitSystem: .metric
                )
                OnboardingV4RulerPickerFactory.weightLossKg(
                    value: lossDisplayBinding,
                    range: range,
                    centerDisplayText: centerLabel,
                    accessibilityValueText: accessibilityTarget
                )
                .accessibilityLabel(FormaProductCopy.Onboarding.V4.TargetWeight.lossRulerAccessibilityLabel)
            }
        } else if let current = formState.parsedCurrentWeightKg {
            let range = OnboardingV4TargetWeightValues.lossRangeDisplay(
                currentWeightKg: current,
                heightCm: formState.parsedHeightCm,
                unitSystem: .imperial
            )
            OnboardingV4RulerPickerFactory.weightLossLb(
                value: lossDisplayBinding,
                range: range,
                centerDisplayText: centerLabel,
                accessibilityValueText: accessibilityTarget
            )
            .accessibilityLabel(FormaProductCopy.Onboarding.V4.TargetWeight.lossRulerAccessibilityLabel)
        }
    }

    private var lossDisplayBinding: Binding<Double> {
        Binding(
            get: {
                OnboardingV4TargetWeightValues.resolvedLossDisplay(from: formState)
            },
            set: { newValue in
                OnboardingV4TargetWeightValues.setGoalFromLossDisplay(newValue, in: &formState)
            }
        )
    }
}

#if DEBUG
#Preview("V4 Target Weight — Metric") {
    OnboardingV4TargetWeightStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingV4HeightWeightValues.setHeightCm(170, in: &state)
            OnboardingV4HeightWeightValues.setWeightKg(72, in: &state)
            state.unitSystem = .metric
            OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &state)
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
}

#Preview("V4 Target Weight — Imperial") {
    OnboardingV4TargetWeightStepView(
        formState: .constant({
            var state = OnboardingFormState()
            OnboardingV4HeightWeightValues.setHeightCm(170, in: &state)
            OnboardingV4HeightWeightValues.setWeightKg(72, in: &state)
            state.unitSystem = .imperial
            OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &state)
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
}
#endif
