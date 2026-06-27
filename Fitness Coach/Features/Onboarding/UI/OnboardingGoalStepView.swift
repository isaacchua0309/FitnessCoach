//
//  OnboardingGoalStepView.swift
//  Fitness Coach
//
//  Forma — Goal weight and pace step for onboarding (v2 journey + legacy v1).
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

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    private var pacePreview: WeightLossPacePreviewModel {
        formState.pacePreview()
    }

    private var goalDirection: OnboardingGoalDirection? {
        guard let current = formState.parsedCurrentWeightKg,
              let goal = formState.parsedGoalWeightKg else {
            return nil
        }
        return OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: current,
            goalWeightKg: goal
        )
    }

    private var showsGoalBMITooLowWarning: Bool {
        guard let goal = formState.parsedGoalWeightKg,
              let height = formState.parsedPositiveHeightCm else {
            return false
        }
        return OnboardingGoalProjectionBuilder.isGoalBMITooLow(
            goalWeightKg: goal,
            heightCm: height
        )
    }

    private var showsCutProjectionCard: Bool {
        formState.isPaceApplicable() && pacePreview.isSaveable
    }

    private var showsNonCutFeedback: Bool {
        guard let direction = goalDirection else { return false }
        switch direction {
        case .maintain, .gain:
            return formState.canAdvance(from: .goal)
        case .cut:
            return false
        }
    }

    private var goalWeightBinding: Binding<String> {
        Binding(
            get: { formState.displayText(for: .goalWeight) },
            set: { formState.setDisplayText($0, for: .goalWeight) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingTheme.sectionSpacing) {
            if !isV2 {
                legacyHeader
            }

            goalWeightField

            if showsGoalBMITooLowWarning {
                OnboardingWarningBanner(message: FormaProductCopy.Onboarding.V2.Goal.bmiWarning)
            }

            if formState.isPaceApplicable() {
                paceSection
            } else if formState.parsedCurrentWeightKg != nil,
                      formState.parsedGoalWeightKg != nil {
                nonCutDirectionCard
            }

            if let validationError = pacePreview.validationError, formState.isPaceApplicable() {
                OnboardingWarningBanner(message: validationError)
            }

            if showsCutProjectionCard {
                cutProjectionCard
            } else if showsNonCutFeedback {
                nonCutFeedbackCard
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsCutProjectionCard)
        .animation(.easeInOut(duration: 0.2), value: showsNonCutFeedback)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: focusedField) { _, field in
            syncNavigator(for: field)
        }
        .onAppear {
            syncNavigator(for: focusedField)
        }
    }

    // MARK: - Header

    private var legacyHeader: some View {
        OnboardingSectionTitle(
            title: FormaProductCopy.Onboarding.V2.Goal.title,
            subtitle: FormaProductCopy.Onboarding.V2.Goal.subtitle
        )
    }

    // MARK: - Goal weight

    private var goalWeightField: some View {
        OnboardingNumberField(
            title: FormaProductCopy.Onboarding.V2.Goal.goalWeightLabel,
            placeholder: OnboardingFormatter.weightPlaceholder(for: formState.unitSystem),
            text: goalWeightBinding,
            helper: OnboardingFormatter.weightUnitLabel(for: formState.unitSystem),
            keyboard: .decimalPad,
            isFocused: focusedField == .goalWeight
        )
        .focused($focusedField, equals: .goalWeight)
        .id(Field.goalWeight)
        .onboardingCard()
    }

    // MARK: - Non-cut paths

    private var nonCutDirectionCard: some View {
        OnboardingInfoCard(
            title: nonCutTitle,
            message: nonCutMessage,
            icon: nonCutIcon
        )
    }

    private var nonCutFeedbackCard: some View {
        OnboardingFeedbackCard(
            icon: nonCutIcon,
            title: FormaProductCopy.Onboarding.V2.GoalFeedback.title,
            message: nonCutMessage,
            style: .info
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var nonCutTitle: String {
        switch goalDirection {
        case .gain:
            return FormaProductCopy.Onboarding.V2.Goal.gainTitle
        case .maintain, .none:
            return FormaProductCopy.Onboarding.V2.Goal.maintainTitle
        case .cut:
            return FormaProductCopy.Onboarding.V2.GoalFeedback.title
        }
    }

    private var nonCutMessage: String {
        switch goalDirection {
        case .gain:
            return FormaProductCopy.Onboarding.V2.Goal.gainMessage
        case .maintain, .none:
            return FormaProductCopy.Onboarding.V2.Goal.maintainMessage
        case .cut:
            return FormaProductCopy.Onboarding.V2.GoalFeedback.message
        }
    }

    private var nonCutIcon: String {
        switch goalDirection {
        case .gain:
            return "arrow.up.right.circle"
        case .maintain, .none:
            return "equal.circle"
        case .cut:
            return "target"
        }
    }

    // MARK: - Pace selection

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(FormaProductCopy.Onboarding.V2.Goal.paceSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

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

    // MARK: - Cut projection card

    private var cutProjectionCard: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            if let safety = pacePreview.safetyDisplay {
                paceSafetyBadge(safety)
            }

            Text(OnboardingGoalProjectionBuilder.projectionHeadline(for: pacePreview.safetyDisplay))
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            projectionMetrics

            if let warning = pacePreview.warningMessage {
                Text(warning)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(warning)
            }
        }
        .onboardingCard()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private var projectionMetrics: some View {
        if let weekly = pacePreview.weeklyLossKg,
           let current = formState.parsedCurrentWeightKg,
           let goal = formState.parsedGoalWeightKg {
            VStack(spacing: 8) {
                projectionRow(
                    label: FormaProductCopy.Onboarding.V2.Goal.expectedPaceLabel,
                    value: OnboardingGoalProjectionBuilder.expectedPaceLabel(weeklyKg: weekly)
                )

                if let weeks = OnboardingGoalProjectionBuilder.estimatedWeeks(
                    currentWeightKg: current,
                    goalWeightKg: goal,
                    weeklyLossKg: weekly
                ) {
                    projectionRow(
                        label: FormaProductCopy.Onboarding.V2.Goal.estimatedTimelineLabel,
                        value: OnboardingGoalProjectionBuilder.estimatedTimelineLabel(weeks: weeks)
                    )
                }

                if let deficit = pacePreview.dailyDeficitKcal {
                    projectionRow(
                        label: FormaProductCopy.Onboarding.V2.Goal.dailyDeficitLabel,
                        value: OnboardingGoalProjectionBuilder.dailyDeficitLabel(kcal: deficit)
                    )
                }
            }
        }
    }

    private func projectionRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
            Spacer()
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.primaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
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

    // MARK: - Keyboard navigation

    private func syncNavigator(for field: Field?) {
        guard let fieldNavigator else { return }

        switch field {
        case .goalWeight:
            fieldNavigator.updateFocus(
                fieldID: Field.goalWeight,
                canPrevious: false,
                canNext: formState.weightLossPaceChoice.isAdvanced,
                onPrevious: nil,
                onNext: formState.weightLossPaceChoice.isAdvanced
                    ? { focusedField = .advancedPaceAmount }
                    : nil,
                onDismiss: { focusedField = nil }
            )
        case .advancedPaceAmount:
            fieldNavigator.updateFocus(
                fieldID: Field.advancedPaceAmount,
                canPrevious: true,
                canNext: false,
                onPrevious: { focusedField = .goalWeight },
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

// MARK: - Form helpers

private extension OnboardingFormState {
    var parsedPositiveHeightCm: Double? {
        let trimmed = heightCmText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }
}

#Preview("Cut") {
    OnboardingGoalStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
        .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
        .preferredColorScheme(.dark)
}

#Preview("Maintain") {
    OnboardingGoalStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.goalWeightKgText = state.currentWeightKgText
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .environment(\.onboardingFieldNavigator, OnboardingFieldNavigator())
    .preferredColorScheme(.dark)
}
