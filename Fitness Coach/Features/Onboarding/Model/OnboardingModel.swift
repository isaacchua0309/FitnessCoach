//
//  OnboardingModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for first-run onboarding.
//

import Combine
import Foundation
import SwiftUI

enum OnboardingCompletionIntent: Equatable, Sendable {
    case signIn
}

@MainActor
final class OnboardingModel: ObservableObject {

    static let minimumGenerationDisplayDuration: TimeInterval =
        OnboardingGeneratingPlanTiming.minimumDisplayDuration

    @Published private(set) var currentStep: OnboardingStep
    @Published var formState = OnboardingFormState()
    @Published private(set) var viewState: OnboardingViewState = .editing
    @Published private(set) var generatedPlan: CalorieTargetResult?
    @Published private(set) var planRevealState: OnboardingPlanRevealState?
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLocalProfile = false
    @Published private(set) var pendingCompletionIntent: OnboardingCompletionIntent?
    @Published private(set) var appleHealthPresentation: OnboardingAppleHealthPresentationState = .ready
    @Published private(set) var appleHealthDeviceState: TrainingIntegrationState = .notConnected

    let flowFloor: OnboardingStep

    var requiresGoogleSignInAtSavePlan: Bool {
        analyticsEntry == .preAuth
    }

    private(set) var hasCommittedLocalProfile = false

    private let actionCenter: FitnessActionCenter
    private let userProfileReader: any UserProfileReading
    private let draftStore: OnboardingDraftStore
    private let coachingContextStore: OnboardingCoachingContextStore
    private let analyticsEntry: OnboardingAnalyticsEntry
    private let generationDelay: any OnboardingGenerationDelayProviding
    private let onCompletion: () -> Void

    private let planGenerationExecutor: OnboardingPlanGenerationExecutor
    private let profileCommitter: OnboardingProfileCommitter
    private let appleHealthCoordinator: OnboardingAppleHealthCoordinator
    private let analyticsTracker: OnboardingAnalyticsTracker

    private var generationTask: Task<Void, Never>?

    init(
        actionCenter: FitnessActionCenter,
        userProfileReader: any UserProfileReading,
        planTargetCalculator: any PlanTargetCalculating,
        onCompletion: @escaping () -> Void,
        draftStore: OnboardingDraftStore? = nil,
        coachingContextStore: OnboardingCoachingContextStore? = nil,
        analyticsLogger: (any OnboardingAnalyticsLogging)? = nil,
        analyticsEntry: OnboardingAnalyticsEntry = .preAuth,
        generationDelay: (any OnboardingGenerationDelayProviding)? = nil,
        healthTrainingIntegration: TrainingIntegrationProviding? = nil,
        trainingInsightsStore: TrainingInsightsStore? = nil
    ) {
        let resolvedDraftStore = draftStore ?? OnboardingDraftStore()
        let resolvedCoachingContextStore = coachingContextStore ?? OnboardingCoachingContextStore()
        let resolvedAnalyticsLogger = analyticsLogger ?? NoOpOnboardingAnalyticsLogger()
        let resolvedGenerationDelay = generationDelay ?? SystemOnboardingGenerationDelayProvider()
        let resolvedHealthIntegration = healthTrainingIntegration ?? HealthTrainingService()

        self.actionCenter = actionCenter
        self.userProfileReader = userProfileReader
        self.draftStore = resolvedDraftStore
        self.coachingContextStore = resolvedCoachingContextStore
        self.analyticsEntry = analyticsEntry
        self.generationDelay = resolvedGenerationDelay
        self.onCompletion = onCompletion

        planGenerationExecutor = OnboardingPlanGenerationExecutor(
            planTargetCalculator: planTargetCalculator,
            generationDelay: resolvedGenerationDelay
        )
        profileCommitter = OnboardingProfileCommitter(
            actionCenter: actionCenter,
            userProfileReader: userProfileReader
        )
        appleHealthCoordinator = OnboardingAppleHealthCoordinator(
            healthTrainingIntegration: resolvedHealthIntegration,
            trainingInsightsStore: trainingInsightsStore
        )
        analyticsTracker = OnboardingAnalyticsTracker(
            analyticsLogger: resolvedAnalyticsLogger,
            analyticsEntry: analyticsEntry
        )

        let session = OnboardingSessionBootstrap.resolve(
            analyticsEntry: analyticsEntry,
            draftStore: resolvedDraftStore,
            userProfileReader: userProfileReader
        )

        formState = session.formState
        generatedPlan = session.generatedPlan
        planRevealState = session.planRevealState
        hasLocalProfile = session.hasLocalProfile
        hasCommittedLocalProfile = session.hasCommittedLocalProfile
        currentStep = session.initialStep
        flowFloor = OnboardingEntry.flowFloor(
            analyticsEntry: analyticsEntry,
            currentStep: session.initialStep
        )
        viewState = resolvedViewState(for: session.initialStep)

        analyticsTracker.bootstrap(
            restoredFromDraft: session.restoredFromDraft,
            currentStep: session.initialStep
        )
    }

