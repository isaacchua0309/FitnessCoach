//
//  OnboardingGoalStepView.swift
//  Fitness Coach
//
//  Forma — Destination step: picker-first goal weight and compact pace (v2 + v3).
//

import SwiftUI

struct OnboardingGoalStepView: View {
    @Binding var formState: OnboardingFormState
    @State private var showsCustomPace = false
    @State private var showsGoalFineTune = false
    @FocusState private var isAdvancedPaceFocused: Bool

    private var isV2: Bool { OnboardingStepPolicy.isV2Enabled }

    private var pacePreview: WeightLossPacePreviewModel {
        formState.pacePreview()
    }

    private var currentWeightKg: Double? {
        formState.parsedCurrentWeightKg
    }

    private var goalDirection: OnboardingGoalDirection? {
        guard let current = currentWeightKg,
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
              let height = formState.parsedHeightCm else {
            return false
        }
        return OnboardingGoalProjectionBuilder.isGoalBMITooLow(
            goalWeightKg: goal,
            heightCm: height
        )
    }

    private var showsCutProjection: Bool {
        formState.isPaceApplicable() && pacePreview.isSaveable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactSectionSpacing) {
            if !isV2, !OnboardingV3StepPolicy.isActive {
                legacyHeader
            }

            if let currentWeightKg {
                goalWeightSelector(currentWeightKg: currentWeightKg)
            }

            if showsGoalBMITooLowWarning {
                OnboardingWarningBanner(message: FormaProductCopy.Onboarding.V2.Goal.bmiWarning)
            }

            if formState.isPaceApplicable() {
                paceSection

                if let validationError = pacePreview.validationError {
                    OnboardingWarningBanner(message: validationError)
                } else if showsCutProjection {
                    compactProjectionCard
                }
            } else if formState.parsedGoalWeightKg != nil {
                maintenanceCard
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showsCutProjection)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            formState.applyGoalWeightDefaultIfNeeded()
            syncCustomPaceVisibility()
        }
        .onChange(of: formState.weightLossPaceChoice) { _, _ in
            syncCustomPaceVisibility()
        }
        .sheet(isPresented: $showsGoalFineTune) {
            goalFineTuneSheet
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

    @ViewBuilder
    private func goalWeightSelector(currentWeightKg: Double) -> some View {
        let goalKg = goalKgBinding.wrappedValue
        let displayRange = OnboardingGoalWeightBounds.displayRange(
            currentWeightKg: currentWeightKg,
            heightCm: formState.parsedHeightCm,
            unitSystem: formState.unitSystem
        )

        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            VStack(spacing: 0) {
                summaryRow(
                    label: FormaProductCopy.Onboarding.V2.Goal.currentWeightSummaryLabel,
                    value: OnboardingGoalWeightBounds.weightSummary(
                        valueKg: currentWeightKg,
                        unitSystem: formState.unitSystem
                    )
                )

                metricDivider

                Button {
                    showsGoalFineTune = true
                } label: {
                    summaryRow(
                        label: FormaProductCopy.Onboarding.V2.Goal.goalWeightSummaryLabel,
                        value: OnboardingGoalWeightBounds.weightSummary(
                            valueKg: goalKg,
                            unitSystem: formState.unitSystem
                        ),
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens exact weight picker")

                metricDivider

                summaryRow(
                    label: FormaProductCopy.Onboarding.V2.Goal.changeSummaryLabel,
                    value: OnboardingGoalWeightBounds.changeSummary(
                        currentKg: currentWeightKg,
                        goalKg: goalKg,
                        unitSystem: formState.unitSystem
                    )
                )
            }
            .onboardingCompactCard()

            Slider(
                value: goalDisplayBinding,
                in: displayRange,
                step: OnboardingGoalWeightBounds.displayStep(for: formState.unitSystem)
            ) {
                Text(FormaProductCopy.Onboarding.V2.Goal.goalWeightLabel)
            }
            .tint(OnboardingTheme.accent)
            .accessibilityLabel(FormaProductCopy.Onboarding.V2.Goal.goalWeightLabel)
            .accessibilityValue(
                OnboardingGoalWeightBounds.weightSummary(
                    valueKg: goalKg,
                    unitSystem: formState.unitSystem
                )
            )
        }
    }

    private var metricDivider: some View {
        Divider()
            .overlay(OnboardingTheme.border)
            .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
    }

    private func summaryRow(
        label: String,
        value: String,
        showsDisclosure: Bool = false
    ) -> some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Text(label)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.secondaryText)

            Spacer(minLength: 0)

            Text(value)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .lineLimit(2)

            if showsDisclosure {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, OnboardingLayout.compactFieldHorizontalPadding)
        .padding(.vertical, OnboardingLayout.compactFieldVerticalPadding)
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    @ViewBuilder
    private var goalFineTuneSheet: some View {
        if formState.unitSystem == .metric {
            OnboardingWheelPickerSheet(
                title: FormaProductCopy.Onboarding.V2.Goal.goalWeightLabel,
                values: goalFineTuneValuesKg,
                selection: goalKgBinding,
                format: { value in
                    value.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(value))"
                        : String(format: "%.1f", value)
                },
                isPresented: $showsGoalFineTune
            )
        } else {
            OnboardingWheelPickerSheet(
                title: FormaProductCopy.Onboarding.V2.Goal.goalWeightLabel,
                values: goalFineTuneValuesLb,
                selection: goalLbBinding,
                format: { value in
                    value.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(value))"
                        : String(format: "%.1f", value)
                },
                isPresented: $showsGoalFineTune
            )
        }
    }

    private var goalFineTuneValuesKg: [Double] {
        guard let current = currentWeightKg else { return [] }
        let range = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: current,
            heightCm: formState.parsedHeightCm
        )
        return OnboardingPickerValueSequence.decimals(in: range, step: 0.5)
    }

    private var goalFineTuneValuesLb: [Double] {
        guard let current = currentWeightKg else { return [] }
        let range = OnboardingGoalWeightBounds.displayRange(
            currentWeightKg: current,
            heightCm: formState.parsedHeightCm,
            unitSystem: .imperial
        )
        return OnboardingPickerValueSequence.decimals(in: range, step: 1)
    }

    // MARK: - Maintenance

    private var maintenanceCard: some View {
        OnboardingInfoCard(
            title: nonCutTitle,
            message: nonCutMessage,
            icon: nonCutIcon
        )
    }

    private var nonCutTitle: String {
        switch goalDirection {
        case .gain:
            return FormaProductCopy.Onboarding.V2.Goal.gainTitle
        case .maintain, .none:
            return FormaProductCopy.Onboarding.V2.Goal.maintainTitle
        case .cut:
            return FormaProductCopy.Onboarding.V2.Goal.maintainTitle
        }
    }

    private var nonCutMessage: String {
        switch goalDirection {
        case .gain:
            return FormaProductCopy.Onboarding.V2.Goal.gainMessage
        case .maintain, .none, .cut:
            return FormaProductCopy.Onboarding.V2.Goal.maintainMessage
        }
    }

    private var nonCutIcon: String {
        switch goalDirection {
        case .gain:
            return "arrow.up.right.circle"
        case .maintain, .none, .cut:
            return "equal.circle"
        }
    }

    // MARK: - Pace

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactLabelGap) {
            Text(FormaProductCopy.Onboarding.V2.Goal.paceSectionTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)

            OnboardingPillGrid(
                items: OnboardingV3InteractionPolicy.visiblePaceChoices,
                selection: paceSelection,
                titleForItem: { OnboardingFormatter.paceChoiceTitle($0) },
                columnCount: 3,
                accessibilityGroupLabel: FormaProductCopy.Onboarding.V2.Goal.paceSectionTitle
            )

            if !showsCustomPace, !formState.weightLossPaceChoice.isAdvanced {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsCustomPace = true
                        formState.selectPaceChoice(.advanced)
                    }
                } label: {
                    Text(OnboardingV3InteractionPolicy.customPaceDisclosureTitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(OnboardingTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(OnboardingV3InteractionPolicy.customPaceDisclosureTitle)
            }

            if showsCustomPace || formState.weightLossPaceChoice.isAdvanced {
                advancedPaceEditor
            }
        }
    }

    private var paceSelection: Binding<WeightLossPaceChoice> {
        Binding(
            get: { formState.weightLossPaceChoice },
            set: { choice in
                formState.selectPaceChoice(choice)
                if !choice.isAdvanced {
                    showsCustomPace = false
                    isAdvancedPaceFocused = false
                }
            }
        )
    }

    private var advancedPaceEditor: some View {
        VStack(alignment: .leading, spacing: OnboardingLayout.compactFieldSpacing) {
            Picker("Period", selection: $formState.advancedPaceDraft.period) {
                ForEach(WeightLossAdvancedPaceDraft.Period.allCases) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.segmented)

            OnboardingTextField(
                title: formState.advancedPaceDraft.period.fieldTitle,
                placeholder: formState.advancedPaceDraft.period == .weekly ? "0.5" : "2.0",
                text: $formState.advancedPaceDraft.amountText,
                helper: "Kilograms",
                keyboard: .decimalPad,
                isFocused: isAdvancedPaceFocused
            )
            .focused($isAdvancedPaceFocused)
            .onboardingScrollTarget(id: "goal-advanced-pace", isFocused: isAdvancedPaceFocused)
        }
        .onboardingCompactCard()
    }

    // MARK: - Projection

    private var compactProjectionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(OnboardingGoalProjectionBuilder.projectionHeadline(for: pacePreview.safetyDisplay))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let weekly = pacePreview.weeklyLossKg,
               let current = currentWeightKg,
               let goal = formState.parsedGoalWeightKg {
                compactMetricRow(
                    label: FormaProductCopy.Onboarding.V2.Goal.expectedPaceLabel,
                    value: OnboardingGoalProjectionBuilder.expectedPaceLabel(weeklyKg: weekly)
                )

                if let weeks = OnboardingGoalProjectionBuilder.estimatedWeeks(
                    currentWeightKg: current,
                    goalWeightKg: goal,
                    weeklyLossKg: weekly
                ) {
                    compactMetricRow(
                        label: FormaProductCopy.Onboarding.V2.Goal.estimatedTimelineLabel,
                        value: OnboardingGoalProjectionBuilder.estimatedTimelineLabel(weeks: weeks)
                    )
                }
            }
        }
        .onboardingCompactCard()
    }

    private func compactMetricRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label + ":")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(OnboardingTheme.primaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }

    // MARK: - Bindings

    private var goalKgBinding: Binding<Double> {
        Binding(
            get: {
                if let goal = formState.parsedGoalWeightKg {
                    return goal
                }
                if let current = currentWeightKg {
                    return current
                }
                return OnboardingV3PickerDefaults.defaultWeightKg
            },
            set: { kg in
                formState.goalWeightKgText = formatStoredKg(kg)
            }
        )
    }

    private var goalLbBinding: Binding<Double> {
        Binding(
            get: {
                (goalKgBinding.wrappedValue * OnboardingFormState.poundsPerKilogram).rounded()
            },
            set: { pounds in
                let kg = pounds / OnboardingFormState.poundsPerKilogram
                formState.goalWeightKgText = formatStoredKg(kg)
            }
        )
    }

    private var goalDisplayBinding: Binding<Double> {
        Binding(
            get: {
                OnboardingGoalWeightBounds.displayValue(
                    fromKg: goalKgBinding.wrappedValue,
                    unitSystem: formState.unitSystem
                )
            },
            set: { display in
                let kg = OnboardingGoalWeightBounds.metricValue(
                    fromDisplay: display,
                    unitSystem: formState.unitSystem
                )
                formState.goalWeightKgText = formatStoredKg(kg)
            }
        )
    }

    private func formatStoredKg(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 0.1) == 0 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }

    private func syncCustomPaceVisibility() {
        if formState.weightLossPaceChoice.isAdvanced {
            showsCustomPace = true
        }
    }
}

// MARK: - Previews

#Preview("Cut — moderate") {
    OnboardingGoalStepView(formState: .constant(OnboardingPreviewData.formState))
        .padding()
        .background(OnboardingTheme.background)
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
    .preferredColorScheme(.dark)
}

#Preview("Gentle pace") {
    OnboardingGoalStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.selectPaceChoice(.gentle)
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Advanced open") {
    OnboardingGoalStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.selectPaceChoice(.advanced)
            state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.5")
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Advanced invalid") {
    OnboardingGoalStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.selectPaceChoice(.advanced)
            state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "2.5")
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Imperial") {
    OnboardingGoalStepView(
        formState: .constant({
            var state = OnboardingPreviewData.formState
            state.unitSystem = .imperial
            return state
        }())
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}


