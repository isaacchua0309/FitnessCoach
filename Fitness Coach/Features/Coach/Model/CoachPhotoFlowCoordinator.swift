//
//  CoachPhotoFlowCoordinator.swift
//  Fitness Coach
//
//  Forma — Meal photo send, analysis session lifecycle, retry, and recommission orchestration.
//

import Foundation

@MainActor
protocol CoachProcessingPhaseControlling: AnyObject {
    func beginProcessing(_ operation: CoachProcessingOperation)
    func endProcessing()
}

@MainActor
final class CoachPhotoFlowCoordinator {

    private let sessionStore = ImageAnalysisSessionStore()
    private let mealPhotoAnalyzer: CoachMealPhotoAnalyzer
    private let timelineRecorder: any CoachTimelineRecording
    private let messagePersistenceCoordinator: CoachMessagePersistenceCoordinator
    private let pendingConfirmationCoordinator: CoachPendingConfirmationCoordinator
    private let contextPacketCoordinator: CoachContextPacketCoordinator
    private var isSending: () -> Bool = { false }
    private var onSessionFailure: () -> Void = {}
    private weak var processingController: CoachProcessingPhaseControlling?

    init(
        mealPhotoAnalyzer: CoachMealPhotoAnalyzer,
        timelineRecorder: any CoachTimelineRecording,
        messagePersistenceCoordinator: CoachMessagePersistenceCoordinator,
        pendingConfirmationCoordinator: CoachPendingConfirmationCoordinator,
        contextPacketCoordinator: CoachContextPacketCoordinator
    ) {
        self.mealPhotoAnalyzer = mealPhotoAnalyzer
        self.timelineRecorder = timelineRecorder
        self.messagePersistenceCoordinator = messagePersistenceCoordinator
        self.pendingConfirmationCoordinator = pendingConfirmationCoordinator
        self.contextPacketCoordinator = contextPacketCoordinator
    }

    func configureRuntime(
        isSending: @escaping () -> Bool,
        onSessionFailure: @escaping () -> Void
    ) {
        self.isSending = isSending
        self.onSessionFailure = onSessionFailure
    }

    func configureProcessing(_ controller: CoachProcessingPhaseControlling) {
        processingController = controller
    }

    func sessionAwaitingClarification() -> ImageAnalysisSession? {
        sessionStore.sessionAwaitingClarification()
    }

    func session(forUserMessageID userMessageID: UUID) -> ImageAnalysisSession? {
        sessionStore.session(forUserMessageID: userMessageID)
    }

    func sendMealPhoto(
        jpegData: Data,
        caption: String?,
        source: CoachInputAttachmentSource?,
        thumbnailJPEG: Data? = nil
    ) async {
        CoachMealPhotoPipeline.assertImagePayloadPresent(jpegData)
        let normalizedJPEG = jpegData

        let displayCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        pendingConfirmationCoordinator.clearPhotoLinkedPendingConfirmation()

        let userMessage = appendUserMealPhotoMessage(
            caption: displayCaption.isEmpty ? nil : displayCaption,
            jpegData: normalizedJPEG,
            thumbnailJPEG: thumbnailJPEG,
            source: source
        )

        let attachment = userMessage.imageAttachment ?? ChatMessageImageAttachment(
            imageJPEG: normalizedJPEG,
            thumbnailJPEG: thumbnailJPEG
                ?? CoachImagePipeline.makeThumbnailSync(from: normalizedJPEG)
                ?? normalizedJPEG,
            source: source
        )
        let session = ImageAnalysisSession.newSession(
            userMessageID: userMessage.id,
            attachment: attachment,
            userCaption: displayCaption
        )
        sessionStore.upsert(session)
        recordPhotoAttached(
            session: session,
            messageId: userMessage.id,
            jpegData: normalizedJPEG,
            source: source
        )

        await runImageAnalysisSession(
            userMessageID: userMessage.id,
            jpegData: normalizedJPEG,
            recommission: nil,
            isRetry: false
        )
    }

    func retryMealPhotoAnalysis(for userMessageID: UUID) async {
        guard isSending() == false else { return }
        guard let session = sessionStore.session(forUserMessageID: userMessageID),
              let jpegData = messages.first(where: { $0.id == userMessageID })?.mealPhotoJPEG else {
            return
        }

        removePhotoAnalysisMessages(for: userMessageID, sessionID: session.sessionId)
        pendingConfirmationCoordinator.clearPendingConfirmationIfLinked(to: userMessageID)

        await runImageAnalysisSession(
            userMessageID: userMessageID,
            jpegData: jpegData,
            recommission: nil,
            isRetry: true
        )
    }

