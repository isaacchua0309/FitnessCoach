//
//  OnboardingModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for first-run onboarding.
//

import Combine
import Foundation

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

    private let userProfileService: UserProfileService
    private let targetService: TargetService
    private let draftStore: OnboardingDraftStore
    private let coachingContextStore: OnboardingCoachingContextStore
    private let analyticsLogger: any OnboardingAnalyticsLogging
    private let analyticsEntry: OnboardingAnalyticsEntry
    private let generationDelay: any OnboardingGenerationDelayProviding
    private let healthTrainingIntegration: TrainingIntegrationProviding
    private let trainingInsightsStore: TrainingInsightsStore?
    private let onCompletion: () -> Void
    private var generationTask: Task<Void, Never>?
    private var stepEnteredAt = Date()
    private var restoredFromDraft: Bool

    init(
        userProfileService: UserProfileService,
        targetService: TargetService,
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
        self.userProfileService = userProfileService
        self.targetService = targetService
        self.draftStore = resolvedDraftStore
        self.coachingContextStore = resolvedCoachingContextStore
        self.analyticsLogger = resolvedAnalyticsLogger
        self.analyticsEntry = analyticsEntry
        self.generationDelay = resolvedGenerationDelay
        self.healthTrainingIntegration = healthTrainingIntegration ?? HealthTrainingService()
        self.trainingInsightsStore = trainingInsightsStore
        self.onCompletion = onCompletion
        self.restoredFromDraft = false

        var resolvedFormState = OnboardingFormState()
        var resolvedGeneratedPlan: CalorieTargetResult?
        var resolvedPlanRevealState: OnboardingPlanRevealState?
        var resolvedHasLocalProfile = false
        var resolvedHasCommittedLocalProfile = false
        var resolvedRestoredFromDraft = false

        let initialStep = Self.resolveInitialStep(
            analyticsEntry: analyticsEntry,
            draftStore: resolvedDraftStore,
            userProfileService: userProfileService,
            formState: &resolvedFormState,
            generatedPlan: &resolvedGeneratedPlan,
            planRevealState: &resolvedPlanRevealState,
            hasLocalProfile: &resolvedHasLocalProfile,
            hasCommittedLocalProfile: &resolvedHasCommittedLocalProfile,
            restoredFromDraft: &resolvedRestoredFromDraft,
            draftStoreForClear: resolvedDraftStore
        )

        formState = resolvedFormState
        generatedPlan = resolvedGeneratedPlan
        planRevealState = resolvedPlanRevealState
        hasLocalProfile = resolvedHasLocalProfile
        hasCommittedLocalProfile = resolvedHasCommittedLocalProfile
        restoredFromDraft = resolvedRestoredFromDraft
        currentStep = initialStep
        flowFloor = OnboardingEntry.flowFloor(
            analyticsEntry: analyticsEntry,
            currentStep: initialStep
        )
        viewState = resolvedViewState(for: initialStep)

        bootstrapAnalyticsSession()
    }

    private static func resolveInitialStep(
        analyticsEntry: OnboardingAnalyticsEntry,
        draftStore: OnboardingDraftStore,
        userProfileService: UserProfileService,
        formState: inout OnboardingFormState,
        generatedPlan: inout CalorieTargetResult?,
        planRevealState: inout OnboardingPlanRevealState?,
        hasLocalProfile: inout Bool,
        hasCommittedLocalProfile: inout Bool,
        restoredFromDraft: inout Bool,
        draftStoreForClear: OnboardingDraftStore
    ) -> OnboardingStep {
        if let draft = draftStore.loadDraft(), draft.step != nil {
            formState = draft.makeFormState()
            generatedPlan = draft.makeGeneratedPlan()
            if let restoredPlan = generatedPlan {
                planRevealState = OnboardingPlanRevealBuilder.build(
                    formState: formState,
                    plan: restoredPlan
                )
            }
            let restoredStep = OnboardingDraftStepResolver.restoredStep(
                rawValue: draft.step!.rawValue,
                formState: formState,
                flow: OnboardingStep.flow
            )
            hasLocalProfile = (try? userProfileService.getCurrentProfile()) != nil
            if restoredStep == .savePlan, hasLocalProfile {
                hasCommittedLocalProfile = true
                draftStoreForClear.clearDraft()
            }
            restoredFromDraft = true
            return restoredStep
        }

        if let profile = try? userProfileService.getCurrentProfile() {
            hasLocalProfile = true
            if OnboardingCommittedProfileRestorer.shouldResumeSavePlan(profile: profile) {
                hasCommittedLocalProfile = true
                OnboardingCommittedProfileRestorer.hydrateFormState(&formState, from: profile)
                let plan = OnboardingCommittedProfileRestorer.reconstructGeneratedPlan(from: profile)
                generatedPlan = plan
                planRevealState = OnboardingPlanRevealBuilder.build(formState: formState, plan: plan)
                return .savePlan
            }
        }

        return OnboardingEntry.initialStep(for: analyticsEntry)
    }

    // MARK: Navigation

    func goNext() {
        clearError()
        let completedStep = currentStep

        switch currentStep {
        case .introProof:
            if let next = nextStep(after: currentStep) {
                advance(to: next, completing: completedStep)
            }
        case .heightWeight, .birthday, .targetWeight:
            guard validateCurrentStep() else { return }
            if let next = nextStep(after: currentStep) {
                advance(to: next, completing: completedStep)
            }
        case .targetEncouragement, .almostThere, .formaProof:
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
        OnboardingAppleHealthPresentationBuilder.build(
            presentation: appleHealthPresentation,
            deviceState: appleHealthDeviceState
        )
    }

    func prepareAppleHealthStep() {
        guard currentStep == .appleHealth else { return }
        appleHealthPresentation = .ready

        Task { [weak self] in
            guard let self else { return }
            let refreshed = await healthTrainingIntegration.refreshState()
            guard currentStep == .appleHealth else { return }
            appleHealthDeviceState = refreshed
            if refreshed == .connected {
                appleHealthPresentation = .connected
            } else if refreshed == .unavailable {
                appleHealthPresentation = .unavailable
            }
        }
    }

    func connectAppleHealth() {
        guard currentStep == .appleHealth else { return }
        guard viewState != .connectingAppleHealth else { return }
        guard appleHealthScreenState.isPrimaryEnabled else { return }

        let completedStep = currentStep
        viewState = .connectingAppleHealth
        appleHealthPresentation = .requesting
        logAppleHealthAnalytics(.appleHealthConnectTapped)
        logAppleHealthAnalytics(.appleHealthPermissionRequested)

        Task { [weak self] in
            await self?.performAppleHealthPermissionFlow(completedStep: completedStep)
        }
    }

    func skipAppleHealth() {
        guard currentStep == .appleHealth else { return }
        guard viewState != .connectingAppleHealth else { return }
        guard appleHealthScreenState.isSkipEnabled else { return }

        logAppleHealthAnalytics(.appleHealthSkipTapped)
        advanceFromAppleHealth(completedStep: .appleHealth)
    }

    private func advanceFromAppleHealth(completedStep: OnboardingStep) {
        guard currentStep == .appleHealth else { return }
        viewState = .editing
        appleHealthPresentation = .ready
        if let next = nextStep(after: .appleHealth) {
            advance(to: next, completing: completedStep)
        }
    }

    private func performAppleHealthPermissionFlow(completedStep: OnboardingStep) async {
        let resultState: TrainingIntegrationState
        if let trainingInsightsStore {
            resultState = await OnboardingAppleHealthFlow.requestPermission(
                trainingInsightsStore: trainingInsightsStore
            )
        } else {
            resultState = await OnboardingAppleHealthFlow.requestPermission(
                using: healthTrainingIntegration
            )
        }

        logAppleHealthAnalytics(
            .appleHealthPermissionResult,
            permissionResult: OnboardingAppleHealthFlow.analyticsResult(for: resultState)
        )

        guard currentStep == .appleHealth else { return }

        appleHealthDeviceState = resultState
        let presentation = OnboardingAppleHealthPresentationBuilder.mapPermissionResult(resultState)
        appleHealthPresentation = presentation
        viewState = .editing

        if presentation == .connected {
            OnboardingHaptics.selectionChanged()
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard currentStep == .appleHealth, appleHealthPresentation == .connected else { return }
            advanceFromAppleHealth(completedStep: completedStep)
        }
    }

    private func nextStep(after step: OnboardingStep) -> OnboardingStep? {
        OnboardingStepPolicy.next(after: step)
    }

    private func backTarget(for step: OnboardingStep) -> OnboardingStep? {
        OnboardingStepPolicy.back(from: step, notBefore: flowFloor)
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

    // MARK: Plan generation

    func generatePlanPreview() {
        beginGeneration()
    }

    func beginGeneration() {
        guard currentStep == .review else { return }
        guard viewState == .editing || viewState == .generationFailed else { return }

        formState.applyTrainingRhythmDefaultsForCurrentActivity()
        if let invalidStep = OnboardingFormState.firstInvalidRequiredStep(for: formState) {
            errorMessage = formState.validationMessage(for: invalidStep)
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

    private func runGeneration() async {
        let startedAt = Date()

        do {
            let input = try formState.makeCalorieTargetInput()
            let plan = try targetService.generateInitialTargets(from: input)

            let elapsed = Date().timeIntervalSince(startedAt)
            let remaining = max(0, Self.minimumGenerationDisplayDuration - elapsed)
            await generationDelay.delay(for: remaining)

            guard !Task.isCancelled else { return }

            generatedPlan = plan
            planRevealState = OnboardingPlanRevealBuilder.build(formState: formState, plan: plan)
            logAnalytics(.planGenerated, properties: planAnalyticsProperties(plan: plan))

            recordStepCompleted(for: .generatingPlan)
            currentStep = .planReveal
            recordStepViewed(.planReveal)
            logAnalytics(.planRevealed, properties: planAnalyticsProperties(plan: plan))
            viewState = .editing
            autosaveDraft()
        } catch {
            guard !Task.isCancelled else { return }
            clearGeneratedPlan()
            viewState = .generationFailed
            errorMessage = FormaProductCopy.Onboarding.V2.Generating.failureMessage
            autosaveDraft()
        }
    }

    func returnToSummaryAfterGenerationFailure() {
        guard currentStep == .generatingPlan else { return }
        advance(to: .review, persistDraft: true, completing: nil)
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
        commitLocalProfileForSavePlan()
        guard errorMessage == nil else { return }
        advance(to: .savePlan, persistDraft: false, completing: .planReveal)
    }

    func commitLocalProfileForSavePlan() {
        guard let generatedPlan else {
            errorMessage = FormaProductCopy.Error.generatePlan
            return
        }

        do {
            if try userProfileService.getCurrentProfile() == nil {
                formState.applyTrainingRhythmDefaultsForCurrentActivity()
                let draft = try formState.makeUserProfileDraft(targets: generatedPlan.targets)
                if draft.birthDate == nil {
                    errorMessage = FormaProductCopy.Onboarding.Flow.Birthday.birthDateRequiredMessage
                    return
                }
                _ = try userProfileService.createProfile(draft)
            }

            hasLocalProfile = true
            persistCoachingContext()
            let wasAlreadyCommitted = hasCommittedLocalProfile
            hasCommittedLocalProfile = true
            draftStore.clearDraft()
            if !wasAlreadyCommitted {
                logAnalytics(.profileSavedLocal, properties: planAnalyticsProperties())
            }
        } catch let error as OnboardingFormError {
            errorMessage = error.message
        } catch ServiceError.invalidInput(let message) {
            errorMessage = message
        } catch {
            errorMessage = FormaProductCopy.Error.createProfile
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

    func beginSignInForCompletion() {
        viewState = .savingProfile
        errorMessage = nil
        logAnalytics(.signInStarted)
    }

    func handleSignInCompletionFailure(message: String? = nil, wasCancelled: Bool = false) {
        guard currentStep == .savePlan else { return }
        viewState = .awaitingSignIn
        errorMessage = message ?? FormaProductCopy.Onboarding.V2.SavePlan.signInRetryMessage
        if wasCancelled {
            logAnalytics(.signInCancelled)
        }
    }

    func finalizeAfterSuccessfulSignIn() {
        logAnalytics(.signInCompleted)
        recordOnboardingFinished(completionPath: "sign_in")
    }

    func finalizeAfterRestoredExistingPlan() {
        logAnalytics(.signInCompleted)
        recordOnboardingFinished(completionPath: "restored_existing")
    }

    // MARK: Helpers

    func flushPendingGenerationForTesting() async {
        await generationTask?.value
    }

    func flushDraftSnapshotIfNeeded() {
        autosaveDraft()
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
        var completedProperties = planAnalyticsProperties()
        completedProperties.completionPath = completionPath
        logAnalytics(.completed, properties: completedProperties)
    }

    // MARK: - Analytics

    private func bootstrapAnalyticsSession() {
        if restoredFromDraft {
            recordStepViewed(currentStep)
            return
        }
        logAnalytics(.started)
        recordStepViewed(currentStep)
    }

    private func recordStepViewed(_ step: OnboardingStep) {
        stepEnteredAt = Date()
        var properties = baseAnalyticsProperties(step: step)
        properties.step = OnboardingDraftBridge.analyticsStepName(step)
        properties.stage = step.stage.rawValue
        logAnalytics(.stepViewed, properties: properties)

        if step == .appleHealth {
            logAppleHealthAnalytics(.appleHealthPromptViewed)
            logAppleHealthAnalytics(.appleHealthOnboardingViewed)
            prepareAppleHealthStep()
        }
    }

    private func recordStepCompleted(for step: OnboardingStep) {
        var properties = baseAnalyticsProperties(step: step)
        properties.step = OnboardingDraftBridge.analyticsStepName(step)
        properties.stage = step.stage.rawValue
        properties.durationMs = stepDurationMs
        logAnalytics(.stepCompleted, properties: properties)
    }

    private var stepDurationMs: Int {
        max(0, Int(Date().timeIntervalSince(stepEnteredAt) * 1000))
    }

    private func baseAnalyticsProperties(step: OnboardingStep) -> OnboardingAnalyticsProperties {
        OnboardingAnalyticsProperties(
            step: OnboardingDraftBridge.analyticsStepName(step),
            stage: step.stage.rawValue,
            entry: analyticsEntry
        )
    }

    private func planAnalyticsProperties(plan: CalorieTargetResult? = nil) -> OnboardingAnalyticsProperties {
        let resolvedPlan = plan ?? generatedPlan
        var properties = baseAnalyticsProperties(step: currentStep)
        guard let resolvedPlan else { return properties }

        let planProperties = OnboardingAnalyticsContextBuilder.planProperties(
            formState: formState,
            plan: resolvedPlan,
            revealState: planRevealState
        )
        properties.goalDirection = planProperties.goalDirection
        properties.isAggressive = planProperties.isAggressive
        properties.estimatedWeeks = planProperties.estimatedWeeks
        return properties
    }

    private func logAnalytics(
        _ event: OnboardingAnalyticsEvent,
        properties: OnboardingAnalyticsProperties? = nil
    ) {
        let resolvedProperties = properties ?? baseAnalyticsProperties(step: currentStep)
        analyticsLogger.log(event, properties: resolvedProperties)
    }

    private func logAppleHealthAnalytics(
        _ event: OnboardingAnalyticsEvent,
        permissionResult: String? = nil
    ) {
        var properties = baseAnalyticsProperties(step: .appleHealth)
        properties.step = OnboardingDraftBridge.analyticsStepName(.appleHealth)
        properties.permissionResult = permissionResult
        logAnalytics(event, properties: properties)
    }

    private func resolvedViewState(for step: OnboardingStep) -> OnboardingViewState {
        if step == .savePlan {
            return analyticsEntry == .postAuth ? .editing : .awaitingSignIn
        }
        return .editing
    }
}

struct OnboardingCoachingContextStore: Sendable {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder

    init(userDefaults: UserDefaults = .standard, encoder: JSONEncoder = JSONEncoder()) {
        self.userDefaults = userDefaults
        self.encoder = encoder
    }

    func save(_ context: OnboardingCoachingContext) {
        guard let data = try? encoder.encode(context) else { return }
        userDefaults.set(data, forKey: OnboardingCoachingContext.userDefaultsKey)
    }

    func load() -> OnboardingCoachingContext? {
        guard let data = userDefaults.data(forKey: OnboardingCoachingContext.userDefaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(OnboardingCoachingContext.self, from: data)
    }

    func clear() {
        userDefaults.removeObject(forKey: OnboardingCoachingContext.userDefaultsKey)
    }
}