    // MARK: Navigation

    func goNext() {
        clearError()
        let completedStep = currentStep

        switch currentStep {
        case .introProof, .targetEncouragement, .almostThere, .formaProof:
            if let next = nextStep(after: currentStep) {
                advance(to: next, completing: completedStep)
            }
        case .heightWeight, .birthday, .targetWeight, .weightLossPace:
            guard validateCurrentStep() else { return }
            if let next = nextStep(after: currentStep) {
                advance(to: next, completing: completedStep)
            }
        case .appleHealth:
            connectAppleHealth()
        case .activityLevel:
            formState.applyTrainingRhythmDefaultsForCurrentActivity()
            guard validateCurrentStep() else { return }
            if let next = nextStep(after: currentStep) {
                advance(to: next, completing: completedStep)
            }
        case .review:
            recordStepCompleted(for: completedStep)
            beginGeneration()
        case .planReveal:
            prepareForSavePlan()
        case .savePlan:
            recordStepCompleted(for: completedStep)
            awaitSignInAndFinish()
        case .generatingPlan:
            break
        }
    }

    var canGoBack: Bool {
        currentStep.allowsBackNavigation(in: OnboardingStep.flow, notBefore: flowFloor)
    }

    var canExitToWelcome: Bool {
        WelcomeOnboardingHandoffPolicy.canExitToWelcome(
            step: currentStep,
            analyticsEntry: analyticsEntry
        )
    }

    func goBack() {
        clearError()
        guard let previous = backTarget(for: currentStep) else { return }

        if currentStep.clearsGeneratedPlanWhenNavigatingBack(in: OnboardingStep.flow) {
            clearGeneratedPlan()
        }

        currentStep = previous
        viewState = resolvedViewState(for: previous)
        if OnboardingInteractionPolicy.rules(for: previous).dismissesKeyboardOnAppear {
            OnboardingKeyboard.dismiss()
        }
        recordStepViewed(previous)
        autosaveDraft()
    }

    func clearError() {
        errorMessage = nil
        if case .error = viewState {
            viewState = .editing
        }
    }

    var appleHealthScreenState: OnboardingAppleHealthScreenState {
        appleHealthCoordinator.buildScreenState(
            presentation: appleHealthPresentation,
            deviceState: appleHealthDeviceState
        )
    }

    func prepareAppleHealthStep() {
        guard currentStep == .appleHealth else { return }
        syncAppleHealthPresentation(from: appleHealthDeviceState)
        logAppleHealthCTAState(action: "step_prepared")

        Task { [weak self] in
            guard let self else { return }
            let refreshed = await appleHealthCoordinator.refreshDeviceState()
            guard currentStep == .appleHealth else { return }
            appleHealthDeviceState = refreshed
            syncAppleHealthPresentation(from: refreshed)
            logAppleHealthCTAState(action: "authorization_refreshed")
        }
    }

