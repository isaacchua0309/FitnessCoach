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
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                    PlanTransformationSummaryCard(state: transformationSummary)

                    PlanGoalWeightInputField(
                        text: $formState.goalWeightKgText,
                        unitSystem: formState.unitSystem,
                        validationMessage: goalWeightValidationMessage
                    )

                    if goalType == .loseFat {
                        WeightLossPaceSettingsView(
                            paceChoice: $formState.weightLossPaceChoice,
                            advancedDraft: $formState.advancedPaceDraft,
                            formState: formState,
                            goalType: goalType,
                            weightKg: parsedWeightKg,
                            goalWeightKg: parsedGoalWeightKg,
                            isPaceApplicable: true
                        )
                        .onChange(of: formState.weightLossPaceChoice) { _, _ in
                            formState.syncAggressivenessFromPaceChoice()
                        }
                    } else {
                        PlanProjectionImpactCard(projection: projection)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private var transformationSummary: PlanTransformationSummaryState {
        PlanTransformationSummaryBuilder.build(
            projection: projection,
            currentWeightKg: parsedPositive(formState.currentWeightKgText),
            goalWeightKg: parsedPositive(formState.goalWeightKgText),
            goalType: goalType
        )
    }

    private var goalWeightValidationMessage: String? {
        PlanGoalWeightValidationBuilder.validate(
            goalWeightText: formState.goalWeightKgText,
            currentWeightKg: parsedPositive(formState.currentWeightKgText),
            heightCm: parsedPositive(formState.heightCmText),
            goalType: goalType,
            unitSystem: formState.unitSystem
        )
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
        Section {
            PlanEditBodyBaselineStepView(
                formState: $formState,
                projection: projection
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var activityLevelStep: some View {
        Section {
            PlanEditActivityStepView(
                formState: $formState,
                showExpertAdjustments: $showExpertAdjustments,
                projection: projection,
                onRegenerateTargets: {
                    Task { await regenerateTargetsForExpertSection() }
                }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var reviewChangesStep: some View {
        let review = PlanEditReviewBuilder.build(
            baseline: baselineProfile,
            formState: formState
        )
        let summary = PlanEditFinalPlanSummaryBuilder.build(
            baseline: baselineProfile,
            formState: formState,
            goalType: goalType,
            projection: projection,
            review: review
        )

        return Section {
            PlanEditReviewStepView(summary: summary)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
            let review = PlanEditReviewBuilder.build(
                baseline: baselineProfile,
                formState: formState
            )
            let summary = PlanEditFinalPlanSummaryBuilder.build(
                baseline: baselineProfile,
                formState: formState,
                goalType: goalType,
                projection: projection,
                review: review,
                targetPreview: preview
            )

            Section {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                    if let warning = summary.warning {
                        PlanEditReviewWarningCard(warning: warning)
                    }

                    PlanEditFinalPlanCard(state: summary)

                    if !summary.todayChanges.isEmpty {
                        PlanEditTodayChangesCard(
                            changes: summary.todayChanges,
                            note: summary.todayNote
                        )
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
            guard goalWeightValidationMessage == nil else { return false }
            guard goalType == .loseFat else { return true }
            return pacePreview.isSaveable
        case .birthdayAndSex:
            guard let birthDate = formState.birthDate else { return false }
            return BirthDateAgeResolver.isValidBirthDate(birthDate) && formState.sex != .preferNotToSay
        case .heightAndWeight:
            return PlanBodyBaselineValidationBuilder.validate(
                heightText: formState.heightCmText,
                weightText: formState.currentWeightKgText
            ).isValid
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