    func submitImageAnalysisClarification(_ clarification: String, for userMessageID: UUID) async {
        guard isSending() == false else { return }
        guard let session = sessionStore.session(forUserMessageID: userMessageID),
              let jpegData = messages.first(where: { $0.id == userMessageID })?.mealPhotoJPEG else {
            return
        }

        let trimmed = clarification.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        _ = sessionStore.apply(
            userMessageID: userMessageID,
            event: .clarificationAnswered(trimmed)
        )
        guard let updatedSession = sessionStore.session(forUserMessageID: userMessageID) else {
            return
        }

        removePhotoAnalysisMessages(for: userMessageID, sessionID: updatedSession.sessionId)
        pendingConfirmationCoordinator.clearPendingConfirmationIfLinked(to: userMessageID)

        _ = messagePersistenceCoordinator.appendAssistantMessage(
            ImageAnalysisSessionCopy.recommissionAcknowledgement(trimmed)
        )

        let recommission = ImageAnalysisRecommissionContext(
            clarification: trimmed,
            clarificationHistory: updatedSession.clarificationTurns,
            previousResult: updatedSession.latestResult
        )

        await runImageAnalysisSession(
            userMessageID: userMessageID,
            jpegData: jpegData,
            recommission: recommission,
            isRetry: false
        )
    }

    func handlePendingFoodDraftEdited(userMessageID: UUID, mealDraft: FoodLogDraft) {
        _ = sessionStore.apply(
            userMessageID: userMessageID,
            event: .draftEdited(mealDraft)
        )
        guard let session = sessionStore.session(forUserMessageID: userMessageID),
              session.status == .needsClarification,
              let question = session.activeClarifyingQuestion else {
            return
        }
        appendAssistantPhotoClarification(
            CoachResponseBuilder.mealPhotoClarification(question),
            session: session
        )
    }

    @discardableResult
    func appendLinkedPhotoAnalysisMessage(
        _ text: String,
        forUserMessageID userMessageID: UUID,
        sourceAttribution: CoachTimelineEventSourceAttribution = .mealImage
    ) -> ChatMessage? {
        guard let session = sessionStore.session(forUserMessageID: userMessageID) else {
            return nil
        }
        return appendAssistantPhotoAnalysisMessage(
            text,
            session: session,
            sourceAttribution: sourceAttribution
        )
    }

    // MARK: Analysis session

    private var messages: [ChatMessage] {
        messagePersistenceCoordinator.currentMessages
    }