    func connectAppleHealth() {
        guard currentStep == .appleHealth else { return }
        guard viewState != .connectingAppleHealth else { return }

        logAppleHealthCTAState(action: "primary_tapped")

        if shouldAdvanceFromConnectedAppleHealth {
            logAppleHealthCTAState(action: "advance_without_permission_request")
            advanceFromAppleHealth(completedStep: .appleHealth)
            return
        }

        guard appleHealthScreenState.isPrimaryEnabled else { return }
        guard appleHealthPresentation.allowsPermissionRequest else { return }

        let completedStep = currentStep
        viewState = .connectingAppleHealth
        appleHealthPresentation = .requesting
        logAppleHealthCTAState(action: "permission_request_started")
        analyticsTracker.logAppleHealth(.appleHealthConnectTapped)
        analyticsTracker.logAppleHealth(.appleHealthPermissionRequested)

        Task { [weak self] in
            await self?.performAppleHealthPermissionFlow(completedStep: completedStep)
        }
    }

    func skipAppleHealth() {
        guard currentStep == .appleHealth else { return }
        guard viewState != .connectingAppleHealth else { return }
        guard appleHealthScreenState.isSkipEnabled else { return }

        analyticsTracker.logAppleHealth(.appleHealthSkipTapped)
        advanceFromAppleHealth(completedStep: .appleHealth)
    }

    // MARK: Plan generation

    func generatePlanPreview() {
        beginGeneration()
    }

    func beginGeneration() {
        guard currentStep == .review else { return }
        guard viewState == .editing || viewState == .generationFailed else { return }

        formState.applyTrainingRhythmDefaultsForCurrentActivity()
        if let invalidStep = planGenerationExecutor.firstInvalidRequiredStep(for: formState) {
            errorMessage = planGenerationExecutor.validationMessage(for: invalidStep, formState: formState)
                ?? FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
            advance(to: invalidStep, persistDraft: true, completing: nil)
            return
        }

        generationTask?.cancel()
        currentStep = .generatingPlan
        viewState = .generatingPlanAnimated
        errorMessage = nil
        recordStepViewed(.generatingPlan)
        autosaveDraft()

        generationTask = Task { @MainActor in
            await runGeneration()
        }
    }

    func completeGenerationRevealHandoff() {
        guard currentStep == .generatingPlan, viewState == .generationSucceeded else { return }

        var transaction = Transaction(
            animation: .easeOut(duration: OnboardingGeneratingPlanTiming.stepTransitionAnimation)
        )
        if UIAccessibility.isReduceMotionEnabled {
            transaction.disablesAnimations = true
        }
        withTransaction(transaction) {
            currentStep = .planReveal
            viewState = .editing
        }

        recordStepViewed(.planReveal)
        if let plan = generatedPlan {
            analyticsTracker.logPlanRevealed(
                formState: formState,
                plan: plan,
                revealState: planRevealState
            )
        }
        autosaveDraft()
    }

    func returnToSummaryAfterGenerationFailure() {
        guard currentStep == .generatingPlan else { return }
        advance(to: .review, persistDraft: true, completing: nil)
    }

    func retryGeneration() {
        guard currentStep == .generatingPlan, viewState == .generationFailed else { return }

        generationTask?.cancel()
        viewState = .generatingPlanAnimated
        errorMessage = nil
        autosaveDraft()

        generationTask = Task { @MainActor in
            await runGeneration()
        }
    }

    func adjustPlanFromReveal() {
        guard currentStep == .planReveal else { return }
        clearGeneratedPlan()
        advance(to: .targetWeight, persistDraft: true, completing: nil)
    }

    // MARK: Profile save / completion

    func completeOnboarding() {
        if currentStep == .savePlan {
            awaitSignInAndFinish()
        }
    }

    func prepareForSavePlan() {
        guard currentStep == .planReveal, viewState == .editing else { return }
        viewState = .savingProfile
        commitLocalProfileForSavePlan()
        guard errorMessage == nil else {
            viewState = .editing
            return
        }
        advance(to: .savePlan, persistDraft: false, completing: .planReveal)
        viewState = .editing
    }

    func commitLocalProfileForSavePlan() {
        do {
            let created = try profileCommitter.commitIfNeeded(
                formState: formState,
                generatedPlan: generatedPlan
            )
            hasLocalProfile = true
            persistCoachingContext()
            let wasAlreadyCommitted = hasCommittedLocalProfile
            hasCommittedLocalProfile = true
            draftStore.clearDraft()
            if created, !wasAlreadyCommitted {
                analyticsTracker.logProfileSavedLocal(
                    currentStep: currentStep,
                    formState: formState,
                    generatedPlan: generatedPlan,
                    revealState: planRevealState
                )
            }
        } catch {
            errorMessage = profileCommitter.userFacingMessage(for: error)
        }
    }

