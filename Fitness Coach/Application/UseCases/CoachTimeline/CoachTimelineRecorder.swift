//
//  CoachTimelineRecorder.swift
//  Fitness Coach
//
//  Forma — Best-effort Coach timeline event recording for Coach, mutations,
//  photo analysis, and context generation.
//
//  Recording failures are logged and never block user actions or AI responses.
//

import Foundation
import OSLog

// MARK: - Protocol

/// Safe, fire-and-forget API for appending Coach timeline events.
protocol CoachTimelineRecording: Sendable {

    // MARK: Conversation

    func recordUserMessage(
        text: String,
        messageId: UUID?,
        hasPhotoAttachment: Bool,
        occurredAt: Date?
    )

    func recordAssistantMessage(
        text: String,
        messageId: UUID?,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        occurredAt: Date?
    )

    // MARK: Food lifecycle

    func recordFoodEstimateCreated(
        payload: FoodEstimatePayload,
        source: CoachTimelineEventSource,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        confidence: CoachTimelineEventConfidence?,
        status: CoachTimelineEventStatus,
        messageId: UUID?,
        photoSessionId: UUID?,
        relatedEventIds: [UUID],
        occurredAt: Date?
    )

    func recordFoodLogged(
        entry: FoodEntry,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        userEditedBeforeConfirm: Bool,
        linkedPhotoSessionId: UUID?,
        occurredAt: Date?
    )

    func recordFoodRejected(
        payload: FoodEstimatePayload,
        messageId: UUID?,
        photoSessionId: UUID?,
        relatedEventIds: [UUID],
        occurredAt: Date?
    )

    func recordFoodEdited(
        entry: FoodEntry,
        supersedesEventId: UUID?,
        occurredAt: Date?
    )

    func recordFoodDeleted(
        entry: FoodEntry,
        supersedesEventId: UUID?,
        occurredAt: Date?
    )

    // MARK: Hydration & weight

    func recordWaterLogged(
        entry: WaterEntry,
        occurredAt: Date?
    )

    func recordWeightLogged(
        entry: WeightEntry,
        occurredAt: Date?
    )

    // MARK: Health activity

    func recordWorkoutDetected(
        workoutCount: Int,
        totalDurationMinutes: Int,
        totalActiveCalories: Int?,
        primaryWorkoutTitle: String?,
        demand: String?,
        occurredAt: Date?
    )

    func recordStepsUpdated(
        steps: Int,
        previousSteps: Int?,
        occurredAt: Date?
    )

    // MARK: Meal photo analysis

    func recordPhotoAttached(
        payload: PhotoPayload,
        messageId: UUID?,
        occurredAt: Date?
    )

    func recordPhotoAnalysisStarted(
        sessionId: UUID,
        messageId: UUID?,
        occurredAt: Date?
    )

    func recordPhotoAnalysisCompleted(
        sessionId: UUID,
        messageId: UUID?,
        mealName: String?,
        estimateId: UUID?,
        confidence: CoachTimelineEventConfidence?,
        occurredAt: Date?
    )

    func recordPhotoAnalysisFailed(
        sessionId: UUID,
        messageId: UUID?,
        errorCategory: String,
        userMessage: String?,
        isRetryable: Bool,
        occurredAt: Date?
    )

    // MARK: Clarification

    func recordClarificationAsked(
        question: String,
        messageId: UUID?,
        sessionId: UUID,
        occurredAt: Date?
    )

    func recordClarificationAnswered(
        answer: String,
        messageId: UUID?,
        sessionId: UUID,
        occurredAt: Date?
    )

    // MARK: Pending confirmation

    func recordPendingConfirmationCreated(
        payload: ConfirmationPayload,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        occurredAt: Date?
    )

    func recordPendingConfirmationConfirmed(
        payload: ConfirmationPayload,
        entryId: UUID?,
        occurredAt: Date?
    )

