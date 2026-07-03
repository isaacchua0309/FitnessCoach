//
//  PlanEditWizard.swift
//  Fitness Coach
//
//  FitPilot AI — Guided plan editing wizard.
//

import SwiftUI

struct PlanEditWizard: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var formState: PlanFormState
    let baselineProfile: UserProfile
    var initialStep: PlanEditWizardStep = .goalAndTargetWeight
    let errorMessage: String?
    let onSave: (PlanFormState) async -> Void
    let onCancel: () -> Void
    let onPrepareTargets: (PlanFormState) async throws -> CalorieTargetResult

    @State private var stepIndex = 0
    @State private var goalType: PlanGoalType = .loseFat
    @State private var isSaving = false
    @State private var isGeneratingTargets = false
    @State private var showExpertAdjustments = false
    @State private var targetPreview: CalorieTargetResult?

    /// Activity step — used by Plan tab deep links.
    static let activityLevelStep: PlanEditWizardStep = .activityLevel

    private var flow: [PlanEditWizardStep] {
        PlanEditWizardFlow.steps(for: formState)
    }

    private var currentStep: PlanEditWizardStep? {
        PlanEditWizardFlow.step(at: stepIndex, formState: formState)
    }

    var body: some View {
        NavigationStack {
            PlanEditShell(
                title: FormaProductCopy.PlanEditHero.shellTitle,
                stepCount: flow.count,
                currentStepIndex: stepIndex,
                heroState: heroState,
                confirmationTitle: confirmationTitle,
                showsConfirmation: showsConfirmation,
                isConfirmationEnabled: isConfirmationEnabled,
                isConfirmationLoading: isConfirmationLoading,
                onCancel: {
                    onCancel()
                    dismiss()
                },
                onConfirm: handleConfirmation
            ) {
                Form {
                    stepContent

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(FormaPlanTokens.Color.planDanger)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .environment(\.planProjection, projection)
            }
            .onAppear {
                goalType = PlanStateBuilder.goalType(for: formState.asProfileSnapshot())
                if let index = PlanEditWizardFlow.index(of: initialStep, formState: formState) {
                    stepIndex = index
                } else {
                    stepIndex = 0
                }
                formState.applyTrainingRhythmDefaultsForCurrentActivity()
            }
            .onChange(of: formState.birthDate) { _, _ in
                formState.syncAgeTextFromBirthDate()
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .goalAndTargetWeight:
            goalAndTargetWeightStep
        case .birthdayAndSex:
            birthdayAndSexStep
        case .heightAndWeight:
            heightAndWeightStep
        case .activityLevel:
            activityLevelStep
        case .reviewChanges:
            reviewChangesStep
        case .confirmTargets:
            confirmTargetsStep
        case .none:
            EmptyView()
        }
    }

    // MARK: Shell state

    private var projection: PlanProjection {
        PlanProjectionBuilder.build(
            formState: formState,
            goalType: goalType,
            caloriePreview: targetPreview,
            referenceDate: Date(),
            calendar: .current
        )
    }

    private var heroState: PlanEditHeroState {
        PlanEditHeroStateBuilder.build(projection: projection)
    }

    private var confirmationTitle: String {
        switch currentStep {
        case .confirmTargets:
            return "Save Plan"
        default:
            return "Next"
        }
    }

    private var showsConfirmation: Bool {
        switch currentStep {
        case .confirmTargets, .reviewChanges:
            return true
        default:
            return stepIndex < flow.count - 1
        }
    }

    private var isConfirmationEnabled: Bool {
        switch currentStep {
        case .confirmTargets:
            return targetPreview != nil && !isSaving
        case .reviewChanges:
            return canAdvanceFromCurrentStep
        default:
            return canAdvanceFromCurrentStep
        }
    }

    private var isConfirmationLoading: Bool {
        switch currentStep {
        case .confirmTargets:
            return isSaving
        case .reviewChanges:
            return isGeneratingTargets
        default:
            return false
        }
    }

    private func handleConfirmation() {
        switch currentStep {
        case .confirmTargets:
            save()
        case .reviewChanges:
            advanceFromReview()
        default:
            advance()
        }
    }

    // MARK: Steps

    private var goalAndTargetWeightStep: some View {
        Group {
            Section {
                PlanGoalSelectionView(
                    selection: $goalType,
                    recommendedGoal: PlanGoalSelectionBuilder.recommendedGoal(for: baselineProfile),
                    onSelect: applyGoalType
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                FormaLabeledNumberField(
                    title: FormaProductCopy.ProfileForm.goalWeight,
                    placeholder: "65",
                    text: $formState.goalWeightKgText,
                    unit: FormaProductCopy.FoodForm.kgUnit,
                    keyboard: .decimalPad
                )
                .padding(.vertical, FormaTokens.Spacing.xs)
                .formaFormSection()
            } header: {
                FormaSettingsSectionHeader(title: "Target weight")
            }

            Section {
                WeightLossPaceSettingsView(
                    paceChoice: $formState.weightLossPaceChoice,
                    advancedDraft: $formState.advancedPaceDraft,
                    weightKg: parsedWeightKg,
                    goalWeightKg: parsedGoalWeightKg,
                    isPaceApplicable: goalType == .loseFat
                )
                .onChange(of: formState.weightLossPaceChoice) { _, _ in
                    formState.syncAggressivenessFromPaceChoice()
                }
            } header: {
                FormaSettingsSectionHeader(title: "Pace")
            } footer: {
                if goalType == .loseFat {
                    Text("Forma computes calorie and macro targets from your pace, weight, and lifestyle.")
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                }
            }

            if goalType != .loseFat {
                Section {
                    PlanProjectionImpactCard(projection: projection)
                } header: {
                    FormaSettingsSectionHeader(title: FormaProductCopy.PlanProjection.impactTitle)
                }
            }
        }
    }

    private var birthdayAndSexStep: some View {
        Group {
            Section {
                OnboardingBirthdayWheelPicker(birthDate: $formState.birthDate)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                FormaSettingsSectionHeader(title: "Birthday")
            } footer: {
                if let birthDate = formState.birthDate {
                    Text("Age used for calculations: \(PlanFormatter.age(BirthDateAgeResolver.age(from: birthDate)))")
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                } else {
                    Text(FormaProductCopy.Onboarding.Flow.Birthday.birthDateRequiredMessage)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    ForEach([Sex.male, .female, .other], id: \.self) { sex in
                        Button {
                            formState.sex = sex
                        } label: {
                            HStack {
                                Text(PlanFormatter.sex(sex))
                                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                                Spacer()
                                if formState.sex == sex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(FormaPlanTokens.Color.planAccent)
                                }
                            }
                            .padding(.vertical, FormaTokens.Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
                .formaFormSection()
            } header: {
                FormaSettingsSectionHeader(title: FormaProductCopy.ProfileForm.sex)
            } footer: {
                Text("Biological sex is required for calorie and macro calculations.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            }
        }
    }

    private var heightAndWeightStep: some View {
        Group {
            Section {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    FormaLabeledNumberField(
                        title: FormaProductCopy.ProfileForm.height,
                        placeholder: "175",
                        text: $formState.heightCmText,
                        unit: "cm",
                        keyboard: .decimalPad
                    )
                    FormaLabeledNumberField(
                        title: FormaProductCopy.ProfileForm.baselineWeight,
                        placeholder: "70",
                        text: $formState.currentWeightKgText,
                        unit: FormaProductCopy.FoodForm.kgUnit,
                        keyboard: .decimalPad
                    )
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
                .formaFormSection()
            } header: {
                FormaSettingsSectionHeader(title: "Height & weight")
            } footer: {
                Text("Current weight drives your maintenance and target calculations.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            }

            if projection.hasEnergyTargets || projection.validationMessage != nil {
                Section {
                    PlanProjectionEnergyCard(projection: projection)
                } header: {
                    FormaSettingsSectionHeader(title: FormaProductCopy.PlanProjection.energyTitle)
                }
            }
        }
    }

    private var activityLevelStep: some View {
        Group {
            Section {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    ForEach(Array(OnboardingActivityLevelValues.orderedLevels.enumerated()), id: \.element) { index, level in
                        if index > 0 {
                            Divider()
                        }

                        Button {
                            formState.selectActivityLevel(level)
                        } label: {
                            HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(PlanFormatter.activityLevel(level))
                                        .font(FormaTokens.Typography.body.weight(.medium))
                                        .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                                    Text(OnboardingActivityLevelValues.optionDescription(for: level))
                                        .font(FormaTokens.Typography.caption)
                                        .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                if formState.activityLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(FormaPlanTokens.Color.planAccent)
                                }
                            }
                            .padding(.vertical, FormaTokens.Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
                .formaFormSection()
            } header: {
                FormaSettingsSectionHeader(title: FormaProductCopy.ProfileForm.activityLevel)
            } footer: {
                let rhythm = ActivityTrainingDefaultsResolver().defaults(for: formState.activityLevel)
                Text("Defaults: \(rhythm.trainingDaysPerWeek) training days/week, \(rhythm.averageStepsPerDay.formatted()) steps/day.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            }

            Section {
                DisclosureGroup("Expert adjustments", isExpanded: $showExpertAdjustments) {
                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                        FormaLabeledNumberField(
                            title: FormaProductCopy.ProfileForm.bodyFat,
                            placeholder: "Optional",
                            text: $formState.estimatedBodyFatPercentageText,
                            unit: "%",
                            keyboard: .decimalPad
                        )

                        FormaLabeledNumberField(
                            title: FormaProductCopy.ProfileForm.trainingDays,
                            placeholder: "3",
                            text: Binding(
                                get: { formState.trainingFrequencyPerWeekText },
                                set: { formState.setTrainingFrequencyPerWeekText($0) }
                            ),
                            keyboard: .numberPad
                        )

                        FormaLabeledNumberField(
                            title: FormaProductCopy.ProfileForm.averageSteps,
                            placeholder: "5000",
                            text: Binding(
                                get: { formState.averageStepsText },
                                set: { formState.setAverageStepsText($0) }
                            ),
                            keyboard: .numberPad
                        )

                        MacroTargetSettingsView(
                            calorieTargetText: $formState.calorieTargetText,
                            proteinTargetText: $formState.proteinTargetText,
                            carbTargetText: $formState.carbTargetText,
                            fatTargetText: $formState.fatTargetText,
                            expectedWeeklyWeightLossKgText: $formState.expectedWeeklyWeightLossKgText,
                            aggressiveness: $formState.aggressiveness,
                            onRegenerate: {
                                Task { await regenerateTargetsForExpertSection() }
                            }
                        )
                    }
                    .padding(.vertical, FormaTokens.Spacing.sm)
                }
            } footer: {
                Text("Optional overrides for body fat, macros, and training assumptions.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            }

            Section {
                PlanProjectionImpactCard(projection: projection)
            } header: {
                FormaSettingsSectionHeader(title: FormaProductCopy.PlanProjection.impactTitle)
            }

            if projection.hasEnergyTargets {
                Section {
                    PlanProjectionEnergyCard(projection: projection)
                } header: {
                    FormaSettingsSectionHeader(title: FormaProductCopy.PlanProjection.energyTitle)
                }
            }
        }
    }

    private var reviewChangesStep: some View {
        let review = PlanEditReviewBuilder.build(
            baseline: baselineProfile,
            formState: formState
        )

        return Group {
            Section {
                if review.changes.isEmpty {
                    Text("No plan inputs changed.")
                        .font(.subheadline)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                } else {
                    ForEach(review.changes) { change in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(change.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                            HStack {
                                Text(change.before)
                                    .strikethrough()
                                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                                Text(change.after)
                                    .fontWeight(.medium)
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                FormaSettingsSectionHeader(title: "Review changes")
            } footer: {
                Text("Next, Forma will regenerate your daily targets from these inputs.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            }

            Section {
                PlanProjectionImpactCard(projection: projection)
            } header: {
                FormaSettingsSectionHeader(title: FormaProductCopy.PlanProjection.impactTitle)
            }
        }
    }

    @ViewBuilder
    private var confirmTargetsStep: some View {
        if isGeneratingTargets {
            Section {
                HStack {
                    Spacer()
                    SwiftUI.ProgressView("Calculating targets…")
                    Spacer()
                }
            }
        } else if let preview = targetPreview {
            let comparison = PlanEditReviewBuilder.buildTargetComparison(
                before: baselineProfile.targets,
                preview: preview
            )

            if comparison.isAggressive || comparison.warning != nil {
                Section {
                    Label(
                        comparison.warning ?? projection.difficultyDescription,
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FormaPlanTokens.Color.planWarning)
                }
            }

            Section {
                PlanProjectionImpactCard(projection: projection)
            } header: {
                FormaSettingsSectionHeader(title: FormaProductCopy.PlanProjection.impactTitle)
            }

            Section {
                ForEach(comparison.rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        HStack {
                            Text(row.before)
                                .strikethrough()
                                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
                            Text(row.after)
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                FormaSettingsSectionHeader(title: "Target changes")
            } footer: {
                Text("Saving updates your plan and today's targets.")
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            }
        } else {
            Section {
                Text("Unable to preview targets. Go back and check your inputs.")
                                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
            }
        }
    }

    // MARK: Validation

    private var parsedWeightKg: Double {
        Double(formState.currentWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 70
    }

    private var parsedGoalWeightKg: Double {
        Double(formState.goalWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? parsedWeightKg
    }

    private var canAdvanceFromCurrentStep: Bool {
        switch currentStep {
        case .goalAndTargetWeight:
            guard goalType == .loseFat else { return true }
            return pacePreview.isSaveable
        case .birthdayAndSex:
            guard let birthDate = formState.birthDate else { return false }
            return BirthDateAgeResolver.isValidBirthDate(birthDate) && formState.sex != .preferNotToSay
        case .heightAndWeight:
            return parsedPositive(formState.heightCmText) != nil
                && parsedPositive(formState.currentWeightKgText) != nil
        case .activityLevel, .reviewChanges:
            return true
        case .confirmTargets:
            return targetPreview != nil
        case .none:
            return false
        }
    }

    private var pacePreview: WeightLossPacePreviewModel {
        WeightLossPacePreviewBuilder.build(
            choice: formState.weightLossPaceChoice,
            advancedDraft: formState.advancedPaceDraft,
            weightKg: parsedWeightKg,
            goalWeightKg: parsedGoalWeightKg
        )
    }

    // MARK: Actions

    private func advance() {
        withAnimation(.easeInOut(duration: 0.2)) {
            stepIndex = min(stepIndex + 1, flow.count - 1)
        }
    }

    private func advanceFromReview() {
        isGeneratingTargets = true
        Task {
            do {
                let preview = try await onPrepareTargets(formState)
                targetPreview = preview
                formState.applyGeneratedTargets(preview.targets)
                isGeneratingTargets = false
                advance()
            } catch {
                isGeneratingTargets = false
            }
        }
    }

    private func applyGoalType(_ type: PlanGoalType) {
        guard let current = Double(formState.currentWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        let goal: Double
        switch type {
        case .loseFat:
            goal = max(current - 5, current * 0.9)
        case .maintain:
            goal = current
        case .gainMuscle:
            goal = current + 3
        }

        formState.goalWeightKgText = formatDouble(goal)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await onSave(formState)
            isSaving = false
        }
    }

    private func regenerateTargetsForExpertSection() async {
        guard let preview = try? await onPrepareTargets(formState) else { return }
        formState.applyGeneratedTargets(preview.targets)
    }

    private func parsedPositive(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    private func formatDouble(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : "\(value)"
    }
}

// MARK: Form snapshot for goal type inference

private extension PlanFormState {
    func asProfileSnapshot() -> UserProfile {
        let now = Date()
        let age = (try? resolvedAge()) ?? 24
        return UserProfile(
            id: UUID(),
            name: name.isEmpty ? nil : name,
            birthDate: birthDate,
            age: age,
            sex: sex,
            heightCm: Double(heightCmText) ?? 170,
            currentWeightKg: Double(currentWeightKgText) ?? 70,
            goalWeightKg: Double(goalWeightKgText) ?? 65,
            estimatedBodyFatPercentage: Double(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: Int(trainingFrequencyPerWeekText) ?? 3,
            averageSteps: Int(averageStepsText) ?? 5000,
            dietPreference: dietPreference.isEmpty ? nil : dietPreference,
            unitSystem: unitSystem,
            targets: UserTargets(
                calorieTarget: Int(calorieTargetText) ?? 2000,
                proteinTarget: Double(proteinTargetText) ?? 140,
                carbTarget: Double(carbTargetText) ?? 200,
                fatTarget: Double(fatTargetText) ?? 56,
                waterTargetMl: Int(waterTargetMlText) ?? 2450,
                expectedWeeklyWeightLossKg: Double(expectedWeeklyWeightLossKgText),
                aggressiveness: aggressiveness
            ),
            createdAt: now,
            updatedAt: now
        )
    }
}

#Preview {
    PlanEditWizard(
        formState: .constant(PlanPreviewData.formState),
        baselineProfile: PlanPreviewData.profile,
        errorMessage: nil,
        onSave: { _ in },
        onCancel: {},
        onPrepareTargets: { _ in PlanPreviewData.generatedPreview }
    )
}
