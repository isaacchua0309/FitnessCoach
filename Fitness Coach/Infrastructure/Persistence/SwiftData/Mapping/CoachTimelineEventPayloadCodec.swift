//
//  CoachTimelineEventPayloadCodec.swift
//  Fitness Coach
//
//  Forma — Safe JSON encode/decode for persisted Coach timeline payloads.
//

import Foundation

/// JSON envelope stored in `CoachTimelineEventEntity.payloadJSON`.
struct CoachTimelinePersistedEnvelope: Codable, Equatable, Sendable {

    static let currentSchemaVersion = CoachTimelineEventEntity.currentSchemaVersion

    var schemaVersion: Int
    var payload: CoachTimelineEventPayload
    var linkedPhotoSessionId: UUID?
    var linkedDailyLogId: UUID?
    var relatedEventIds: [UUID]

    init(
        schemaVersion: Int = CoachTimelinePersistedEnvelope.currentSchemaVersion,
        payload: CoachTimelineEventPayload,
        linkedPhotoSessionId: UUID? = nil,
        linkedDailyLogId: UUID? = nil,
        relatedEventIds: [UUID] = []
    ) {
        self.schemaVersion = schemaVersion
        self.payload = payload
        self.linkedPhotoSessionId = linkedPhotoSessionId
        self.linkedDailyLogId = linkedDailyLogId
        self.relatedEventIds = relatedEventIds
    }

    init(event: CoachTimelineEvent) {
        self.init(
            payload: event.payload,
            linkedPhotoSessionId: event.link.linkedPhotoSessionId,
            linkedDailyLogId: event.link.linkedDailyLogId,
            relatedEventIds: event.link.relatedEventIds
        )
    }
}

enum CoachTimelinePayloadDecodeResult: Equatable, Sendable {
    case success(CoachTimelinePersistedEnvelope)
    case unknownPayload(rawJSON: String)
    case empty
}

enum CoachTimelineEventPayloadCodec {

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func encodeEnvelope(_ envelope: CoachTimelinePersistedEnvelope) -> String {
        guard let data = try? encoder.encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return fallbackJSON(for: envelope.payload)
        }
        return json
    }

    static func encode(event: CoachTimelineEvent) -> String {
        encodeEnvelope(CoachTimelinePersistedEnvelope(event: event))
    }

    static func decode(_ json: String) -> CoachTimelinePayloadDecodeResult {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        guard let data = trimmed.data(using: .utf8) else {
            return .unknownPayload(rawJSON: trimmed)
        }

        if let envelope = try? decoder.decode(CoachTimelinePersistedEnvelope.self, from: data) {
            return .success(sanitize(envelope))
        }

        if let payload = try? decoder.decode(CoachTimelineEventPayload.self, from: data) {
            return .success(
                CoachTimelinePersistedEnvelope(
                    payload: payload
                )
            )
        }

        return .unknownPayload(rawJSON: trimmed)
    }

    static func decodePayloadOnly(_ json: String) -> CoachTimelineEventPayload {
        switch decode(json) {
        case .success(let envelope):
            return envelope.payload
        case .unknownPayload, .empty:
            return .empty
        }
    }

    private static func sanitize(_ envelope: CoachTimelinePersistedEnvelope) -> CoachTimelinePersistedEnvelope {
        var next = envelope
        if next.schemaVersion > CoachTimelinePersistedEnvelope.currentSchemaVersion {
            next.schemaVersion = CoachTimelinePersistedEnvelope.currentSchemaVersion
        }
        return next
    }

    private static func fallbackJSON(for payload: CoachTimelineEventPayload) -> String {
        let envelope = CoachTimelinePersistedEnvelope(payload: payload)
        guard let data = try? encoder.encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"schemaVersion\":1,\"payload\":{\"kind\":\"empty\"}}"
        }
        return json
    }
}

enum CoachTimelineEventTypeCodec {

    static func decode(_ raw: String) -> CoachTimelineEventType {
        CoachTimelineEventType(rawValue: raw) ?? .unknown
    }
}

enum CoachTimelineEventSourceCodec {

    static func decode(_ raw: String) -> CoachTimelineEventSource {
        CoachTimelineEventSource(rawValue: raw) ?? .system
    }
}

enum CoachTimelineEventSourceAttributionCodec {

    static func decode(_ raw: String?) -> CoachTimelineEventSourceAttribution {
        guard let raw else { return .system }
        return CoachTimelineEventSourceAttribution(rawValue: raw) ?? .system
    }
}

enum CoachTimelineEventStatusCodec {

    static func decode(_ raw: String) -> CoachTimelineEventStatus {
        CoachTimelineEventStatus(rawValue: raw) ?? .failed
    }
}

enum CoachTimelineEventConfidenceCodec {

    static func decode(_ raw: String?) -> CoachTimelineEventConfidence? {
        guard let raw else { return nil }
        return CoachTimelineEventConfidence(rawValue: raw)
    }
}
