//
//  PlanEditWizard.swift
//  Fitness Coach
//
//  FitPilot AI — Guided plan editing wizard.
//

import SwiftUI

struct PlanEditWizard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var formState: PlanFormState
    let baselineProfile: UserProfile
    var initialStep: PlanEditWizardStep = .goalAndTargetWeight
    var weeklyReviewContext: PlanEditWeeklyReviewContext?
    let errorMessage: String?
    let onSave: (PlanFormState) async throws -> Void
    let onCancel: () -> Void
    let onPrepareTargets: (PlanFormState) async throws -> CalorieTargetResult

    @State private var stepIndex = 0
    @State private var goalType: PlanGoalType = .loseFat
    @State private var isSaving = false
    @State private var saveSuccessState: PlanEditSaveSuccessState?
    @State private var isGeneratingTargets = false
    @State private var showExpertAdjustments = false
    @State private var targetPreview: CalorieTargetResult?
    @State private var didInitialize = false
    @State private var discardConfirmationState = PlanEditDiscardConfirmationState()
    @State private var isStepTransitionInFlight = false
    @State private var stepTransitionGeneration = 0

    /// Activity step — used by Plan tab deep links.
    static let activityLevelStep: PlanEditWizardStep = .activityLevel

    private var flow: [PlanEditWizardStep] {
        PlanEditWizardFlow.steps(for: formState)
    }

    private var currentStep: PlanEditWizardStep? {
        PlanEditWizardFlow.step(at: stepIndex, formState: formState)
    }

    private var reviewState: PlanEditReviewState {
        PlanEditReviewBuilder.build(
            baseline: baselineProfile,
            formState: formState
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let saveSuccessState {
                    PlanEditSaveSuccessView(state: saveSuccessState)
                        .transition(reduceMotion ? .identity : .opacity)
                } else {
                    wizardContent
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .animation(
                PlanEditMotion.animation(PlanEditMotion.stepTransition, reduceMotion: reduceMotion),
                value: saveSuccessState != nil
            )
            .onAppear(perform: initializeIfNeeded)
            .onChange(of: scenePhase) { _, newPhase in
                // Preserve in-progress edits when the app backgrounds.
                guard newPhase == .active, didInitialize else { return }
            }
            .onChange(of: formState.currentWeightKgText) { _, _ in
                if goalType == .maintain {
                    formState.syncMaintainGoalWeightFromCurrent()
                }
            }
            .overlay {
                if saveSuccessState == nil, discardConfirmationState.isShowingConfirmation {
                    DiscardChangesConfirmationView(
                        title: FormaProductCopy.PlanEditWizardCopy.discardChangesTitle,
                        message: FormaProductCopy.PlanEditWizardCopy.discardChangesMessage,
                        keepEditingTitle: FormaProductCopy.PlanEditWizardCopy.keepEditing,
                        discardTitle: FormaProductCopy.PlanEditWizardCopy.discardChanges,
                        onKeepEditing: {
                            discardConfirmationState.keepEditing()
                        },
                        onDiscard: {
                            discardConfirmationState.dismissConfirmation()
                            discardDraftChanges()
                        }
                    )
                    .zIndex(1)
                }
            }
            .animation(
                PlanEditMotion.animation(PlanEditMotion.modalPresentation, reduceMotion: reduceMotion),
                value: discardConfirmationState.isShowingConfirmation
            )
            .formaThemeReactive()
        }
    }

    private var wizardContent: some View {
        AdjustPlanView(
                title: FormaProductCopy.PlanEditHero.shellTitle,
                stepCount: flow.count,
                currentStepIndex: stepIndex,
                heroState: heroState,
                confirmationTitle: confirmationTitle,
                showsConfirmation: showsConfirmation,
                isConfirmationEnabled: isConfirmationEnabled,
                isConfirmationLoading: isConfirmationLoading,
                onCancel: requestCancel,
                onConfirm: handleConfirmation
            ) {
                Form {
                    animatedStepContent

                    if let inlineNotice = stepInlineNotice {
                        Section {
                            Text(inlineNotice)
                                .font(FormaTokens.Typography.caption)
                                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(FormaPlanTokens.Color.planDanger)
                        }
                        .planEditAnnounces(announcedError(errorMessage))
                    }
                }
                .scrollContentBackground(.hidden)
                .animation(
                    PlanEditMotion.animation(PlanEditMotion.stepTransition, reduceMotion: reduceMotion),
                    value: currentStep
                )
                .environment(\.planProjection, projection)
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .planEditSupportsDynamicType()
    }

    @ViewBuilder
    private var animatedStepContent: some View {
        if let step = currentStep {
            stepContent
                .id(step)
                .transition(reduceMotion ? .identity : PlanEditMotion.stepContentTransition)
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
            return FormaProductCopy.PlanEditCommon.savePlan
        default:
            return FormaProductCopy.PlanEditCommon.next
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
        guard !isNavigationLocked else { return false }

        switch currentStep {
        case .confirmTargets:
            return PlanEditWizardStepGate.canSave(
                targetPreview: targetPreview,
                reviewHasChanges: reviewState.hasChanges,
                isSaving: isSaving
            ) && saveSuccessState == nil
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

    private var hasUnsavedChanges: Bool {
        PlanEditWizardStepGate.hasUnsavedChanges(
            baseline: baselineProfile,
            formState: formState
        )
    }

    private var isNavigationLocked: Bool {
        isStepTransitionInFlight || isSaving || isGeneratingTargets
    }

    private var stepInlineNotice: String? {
        switch currentStep {
        case .confirmTargets where !reviewState.hasChanges:
            return FormaProductCopy.PlanEditWizardCopy.saveNoChangesHint
        case .activityLevel
            where PlanEditWizardStepGate.shouldWarnCustomPaceAfterActivityChange(formState: formState):
            return FormaProductCopy.PlanEditPace.activityChangedCustomPace
        default:
            return nil
        }
    }

    private func handleConfirmation() {
        guard !isNavigationLocked else { return }

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
                GoalOptionSelector(
                    selection: $goalType,
                    recommendedGoal: PlanGoalSelectionBuilder.recommendedGoal(for: baselineProfile),
                    onSelect: applyGoalType
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listSectionSpacing(FormaTokens.Spacing.md)

            Section {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    GoalPathPreviewCard(state: transformationSummary)

                    if goalType == .maintain {
                        maintainGoalSummary
                    } else {
                        PlanGoalWeightInputField(
                            text: $formState.goalWeightKgText,
                            unitSystem: formState.unitSystem,
                            validationMessage: goalWeightValidationMessage
                        )
                    }

                    if let nonCutPaceNotice = PlanEditWizardStepGate.nonCutPaceNotice(
                        goalType: goalType,
                        formState: formState
                    ) {
                        Text(nonCutPaceNotice)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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
                        .onChange(of: formState.advancedPaceDraft.amountText) { _, _ in
                            formState.recordCustomPaceCaptureIfNeeded()
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

    private var maintainGoalSummary: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(FormaProductCopy.PlanEditTarget.targetWeightTitle)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

            Text(maintainGoalLine)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let validationMessage = goalWeightValidationMessage {
                Text(validationMessage)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planDanger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(announcedError(validationMessage))
                    .planEditAnnounces(announcedError(validationMessage))
            }
        }
    }

    private var maintainGoalLine: String {
        if let currentKg = parsedPositive(formState.currentWeightKgText) {
            let summary = OnboardingGoalWeightBounds.weightSummary(
                valueKg: currentKg,
                unitSystem: formState.unitSystem
            )
            return FormaProductCopy.PlanEditTarget.maintainAroundWeight(summary)
        }
        return FormaProductCopy.PlanEditTarget.maintainTargetSummary
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
                FormaSettingsSectionHeader(title: FormaProductCopy.PlanEditCommon.birthdayTitle)
            } footer: {
                if let birthDate = formState.birthDate {
                    Text(
                        FormaProductCopy.PlanEditCommon.ageForPlan(
                            PlanFormatter.age(BirthDateAgeResolver.age(from: birthDate))
                        )
                    )
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
                        sexSelectionRow(for: sex)
                    }
                }
                .padding(.vertical, FormaTokens.Spacing.xs)
                .formaFormSection()
            } header: {
                FormaSettingsSectionHeader(title: FormaProductCopy.ProfileForm.sex)
            } footer: {
                Text(FormaProductCopy.PlanEditCommon.sexRequiredNote)
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
        let summary = PlanEditFinalPlanSummaryBuilder.build(
            baseline: baselineProfile,
            formState: formState,
            goalType: goalType,
            projection: projection,
            review: reviewState
        )

        return Section {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                if let weeklyReviewContext {
                    PlanEditWeeklyReviewContextCard(state: weeklyReviewContext)
                }

                PlanEditReviewStepView(summary: summary)
            }
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
                    SwiftUI.ProgressView(FormaProductCopy.PlanEditActivity.calculatingTargets)
                    Spacer()
                }
            }
        } else if let preview = targetPreview {
            let summary = PlanEditFinalPlanSummaryBuilder.build(
                baseline: baselineProfile,
                formState: formState,
                goalType: goalType,
                projection: projection,
                review: reviewState,
                targetPreview: preview
            )

            Section {
                PlanEditReviewStepView(
                    summary: summary,
                    showsStatusBanner: false,
                    showsInputChanges: false
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            Section {
                Text(FormaProductCopy.PlanEditActivity.previewUnavailable)
                                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
            }
        }
    }

    // MARK: Validation

    private var parsedWeightKg: Double {
        parsedPositive(formState.currentWeightKgText) ?? 70
    }

    private var parsedGoalWeightKg: Double {
        parsedPositive(formState.goalWeightKgText) ?? parsedWeightKg
    }

    private var canAdvanceFromCurrentStep: Bool {
        PlanEditWizardStepGate.canAdvance(
            from: currentStep,
            formState: formState,
            goalType: goalType,
            goalWeightValidationMessage: goalWeightValidationMessage,
            pacePreview: pacePreview
        )
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

    private func sexSelectionRow(for sex: Sex) -> some View {
        let isSelected = formState.sex == sex

        return Button {
            formState.sex = sex
        } label: {
            HStack {
                Text(PlanFormatter.sex(sex))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(FormaPlanTokens.Color.planAccent)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PlanFormatter.sex(sex))
        .accessibilityValue(PlanEditAccessibility.selectionValue(isSelected: isSelected))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func announcedError(_ message: String) -> String {
        "\(FormaProductCopy.PlanEditAccessibility.errorPrefix). \(message)"
    }

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true
        goalType = PlanStateBuilder.goalType(for: formState.asProfileSnapshot())
        if let index = PlanEditWizardFlow.index(of: initialStep, formState: formState) {
            stepIndex = index
        } else {
            stepIndex = 0
        }
        formState.applyTrainingRhythmDefaultsForCurrentActivity()
        if goalType == .maintain {
            formState.syncMaintainGoalWeightFromCurrent()
        }
    }

    private func requestCancel() {
        switch discardConfirmationState.handleCancelRequest(
            hasUnsavedChanges: hasUnsavedChanges
        ) {
        case .dismissImmediately:
            dismissAdjustPlan()
        case .presentConfirmation:
            break
        }
    }

    private func discardDraftChanges() {
        onCancel()
        dismiss()
    }

    private func dismissAdjustPlan() {
        onCancel()
        dismiss()
    }

    private func advance() {
        guard !isStepTransitionInFlight else { return }
        guard stepIndex < flow.count - 1 else { return }

        beginStepTransition {
            stepIndex = min(stepIndex + 1, flow.count - 1)
        }
    }

    private func beginStepTransition(_ updates: @escaping () -> Void) {
        guard !isStepTransitionInFlight else { return }

        isStepTransitionInFlight = true
        stepTransitionGeneration += 1
        let generation = stepTransitionGeneration

        PlanEditMotion.withAnimationIfEnabled(
            PlanEditMotion.stepTransition,
            reduceMotion: reduceMotion,
            updates
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + PlanEditMotion.stepTransitionDuration) {
            guard generation == stepTransitionGeneration else { return }
            isStepTransitionInFlight = false
        }
    }

    private func advanceFromReview() {
        guard !isGeneratingTargets else { return }
        isGeneratingTargets = true
        Task {
            do {
                let preview = try await onPrepareTargets(formState)
                guard !Task.isCancelled else { return }
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
        goalType = type

        if type != .loseFat {
            formState.resetPaceForNonCutGoal()
        }

        guard let current = parsedPositive(formState.currentWeightKgText) else {
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
        guard !isNavigationLocked else { return }
        guard PlanEditWizardStepGate.canSave(
            targetPreview: targetPreview,
            reviewHasChanges: reviewState.hasChanges,
            isSaving: isSaving
        ), saveSuccessState == nil else { return }
        isSaving = true
        Task {
            do {
                try await onSave(formState)
                guard !Task.isCancelled else { return }
                let success = PlanEditSaveSuccessBuilder.build(projection: projection)
                PlanEditMotion.withAnimationIfEnabled(
                    PlanEditMotion.successReveal,
                    reduceMotion: reduceMotion
                ) {
                    saveSuccessState = success
                }
                isSaving = false
                try? await Task.sleep(nanoseconds: PlanEditSaveSuccessBuilder.displayDurationNanoseconds)
                dismissAdjustPlan()
            } catch {
                isSaving = false
            }
        }
    }

    private func regenerateTargetsForExpertSection() async {
        guard let preview = try? await onPrepareTargets(formState) else { return }
        formState.applyGeneratedTargets(preview.targets)
    }

    private func parsedPositive(_ text: String) -> Double? {
        switch PlanNumericInputParser.parsePositiveDecimal(text) {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
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
    .formaThemePreview()
}