    func saveLocalProfile() {
        guard hasCommittedLocalProfile else {
            commitLocalProfileForSavePlan()
            return
        }
        persistCoachingContext()
    }

    func awaitSignInAndFinish() {
        if !(hasCommittedLocalProfile || hasLocalProfile) {
            commitLocalProfileForSavePlan()
            guard errorMessage == nil else { return }
        }

        pendingCompletionIntent = .signIn
        viewState = .awaitingSignIn
        errorMessage = nil
        onCompletion()
    }

    func logSavePlanSignInStarted() {
        guard currentStep == .savePlan else { return }
        analyticsTracker.logSignInStarted()
    }

    func handleGoogleSignInCancelled() {
        guard currentStep == .savePlan else { return }
        errorMessage = nil
        analyticsTracker.logSignInCancelled()
    }

    func handleGoogleSignInFailed() {
        guard currentStep == .savePlan else { return }
        errorMessage = FormaProductCopy.Onboarding.V2.SavePlan.signInRetryHeadline
    }

    func handleSignInCompletionFailure(message: String? = nil, wasCancelled: Bool = false) {
        _ = message
        if wasCancelled {
            handleGoogleSignInCancelled()
        } else {
            handleGoogleSignInFailed()
        }
    }

    func markSignInSucceededForHandoff() {
        guard currentStep == .savePlan else { return }
        viewState = .signInSucceeded
        finalizeAfterSuccessfulSignIn()
    }

    func finalizeAfterSuccessfulSignIn() {
        analyticsTracker.logSignInCompleted()
        recordOnboardingFinished(completionPath: "sign_in")
    }

    func finalizeAfterRestoredExistingPlan() {
        analyticsTracker.logSignInCompleted()
        recordOnboardingFinished(completionPath: "restored_existing")
    }

    // MARK: Helpers

    func flushPendingGenerationForTesting() async {
        await generationTask?.value
    }

    func flushDraftSnapshotIfNeeded() {
        autosaveDraft()
    }

    // MARK: Private

    private func advanceFromAppleHealth(completedStep: OnboardingStep) {
        guard currentStep == .appleHealth else { return }
        viewState = .editing
        if let next = nextStep(after: .appleHealth) {
            advance(to: next, completing: completedStep)
        }
        syncAppleHealthPresentation(from: appleHealthDeviceState)
        logAppleHealthCTAState(action: "advanced_from_step")
    }

    private var shouldAdvanceFromConnectedAppleHealth: Bool {
        appleHealthCoordinator.shouldAdvanceFromConnected(
            presentation: appleHealthPresentation,
            deviceState: appleHealthDeviceState
        )
    }

    private func syncAppleHealthPresentation(from deviceState: TrainingIntegrationState) {
        appleHealthPresentation = appleHealthCoordinator.mapPresentation(from: deviceState)
    }

    private func logAppleHealthCTAState(action: String) {
        appleHealthCoordinator.logCTAState(
            action: action,
            presentation: appleHealthPresentation,
            deviceState: appleHealthDeviceState,
            screenState: appleHealthScreenState,
            isConnecting: viewState == .connectingAppleHealth
        )
    }

    private func performAppleHealthPermissionFlow(completedStep: OnboardingStep) async {
        let resultState = await appleHealthCoordinator.requestPermission()

        analyticsTracker.logAppleHealth(
            .appleHealthPermissionResult,
            permissionResult: OnboardingAppleHealthFlow.analyticsResult(for: resultState)
        )

        guard currentStep == .appleHealth else { return }

        appleHealthDeviceState = resultState
        appleHealthPresentation = appleHealthCoordinator.mapPresentation(from: resultState)
        viewState = .editing
        logAppleHealthCTAState(action: "permission_request_finished")

        if appleHealthPresentation == .connected {
            OnboardingHaptics.selectionChanged()
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard currentStep == .appleHealth, appleHealthPresentation == .connected else { return }
            advanceFromAppleHealth(completedStep: completedStep)
        }
    }