    private func runImageAnalysisSession(
        userMessageID: UUID,
        jpegData: Data,
        recommission: ImageAnalysisRecommissionContext?,
        isRetry: Bool
    ) async {
        CoachMealPhotoPipeline.assertImagePayloadPresent(jpegData)

        guard let session = sessionStore.session(forUserMessageID: userMessageID) else {
            return
        }

        let traceLabel = isRetry ? "Meal photo retry" : CoachMealPhotoPipeline.userMessageLabel
        let traceId = FormaPipelineTracer.beginTrace(userMessage: traceLabel)
        let traceStarted = Date()
        var traceOutcome = recommission == nil ? "photoAnalysis" : "photoRecommission"

        _ = sessionStore.apply(userMessageID: userMessageID, event: .analysisStarted)
        let activeSession = sessionStore.session(forUserMessageID: userMessageID) ?? session

        CoachImageAnalysisDebugLogger.logAnalysisStarted(
            sessionId: activeSession.sessionId,
            userMessageId: userMessageID,
            attempt: activeSession.attempts,
            isRetry: isRetry,
            isRecommission: recommission != nil,
            hasCaption: !session.userCaption.isEmpty,
            compressedBytes: jpegData.count
        )
        recordPhotoAnalysisStarted(
            session: activeSession,
            messageId: userMessageID,
            isRetry: isRetry,
            isRecommission: recommission != nil
        )

        processingController?.beginProcessing(.mealPhoto(userMessageID: userMessageID, prompt: session.userCaption))
        defer {
            processingController?.endProcessing()
            FormaPipelineTracer.endTrace(
                traceId: traceId,
                outcome: traceOutcome,
                durationMs: Int(Date().timeIntervalSince(traceStarted) * 1_000)
            )
        }

        let priorChatMessages = messages.filter { $0.id != userMessageID }
        let caption = session.userCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextPacket = await contextPacketCoordinator.prepareContextPacket(
            recentMessages: priorChatMessages,
            currentUserMessage: caption.isEmpty ? nil : caption
        )
        let outcome = await mealPhotoAnalyzer.analyze(
            session: activeSession,
            recommission: recommission,
            recentMessages: priorChatMessages,
            context: contextPacket,
            currentUserMessage: caption.isEmpty ? nil : caption
        )

        if let sessionResult = outcome.sessionResult, outcome.result.pendingConfirmation != nil {
            _ = sessionStore.apply(
                userMessageID: userMessageID,
                event: .analysisSucceeded(sessionResult)
            )
            let updatedSession = sessionStore.session(forUserMessageID: userMessageID) ?? activeSession
            applyPhotoAnalysisSuccess(
                outcome.result,
                session: updatedSession,
                supersedeExisting: recommission != nil || isRetry
            )
            if updatedSession.status == .needsClarification,
               let question = updatedSession.activeClarifyingQuestion {
                appendAssistantPhotoClarification(
                    CoachResponseBuilder.mealPhotoClarification(question),
                    session: updatedSession
                )
            }
            recordPhotoAnalysisCompleted(
                session: updatedSession,
                sessionResult: sessionResult,
                messageId: messages.last(where: {
                    $0.photoAnalysisLink?.sessionID == updatedSession.sessionId
                })?.id
            )
            traceOutcome = updatedSession.status == .needsClarification ?
                "photoAnalysisNeedsClarification" :
                "photoAnalysisCompleted"
            CoachImageAnalysisDebugLogger.logSessionOutcome(
                sessionId: updatedSession.sessionId,
                attempt: updatedSession.attempts,
                sessionStatus: String(describing: updatedSession.status),
                confidence: sessionResult.confidence.rawValue,
                itemCount: sessionResult.mealDraft.components.count
            )
            return
        }

        let errorMessage = outcome.errorMessage ?? outcome.result.message
        _ = sessionStore.apply(
            userMessageID: userMessageID,
            event: .analysisFailed(errorMessage)
        )
        pendingConfirmationCoordinator.clearPendingConfirmationIfLinked(to: userMessageID)
        if outcome.errorCategory == "authentication" {
            onSessionFailure()
        }
        if let failedSession = sessionStore.session(forUserMessageID: userMessageID) {
            CoachImageAnalysisDebugLogger.logSessionOutcome(
                sessionId: failedSession.sessionId,
                attempt: failedSession.attempts,
                sessionStatus: "failed",
                errorCategory: outcome.errorCategory ?? "unknown"
            )
            appendMealPhotoFailureMessage(
                text: errorMessage,
                session: failedSession
            )
            recordPhotoAnalysisFailed(
                session: failedSession,
                errorCategory: outcome.errorCategory ?? "unknown",
                userMessage: errorMessage,
                messageId: userMessageID
            )
        }
        traceOutcome = "photoAnalysisFailed"
    }

    private func applyPhotoAnalysisSuccess(
        _ result: CoachActionResult,
        session: ImageAnalysisSession,
        supersedeExisting: Bool
    ) {
        let priorFoodDraft: AIFoodConfirmationDraft? = {
            guard supersedeExisting else { return nil }
            return pendingConfirmationCoordinator.priorFoodDraftForSupersede(userMessageID: session.userMessageID)
        }()

        if supersedeExisting {
            removePhotoAnalysisMessages(
                for: session.userMessageID,
                sessionID: session.sessionId
            )
            if priorFoodDraft == nil {
                pendingConfirmationCoordinator.clearPendingConfirmationIfLinked(to: session.userMessageID)
            }
        }

        if var confirmation = result.pendingConfirmation,
           case .food(var draft) = confirmation {
            draft.imageAnalysisSessionID = session.sessionId
            draft.relatedPhotoUserMessageID = session.userMessageID
            if let priorFoodDraft {
                draft = AIFoodConfirmationDraft(
                    id: priorFoodDraft.id,
                    originalText: draft.originalText,
                    assistantMessage: draft.assistantMessage,
                    mealDraft: draft.mealDraft,
                    confidence: draft.confidence,
                    requiresConfirmation: draft.requiresConfirmation,
                    sanityWarning: draft.sanityWarning,
                    imageAnalysisSessionID: draft.imageAnalysisSessionID,
                    relatedPhotoUserMessageID: draft.relatedPhotoUserMessageID,
                    createdAt: priorFoodDraft.createdAt
                )
            }
            confirmation = .food(draft)
            pendingConfirmationCoordinator.setPendingConfirmation(confirmation)
        }

        if !result.message.isEmpty {
            appendAssistantPhotoAnalysisMessage(
                result.message,
                session: session
            )
        }
    }

    // MARK: Message helpers

