//
//  OnboardingModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for first-run onboarding.
//
//  OnboardingModel calls services only. It does not access SwiftData directly,
//  call AI, or coordinate with other feature models.
//

import Combine
import Foundation

enum OnboardingCompletionIntent: Equatable, Sendable {
    case signIn
    case localOnly
}

@MainActor
final class OnboardingModel: ObservableObject {

    static let minimumGenerationDisplayDuration: TimeInterval = 1.2

    @Published private(set) var currentStep: OnboardingStep
    @Published var formState = OnboardingFormState()
    @Published private(set) var viewState: OnboardingViewState = .editing
    @Published private(set) var generatedPlan: CalorieTargetResult?
    @Published private(set) var planRevealState: OnboardingPlanRevealState?
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasLocalProfile = false
    @Published private(set) var pendingCompletionIntent: OnboardingCompletionIntent?

    let allowsLocalOnlyContinuation: Bool
    let flowScope: OnboardingFlowScope

    /// Post-auth onboarding skips Google sign-in at save plan because the user is already signed in.
    var requiresGoogleSignInAtSavePlan: Bool {
        flowScope != .v2PostAuth
    }

    /// True after local profile + coaching context are committed during v2 save-plan flow.
    private(set) var hasCommittedLocalProfile = false

    private let userProfileService: UserProfileService
    private let targetService: TargetService
    private let draftStore: OnboardingDraftStore
    private let coachingContextStore: OnboardingCoachingContextStore
    private let analyticsLogger: any OnboardingAnalyticsLogging
    private let analyticsEntry: OnboardingAnalyticsEntry
    private let generationDelay: any OnboardingGenerationDelayProviding
    private let onCompletion: () -> Void
    private var generationTask: Task<Void, Never>?
    private var stepEnteredAt = Date()
    private var restoredFromDraft: Bool

    init(
        userProfileService: UserProfileService,
        targetService: TargetService,
        onCompletion: @escaping () -> Void,
        draftStore: OnboardingDraftStore = OnboardingDraftStore(),
        coachingContextStore: OnboardingCoachingContextStore = OnboardingCoachingContextStore(),
        analyticsLogger: any OnboardingAnalyticsLogging = NoOpOnboardingAnalyticsLogger(),
        analyticsEntry: OnboardingAnalyticsEntry = .preAuth,
        flowScope: OnboardingFlowScope? = nil,
        generationDelay: any OnboardingGenerationDelayProviding = SystemOnboardingGenerationDelayProvider(),
        allowsLocalOnlyContinuation: Bool = OnboardingRoutingConfiguration.production.allowsLocalOnlyContinuation
    ) {
        let resolvedFlowScope = flowScope ?? OnboardingFlowScope.resolve(
            routingMode: OnboardingV2FeatureFlag.routingMode,
            entry: analyticsEntry
        )
        self.userProfileService = userProfileService
        self.targetService = targetService
        self.draftStore = draftStore
        self.coachingContextStore = coachingContextStore
        self.analyticsLogger = analyticsLogger
        self.analyticsEntry = analyticsEntry
        self.flowScope = resolvedFlowScope
        self.generationDelay = generationDelay
        self.allowsLocalOnlyContinuation = allowsLocalOnlyContinuation
        self.onCompletion = onCompletion
        self.currentStep = resolvedFlowScope.entryStep
        self.restoredFromDraft = false

        if let draft = draftStore.loadDraft(), shouldRestoreDraft(draft) {
            formState = draft.makeFormState()
            generatedPlan = draft.makeGeneratedPlan()
            if let restoredPlan = generatedPlan {
                planRevealState = OnboardingPlanRevealBuilder.build(
                    formState: formState,
                    plan: restoredPlan
                )
            }
            currentStep = restoredStep(from: draft)
            hasLocalProfile = (try? userProfileService.getCurrentProfile()) != nil
            if resolvedFlowScope.usesV2Steps, currentStep == .savePlan, hasLocalProfile {
                hasCommittedLocalProfile = true
                draftStore.clearDraft()
            }
            viewState = resolvedViewState(for: currentStep)
            restoredFromDraft = true
        }

        bootstrapAnalyticsSession()
    }

    // MARK: Navigation

    func goNext() {
        clearError()

        if flowScope.usesV2Steps {
            goNextV2()
        } else {
            goNextLegacy()
        }
    }

