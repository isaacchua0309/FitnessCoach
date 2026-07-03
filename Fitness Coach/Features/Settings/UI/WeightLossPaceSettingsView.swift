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
        PlanEditCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                Text(copy.advancedCustomTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                Picker("Period", selection: $advancedDraft.period) {
                    Text(copy.advancedPeriodWeekly).tag(WeightLossAdvancedPaceDraft.Period.weekly)
                    Text(copy.advancedPeriodMonthly).tag(WeightLossAdvancedPaceDraft.Period.monthly)
                }
                .pickerStyle(.segmented)
                .tint(FormaPlanTokens.Color.planAccent)

                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    Text(
                        advancedDraft.period == .weekly
                            ? copy.advancedAmountWeeklyTitle
                            : copy.advancedAmountMonthlyTitle
                    )
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)

                    HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.md) {
                        TextField(advancedDraft.amountPlaceholder, text: $advancedDraft.amountText)
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                            .keyboardType(.decimalPad)

                        Text(FormaProductCopy.FoodForm.kgUnit)
                            .font(FormaTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(FormaPlanTokens.Color.planAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                Capsule()
                                    .fill(FormaPlanTokens.Color.planAccentSoft)
                            }
                    }
                    .padding(.horizontal, FormaTokens.Spacing.md)
                    .padding(.vertical, FormaTokens.Spacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                            .fill(FormaPlanTokens.Color.planInputBackground)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                            .stroke(FormaPlanTokens.Color.planCardBorder.opacity(0.55), lineWidth: 1)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func advancedImpactPreview(_ presentation: PlanPaceOutcomePresentation) -> some View {
        PlanEditCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                if let energy = presentation.energyBalanceLabel {
                    impactMetricRow(
                        label: copy.energyPreviewLabel,
                        value: energy
                    )
                }

                if let adherence = presentation.adherenceEstimate {
                    impactMetricRow(
                        label: FormaProductCopy.PlanProjection.adherenceLabel,
                        value: adherence
                    )
                }
                if let recovery = presentation.recoveryImpact {
                    impactMetricRow(
                        label: FormaProductCopy.PlanProjection.recoveryLabel,
                        value: recovery
                    )
                }
                if let hunger = presentation.hungerImpact {
                    impactMetricRow(
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

    private func impactMetricRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            Text(value)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
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
