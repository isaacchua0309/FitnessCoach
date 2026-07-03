//
//  WeightLossPaceSettingsView.swift
//  Fitness Coach
//
//  Forma — Outcome-driven pace selection for Plan edit.
//

import SwiftUI

struct WeightLossPaceSettingsView: View {
    @Binding var paceChoice: WeightLossPaceChoice
    @Binding var advancedDraft: WeightLossAdvancedPaceDraft

    let formState: PlanFormState
    let goalType: PlanGoalType
    let weightKg: Double
    let goalWeightKg: Double
    let isPaceApplicable: Bool

    private let copy = FormaProductCopy.PlanEditTarget.self

    private var paceOptions: [PlanPaceOutcomePresentation] {
        PlanPaceOutcomeBuilder.options(
            formState: formState,
            goalType: goalType,
            advancedDraft: advancedDraft,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg
        )
    }

    private var selectedAdvancedPresentation: PlanPaceOutcomePresentation? {
        guard paceChoice == .advanced else { return nil }
        return paceOptions.first { $0.choice == .advanced }
    }

    var body: some View {
        if isPaceApplicable {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                Text(copy.paceTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                ForEach(paceOptions) { option in
                    PlanPaceOutcomeCard(
                        presentation: option,
                        isSelected: paceChoice == option.choice,
                        action: {
                            paceChoice = option.choice
                        }
                    )
                }

                if paceChoice == .advanced {
                    advancedEditor
                    if let advanced = selectedAdvancedPresentation {
                        advancedImpactPreview(advanced)
                    }
                }
            }
        }
    }

    // MARK: - Advanced

    private var advancedEditor: some View {
        PlanProjectionCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                Text(copy.advancedCustomTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                PlanNativeSegmentedPicker(
                    title: copy.advancedPeriodPickerTitle,
                    selection: $advancedDraft.period
                ) {
                    Text(copy.advancedPeriodWeekly).tag(WeightLossAdvancedPaceDraft.Period.weekly)
                    Text(copy.advancedPeriodMonthly).tag(WeightLossAdvancedPaceDraft.Period.monthly)
                }

                PlanInputField(
                    model: PlanInputFieldDisplayModel(
                        title: advancedDraft.period == .weekly
                            ? copy.advancedAmountWeeklyTitle
                            : copy.advancedAmountMonthlyTitle,
                        placeholder: advancedDraft.amountPlaceholder,
                        unitLabel: FormaProductCopy.FoodForm.kgUnit,
                        usesCompactChrome: true
                    ),
                    text: $advancedDraft.amountText
                )
            }
        }
    }

    @ViewBuilder
    private func advancedImpactPreview(_ presentation: PlanPaceOutcomePresentation) -> some View {
        PlanProjectionCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                if let energy = presentation.energyBalanceLabel {
                    PlanProjectionImpactRow(
                        label: copy.energyPreviewLabel,
                        value: energy
                    )
                }

                if let adherence = presentation.adherenceEstimate {
                    PlanProjectionImpactRow(
                        label: FormaProductCopy.PlanProjection.adherenceLabel,
                        value: adherence
                    )
                }
                if let recovery = presentation.recoveryImpact {
                    PlanProjectionImpactRow(
                        label: FormaProductCopy.PlanProjection.recoveryLabel,
                        value: recovery
                    )
                }
                if let hunger = presentation.hungerImpact {
                    PlanProjectionImpactRow(
                        label: FormaProductCopy.PlanProjection.hungerLabel,
                        value: hunger
                    )
                }

                if let validationError = presentation.validationError {
                    Text(validationError)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planDanger)
                }
            }
        }
    }
}

#Preview {
    let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)

    return ScrollView {
        WeightLossPaceSettingsView(
            paceChoice: .constant(.moderate),
            advancedDraft: .constant(.default),
            formState: formState,
            goalType: .loseFat,
            weightKg: 80,
            goalWeightKg: 72,
            isPaceApplicable: true
        )
        .padding()
    }
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