    func goBack() {
        clearError()
        guard let previous = backTarget(for: currentStep) else { return }

        if currentStep.clearsGeneratedPlanWhenNavigatingBack(in: flowScope.flow) {
            clearGeneratedPlan()
        }

        currentStep = previous
        viewState = resolvedViewState(for: previous)
        recordStepViewed(previous)
        autosaveDraft()
    }

    func clearError() {
        errorMessage = nil
        if case .error = viewState {
            viewState = .editing
        }
    }

    // MARK: V2 navigation graph

    private func goNextV2() {
        let completedStep = currentStep
        switch currentStep {
        case .landing:
            advance(to: .welcome, completing: completedStep)
        case .welcome:
            if flowScope.completesWithSignInAfterWelcome {
                completeValueFirstTeaserForSignIn()
            } else {
                advance(to: .motivation, completing: completedStep)
            }
        case .motivation:
            advance(to: .body, completing: completedStep)
        case .body:
            guard validateCurrentStep() else { return }
            advance(to: .goal, completing: completedStep)
        case .goal:
            guard validateCurrentStep() else { return }
            advance(to: .activity, completing: completedStep)
        case .activity:
            guard validateCurrentStep() else { return }
            advance(to: .preferences, completing: completedStep)
        case .preferences:
            advance(to: .summary, completing: completedStep)
        case .summary:
            recordStepCompleted(for: completedStep)
            beginGeneration()
        case .planReveal:
            prepareForSavePlan()
        case .savePlan:
            awaitSignInAndFinish()
        case .generatingPlan, .planPreview:
            break
        }
    }

    private func goNextLegacy() {
        let completedStep = currentStep
        switch currentStep {
        case .welcome:
            advance(to: .body, completing: completedStep)
        case .body:
            guard validateCurrentStep() else { return }
            advance(to: .goal, completing: completedStep)
        case .goal:
            guard validateCurrentStep() else { return }
            advance(to: .activity, completing: completedStep)
        case .activity:
            guard validateCurrentStep() else { return }
            advance(to: .preferences, completing: completedStep)
        case .preferences:
            recordStepCompleted(for: completedStep)
            beginLegacyGeneration()
        case .planPreview:
            break
        default:
            break
        }
    }

    // MARK: Plan generation

    func generatePlanPreview() {
        if flowScope.usesV2Steps {
            beginGeneration()
        } else {
            beginLegacyGeneration()
        }
    }

    func beginGeneration() {
        if let invalidStep = Self.firstInvalidRequiredStep(for: formState) {
            errorMessage = formState.validationMessage(for: invalidStep)
                ?? FormaProductCopy.Onboarding.V2.Validation.summaryIncomplete
            currentStep = invalidStep
            viewState = resolvedViewState(for: invalidStep)
            autosaveDraft()
            return
        }

        generationTask?.cancel()
        currentStep = .generatingPlan
        viewState = .generatingPlanAnimated
        errorMessage = nil
        recordStepViewed(.generatingPlan)
        autosaveDraft()

        generationTask = Task { @MainActor in
            await runGeneration(returnTo: .summary)
        }
    }

    private func beginLegacyGeneration() {
        generationTask?.cancel()
        viewState = .generatingPlan
        errorMessage = nil

        generationTask = Task { @MainActor in
            await runGeneration(returnTo: .preferences, advanceToLegacyPreview: true)
        }
    }

    private func runGeneration(
        returnTo: OnboardingStep,
        advanceToLegacyPreview: Bool = false
    ) async {
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

            if advanceToLegacyPreview {
                currentStep = .planPreview
                recordStepViewed(.planPreview)
            } else {
                currentStep = .planReveal
                recordStepViewed(.planReveal)
                logAnalytics(.planRevealed, properties: planAnalyticsProperties(plan: plan))
            }
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
        currentStep = .summary
        viewState = .editing
        autosaveDraft()
    }

    func adjustPlanFromReveal() {
        guard currentStep == .planReveal else { return }
        clearGeneratedPlan()
        currentStep = .goal
        viewState = .editing
        autosaveDraft()
    }

    // MARK: Profile save / completion

    func completeOnboarding() {
        if flowScope.usesV2Steps, currentStep == .savePlan {
            awaitSignInAndFinish()
        } else {
            saveProfileAndCompleteLegacy()
        }
    }

    /// Value-first fallback: welcome completes with a sign-in handoff draft at motivation.
    var expectsValueFirstSignInHandoff: Bool {
        flowScope.completesWithSignInAfterWelcome
            && pendingCompletionIntent == .signIn
            && currentStep == .welcome
    }

