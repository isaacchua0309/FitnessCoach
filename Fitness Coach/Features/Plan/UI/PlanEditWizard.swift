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
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.horizontal)
                    .padding(.top, 8)

                Form {
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

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(FormaTokens.Color.destructive)
                        }
                    }
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    toolbarConfirmationButton
                }
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

    // MARK: Steps

    private var goalAndTargetWeightStep: some View {
        Group {
            Section {
                Picker("Goal", selection: $goalType) {
                    ForEach(PlanGoalType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: goalType) { _, newValue in
                    applyGoalType(newValue)
                }
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
                        .foregroundStyle(FormaTokens.Color.textTertiary)
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
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                } else {
                    Text(FormaProductCopy.Onboarding.Flow.Birthday.birthDateRequiredMessage)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
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
                                    .foregroundStyle(FormaTokens.Color.textPrimary)
                                Spacer()
                                if formState.sex == sex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(FormaTokens.Color.accent)
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
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        }
    }

    private var heightAndWeightStep: some View {
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
                .foregroundStyle(FormaTokens.Color.textTertiary)
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
                                        .foregroundStyle(FormaTokens.Color.textPrimary)
                                    Text(OnboardingActivityLevelValues.optionDescription(for: level))
                                        .font(FormaTokens.Typography.caption)
                                        .foregroundStyle(FormaTokens.Color.textTertiary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 0)
                                if formState.activityLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(FormaTokens.Color.accent)
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
                    .foregroundStyle(FormaTokens.Color.textTertiary)
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
                    .foregroundStyle(FormaTokens.Color.textTertiary)
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
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                } else {
                    ForEach(review.changes) { change in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(change.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                            HStack {
                                Text(change.before)
                                    .strikethrough()
                                    .foregroundStyle(FormaTokens.Color.textSecondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(FormaTokens.Color.textTertiary)
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
                    .foregroundStyle(FormaTokens.Color.textTertiary)
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
                        comparison.warning ?? "These targets may be aggressive. Review before saving.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(FormaTokens.Color.warning)
                }
            }

            Section {
                ForEach(comparison.rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                        HStack {
                            Text(row.before)
                                .strikethrough()
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(FormaTokens.Color.textTertiary)
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
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }
        } else {
            Section {
                Text("Unable to preview targets. Go back and check your inputs.")
                                .foregroundStyle(FormaTokens.Color.textSecondary)
            }
        }
    }

    // MARK: Chrome

    @ViewBuilder
    private var toolbarConfirmationButton: some View {
        switch currentStep {
        case .confirmTargets:
            Button {
                save()
            } label: {
                if isSaving {
                    SwiftUI.ProgressView()
                } else {
                    Text("Save Plan")
                }
            }
            .disabled(isSaving || targetPreview == nil || isGeneratingTargets)
        case .reviewChanges:
            Button {
                advanceFromReview()
            } label: {
                if isGeneratingTargets {
                    SwiftUI.ProgressView()
                } else {
                    Text("Next")
                }
            }
            .disabled(isGeneratingTargets || !canAdvanceFromCurrentStep)
        default:
            if stepIndex < flow.count - 1 {
                Button("Next") { advance() }
                    .disabled(!canAdvanceFromCurrentStep)
            } else {
                EmptyView()
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(flow.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= stepIndex ? FormaTokens.Color.progress : FormaTokens.Color.progressTrack)
                    .frame(height: 3)
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
