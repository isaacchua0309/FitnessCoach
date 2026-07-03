//
//  CoachTimelineEventEntity+Mapping.swift
//  Fitness Coach
//
//  Forma — SwiftData mapping between Coach timeline entity and domain model.
//

import Foundation

extension CoachTimelineEventEntity {

    convenience init(model: CoachTimelineEvent, userId: String?) {
        let now = Date()
        self.init(
            id: model.id,
            userId: userId,
            eventTypeRaw: model.type.rawValue,
            sourceRaw: model.source.rawValue,
            statusRaw: model.status.rawValue,
            confidenceRaw: model.confidence?.rawValue,
            sourceAttributionRaw: model.sourceAttribution.rawValue,
            utcCreatedAt: model.utcTimestamp,
            localCreatedAt: model.localTimestamp,
            localDate: model.localDate,
            timezoneIdentifier: model.timezoneIdentifier,
            summary: CoachTimelineEventSummaryBuilder.summary(for: model),
            payloadJSON: CoachTimelineEventPayloadCodec.encode(event: model),
            linkedEntryId: model.linkedEntryId,
            linkedMessageId: model.linkedMessageId,
            supersedesEventId: model.supersedesEventId,
            schemaVersion: Self.currentSchemaVersion,
            createdAt: model.recordedAt,
            updatedAt: now
        )
    }

    func toModel() -> CoachTimelineEvent {
        let decodedType = CoachTimelineEventTypeCodec.decode(eventTypeRaw)
        let decodedSource = CoachTimelineEventSourceCodec.decode(sourceRaw)
        let decodedStatus = CoachTimelineEventStatusCodec.decode(statusRaw)
        let decodedConfidence = CoachTimelineEventConfidenceCodec.decode(confidenceRaw)
        let decodedAttribution = CoachTimelineEventSourceAttributionCodec.decode(sourceAttributionRaw)

        let payloadResult = CoachTimelineEventPayloadCodec.decode(payloadJSON)
        let envelope: CoachTimelinePersistedEnvelope
        let resolvedSummary: String

        switch payloadResult {
        case .success(let decodedEnvelope):
            envelope = decodedEnvelope
            resolvedSummary = summary
        case .unknownPayload:
            envelope = CoachTimelinePersistedEnvelope(payload: .empty)
            resolvedSummary = CoachTimelineEventSummaryBuilder.summaryForUnknownPayload(
                eventTypeRaw: eventTypeRaw,
                existingSummary: summary
            )
        case .empty:
            envelope = CoachTimelinePersistedEnvelope(payload: .empty)
            resolvedSummary = summary.isEmpty
                ? CoachTimelineEventSummaryBuilder.summaryForUnknownPayload(
                    eventTypeRaw: eventTypeRaw,
                    existingSummary: ""
                )
                : summary
        }

        return CoachTimelineEvent(
            id: id,
            type: decodedType,
            source: decodedSource,
            sourceAttribution: decodedAttribution,
            confidence: decodedConfidence,
            status: decodedStatus,
            payload: envelope.payload,
            utcTimestamp: utcCreatedAt,
            localTimestamp: localCreatedAt,
            timezoneIdentifier: timezoneIdentifier,
            localDate: localDate,
            link: CoachTimelineEventLink(
                linkedEntryId: linkedEntryId,
                linkedMessageId: linkedMessageId,
                linkedPhotoSessionId: envelope.linkedPhotoSessionId,
                linkedDailyLogId: envelope.linkedDailyLogId,
                relatedEventIds: envelope.relatedEventIds
            ),
            supersedesEventId: supersedesEventId,
            recordedAt: createdAt
        )
    }

    func applySummaryAndPayload(from event: CoachTimelineEvent) {
        summary = CoachTimelineEventSummaryBuilder.summary(for: event)
        payloadJSON = CoachTimelineEventPayloadCodec.encode(event: event)
        updatedAt = Date()
    }
}
