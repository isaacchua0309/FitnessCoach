//
//  PlanEditActivityStepView.swift
//  Fitness Coach
//
//  Forma — Outcome-driven activity level step for Edit Plan.
//

import SwiftUI

struct PlanEditActivityStepView: View {
    @Binding var formState: PlanFormState
    @Binding var showExpertAdjustments: Bool
    let projection: PlanProjection
    let onRegenerateTargets: () -> Void

    private var activityOptions: [PlanActivityLevelPresentation] {
        PlanActivityLevelPresentationBuilder.options(formState: formState)
    }

    private var targetPreview: PlanActivityTargetPreviewState {
        PlanActivityTargetPreviewBuilder.build(
            projection: projection,
            formState: formState
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
            Text(FormaProductCopy.PlanEditActivity.sectionTitle)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

            VStack(spacing: FormaTokens.Spacing.sm) {
                ForEach(activityOptions) { option in
                    PlanActivityLevelCard(
                        presentation: option,
                        isSelected: formState.activityLevel == option.level,
                        action: {
                            formState.selectActivityLevel(option.level)
                        }
                    )
                }
            }

            PlanActivityTargetPreviewCard(state: targetPreview)

            PlanActivityExpertAdjustmentsCard(isExpanded: $showExpertAdjustments) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    FormaLabeledNumberField(
                        title: FormaProductCopy.ProfileForm.bodyFat,
                        placeholder: FormaProductCopy.PlanEditActivity.optionalPlaceholder,
                        text: $formState.estimatedBodyFatPercentageText,
                        unit: "%",
                        keyboard: .decimalPad
                    )

                    FormaLabeledNumberField(
                        title: FormaProductCopy.ProfileForm.trainingDays,
                        placeholder: "3",
                        text: Binding(
                            get: { formState.trainingFrequencyPerWeekText },
                            set: { formState.setTrainingFrequencyPerWeekText($0) }
                        ),
                        keyboard: .numberPad
                    )

                    FormaLabeledNumberField(
                        title: FormaProductCopy.ProfileForm.averageSteps,
                        placeholder: "5000",
                        text: Binding(
                            get: { formState.averageStepsText },
                            set: { formState.setAverageStepsText($0) }
                        ),
                        keyboard: .numberPad
                    )

                    MacroTargetSettingsView(
                        calorieTargetText: $formState.calorieTargetText,
                        proteinTargetText: $formState.proteinTargetText,
                        carbTargetText: $formState.carbTargetText,
                        fatTargetText: $formState.fatTargetText,
                        expectedWeeklyWeightLossKgText: $formState.expectedWeeklyWeightLossKgText,
                        aggressiveness: $formState.aggressiveness,
                        presentationStyle: .embedded,
                        onRegenerate: onRegenerateTargets
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    struct PreviewHost: View {
        @State private var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        @State private var showExpert = false

        var body: some View {
            ScrollView {
                PlanEditActivityStepView(
                    formState: $formState,
                    showExpertAdjustments: $showExpert,
                    projection: PlanProjectionBuilder.build(
                        formState: formState,
                        goalType: .loseFat
                    ),
                    onRegenerateTargets: {}
                )
                .padding()
            }
            .background(FormaPlanTokens.Color.planBackground)
        }
    }

    return PreviewHost()
        .formaThemePreview()
}
#endif