    func recordPendingConfirmationRejected(
        payload: ConfirmationPayload,
        occurredAt: Date?
    )

    // MARK: Undo & errors

    func recordUndoPerformed(
        entryType: String,
        undoneEntryId: UUID?,
        summary: String?,
        occurredAt: Date?
    )

    func recordBackendError(
        category: String,
        userMessage: String?,
        isRetryable: Bool,
        httpStatus: Int?,
        occurredAt: Date?
    )

    func recordAuthError(
        userMessage: String?,
        occurredAt: Date?
    )

    func recordHealthDataUnavailable(
        missingSignals: [String],
        reason: String?,
        healthIntelligenceAwarenessAvailable: Bool?,
        occurredAt: Date?
    )

    func recordContextGenerated(
        payload: ContextGenerationPayload,
        occurredAt: Date?
    )
}

// MARK: - No-op

struct NoOpCoachTimelineRecorder: CoachTimelineRecording {

    func recordUserMessage(
        text: String,
        messageId: UUID?,
        hasPhotoAttachment: Bool,
        occurredAt: Date?
    ) {}

    func recordAssistantMessage(
        text: String,
        messageId: UUID?,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        occurredAt: Date?
    ) {}

    func recordFoodEstimateCreated(
        payload: FoodEstimatePayload,
        source: CoachTimelineEventSource,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        confidence: CoachTimelineEventConfidence?,
        status: CoachTimelineEventStatus,
        messageId: UUID?,
        photoSessionId: UUID?,
        relatedEventIds: [UUID],
        occurredAt: Date?
    ) {}

    func recordFoodLogged(
        entry: FoodEntry,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        userEditedBeforeConfirm: Bool,
        linkedPhotoSessionId: UUID?,
        occurredAt: Date?
    ) {}

    func recordFoodRejected(
        payload: FoodEstimatePayload,
        messageId: UUID?,
        photoSessionId: UUID?,
        relatedEventIds: [UUID],
        occurredAt: Date?
    ) {}

    func recordFoodEdited(
        entry: FoodEntry,
        supersedesEventId: UUID?,
        occurredAt: Date?
    ) {}

    func recordFoodDeleted(
        entry: FoodEntry,
        supersedesEventId: UUID?,
        occurredAt: Date?
    ) {}

    func recordWaterLogged(entry: WaterEntry, occurredAt: Date?) {}

    func recordWeightLogged(entry: WeightEntry, occurredAt: Date?) {}

    func recordWorkoutDetected(
        workoutCount: Int,
        totalDurationMinutes: Int,
        totalActiveCalories: Int?,
        primaryWorkoutTitle: String?,
        demand: String?,
        occurredAt: Date?
    ) {}

    func recordStepsUpdated(steps: Int, previousSteps: Int?, occurredAt: Date?) {}

    func recordPhotoAttached(payload: PhotoPayload, messageId: UUID?, occurredAt: Date?) {}

    func recordPhotoAnalysisStarted(sessionId: UUID, messageId: UUID?, occurredAt: Date?) {}

    func recordPhotoAnalysisCompleted(
        sessionId: UUID,
        messageId: UUID?,
        mealName: String?,
        estimateId: UUID?,
        confidence: CoachTimelineEventConfidence?,
        occurredAt: Date?
    ) {}

    func recordPhotoAnalysisFailed(
        sessionId: UUID,
        messageId: UUID?,
        errorCategory: String,
        userMessage: String?,
        isRetryable: Bool,
        occurredAt: Date?
    ) {}

    func recordClarificationAsked(
        question: String,
        messageId: UUID?,
        sessionId: UUID,
        occurredAt: Date?
    ) {}

    func recordClarificationAnswered(
        answer: String,
        messageId: UUID?,
        sessionId: UUID,
        occurredAt: Date?
    ) {}

    func recordPendingConfirmationCreated(
        payload: ConfirmationPayload,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        occurredAt: Date?
    ) {}

