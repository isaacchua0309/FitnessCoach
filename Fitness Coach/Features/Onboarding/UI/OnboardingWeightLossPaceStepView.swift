//
//  OnboardingWeightLossPaceStepView.swift
//  Fitness Coach
//
//  Forma — onboarding weight-loss pace selection.
//

import SwiftUI

struct OnboardingWeightLossPaceStepView: View {
    @Binding var formState: OnboardingFormState

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case advancedAmount
    }

    private var preview: WeightLossPacePreviewModel {
        formState.pacePreview()
    }

    private var blockingValidationMessage: String? {
        guard formState.isPaceApplicable() else {
            return nil
        }
        return preview.validationError
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            header

            if formState.isPaceApplicable() {
                paceOptions

                if formState.weightLossPaceChoice.isAdvanced {
                    advancedEditor
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                previewCard
            } else {
                OnboardingInfoCard(
                    title: "Pace is not needed",
                    message: "Your target is maintenance or gain, so Forma will skip weight-loss deficit pacing.",
                    icon: "checkmark.circle.fill"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.22), value: formState.weightLossPaceChoice)
        .animation(.easeOut(duration: 0.22), value: formState.advancedPaceDraft.period)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            OnboardingStageProgressHeader(currentStep: .weightLossPace, showsSubtitle: false)
                .accessibilityElement(children: .contain)

            Text("How fast do you want to lose weight?")
                .font(OnboardingMarketingTypography.visionHeadline)
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("We'll adjust your daily calories based on the pace you choose. You can change this later.")
                .font(FormaTokens.Typography.body)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var paceOptions: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(WeightLossPaceChoice.allCases) { choice in
                paceOptionCard(choice)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Weight loss pace options")
    }

    private func paceOptionCard(_ choice: WeightLossPaceChoice) -> some View {
        let isSelected = formState.weightLossPaceChoice == choice

        return Button {
            formState.selectPaceChoice(choice)
            OnboardingHaptics.selectionChanged()
            if choice.isAdvanced {
                focusedField = .advancedAmount
            } else {
                focusedField = nil
            }
        } label: {
            HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                Image(systemName: icon(for: choice, selected: isSelected))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.tertiaryText)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(choice.displayName)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)

                    Text(description(for: choice))
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onboardingCompactCard(selected: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var advancedEditor: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            Picker("Advanced pace period", selection: $formState.advancedPaceDraft.period) {
                ForEach(WeightLossAdvancedPaceDraft.Period.allCases) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .tint(OnboardingTheme.primary)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                    Text(formState.advancedPaceDraft.period.fieldTitle)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.secondaryText)

                    Spacer(minLength: 0)

                    Text("kg")
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.tertiaryText)
                }

                TextField(
                    formState.advancedPaceDraft.amountPlaceholder,
                    text: $formState.advancedPaceDraft.amountText
                )
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .advancedAmount)
                .font(FormaTokens.Typography.sectionTitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .padding(.horizontal, FormaTokens.Spacing.md)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                .background(OnboardingTheme.surfaceSubtle.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(inputBorderColor, lineWidth: 1)
                }
                .accessibilityLabel(formState.advancedPaceDraft.period.fieldTitle)
            }
        }
        .onboardingCompactCard(selected: true)
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            HStack {
                Text("Pace preview")
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)

                Spacer(minLength: 0)

                if let safetyDisplay = preview.safetyDisplay {
                    safetyBadge(safetyDisplay)
                }
            }

            if let blockingValidationMessage {
                Text(blockingValidationMessage)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 6) {
                    previewRow("Weekly", value: preview.weeklyLossKg.map { formatKg($0) + "/week" } ?? "-")
                    previewRow("Monthly", value: preview.monthlyLossKg.map { formatKg($0) + "/month" } ?? "-")
                    previewRow(
                        "Deficit",
                        value: preview.dailyDeficitKcal.map { "\($0) kcal/day" } ?? "-"
                    )
                }

                if let summary = preview.deficitSummaryLine {
                    Text(summary)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let warning = preview.warningMessage {
                    Text(warning)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(OnboardingTheme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onboardingCard(selected: preview.safetyDisplay == .sustainable)
        .accessibilityElement(children: .combine)
    }

    private func previewRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)

            Spacer(minLength: FormaTokens.Spacing.sm)

            Text(value)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
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
                    .fill(safetyColor(display).opacity(0.15))
            }
    }

    private var inputBorderColor: Color {
        blockingValidationMessage == nil
            ? OnboardingTheme.border.opacity(0.7)
            : OnboardingTheme.warning.opacity(0.9)
    }

    private func description(for choice: WeightLossPaceChoice) -> String {
        switch choice {
        case .gentle:
            return "About 0.25% of body weight per week. Easier recovery, steadier days."
        case .moderate:
            return "About 0.50% of body weight per week. Balanced for most routines."
        case .aggressive:
            return "About 0.75% of body weight per week. Faster, but more demanding."
        case .advanced:
            return "Set a custom weekly or monthly kg target."
        }
    }

    private func icon(for choice: WeightLossPaceChoice, selected: Bool) -> String {
        if selected { return "checkmark.circle.fill" }

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

    private func safetyColor(_ display: WeightLossPaceSafetyDisplay) -> Color {
        switch display {
        case .sustainable:
            return OnboardingTheme.success
        case .demanding, .tooAggressive:
            return OnboardingTheme.warning
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }
}

#if DEBUG
#Preview("Weight-loss pace") {
    OnboardingWeightLossPaceStepView(
        formState: .constant(OnboardingPreviewData.targetWeightLossFormState)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Advanced pace") {
    OnboardingWeightLossPaceStepView(
        formState: .constant({
            var state = OnboardingPreviewData.targetWeightLossFormState
            state.selectPaceChoice(.advanced)
            state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.7")
            return state
        }())
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Maintenance fallback") {
    OnboardingWeightLossPaceStepView(
        formState: .constant(OnboardingPreviewData.targetWeightMaintainFormState)
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
