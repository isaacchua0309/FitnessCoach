//
//  WeightLossPaceSettingsView.swift
//  Fitness Coach
//
//  Forma — Pace selection (presets + advanced) for Plan edit.
//

import SwiftUI

struct WeightLossPaceSettingsView: View {
    @Environment(\.planProjection) private var planProjection

    @Binding var paceChoice: WeightLossPaceChoice
    @Binding var advancedDraft: WeightLossAdvancedPaceDraft

    let weightKg: Double
    let goalWeightKg: Double
    let isPaceApplicable: Bool

    private var paceValidation: WeightLossPacePreviewModel {
        WeightLossPacePreviewBuilder.build(
            choice: paceChoice,
            advancedDraft: advancedDraft,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg
        )
    }

    var body: some View {
        if isPaceApplicable {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                ForEach(WeightLossPaceChoice.allCases) { choice in
                    paceOptionRow(choice)
                }

                if paceChoice.isAdvanced {
                    advancedEditor
                }

                if let projection = planProjection,
                   paceValidation.isSaveable || paceValidation.validationError != nil {
                    PlanProjectionPaceCard(
                        projection: projection,
                        validationError: paceValidation.validationError,
                        supplementalWarning: paceValidation.warningMessage
                    )
                } else if paceValidation.isSaveable || paceValidation.validationError != nil {
                    legacyPreviewCard
                }
            }
        }
    }

    // MARK: - Preset / advanced rows

    private func paceOptionRow(_ choice: WeightLossPaceChoice) -> some View {
        Button {
            paceChoice = choice
        } label: {
            HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                Image(systemName: paceChoice == choice ? "checkmark.circle.fill" : icon(for: choice))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(
                        paceChoice == choice
                            ? FormaPlanTokens.Color.planAccent
                            : FormaPlanTokens.Color.planMutedText
                    )
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.displayName)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    Text(choice.subtitle)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, FormaTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(paceChoice == choice ? .isSelected : [])
    }

    private var advancedEditor: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            Picker("Period", selection: $advancedDraft.period) {
                ForEach(WeightLossAdvancedPaceDraft.Period.allCases) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .tint(FormaPlanTokens.Color.planAccent)

            FormaLabeledNumberField(
                title: advancedDraft.period.fieldTitle,
                placeholder: advancedDraft.amountPlaceholder,
                text: $advancedDraft.amountText,
                unit: FormaProductCopy.FoodForm.kgUnit,
                keyboard: .decimalPad
            )
        }
        .padding(.leading, 34)
    }

    // MARK: - Fallback preview (previews / missing environment)

    private var legacyPreviewCard: some View {
        PlanEditCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                if let validationError = paceValidation.validationError {
                    Text(validationError)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                } else {
                    if let summary = paceValidation.deficitSummaryLine {
                        Text(summary)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                            .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    }

                    legacyEquivalentRows

                    if let warning = paceValidation.warningMessage {
                        Text(warning)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var legacyEquivalentRows: some View {
        if let weekly = paceValidation.weeklyLossKg, let monthly = paceValidation.monthlyLossKg {
            VStack(alignment: .leading, spacing: 4) {
                equivalentRow(
                    label: FormaProductCopy.PlanProjection.weeklyPaceLabel,
                    value: formatKg(weekly) + "/week"
                )
                equivalentRow(
                    label: FormaProductCopy.PlanProjection.monthlyPaceLabel,
                    value: formatKg(monthly) + "/month"
                )
                if let deficit = paceValidation.dailyDeficitKcal {
                    equivalentRow(
                        label: FormaProductCopy.PlanProjection.energyBalanceLabel,
                        value: "\(deficit) kcal/day"
                    )
                }
            }
        }
    }

    private func equivalentRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            Spacer()
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
        }
    }

    private func icon(for choice: WeightLossPaceChoice) -> String {
        switch choice {
        case .gentle:
            return "leaf"
        case .moderate:
            return "gauge.medium"
        case .aggressive:
            return "flame"
        case .advanced:
            return "slider.horizontal.3"
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }
}

#Preview {
    let projection = PlanProjectionBuilder.build(
        formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile),
        goalType: .loseFat
    )

    return Form {
        Section {
            WeightLossPaceSettingsView(
                paceChoice: .constant(.moderate),
                advancedDraft: .constant(.default),
                weightKg: 80,
                goalWeightKg: 72,
                isPaceApplicable: true
            )
            .environment(\.planProjection, projection)
        }
    }
}