    func recordPendingConfirmationConfirmed(
        payload: ConfirmationPayload,
        entryId: UUID?,
        occurredAt: Date?
    ) {}

    func recordPendingConfirmationRejected(payload: ConfirmationPayload, occurredAt: Date?) {}

    func recordUndoPerformed(
        entryType: String,
        undoneEntryId: UUID?,
        summary: String?,
        occurredAt: Date?
    ) {}

    func recordBackendError(
        category: String,
        userMessage: String?,
        isRetryable: Bool,
        httpStatus: Int?,
        occurredAt: Date?
    ) {}

    func recordAuthError(userMessage: String?, occurredAt: Date?) {}

    func recordHealthDataUnavailable(
        missingSignals: [String],
        reason: String?,
        healthIntelligenceAwarenessAvailable: Bool?,
        occurredAt: Date?
    ) {}

    func recordContextGenerated(payload: ContextGenerationPayload, occurredAt: Date?) {}
}

// MARK: - Default implementation

/// Best-effort timeline recorder backed by `CoachTimelineStoring`.
///
/// When `store` is `nil`, all record calls are no-ops.
final class DefaultCoachTimelineRecorder: CoachTimelineRecording, @unchecked Sendable {

    private let store: (any CoachTimelineStoring)?
    private let calendar: Calendar
    private let logger = Logger(subsystem: "Forma", category: "CoachTimeline")

    init(
        store: (any CoachTimelineStoring)?,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.calendar = calendar
    }

    // MARK: Conversation

    func recordUserMessage(
        text: String,
        messageId: UUID? = nil,
        hasPhotoAttachment: Bool = false,
        occurredAt: Date? = nil
    ) {
        let preview = CoachTimelineRecorderFormatting.textPreview(text)
        let payload = MessagePayload(
            textPreview: preview,
            fullText: CoachTimelineRecorderFormatting.boundedFullText(text),
            role: "user",
            hasPhotoAttachment: hasPhotoAttachment
        )
        append(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .localParser,
            status: .confirmed,
            payload: .message(payload),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(linkedMessageId: messageId)
        )
    }

    func recordAssistantMessage(
        text: String,
        messageId: UUID? = nil,
        sourceAttribution: CoachTimelineEventSourceAttribution = .classifier,
        occurredAt: Date? = nil
    ) {
        let preview = CoachTimelineRecorderFormatting.textPreview(text)
        let payload = MessagePayload(
            textPreview: preview,
            fullText: CoachTimelineRecorderFormatting.boundedFullText(text),
            role: "assistant",
            hasPhotoAttachment: false
        )
        append(
            type: .assistantMessage,
            source: .aiBackend,
            sourceAttribution: sourceAttribution,
            status: .confirmed,
            payload: .message(payload),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(linkedMessageId: messageId)
        )
    }

    // MARK: Food lifecycle