    private func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        if step == .targetWeight, !formState.isPaceApplicable() {
            return .targetEncouragement
        }
        return OnboardingStepPolicy.next(after: step)
    }

    private func backTarget(for step: OnboardingStep) -> OnboardingStep? {
        if step == .targetEncouragement, !formState.isPaceApplicable() {
            return .targetWeight
        }
        return OnboardingStepPolicy.back(from: step, notBefore: flowFloor)
    }

    private func advance(
        to step: OnboardingStep,
        persistDraft: Bool = true,
        completing completedStep: OnboardingStep? = nil
    ) {
        if let completedStep {
            recordStepCompleted(for: completedStep)
        }
        currentStep = step
        viewState = resolvedViewState(for: step)
        if OnboardingInteractionPolicy.rules(for: step).dismissesKeyboardOnAppear {
            OnboardingKeyboard.dismiss()
        }
        recordStepViewed(step)
        if persistDraft, shouldPersistDraft {
            autosaveDraft()
        }
    }

    private func validateCurrentStep() -> Bool {
        do {
            try formState.validate(step: currentStep)
            return true
        } catch let error as OnboardingFormError {
            errorMessage = error.message
            return false
        } catch {
            errorMessage = FormaProductCopy.Error.checkInputs
            return false
        }
    }

    private func runGeneration() async {
        do {
            let plan = try await planGenerationExecutor.runGeneration(formState: formState)
            guard !Task.isCancelled else { return }
            revealGeneratedPlan(plan)
            await holdForGenerationSuccessBeatIfNeeded()
            guard !Task.isCancelled else { return }
            completeGenerationRevealHandoff()
        } catch {
            guard !Task.isCancelled else { return }
            clearGeneratedPlan()
            viewState = .generationFailed
            errorMessage = FormaProductCopy.Onboarding.V2.Generating.failureMessage
            autosaveDraft()
        }
    }

    private func revealGeneratedPlan(_ plan: CalorieTargetResult) {
        generatedPlan = plan
        planRevealState = planGenerationExecutor.buildPlanReveal(formState: formState, plan: plan)
        analyticsTracker.logPlanGenerated(
            currentStep: currentStep,
            formState: formState,
            plan: plan,
            revealState: planRevealState
        )
        recordStepCompleted(for: .generatingPlan)
        viewState = .generationSucceeded
        autosaveDraft()
    }

    private func holdForGenerationSuccessBeatIfNeeded() async {
        guard viewState == .generationSucceeded else { return }
        let hold = planGenerationExecutor.successHoldDuration()
        guard hold > 0 else { return }
        await generationDelay.delay(for: hold)
    }

    private func clearGeneratedPlan() {
        generatedPlan = nil
        planRevealState = nil
    }

    private var shouldPersistDraft: Bool {
        !hasCommittedLocalProfile
    }

    private func autosaveDraft() {
        guard shouldPersistDraft else { return }
        draftStore.saveDraft(
            OnboardingDraft(
                formState: formState,
                step: currentStep,
                generatedPlan: generatedPlan
            )
        )
    }

    private func persistCoachingContext() {
        coachingContextStore.save(formState.makeCoachingContext())
    }

    private func recordOnboardingFinished(completionPath: String) {
        analyticsTracker.logCompleted(
            currentStep: currentStep,
            formState: formState,
            generatedPlan: generatedPlan,
            revealState: planRevealState,
            completionPath: completionPath
        )
    }

    private func recordStepViewed(_ step: OnboardingStep) {
        analyticsTracker.recordStepViewed(step)
        if step == .appleHealth {
            prepareAppleHealthStep()
        }
    }

    private func recordStepCompleted(for step: OnboardingStep) {
        analyticsTracker.recordStepCompleted(for: step)
    }

    private func resolvedViewState(for step: OnboardingStep) -> OnboardingViewState {
        if step == .savePlan {
            return analyticsEntry == .postAuth ? .editing : .awaitingSignIn
        }
        return .editing
    }
}
