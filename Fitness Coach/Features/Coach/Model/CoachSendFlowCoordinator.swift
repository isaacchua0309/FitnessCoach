//
//  CoachSendFlowCoordinator.swift
//  Fitness Coach
//
//  Forma — Text send orchestration, routing, processing phase, and action result application.
//

import Foundation

@MainActor
struct CoachSendFlowBindings {
    var isSending: () -> Bool
    var setProcessingPhase: (CoachProcessingPhase) -> Void
    var presentSessionFailure: () -> Void
    var messages: () -> [ChatMessage]
    var getLastTimelineAttribution: () -> CoachTimelineEventSourceAttribution
    var setLastTimelineAttribution: (CoachTimelineEventSourceAttribution) -> Void
}

@MainActor
final class CoachSendFlowCoordinator: CoachProcessingPhaseControlling {

    private var bindings: CoachSendFlowBindings?
    private let aiService: AIServiceProtocol?
    private let aiCommandParsingEnabled: Bool
    private let hasContextPacketBuilder: Bool
    private let coachModelConfig: CoachModelConfig
    private var routeDecider: CoachRouteDecider
    private let routeHandler: CoachAIRouteHandler
    private let messagePersistenceCoordinator: CoachMessagePersistenceCoordinator
    private let pendingConfirmationCoordinator: CoachPendingConfirmationCoordinator
    private let photoFlowCoordinator: CoachPhotoFlowCoordinator
    private let inputCoordinator: CoachInputCoordinator
    private let contextPacketCoordinator: CoachContextPacketCoordinator

    init(
        aiService: AIServiceProtocol?,
        aiCommandParsingEnabled: Bool,
        hasContextPacketBuilder: Bool,
        coachModelConfig: CoachModelConfig,
        routeDecider: CoachRouteDecider,
        routeHandler: CoachAIRouteHandler,
        messagePersistenceCoordinator: CoachMessagePersistenceCoordinator,
        pendingConfirmationCoordinator: CoachPendingConfirmationCoordinator,
        photoFlowCoordinator: CoachPhotoFlowCoordinator,
        inputCoordinator: CoachInputCoordinator,
        contextPacketCoordinator: CoachContextPacketCoordinator
    ) {
        self.aiService = aiService
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        self.hasContextPacketBuilder = hasContextPacketBuilder
        self.coachModelConfig = coachModelConfig
        self.routeDecider = routeDecider
        self.routeHandler = routeHandler
        self.messagePersistenceCoordinator = messagePersistenceCoordinator
        self.pendingConfirmationCoordinator = pendingConfirmationCoordinator
        self.photoFlowCoordinator = photoFlowCoordinator
        self.inputCoordinator = inputCoordinator
        self.contextPacketCoordinator = contextPacketCoordinator
    }

    func configure(bindings: CoachSendFlowBindings) {
        self.bindings = bindings
    }

    func sendCurrentMessage(snapshot: CoachInputSendSnapshot) async {
        beginProcessing(.text)
        defer { endProcessing() }

        switch snapshot.sendPayload {
        case .textOnly(let text):
            await send(text, managesProcessingLock: false)
        case .imageOnly(let jpegData):
            await photoFlowCoordinator.sendMealPhoto(
                jpegData: jpegData,
                caption: nil,
                source: snapshot.pendingImage?.source,
                thumbnailJPEG: snapshot.pendingImage?.thumbnail
            )
        case .textAndImage(let text, let jpegData):
            await photoFlowCoordinator.sendMealPhoto(
                jpegData: jpegData,
                caption: text,
                source: snapshot.pendingImage?.source,
                thumbnailJPEG: snapshot.pendingImage?.thumbnail
            )
        }
    }

    func send(_ text: String, managesProcessingLock: Bool = true) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputCoordinator.discardStagedAttachmentForTextSend()
        if managesProcessingLock {
            guard bindings?.isSending() == false else { return }
            beginProcessing(.text)
        }

        defer {
            if managesProcessingLock {
                endProcessing()
            }
        }

        switch CoachInputSafety.validate(trimmed) {
        case .empty:
            return
        case .tooLong:
            messagePersistenceCoordinator.appendUserMessage(text: trimmed)
            messagePersistenceCoordinator.appendAssistantMessage(CoachResponseBuilder.inputTooLongResponse)
            return
        case .valid:
            break
        }

        messagePersistenceCoordinator.appendUserMessage(text: trimmed)

        let traceId = FormaPipelineTracer.beginTrace(userMessage: trimmed)
        let traceStarted = Date()
        var traceOutcome = "completed"
        defer {
            FormaPipelineTracer.endTrace(
                traceId: traceId,
                outcome: traceOutcome,
                durationMs: Int(Date().timeIntervalSince(traceStarted) * 1_000)
            )
        }

        if let pendingResult = await pendingConfirmationCoordinator.handleTextInput(trimmed) {
            traceOutcome = "pendingConfirmation"
            applyActionResult(pendingResult)
            return
        }