    func recordFoodEstimateCreated(
        payload: FoodEstimatePayload,
        source: CoachTimelineEventSource,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        confidence: CoachTimelineEventConfidence? = nil,
        status: CoachTimelineEventStatus = .pending,
        messageId: UUID? = nil,
        photoSessionId: UUID? = nil,
        relatedEventIds: [UUID] = [],
        occurredAt: Date? = nil
    ) {
        append(
            type: .foodEstimateCreated,
            source: source,
            sourceAttribution: sourceAttribution,
            confidence: confidence,
            status: status,
            payload: .foodEstimate(payload),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedMessageId: messageId,
                linkedPhotoSessionId: photoSessionId,
                relatedEventIds: relatedEventIds
            )
        )
    }

    func recordFoodLogged(
        entry: FoodEntry,
        sourceAttribution: CoachTimelineEventSourceAttribution = .userConfirmation,
        userEditedBeforeConfirm: Bool = false,
        linkedPhotoSessionId: UUID? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: sourceAttribution,
            confidence: CoachTimelineEventConfidence.from(entry.confidence),
            status: .confirmed,
            payload: .foodLogged(
                entry.timelineLoggedPayload(userEditedBeforeConfirm: userEditedBeforeConfirm)
            ),
            occurredAt: occurredAt ?? entry.createdAt,
            link: CoachTimelineEventLink(
                linkedEntryId: entry.id,
                linkedDailyLogId: entry.dailyLogId,
                linkedPhotoSessionId: linkedPhotoSessionId
            )
        )
    }

    func recordFoodRejected(
        payload: FoodEstimatePayload,
        messageId: UUID? = nil,
        photoSessionId: UUID? = nil,
        relatedEventIds: [UUID] = [],
        occurredAt: Date? = nil
    ) {
        append(
            type: .foodRejected,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .rejected,
            payload: .foodEstimate(payload),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedMessageId: messageId,
                linkedPhotoSessionId: photoSessionId,
                relatedEventIds: relatedEventIds
            )
        )
    }

    func recordFoodEdited(
        entry: FoodEntry,
        supersedesEventId: UUID? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .foodEdited,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            confidence: CoachTimelineEventConfidence.from(entry.confidence),
            status: .confirmed,
            payload: .foodLogged(entry.timelineLoggedPayload(isEdit: true)),
            occurredAt: occurredAt ?? entry.updatedAt,
            link: CoachTimelineEventLink(
                linkedEntryId: entry.id,
                linkedDailyLogId: entry.dailyLogId
            ),
            supersedesEventId: supersedesEventId
        )
    }

    func recordFoodDeleted(
        entry: FoodEntry,
        supersedesEventId: UUID? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .foodDeleted,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            confidence: CoachTimelineEventConfidence.from(entry.confidence),
            status: .confirmed,
            payload: .foodLogged(entry.timelineLoggedPayload(isDelete: true)),
            occurredAt: occurredAt ?? entry.updatedAt,
            link: CoachTimelineEventLink(
                linkedEntryId: entry.id,
                linkedDailyLogId: entry.dailyLogId
            ),
            supersedesEventId: supersedesEventId
        )
    }

    // MARK: Hydration & weight

    func recordWaterLogged(entry: WaterEntry, occurredAt: Date? = nil) {
        append(
            type: .waterLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .waterLogged(
                WaterLoggedPayload(
                    entryId: entry.id,
                    dailyLogId: entry.dailyLogId,
                    amountMl: entry.amountMl
                )
            ),
            occurredAt: occurredAt ?? entry.createdAt,
            link: CoachTimelineEventLink(
                linkedEntryId: entry.id,
                linkedDailyLogId: entry.dailyLogId
            )
        )
    }

    func recordWeightLogged(entry: WeightEntry, occurredAt: Date? = nil) {
        append(
            type: .weightLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .weightLogged(
                WeightLoggedPayload(
                    entryId: entry.id,
                    weightKg: entry.weightKg,
                    note: entry.note
                )
            ),
            occurredAt: occurredAt ?? entry.createdAt,
            link: CoachTimelineEventLink(linkedEntryId: entry.id)
        )
    }

    // MARK: Health activity

    func recordWorkoutDetected(
        workoutCount: Int,
        totalDurationMinutes: Int = 0,
        totalActiveCalories: Int? = nil,
        primaryWorkoutTitle: String? = nil,
        demand: String? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .workoutDetected,
            source: .healthSync,
            sourceAttribution: .healthKit,
            status: .confirmed,
            payload: .workoutDetected(
                WorkoutDetectedPayload(
                    workoutCount: workoutCount,
                    totalDurationMinutes: totalDurationMinutes,
                    totalActiveCalories: totalActiveCalories,
                    primaryWorkoutTitle: primaryWorkoutTitle,
                    demand: demand
                )
            ),
            occurredAt: occurredAt
        )
    }

    func recordStepsUpdated(
        steps: Int,
        previousSteps: Int? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .stepsUpdated,
            source: .healthSync,
            sourceAttribution: .healthKit,
            status: .confirmed,
            payload: .steps(StepsPayload(steps: steps, previousSteps: previousSteps)),
            occurredAt: occurredAt
        )
    }

    // MARK: Meal photo analysis

    func recordPhotoAttached(
        payload: PhotoPayload,
        messageId: UUID? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .photoAttached,
            source: .coachUI,
            sourceAttribution: .mealImage,
            status: .confirmed,
            payload: .photo(payload),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedMessageId: messageId,
                linkedPhotoSessionId: payload.sessionId
            )
        )
    }

    func recordPhotoAnalysisStarted(
        sessionId: UUID,
        messageId: UUID? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .photoAnalysisStarted,
            source: .aiBackend,
            sourceAttribution: .mealImage,
            status: .pending,
            payload: .photo(PhotoPayload(sessionId: sessionId)),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedMessageId: messageId,
                linkedPhotoSessionId: sessionId
            )
        )
    }

    func recordPhotoAnalysisCompleted(
        sessionId: UUID,
        messageId: UUID? = nil,
        mealName: String? = nil,
        estimateId: UUID? = nil,
        confidence: CoachTimelineEventConfidence? = nil,
        occurredAt: Date? = nil
    ) {
        var photoPayload = PhotoPayload(sessionId: sessionId)
        if let mealName {
            photoPayload.hasCaption = !mealName.isEmpty
        }
        append(
            type: .photoAnalysisCompleted,
            source: .aiBackend,
            sourceAttribution: .mealImage,
            confidence: confidence,
            status: .confirmed,
            payload: .photo(photoPayload),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedMessageId: messageId,
                linkedPhotoSessionId: sessionId,
                relatedEventIds: estimateId.map { [$0] } ?? []
            )
        )
    }

    func recordPhotoAnalysisFailed(
        sessionId: UUID,
        messageId: UUID? = nil,
        errorCategory: String,
        userMessage: String? = nil,
        isRetryable: Bool = false,
        occurredAt: Date? = nil
    ) {
        append(
            type: .photoAnalysisFailed,
            source: .aiBackend,
            sourceAttribution: .mealImage,
            status: .failed,
            payload: .error(
                ErrorPayload(
                    category: errorCategory,
                    userMessagePreview: userMessage.map(CoachTimelineRecorderFormatting.textPreview),
                    isRetryable: isRetryable
                )
            ),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedMessageId: messageId,
                linkedPhotoSessionId: sessionId
            )
        )
    }

    // MARK: Clarification

    func recordClarificationAsked(
        question: String,
        messageId: UUID? = nil,
        sessionId: UUID,
        occurredAt: Date? = nil
    ) {
        let preview = CoachTimelineRecorderFormatting.textPreview(question)
        append(
            type: .clarificationAsked,
            source: .aiBackend,
            sourceAttribution: .mealImage,
            status: .pending,
            payload: .message(
                MessagePayload(textPreview: preview, fullText: CoachTimelineRecorderFormatting.boundedFullText(question), role: "assistant")
            ),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedMessageId: messageId,
                linkedPhotoSessionId: sessionId
            )
        )
    }

    func recordClarificationAnswered(
        answer: String,
        messageId: UUID? = nil,
        sessionId: UUID,
        occurredAt: Date? = nil
    ) {
        let preview = CoachTimelineRecorderFormatting.textPreview(answer)
        append(
            type: .clarificationAnswered,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .message(
                MessagePayload(textPreview: preview, fullText: CoachTimelineRecorderFormatting.boundedFullText(answer), role: "user")
            ),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedMessageId: messageId,
                linkedPhotoSessionId: sessionId
            )
        )
    }

    // MARK: Pending confirmation

    func recordPendingConfirmationCreated(
        payload: ConfirmationPayload,
        sourceAttribution: CoachTimelineEventSourceAttribution = .estimateFood,
        occurredAt: Date? = nil
    ) {
        var relatedEventIds = payload.pendingConfirmationId.map { [$0] } ?? []
        if let timelineEventId = payload.relatedTimelineEventId {
            relatedEventIds.append(timelineEventId)
        }
        append(
            type: .pendingConfirmationCreated,
            source: .coachUI,
            sourceAttribution: sourceAttribution,
            status: .pending,
            payload: .confirmation(payload),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedEntryId: payload.linkedEntryId,
                linkedPhotoSessionId: payload.relatedPhotoSessionId,
                relatedEventIds: relatedEventIds
            )
        )
    }

    func recordPendingConfirmationConfirmed(
        payload: ConfirmationPayload,
        entryId: UUID? = nil,
        occurredAt: Date? = nil
    ) {
        var relatedEventIds = payload.pendingConfirmationId.map { [$0] } ?? []
        if let timelineEventId = payload.relatedTimelineEventId {
            relatedEventIds.append(timelineEventId)
        }
        append(
            type: .pendingConfirmationConfirmed,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .confirmation(payload),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedEntryId: entryId ?? payload.linkedEntryId,
                linkedPhotoSessionId: payload.relatedPhotoSessionId,
                relatedEventIds: relatedEventIds
            )
        )
    }

    func recordPendingConfirmationRejected(
        payload: ConfirmationPayload,
        occurredAt: Date? = nil
    ) {
        append(
            type: .pendingConfirmationRejected,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .rejected,
            payload: .confirmation(payload),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(
                linkedPhotoSessionId: payload.relatedPhotoSessionId,
                relatedEventIds: payload.pendingConfirmationId.map { [$0] } ?? []
            )
        )
    }

    // MARK: Undo & errors

    func recordUndoPerformed(
        entryType: String,
        undoneEntryId: UUID? = nil,
        summary: String? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .undoPerformed,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .undo(
                UndoPerformedPayload(
                    entryType: entryType,
                    undoneEntryId: undoneEntryId,
                    summary: summary.map(CoachTimelineRecorderFormatting.textPreview)
                )
            ),
            occurredAt: occurredAt,
            link: CoachTimelineEventLink(linkedEntryId: undoneEntryId)
        )
    }

    func recordBackendError(
        category: String,
        userMessage: String? = nil,
        isRetryable: Bool = false,
        httpStatus: Int? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .backendError,
            source: .aiBackend,
            sourceAttribution: .system,
            status: .failed,
            payload: .error(
                ErrorPayload(
                    category: category,
                    userMessagePreview: userMessage.map(CoachTimelineRecorderFormatting.textPreview),
                    isRetryable: isRetryable,
                    httpStatus: httpStatus
                )
            ),
            occurredAt: occurredAt
        )
    }

    func recordAuthError(userMessage: String? = nil, occurredAt: Date? = nil) {
        append(
            type: .authError,
            source: .aiBackend,
            sourceAttribution: .system,
            status: .failed,
            payload: .error(
                ErrorPayload(
                    category: "authentication",
                    userMessagePreview: userMessage.map(CoachTimelineRecorderFormatting.textPreview),
                    isRetryable: true
                )
            ),
            occurredAt: occurredAt
        )
    }

    func recordHealthDataUnavailable(
        missingSignals: [String] = [],
        reason: String? = nil,
        healthIntelligenceAwarenessAvailable: Bool? = nil,
        occurredAt: Date? = nil
    ) {
        append(
            type: .healthDataUnavailable,
            source: .system,
            sourceAttribution: .healthIntelligence,
            status: .confirmed,
            payload: .healthAvailability(
                HealthAvailabilityPayload(
                    isAvailable: false,
                    missingSignals: missingSignals,
                    reason: reason,
                    healthIntelligenceAwarenessAvailable: healthIntelligenceAwarenessAvailable
                )
            ),
            occurredAt: occurredAt
        )
    }

    func recordContextGenerated(
        payload: ContextGenerationPayload,
        occurredAt: Date? = nil
    ) {
        append(
            type: .contextGenerated,
            source: .system,
            sourceAttribution: .system,
            status: .confirmed,
            payload: .contextGeneration(payload),
            occurredAt: occurredAt
        )
    }

    // MARK: Private

    private func append(
        type: CoachTimelineEventType,
        source: CoachTimelineEventSource,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        confidence: CoachTimelineEventConfidence? = nil,
        status: CoachTimelineEventStatus,
        payload: CoachTimelineEventPayload,
        occurredAt: Date?,
        link: CoachTimelineEventLink = CoachTimelineEventLink(),
        supersedesEventId: UUID? = nil
    ) {
        guard let store else { return }

        let instant = occurredAt ?? Date()
        let event = CoachTimelineEvent.make(
            type: type,
            source: source,
            sourceAttribution: sourceAttribution,
            confidence: confidence,
            status: status,
            payload: payload,
            occurredAt: instant,
            calendar: calendar,
            link: link,
            supersedesEventId: supersedesEventId
        )

        Task { @MainActor in
            do {
                try await store.append(event)
            } catch {
                self.logFailure(event: event, error: error)
            }
        }
    }

    private func logFailure(event: CoachTimelineEvent, error: Error) {
        let summary = CoachTimelineEventSummaryBuilder.summary(for: event)
        logger.error(
            "Coach timeline record failed type=\(event.type.rawValue, privacy: .public) summary=\(summary, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
        )
        #if DEBUG
        FormaPipelineTracer.event(
            stage: .error,
            level: .error,
            message: "Coach timeline record failed",
            fields: [
                "eventType": event.type.rawValue,
                "localDate": event.localDate,
                "timezone": event.timezoneIdentifier,
                "error": error.localizedDescription
            ]
        )
        #endif
    }
}

