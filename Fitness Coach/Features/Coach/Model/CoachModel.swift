//
//  CoachModel.swift
//  Fitness Coach
//
//  FitPilot AI — AI interface into shared fitness state (not a state owner).
//

import Combine
import Foundation
import UIKit

@MainActor
final class CoachModel: ObservableObject {

    // MARK: Published surface (SwiftUI)

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var inputState: CoachInputState = .empty
    @Published private(set) var processingPhase: CoachProcessingPhase = .idle
    @Published private(set) var errorTitle: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var showsAuthRetry: Bool = false
    @Published var pendingConfirmation: CoachPendingConfirmation?
    @Published var isShowingFoodEditSheet = false
    @Published var isConfirmingPending = false
    @Published var foodEditErrorMessage: String?
    @Published private(set) var todayContext: CoachTodayContextState?
    @Published private(set) var starterPromptSpecs: [CoachStarterPromptSpec] = CoachStarterPrompt.defaultQuickActionSpecs
    @Published private(set) var activeLaunchPresentation: CoachLaunchPresentation?
    @Published private(set) var composerPlaceholderOverride: String?
    @Published private(set) var requestsComposerFocus = false
    @Published private(set) var requestsCameraPresentation = false

    var lastTimelineAttribution: CoachTimelineEventSourceAttribution = .localParser

    // MARK: Coordinators

    private let inputCoordinator: CoachInputCoordinator
    let photoFlowCoordinator: CoachPhotoFlowCoordinator
    private let pendingConfirmationCoordinator: CoachPendingConfirmationCoordinator
    let messagePersistenceCoordinator: CoachMessagePersistenceCoordinator
    private let sendFlowCoordinator: CoachSendFlowCoordinator
    private let todayContextCoordinator: CoachTodayContextCoordinator
    private let launchChromeCoordinator: CoachLaunchChromeCoordinator
    private let nutritionEstimateActionCoordinator: CoachNutritionEstimateActionCoordinator
    private let coachAnalyticsLogger: any CoachAnalyticsLogging

    // MARK: Derived surface

    var isSending: Bool {
        CoachModelStateReducer.isSending(processingPhase: processingPhase)
    }

    var inputText: String {
        get { inputCoordinator.inputText }
        set { inputCoordinator.inputText = newValue }
    }

    var messageCount: Int { messages.count }

    var awaitingPhotoClarification: Bool {
        photoFlowCoordinator.sessionAwaitingClarification() != nil
    }

    var photoClarificationComposerPlaceholder: String? {
        guard awaitingPhotoClarification else { return nil }
        return FormaProductCopy.Coach.composerPhotoClarificationPlaceholder
    }

    var resolvedComposerPlaceholder: String {
        if let composerPlaceholderOverride {
            return composerPlaceholderOverride
        }
        if let photoClarificationComposerPlaceholder {
            return photoClarificationComposerPlaceholder
        }
        return FormaProductCopy.Coach.composerPlaceholder
    }

