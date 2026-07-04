//
//  PlanEditBodyBaselineStepView.swift
//  Fitness Coach
//
//  Forma — Outcome-driven height & weight step for Edit Plan.
//

import SwiftUI

struct PlanEditBodyBaselineStepView: View {
    @Binding var formState: PlanFormState
    let projection: PlanProjection

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case height
        case weight
    }

    private var validation: PlanBodyBaselineFieldValidation {
        PlanBodyBaselineValidationBuilder.validate(
            heightText: formState.heightCmText,
            weightText: formState.currentWeightKgText
        )
    }

    private var summaryState: PlanBodyBaselineSummaryState {
        PlanBodyBaselineSummaryBuilder.summary(
            formState: formState,
            projection: projection
        )
    }

    private var projectionState: PlanBodyBaselineProjectionState {
        PlanBodyBaselineSummaryBuilder.projection(
            formState: formState,
            projection: projection
        )
    }

    private var weightUnitLabel: String {
        OnboardingFormatter.weightUnitAbbreviation(for: formState.unitSystem)
    }

    private var unitSystemSelectionID: String {
        formState.unitSystem == .metric ? "metric" : "imperial"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
            PlanBodyBaselineSummaryCard(state: summaryState)

            PlanSegmentedControl(
                options: [
                    PlanSegmentedOption(
                        id: "metric",
                        title: FormaProductCopy.PlanEditBodyBaseline.unitMetric
                    ),
                    PlanSegmentedOption(
                        id: "imperial",
                        title: FormaProductCopy.PlanEditBodyBaseline.unitImperial
                    )
                ],
                selectedID: unitSystemSelectionID,
                onSelect: { id in
                    formState.unitSystem = id == "metric" ? .metric : .imperial
                }
            )

            VStack(spacing: FormaTokens.Spacing.md) {
                PlanBodyMetricInputField(
                    title: FormaProductCopy.PlanEditBodyBaseline.heightLabel,
                    text: $formState.heightCmText,
                    unitLabel: FormaProductCopy.PlanEditBodyBaseline.heightUnit,
                    placeholder: "175",
                    validationMessage: validation.heightMessage,
                    isFocused: focusedField == .height
                )
                .focused($focusedField, equals: .height)

                PlanBodyMetricInputField(
                    title: FormaProductCopy.PlanEditBodyBaseline.weightLabel,
                    text: $formState.currentWeightKgText,
                    unitLabel: weightUnitLabel,
                    placeholder: "70",
                    validationMessage: validation.weightMessage,
                    isFocused: focusedField == .weight
                )
                .focused($focusedField, equals: .weight)
            }

            PlanBodyBaselineProjectionCard(state: projectionState)
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    ScrollView {
        PlanEditBodyBaselineStepView(
            formState: .constant(PlanFormState(profile: PlanMissionControlFixtures.loseProfile)),
            projection: PlanProjectionBuilder.build(
                formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile),
                goalType: .loseFat
            )
        )
        .padding()
    }
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