        if let clarificationSession = photoFlowCoordinator.sessionAwaitingClarification() {
            messagePersistenceCoordinator.appendUserMessage(text: trimmed)
            messagePersistenceCoordinator.recordClarificationAnswered(
                answer: trimmed,
                session: clarificationSession
            )
            await photoFlowCoordinator.submitImageAnalysisClarification(
                trimmed,
                for: clarificationSession.userMessageID
            )
            traceOutcome = "photoClarification"
            return
        }

        let result = await processCoachMessage(trimmed, traceId: traceId, traceOutcome: &traceOutcome)
        applyActionResult(result)
    }

    func beginProcessing(_ operation: CoachProcessingOperation) {
        bindings?.setProcessingPhase(CoachModelStateReducer.processingPhase(for: operation))
        inputCoordinator.syncSendingFlag()
    }

    func endProcessing() {
        bindings?.setProcessingPhase(CoachModelStateReducer.idleProcessingPhase)
        inputCoordinator.syncSendingFlag()
    }

    func applyActionResult(
        _ result: CoachActionResult,
        relatedPhotoUserMessageID: UUID? = nil,
        assistantAttribution: CoachTimelineEventSourceAttribution? = nil
    ) {
        pendingConfirmationCoordinator.applyPendingConfirmation(from: result)
        let attribution = assistantAttribution ?? bindings?.getLastTimelineAttribution() ?? .localParser
        if let structured = result.structuredContent {
            _ = messagePersistenceCoordinator.appendAssistantStructuredMessage(
                structured,
                accessibilityText: result.message,
                sourceAttribution: attribution
            )
        } else if !result.message.isEmpty {
            if let relatedPhotoUserMessageID,
               photoFlowCoordinator.appendLinkedPhotoAnalysisMessage(
                result.message,
                forUserMessageID: relatedPhotoUserMessageID,
                sourceAttribution: attribution
               ) != nil {
                return
            }
            _ = messagePersistenceCoordinator.appendAssistantMessage(
                result.message,
                sourceAttribution: attribution
            )
        }
    }

    // MARK: Routing

    private func processCoachMessage(
        _ text: String,
        traceId: UUID,
        traceOutcome: inout String
    ) async -> CoachActionResult {
        guard aiCommandParsingEnabled,
              hasContextPacketBuilder,
              let aiService else {
            traceOutcome = "aiDisabled"
            FormaPipelineTracer.logError(
                traceId: traceId,
                stage: .coachSend,
                message: "AI command parsing unavailable",
                fields: [
                    "aiCommandParsingEnabled": String(aiCommandParsingEnabled),
                    "hasContextBuilder": String(hasContextPacketBuilder),
                    "hasAIService": String(self.aiService != nil)
                ]
            )
            messagePersistenceCoordinator.recordBackendError(.backendUnavailable)
            return .message(CoachResponseBuilder.backendUnavailableResponse)
        }

        let priorChatMessages = Array((bindings?.messages() ?? []).dropLast())
        guard let context = await contextPacketCoordinator.prepareContextPacket(
            recentMessages: priorChatMessages,
            currentUserMessage: text
        ) else {
            traceOutcome = "aiDisabled"
            messagePersistenceCoordinator.recordBackendError(.backendUnavailable)
            return .message(CoachResponseBuilder.backendUnavailableResponse)
        }

        do {
            let decision = try await routeDecider.decide(
                text: text,
                context: context,
                aiService: aiService,
                config: coachModelConfig
            )
            bindings?.setLastTimelineAttribution(
                CoachModelTimelineSupport.timelineAttribution(for: decision)
            )
            let result = try await routeHandler.handle(
                decision.route,
                context: context,
                pendingConfirmation: pendingConfirmationCoordinator.currentPendingConfirmation
            )
            traceOutcome = "routed:\(decision.chosenHandler)"
            return result
        } catch let error as AIServiceError {
            if case .authenticationFailed = error {
                traceOutcome = "authFailed"
                FormaPipelineTracer.logError(
                    traceId: traceId,
                    stage: .error,
                    message: "Coach session authentication failed",
                    fields: ["error": error.userMessage]
                )
                bindings?.presentSessionFailure()
                messagePersistenceCoordinator.recordAuthError(userMessage: error.userMessage)
                return .message("")
            }
            traceOutcome = "aiServiceError"
            var errorFields: [String: String] = [
                "error": String(describing: error),
                "userMessage": error.userMessage
            ]
            #if DEBUG
            if case .backendUnavailable = error {
                errorFields["debugHint"] = "See OSLog subsystem Forma category CoachAI and PipelineTrace for this traceId"
            }
            #endif
            FormaPipelineTracer.logError(
                traceId: traceId,
                stage: .error,
                message: "AIService error surfaced to user",
                fields: errorFields
            )
            messagePersistenceCoordinator.recordBackendError(error)
            return .message(error.userMessage)
        } catch {
            traceOutcome = "unexpectedError"
            FormaPipelineTracer.logError(
                traceId: traceId,
                stage: .error,
                message: "Unexpected coach processing error",
                fields: [
                    "error": error.localizedDescription,
                    "errorType": String(describing: type(of: error))
                ]
            )
            let wrapped = AIServiceError.requestFailed(error.localizedDescription)
            messagePersistenceCoordinator.recordBackendError(wrapped)
            return .message(wrapped.userMessage)
        }
    }
}