    init(
        services: CoachServices,
        dependencies: CoachDependencies? = nil
    ) {
        let pipeline = (dependencies ?? CoachDependencies()).assemble(services: services)
        let inputCoordinator = CoachInputCoordinator()

        self.messagePersistenceCoordinator = pipeline.messagePersistenceCoordinator
        self.pendingConfirmationCoordinator = pipeline.pendingConfirmationCoordinator
        self.inputCoordinator = inputCoordinator
        self.coachAnalyticsLogger = pipeline.analyticsLogger
        self.todayContextCoordinator = pipeline.todayContextCoordinator

        let photoFlowCoordinator = CoachPhotoFlowCoordinator(
            mealPhotoAnalyzer: pipeline.mealPhotoAnalyzer,
            timelineRecorder: pipeline.timelineRecorder,
            messagePersistenceCoordinator: pipeline.messagePersistenceCoordinator,
            pendingConfirmationCoordinator: pipeline.pendingConfirmationCoordinator,
            contextPacketCoordinator: pipeline.contextPacketCoordinator
        )
        let sendFlowCoordinator = CoachSendFlowCoordinator(
            aiService: pipeline.aiService,
            aiCommandParsingEnabled: pipeline.aiCommandParsingEnabled,
            hasContextPacketBuilder: pipeline.contextPacketBuilder != nil,
            coachModelConfig: pipeline.coachModelConfig,
            routeDecider: pipeline.routeDecider,
            routeHandler: pipeline.routeHandler,
            messagePersistenceCoordinator: pipeline.messagePersistenceCoordinator,
            pendingConfirmationCoordinator: pipeline.pendingConfirmationCoordinator,
            photoFlowCoordinator: photoFlowCoordinator,
            inputCoordinator: inputCoordinator,
            contextPacketCoordinator: pipeline.contextPacketCoordinator
        )

        self.photoFlowCoordinator = photoFlowCoordinator
        self.sendFlowCoordinator = sendFlowCoordinator
        let launchChromeCoordinator = CoachLaunchChromeCoordinator(inputCoordinator: inputCoordinator)
        self.launchChromeCoordinator = launchChromeCoordinator
        self.nutritionEstimateActionCoordinator = CoachNutritionEstimateActionCoordinator(
            pendingConfirmationCoordinator: pipeline.pendingConfirmationCoordinator,
            sendFlowCoordinator: sendFlowCoordinator,
            launchChromeCoordinator: launchChromeCoordinator,
            inputCoordinator: inputCoordinator
        )

        self.messages = pipeline.messagePersistenceCoordinator.restoreMessages()

        inputCoordinator.onStateChange = { [weak self] state in
            self?.inputState = state
        }
        inputCoordinator.configureSendingState { [weak self] in
            self?.isSending ?? false
        }

        photoFlowCoordinator.configureRuntime(
            isSending: { [weak self] in self?.isSending ?? false },
            onSessionFailure: { [weak self] in self?.presentCoachSessionFailure() }
        )
        photoFlowCoordinator.configureProcessing(sendFlowCoordinator)
        nutritionEstimateActionCoordinator.configure { [weak self] event, properties in
            self?.logCoachAnalytics(event, properties: properties)
        }
        pendingConfirmationCoordinator.configure(delegate: self)
        messagePersistenceCoordinator.configure(delegate: self)
        launchChromeCoordinator.configure(delegate: self)
        sendFlowCoordinator.configure(bindings: CoachSendFlowBindings(
            isSending: { [weak self] in self?.isSending ?? false },
            setProcessingPhase: { [weak self] phase in self?.processingPhase = phase },
            presentSessionFailure: { [weak self] in self?.presentCoachSessionFailure() },
            messages: { [weak self] in self?.messages ?? [] },
            getLastTimelineAttribution: { [weak self] in self?.lastTimelineAttribution ?? .localParser },
            setLastTimelineAttribution: { [weak self] attribution in self?.lastTimelineAttribution = attribution }
        ))
    }

    // MARK: Today context

    func refreshTodayContext() {
        Task {
            todayContext = await todayContextCoordinator.refreshTodayContext()
        }
    }

    // MARK: Composer — meal photo attachment

    func removeStagedMealPhoto() { inputCoordinator.removeStagedMealPhoto() }
    func storePendingImageLocalSource(_ image: UIImage) -> UUID { inputCoordinator.storePendingImageLocalSource(image) }
    func pendingImageLocalSource(for id: UUID) -> UIImage? { inputCoordinator.pendingImageLocalSource(for: id) }
    func attachPendingImageLocalReference(_ id: UUID) { inputCoordinator.attachPendingImageLocalReference(id) }
    func clearPendingImageError() { inputCoordinator.clearPendingImageError() }
    @discardableResult func beginPendingImageProcessing(source: CoachInputAttachmentSource) -> Bool {
        inputCoordinator.beginPendingImageProcessing(source: source)
    }
    func hasActivePendingImageImport() -> Bool { inputCoordinator.hasActivePendingImageImport() }
    func shouldAcceptImportSuccess(localReferenceID: UUID) -> Bool {
        inputCoordinator.shouldAcceptImportSuccess(localReferenceID: localReferenceID)
    }
    @discardableResult func requestPhotoPick() -> Bool { inputCoordinator.requestPhotoPick() }
    func stagePipelineProcessedPhoto(
        _ imported: CoachImagePipeline.ProcessedImageImport,
        source: CoachInputAttachmentSource
    ) async -> Bool {
        await inputCoordinator.stagePipelineProcessedPhoto(imported, source: source)
    }

    func appendMealPhotoSelectionFailure(_ error: CoachMealPhotoError) {
        guard error != .userCancelled else { return }
        guard !error.supportsComposerRetry else { return }
        CoachImageAnalysisDebugLogger.logError(error)
        messagePersistenceCoordinator.appendAssistantMessage(CoachResponseBuilder.mealPhotoError(error))
    }

    func failPendingImageProcessing(_ error: CoachMealPhotoError) { inputCoordinator.failPendingImageProcessing(error) }
    func reportComposerImageSelectionError(_ error: CoachMealPhotoError) {
        inputCoordinator.reportComposerImageSelectionError(error)
    }
    func revertPendingImageProcessingCancel() { inputCoordinator.revertPendingImageProcessingCancel() }

    // MARK: Send

    func sendCurrentMessage() async {
        guard !isSending else { return }
        guard let snapshot = inputCoordinator.takeSendSnapshot() else { return }
        launchChromeCoordinator.clearComposerLaunchChrome()
        launchChromeCoordinator.consumeLaunchPresentation()
        await sendFlowCoordinator.sendCurrentMessage(snapshot: snapshot)
    }

