//
//  CoachMessagePersistenceCoordinator.swift
//  Fitness Coach
//
//  Forma — Coach chat transcript persistence and timeline message recording.
//

import Foundation

@MainActor
protocol CoachMessagePersistenceDelegate: AnyObject {
    var transcriptMessages: [ChatMessage] { get set }
    func persistenceDidAppendStructuredMessage(_ content: CoachStructuredMessageContent)
}

@MainActor
final class CoachMessagePersistenceCoordinator {

    private weak var delegate: CoachMessagePersistenceDelegate?
    private let transcriptStore: CoachChatTranscriptStore
    private let timelineRecorder: any CoachTimelineRecording
    private var recordedTimelineUserMessageIDs = Set<UUID>()
    private var recordedTimelineAssistantMessageIDs = Set<UUID>()

    init(
        transcriptStore: CoachChatTranscriptStore,
        timelineRecorder: any CoachTimelineRecording
    ) {
        self.transcriptStore = transcriptStore
        self.timelineRecorder = timelineRecorder
    }

    func configure(delegate: CoachMessagePersistenceDelegate) {
        self.delegate = delegate
    }

    func restoreMessages() -> [ChatMessage] {
        transcriptStore.loadMessages()
    }

    var currentMessages: [ChatMessage] {
        delegate?.transcriptMessages ?? []
    }

    func mutateMessages(_ transform: (inout [ChatMessage]) -> Void) {
        guard var messages = delegate?.transcriptMessages else { return }
        transform(&messages)
        delegate?.transcriptMessages = messages
        persistTranscript()
    }

    func persistTranscript() {
        transcriptStore.saveMessages(delegate?.transcriptMessages ?? [])
    }

    @discardableResult
    func appendUserMessage(text: String) -> ChatMessage {
        let message = ChatMessage(
            id: UUID(),
            role: .user,
            text: text,
            createdAt: Date(),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        )
        mutateMessages { $0.append(message) }
        recordUserMessageIfNeeded(message)
        return message
    }

    @discardableResult
    func appendAssistantMessage(
        _ text: String,
        sourceAttribution: CoachTimelineEventSourceAttribution = .localParser
    ) -> ChatMessage {
        let message = ChatMessage(
            id: UUID(),
            role: .assistant,
            text: text,
            createdAt: Date(),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        )
        mutateMessages { $0.append(message) }
        recordAssistantMessageIfNeeded(message, sourceAttribution: sourceAttribution)
        return message
    }

    @discardableResult
    func appendAssistantStructuredMessage(
        _ content: CoachStructuredMessageContent,
        accessibilityText: String,
        sourceAttribution: CoachTimelineEventSourceAttribution = .classifier
    ) -> ChatMessage {
        let message = ChatMessage(
            id: UUID(),
            role: .assistant,
            text: accessibilityText,
            createdAt: Date(),
            relatedDailyLogId: nil,
            relatedEntryId: nil,
            structuredContent: content
        )
        mutateMessages { $0.append(message) }
        recordAssistantMessageIfNeeded(message, sourceAttribution: sourceAttribution)
        delegate?.persistenceDidAppendStructuredMessage(content)
        return message
    }

    func recordUserMessageIfNeeded(
        _ message: ChatMessage,
        hasPhotoAttachment: Bool? = nil
    ) {
        guard message.role == .user else { return }
        guard recordedTimelineUserMessageIDs.insert(message.id).inserted else { return }

        timelineRecorder.recordUserMessage(
            text: message.text,
            messageId: message.id,
            hasPhotoAttachment: hasPhotoAttachment ?? message.hasMealPhotoAttachment,
            occurredAt: message.createdAt
        )
    }

    func recordAssistantMessageIfNeeded(
        _ message: ChatMessage,
        sourceAttribution: CoachTimelineEventSourceAttribution
    ) {
        guard message.role == .assistant else { return }
        guard recordedTimelineAssistantMessageIDs.insert(message.id).inserted else { return }

        timelineRecorder.recordAssistantMessage(
            text: message.text,
            messageId: message.id,
            sourceAttribution: sourceAttribution,
            occurredAt: message.createdAt
        )
    }

    func recordBackendError(_ error: AIServiceError) {
        timelineRecorder.recordBackendError(
            category: CoachModelTimelineSupport.backendErrorCategory(for: error),
            userMessage: error.userMessage,
            isRetryable: CoachModelTimelineSupport.isRetryableBackendError(error),
            httpStatus: nil,
            occurredAt: Date()
        )
    }

    func recordAuthError(userMessage: String?) {
        timelineRecorder.recordAuthError(
            userMessage: userMessage,
            occurredAt: Date()
        )
    }

    func recordClarificationAnswered(
        answer: String,
        session: ImageAnalysisSession
    ) {
        timelineRecorder.recordClarificationAnswered(
            answer: answer,
            messageId: delegate?.transcriptMessages.last(where: { $0.role == .user })?.id,
            sessionId: session.sessionId,
            occurredAt: Date()
        )
    }

    func recordClarificationAsked(
        question: String,
        messageId: UUID,
        sessionId: UUID,
        occurredAt: Date
    ) {
        timelineRecorder.recordClarificationAsked(
            question: question,
            messageId: messageId,
            sessionId: sessionId,
            occurredAt: occurredAt
        )
    }
}