    private func completeValueFirstTeaserForSignIn() {
        recordStepCompleted(for: .welcome)
        draftStore.saveDraft(
            OnboardingDraft(formState: formState, currentStep: .motivation)
        )
        pendingCompletionIntent = .signIn
        onCompletion()
    }

    func prepareForSavePlan() {
        commitLocalProfileForSavePlan()
        guard errorMessage == nil else { return }
        advance(to: .savePlan, persistDraft: false, completing: .planReveal)
    }

    /// Creates the on-device profile and coaching context, then clears the onboarding draft.
    func commitLocalProfileForSavePlan() {
        guard let generatedPlan else {
            errorMessage = FormaProductCopy.Error.generatePlan
            return
        }

        do {
            if try userProfileService.getCurrentProfile() == nil {
                let draft = try formState.makeUserProfileDraft(targets: generatedPlan.targets)
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

    /// Legacy helper retained for tests; v2 save-plan uses `commitLocalProfileForSavePlan`.
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

    /// Completes onboarding locally without Google sign-in when routing policy allows it.
    func completeWithoutAccount() {
        guard allowsLocalOnlyContinuation else { return }
        guard currentStep == .savePlan else { return }
        if !(hasCommittedLocalProfile || hasLocalProfile) {
            commitLocalProfileForSavePlan()
            guard errorMessage == nil else { return }
        }

        pendingCompletionIntent = .localOnly
        viewState = .awaitingSignIn
        errorMessage = nil
        finalizeLocalOnboarding()
        onCompletion()
    }

    /// AuthGateView sets this while Google sign-in is in flight from the save-plan step.
    func beginSignInForCompletion() {
        viewState = .savingProfile
        errorMessage = nil
        logAnalytics(.signInStarted)
    }

    /// Restores retry-friendly save-plan UI after sign-in cancel/failure.
    func handleSignInCompletionFailure(message: String? = nil, wasCancelled: Bool = false) {
        guard currentStep == .savePlan else { return }
        viewState = .awaitingSignIn
        errorMessage = message ?? FormaProductCopy.Onboarding.V2.SavePlan.signInRetryMessage
        if wasCancelled {
            logAnalytics(.signInCancelled)
        }
    }

    /// Called after cloud sync succeeds; records analytics and first-run flags.
    func finalizeAfterSuccessfulSignIn() {
        logAnalytics(.signInCompleted)
        recordOnboardingFinished(completionPath: "sign_in")
    }

    private func finalizeLocalOnboarding() {
        recordOnboardingFinished(completionPath: "local_only")
    }

    private func saveProfileAndCompleteLegacy() {
        guard let generatedPlan else {
            errorMessage = FormaProductCopy.Error.generatePlan
            return
        }

        viewState = .completing
        errorMessage = nil

        do {
            if try userProfileService.getCurrentProfile() != nil {
                errorMessage = FormaProductCopy.Error.profileExists
                viewState = .editing
                return
            }

            let draft = try formState.makeUserProfileDraft(targets: generatedPlan.targets)
            _ = try userProfileService.createProfile(draft)
            draftStore.clearDraft()
            finishOnboarding(completionPath: "legacy")
        } catch let error as OnboardingFormError {
            errorMessage = error.message
            viewState = .editing
        } catch ServiceError.invalidInput(let message) {
            errorMessage = message
            viewState = .editing
        } catch {
            errorMessage = FormaProductCopy.Error.createProfile
            viewState = .editing
        }
    }

    // MARK: Helpers

    func flushPendingGenerationForTesting() async {
        await generationTask?.value
    }

    /// Persists the in-progress wizard snapshot (e.g. before app background / termination).
    func flushDraftSnapshotIfNeeded() {
        autosaveDraft()
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

    private func validateRequiredFieldsForGeneration() -> Bool {
        Self.firstInvalidRequiredStep(for: formState) == nil
    }

    static func firstInvalidRequiredStep(for formState: OnboardingFormState) -> OnboardingStep? {
        OnboardingPersonalizationSummaryBuilder.firstInvalidRequiredStep(for: formState)
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
        recordStepViewed(step)
        if persistDraft, shouldPersistDraft {
            autosaveDraft()
        }
    }

    private func clearGeneratedPlan() {
        generatedPlan = nil
        planRevealState = nil
    }

    private var shouldPersistDraft: Bool {
        !(flowScope.usesV2Steps && hasCommittedLocalProfile)
    }

    private func autosaveDraft() {
        guard shouldPersistDraft else { return }
        draftStore.saveDraft(
            OnboardingDraft(
                formState: formState,
                currentStep: currentStep,
                generatedPlan: generatedPlan
            )
        )
    }

    private func persistCoachingContext() {
        coachingContextStore.save(formState.makeCoachingContext())
    }

    private func finishOnboarding(completionPath: String) {
        recordOnboardingFinished(completionPath: completionPath)
        onCompletion()
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
        logAnalytics(.stepViewed, step: step)
    }

    private func recordStepCompleted(for step: OnboardingStep) {
        var properties = baseAnalyticsProperties(step: step)
        properties.durationMs = stepDurationMs
        logAnalytics(.stepCompleted, properties: properties)

        if let feedbackKind = OnboardingAnalyticsContextBuilder.feedbackKind(for: step, formState: formState) {
            properties.feedbackKind = feedbackKind
            logAnalytics(.feedbackShown, properties: properties)
        }
    }

    private var stepDurationMs: Int {
        max(0, Int(Date().timeIntervalSince(stepEnteredAt) * 1000))
    }

    private func baseAnalyticsProperties(step: OnboardingStep) -> OnboardingAnalyticsProperties {
        OnboardingAnalyticsProperties(
            step: analyticsStepName(step),
            stage: step.stage.rawValue,
            entry: analyticsEntry,
            goalDirection: OnboardingAnalyticsContextBuilder.goalDirection(from: formState),
            loggingMode: OnboardingAnalyticsContextBuilder.loggingMode(from: formState),
            v2Enabled: String(flowScope.usesV2Steps)
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
        properties.goalDirection = planProperties.goalDirection ?? properties.goalDirection
        properties.isAggressive = planProperties.isAggressive
        properties.estimatedWeeks = planProperties.estimatedWeeks
        properties.loggingMode = planProperties.loggingMode ?? properties.loggingMode
        return properties
    }

    private func logAnalytics(
        _ event: OnboardingAnalyticsEvent,
        step: OnboardingStep? = nil,
        properties: OnboardingAnalyticsProperties? = nil
    ) {
        let resolvedProperties = properties ?? baseAnalyticsProperties(step: step ?? currentStep)
        analyticsLogger.log(event, properties: resolvedProperties)
    }

    private func analyticsStepName(_ step: OnboardingStep) -> String {
        switch step {
        case .landing: return "landing"
        case .welcome: return "welcome"
        case .motivation: return "motivation"
        case .body: return "body"
        case .goal: return "goal"
        case .activity: return "activity"
        case .preferences: return "preferences"
        case .summary: return "summary"
        case .generatingPlan: return "generatingPlan"
        case .planReveal: return "planReveal"
        case .planPreview: return "planPreview"
        case .savePlan: return "savePlan"
        }
    }

    private func friendlyGenerationError(from error: Error) -> String {
        if let formError = error as? OnboardingFormError {
            return formError.message
        }
        if let planError = error as? PlanCalculationError {
            return planError.userMessage
        }
        return FormaProductCopy.Error.generatePlan
    }

    private func resolvedViewState(for step: OnboardingStep) -> OnboardingViewState {
        Self.resolvedViewState(for: step, flowScope: flowScope)
    }

    private static func resolvedViewState(for step: OnboardingStep, flowScope: OnboardingFlowScope) -> OnboardingViewState {
        if flowScope.usesV2Steps, step == .savePlan {
            return flowScope == .v2PostAuth ? .editing : .awaitingSignIn
        }
        return .editing
    }

    private func shouldRestoreDraft(_ draft: OnboardingDraft) -> Bool {
        guard let step = draft.currentStep else { return false }
        if step.isValid(for: flowScope) {
            return true
        }
        return flowScope == .legacy && OnboardingStep.legacyFlow.contains(step)
    }

    private func restoredStep(from draft: OnboardingDraft) -> OnboardingStep {
        guard let step = draft.currentStep else {
            return flowScope.entryStep
        }

        if step == .generatingPlan {
            return .summary
        }

        if step.isValid(for: flowScope) {
            return step
        }

        return flowScope.entryStep
    }

    private func backTarget(for step: OnboardingStep) -> OnboardingStep? {
        if flowScope == .legacy {
            return step.backTarget(isV2Enabled: false)
        }

        switch step {
        case .planReveal:
            return .summary
        case .savePlan:
            return .planReveal
        case .generatingPlan, .landing:
            return nil
        default:
            break
        }

        if let scoped = step.previous(in: flowScope.flow) {
            return scoped
        }

        return step.backTarget(isV2Enabled: true)
    }
}

// MARK: - Coaching context persistence

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
}