    @discardableResult
    private func appendUserMealPhotoMessage(
        caption: String?,
        jpegData: Data,
        thumbnailJPEG: Data? = nil,
        source: CoachInputAttachmentSource?
    ) -> ChatMessage {
        let attachment: ChatMessageImageAttachment
        if let thumbnailJPEG {
            attachment = ChatMessageImageAttachment(
                imageJPEG: jpegData,
                thumbnailJPEG: thumbnailJPEG,
                source: source
            )
        } else {
            attachment = ChatMessageImageAttachment.fromJPEG(jpegData, source: source)
                ?? ChatMessageImageAttachment(imageJPEG: jpegData, thumbnailJPEG: jpegData, source: source)
        }
        let message = ChatMessage.userMealPhoto(caption: caption, attachment: attachment)
        messagePersistenceCoordinator.mutateMessages { $0.append(message) }
        messagePersistenceCoordinator.recordUserMessageIfNeeded(message, hasPhotoAttachment: true)
        return message
    }

    @discardableResult
    private func appendAssistantPhotoAnalysisMessage(
        _ text: String,
        session: ImageAnalysisSession,
        sourceAttribution: CoachTimelineEventSourceAttribution = .mealImage
    ) -> ChatMessage {
        let message = ChatMessage.assistantPhotoAnalysisResult(
            text: text,
            sessionID: session.sessionId,
            relatedUserMessageID: session.userMessageID
        )
        messagePersistenceCoordinator.mutateMessages { $0.append(message) }
        messagePersistenceCoordinator.recordAssistantMessageIfNeeded(
            message,
            sourceAttribution: sourceAttribution
        )
        return message
    }

    @discardableResult
    private func appendAssistantPhotoClarification(
        _ text: String,
        session: ImageAnalysisSession
    ) -> ChatMessage {
        let message = ChatMessage.assistantPhotoClarification(
            text: text,
            sessionID: session.sessionId,
            relatedUserMessageID: session.userMessageID
        )
        messagePersistenceCoordinator.mutateMessages { $0.append(message) }
        messagePersistenceCoordinator.recordAssistantMessageIfNeeded(
            message,
            sourceAttribution: .mealImage
        )
        messagePersistenceCoordinator.recordClarificationAsked(
            question: text,
            messageId: message.id,
            sessionId: session.sessionId,
            occurredAt: message.createdAt
        )
        return message
    }

    private func appendMealPhotoFailureMessage(text: String, session: ImageAnalysisSession) {
        let message = ChatMessage.assistantPhotoAnalysisFailure(
            text: text,
            sessionID: session.sessionId,
            relatedUserMessageID: session.userMessageID
        )
        messagePersistenceCoordinator.mutateMessages { $0.append(message) }
    }

    private func removePhotoAnalysisMessages(for userMessageID: UUID, sessionID: UUID) {
        messagePersistenceCoordinator.mutateMessages { messages in
            messages.removeAll { message in
                guard let link = message.photoAnalysisLink else { return false }
                return link.relatedUserMessageID == userMessageID && link.sessionID == sessionID
            }
        }
    }

    // MARK: Timeline

    private func recordPhotoAttached(
        session: ImageAnalysisSession,
        messageId: UUID,
        jpegData: Data,
        source: CoachInputAttachmentSource?
    ) {
        timelineRecorder.recordPhotoAttached(
            payload: PhotoPayload(
                sessionId: session.sessionId,
                mimeType: CoachImageUploadConfig.default.mimeType,
                compressedByteSize: jpegData.count,
                attachmentSource: source.map(CoachImageAnalysisDebugLogFormatter.sourceLabel),
                hasCaption: !session.userCaption.isEmpty
            ),
            messageId: messageId,
            occurredAt: Date()
        )
    }

    private func recordPhotoAnalysisStarted(
        session: ImageAnalysisSession,
        messageId: UUID,
        isRetry: Bool,
        isRecommission: Bool
    ) {
        timelineRecorder.recordPhotoAnalysisStarted(
            sessionId: session.sessionId,
            messageId: messageId,
            occurredAt: Date()
        )
    }

    private func recordPhotoAnalysisCompleted(
        session: ImageAnalysisSession,
        sessionResult: ImageAnalysisSessionResult,
        messageId: UUID?
    ) {
        timelineRecorder.recordPhotoAnalysisCompleted(
            sessionId: session.sessionId,
            messageId: messageId,
            mealName: sessionResult.mealDraft.displayName,
            estimateId: pendingConfirmationCoordinator.pendingConfirmationEstimateId(),
            confidence: {
                switch sessionResult.confidence {
                case .high: return .high
                case .medium: return .medium
                case .low: return .low
                }
            }(),
            occurredAt: Date()
        )
    }

    private func recordPhotoAnalysisFailed(
        session: ImageAnalysisSession,
        errorCategory: String,
        userMessage: String?,
        messageId: UUID
    ) {
        timelineRecorder.recordPhotoAnalysisFailed(
            sessionId: session.sessionId,
            messageId: messageId,
            errorCategory: errorCategory,
            userMessage: userMessage,
            isRetryable: errorCategory != "authentication",
            occurredAt: Date()
        )
    }
}