// MARK: - Formatting

private enum CoachTimelineRecorderFormatting {

    static let previewMaxLength = 180

    static func textPreview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > previewMaxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: previewMaxLength)
        return String(trimmed[..<index]) + "…"
    }

    static func boundedFullText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= CoachInputSafety.maxTextCharacters else { return nil }
        return trimmed
    }
}

// MARK: - Domain mapping

private extension FoodEntry {

    func timelineLoggedPayload(
        isEdit: Bool = false,
        isDelete: Bool = false,
        userEditedBeforeConfirm: Bool = false
    ) -> FoodLoggedPayload {
        FoodLoggedPayload(
            entryId: id,
            dailyLogId: dailyLogId,
            mealType: mealType?.rawValue,
            name: name,
            quantity: quantity,
            unit: unit,
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            source: source.rawValue,
            confidence: confidence.rawValue,
            userEditedBeforeConfirm: userEditedBeforeConfirm,
            isEdit: isEdit,
            isDelete: isDelete
        )
    }
}

extension CoachTimelineEventConfidence {

    static func from(_ level: ConfidenceLevel) -> CoachTimelineEventConfidence {
        switch level {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}

extension FoodLogDraft {

    func timelineEstimatePayload(
        estimateId: UUID? = nil,
        requiresConfirmation: Bool = true,
        sanityWarning: String? = nil,
        originalText: String? = nil
    ) -> FoodEstimatePayload {
        FoodEstimatePayload(
            estimateId: estimateId ?? id,
            mealName: displayName,
            mealType: mealType?.rawValue,
            calories: totalCalories > 0 ? totalCalories : nil,
            proteinGrams: totalProtein > 0 ? totalProtein : nil,
            carbsGrams: totalCarbs > 0 ? totalCarbs : nil,
            fatGrams: totalFat > 0 ? totalFat : nil,
            componentCount: components.count,
            requiresConfirmation: requiresConfirmation,
            originalText: originalText,
            sanityWarning: sanityWarning
        )
    }
}
