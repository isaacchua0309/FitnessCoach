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

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
            PlanBodyBaselineSummaryCard(state: summaryState)

            unitSystemChips

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

    private var unitSystemChips: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            unitChip(
                title: FormaProductCopy.PlanEditBodyBaseline.unitMetric,
                isSelected: formState.unitSystem == .metric
            ) {
                formState.unitSystem = .metric
            }

            unitChip(
                title: FormaProductCopy.PlanEditBodyBaseline.unitImperial,
                isSelected: formState.unitSystem == .imperial
            ) {
                formState.unitSystem = .imperial
            }
        }
    }

    private func unitChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(
                    isSelected
                        ? FormaPlanTokens.Color.planAccent
                        : FormaPlanTokens.Color.planSecondaryText
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                .background {
                    Capsule()
                        .fill(
                            isSelected
                                ? FormaPlanTokens.Color.planAccentSoft
                                : FormaPlanTokens.Color.planUnselectedCardBackground
                        )
                }
                .overlay {
                    Capsule()
                        .stroke(
                            PlanEditSelectionChrome.cardStrokeColor(isSelected: isSelected),
                            lineWidth: PlanEditSelectionChrome.cardStrokeWidth(isSelected: isSelected)
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