    func send(_ text: String, managesProcessingLock: Bool = true) async {
        await sendFlowCoordinator.send(text, managesProcessingLock: managesProcessingLock)
    }

    func retryMealPhotoAnalysis(for userMessageID: UUID) async {
        await photoFlowCoordinator.retryMealPhotoAnalysis(for: userMessageID)
    }

    func submitImageAnalysisClarification(_ clarification: String, for userMessageID: UUID) async {
        await photoFlowCoordinator.submitImageAnalysisClarification(clarification, for: userMessageID)
    }

    func applyStarterPrompt(_ prompt: CoachStarterPrompt) async {
        await applyStarterPromptSpec(prompt.spec)
    }

    func applyStarterPromptSpec(_ prompt: CoachStarterPromptSpec) async {
        switch prompt.behavior {
        case .prefill(let text):
            inputText = text
        case .send(let text):
            await send(text)
        case .openPhotoPicker:
            break
        }
    }

    func applyExampleCommand(_ text: String) async {
        await send(text)
    }

    func clearError() {
        applyTransientError(CoachModelStateReducer.clearedError())
    }

    func prepareInput(prefill: String?) {
        guard let prefill, !prefill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            launch(with: .normal)
            return
        }
        launch(with: .prefill(prefill))
    }

    // MARK: Launch chrome

    func launch(with intent: CoachLaunchIntent) {
        launchChromeCoordinator.launch(with: intent)
    }

    func consumeLaunchPresentation() {
        launchChromeCoordinator.consumeLaunchPresentation()
    }

    func consumeComposerFocusRequest() {
        launchChromeCoordinator.consumeComposerFocusRequest()
    }

    func consumeCameraPresentationRequest() {
        launchChromeCoordinator.consumeCameraPresentationRequest()
    }

    func handleCoachBecameInactive() {
        launchChromeCoordinator.handleCoachBecameInactive(
            hasEmptyComposer: inputState.trimmedText.isEmpty && inputState.pendingImage == nil
        )
    }

    func noteComposerInteraction() {
        launchChromeCoordinator.noteComposerInteraction()
    }

    // MARK: Pending confirmation

    func confirmPendingFromBar() async {
        await pendingConfirmationCoordinator.confirmFromBar()
    }

    func rejectPendingFromBar() {
        pendingConfirmationCoordinator.rejectFromBar()
    }

    func handleNutritionEstimateAction(_ action: NutritionSuggestedAction) async {
        await nutritionEstimateActionCoordinator.handle(action) { [weak self] query in
            await self?.send(query)
        }
    }

    func openFoodEditSheet() { pendingConfirmationCoordinator.openFoodEditSheet() }
    func dismissFoodEditSheet() { pendingConfirmationCoordinator.dismissFoodEditSheet() }
    func saveFoodEdit(_ formState: FoodLogEditFormState) { pendingConfirmationCoordinator.saveFoodEdit(formState) }

    // MARK: Surface state helpers

    private func presentCoachSessionFailure() {
        applyTransientError(CoachModelStateReducer.sessionFailureError())
    }

    func applyLaunchChrome(_ state: CoachLaunchChromeState) {
        activeLaunchPresentation = state.activeLaunchPresentation
        composerPlaceholderOverride = state.composerPlaceholderOverride
        requestsComposerFocus = state.requestsComposerFocus
        requestsCameraPresentation = state.requestsCameraPresentation
    }

    private func applyTransientError(_ state: CoachTransientErrorState) {
        errorTitle = state.title
        errorMessage = state.message
        showsAuthRetry = state.showsAuthRetry
    }

    func applyPendingConfirmationUI(_ state: CoachPendingConfirmationUIState) {
        pendingConfirmation = state.pendingConfirmation
        isConfirmingPending = state.isConfirmingPending
        foodEditErrorMessage = state.foodEditErrorMessage
        isShowingFoodEditSheet = state.isShowingFoodEditSheet
    }

    func setTranscriptMessages(_ messages: [ChatMessage]) {
        self.messages = messages
    }

    func logCoachAnalytics(_ event: CoachAnalyticsEvent, properties: CoachAnalyticsProperties) {
        coachAnalyticsLogger.log(event, properties: properties)
    }

    func logNutritionCardShown(_ content: CoachStructuredMessageContent) {
        switch content {
        case .nutritionEstimate(let state):
            logCoachAnalytics(
                .nutritionEstimateCardShown,
                properties: CoachAnalyticsProperties(
                    confidenceLevel: state.confidenceLevel.rawValue,
                    hasMacros: state.hasMacros,
                    hasTodayContext: state.hasTodayContext,
                    sourceType: state.sourceType?.rawValue
                )
            )
        case .nutritionComparison:
            logCoachAnalytics(.nutritionComparisonCardShown, properties: CoachAnalyticsProperties())
        }
    }
}
