//
//  WeightLossPaceSettingsView.swift
//  Fitness Coach
//
//  Forma — Pace selection (presets + advanced) for Plan edit.
//

import SwiftUI

struct WeightLossPaceSettingsView: View {
    @Binding var paceChoice: WeightLossPaceChoice
    @Binding var advancedDraft: WeightLossAdvancedPaceDraft

    let weightKg: Double
    let goalWeightKg: Double
    let isPaceApplicable: Bool

    private var preview: WeightLossPacePreviewModel {
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

                if preview.isSaveable || preview.validationError != nil {
                    previewCard
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
                            ? FormaTokens.Color.accent
                            : FormaTokens.Color.textTertiary
                    )
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.displayName)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                    Text(choice.subtitle)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
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

    // MARK: - Preview

    private var previewCard: some View {
        FormaPlanCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                if let validationError = preview.validationError {
                    Text(validationError)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                } else {
                    if let safetyDisplay = preview.safetyDisplay {
                        safetyBadge(safetyDisplay)
                    }

                    if let summary = preview.deficitSummaryLine {
                        Text(summary)
                            .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                            .foregroundStyle(FormaTokens.Color.textPrimary)
                    }

                    equivalentRows

                    if let warning = preview.warningMessage {
                        Text(warning)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var equivalentRows: some View {
        if let weekly = preview.weeklyLossKg, let monthly = preview.monthlyLossKg {
            VStack(alignment: .leading, spacing: 4) {
                equivalentRow(
                    label: "Weekly",
                    value: formatKg(weekly) + "/week"
                )
                equivalentRow(
                    label: "Monthly",
                    value: formatKg(monthly) + "/month"
                )
                if let deficit = preview.dailyDeficitKcal {
                    equivalentRow(
                        label: "Deficit",
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
                .foregroundStyle(FormaTokens.Color.textTertiary)
            Spacer()
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
    }

    private func safetyBadge(_ display: WeightLossPaceSafetyDisplay) -> some View {
        Text(display.rawValue)
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(safetyColor(display))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(safetyColor(display).opacity(0.16))
            }
    }

    private func safetyColor(_ display: WeightLossPaceSafetyDisplay) -> Color {
        switch display {
        case .sustainable:
            return FormaTokens.Color.success
        case .demanding:
            return FormaTokens.Color.warning
        case .tooAggressive:
            return FormaTokens.Color.warning
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
    Form {
        Section {
            WeightLossPaceSettingsView(
                paceChoice: .constant(.moderate),
                advancedDraft: .constant(.default),
                weightKg: 80,
                goalWeightKg: 72,
                isPaceApplicable: true
            )
        }
    }
}
