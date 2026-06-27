//
//  OnboardingGoalStepView.swift
//  Fitness Coach
//
//  FitPilot AI — Goal step for onboarding.
//

import SwiftUI

struct OnboardingGoalStepView: View {
    @Binding var formState: OnboardingFormState
    @FocusState private var focusedField: Field?
    @Environment(\.onboardingFieldNavigator) private var fieldNavigator

    private enum Field: String, Hashable {
        case goalWeight
        case advancedPaceAmount
    }

    private var pacePreview: WeightLossPacePreviewModel {
        formState.pacePreview()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            OnboardingSectionTitle(
                title: "Set your destination",
                subtitle: FormaProductCopy.Onboarding.goalSubtitle
            )

            OnboardingNumberField(
                title: "Goal weight",
                placeholder: "76",
                text: $formState.goalWeightKgText,
                helper: "Kilograms",
                keyboard: .decimalPad,
                isFocused: focusedField == .goalWeight
            )
            .focused($focusedField, equals: .goalWeight)
            .id(Field.goalWeight)

            if formState.isPaceApplicable() {
                paceSection
            } else if formState.parsedCurrentWeightKg != nil,
                      formState.parsedGoalWeightKg != nil {
                OnboardingInfoCard(
                    title: "Maintenance pace",
                    message: "Weight-loss pace applies when your goal is below your current weight. Forma will match calories to maintenance for now.",
                    icon: "equal.circle"
                )
            }
        }
        .onChange(of: focusedField) { _, field in
            syncNavigator(for: field)
        }
        .onAppear {
            syncNavigator(for: focusedField)
        }
    }

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OnboardingSectionTitle(
                title: "Weight-loss pace",
                subtitle: FormaProductCopy.Onboarding.goalPaceSubtitle
            )

            ForEach(WeightLossPaceChoice.allCases) { choice in
                OnboardingSelectionCard(
                    title: OnboardingFormatter.paceChoiceTitle(choice),
                    subtitle: choice.subtitle,
                    icon: icon(for: choice),
                    isSelected: formState.weightLossPaceChoice == choice
                ) {
                    focusedField = nil
                    formState.selectPaceChoice(choice)
                }
            }

            if formState.weightLossPaceChoice.isAdvanced {
                advancedEditor
            }

            pacePreviewSection
        }
    }

    private var advancedEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Period", selection: $formState.advancedPaceDraft.period) {
                ForEach(WeightLossAdvancedPaceDraft.Period.allCases) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.segmented)

            OnboardingNumberField(
                title: formState.advancedPaceDraft.period.fieldTitle,
                placeholder: formState.advancedPaceDraft.period == .weekly ? "0.5" : "2.0",
                text: $formState.advancedPaceDraft.amountText,
                helper: "Kilograms",
                keyboard: .decimalPad,
                isFocused: focusedField == .advancedPaceAmount
            )
            .focused($focusedField, equals: .advancedPaceAmount)
            .id(Field.advancedPaceAmount)
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var pacePreviewSection: some View {
        if let validationError = pacePreview.validationError {
            OnboardingWarningBanner(message: validationError)
        } else if pacePreview.isSaveable {
            VStack(alignment: .leading, spacing: 10) {
                if let safety = pacePreview.safetyDisplay {
                    paceSafetyBadge(safety)
                }

                if let summary = pacePreview.deficitSummaryLine {
                    Text(summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let weekly = pacePreview.weeklyLossKg,
                   let monthly = pacePreview.monthlyLossKg {
                    paceEquivalentRow(
                        label: "Weekly",
                        value: OnboardingFormatter.weeklyLoss(weekly) ?? ""
                    )
                    paceEquivalentRow(
                        label: "Monthly",
                        value: OnboardingFormatter.monthlyLoss(monthly)
                    )
                    if let deficit = pacePreview.dailyDeficitKcal {
                        paceEquivalentRow(
                            label: "Deficit",
                            value: "\(deficit) kcal/day"
                        )
                    }
                }

                if let warning = pacePreview.warningMessage {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .onboardingCard()
        }
    }

    private func paceEquivalentRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.primaryText)
        }
    }

    private func paceSafetyBadge(_ display: WeightLossPaceSafetyDisplay) -> some View {
        Text(OnboardingFormatter.safetyDisplay(display))
            .font(.caption.weight(.semibold))
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
            return OnboardingTheme.accent
        case .demanding, .tooAggressive:
            return OnboardingTheme.warning
        }
    }

    private func syncNavigator(for field: Field?) {
        guard let fieldNavigator else { return }

        switch field {
        case .goalWeight:
            fieldNavigator.updateFocus(
                fieldID: Field.goalWeight,
                canPrevious: false,
                canNext: false,
                onPrevious: nil,
                onNext: nil,
                onDismiss: { focusedField = nil }
            )
        case .advancedPaceAmount:
            fieldNavigator.updateFocus(
                fieldID: Field.advancedPaceAmount,
                canPrevious: false,
                canNext: false,
                onPrevious: nil,
                onNext: nil,
                onDismiss: { focusedField = nil }
            )
        case nil:
            fieldNavigator.clearFocus()
        }
    }

    private func icon(for choice: WeightLossPaceChoice) -> String {
        switch choice {
        case .gentle:
            return "leaf.fill"
        case .moderate:
            return "gauge.medium"
        case .aggressive:
            return "flame.fill"
        case .advanced:
            return "slider.horizontal.3"
        }
    }
}

#Preview {
    OnboardingGoalStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
}
