//
//  CoachAccuracyObservability.swift
//  Fitness Coach
//
//  Production-safe Coach accuracy telemetry — counts, buckets, and categories only.
//  Never logs raw user text, food names, image bytes, auth tokens, or full context JSON.
//

import Foundation
import OSLog

// MARK: - Metrics

struct CoachContextObservabilitySnapshot: Equatable, Sendable {
    var schemaVersion: Int
    var generationMode: String
    var sizeBucket: String
    var encodedByteCount: Int
    var timelineEventCount: Int
    var recentMealsCount: Int
    var commonFoodsCount: Int
    var missingDataFlagsCount: Int
    var healthIntelligencePresent: Bool
    var compactionOccurred: Bool
    var fallbackPacketUsed: Bool

    static func from(
        _ packet: CoachContextPacketV2,
        compactionOccurred: Bool = false,
        fallbackPacketUsed: Bool = false
    ) -> CoachContextObservabilitySnapshot {
        CoachContextObservabilitySnapshot(
            schemaVersion: packet.meta.schemaVersion,
            generationMode: packet.generationMode.rawValue,
            sizeBucket: CoachAccuracyObservabilityLogFormatter.sizeBucket(
                byteCount: packet.estimatedEncodedByteCount()
            ),
            encodedByteCount: packet.estimatedEncodedByteCount(),
            timelineEventCount: packet.timeline.recentEvents.count,
            recentMealsCount: packet.recentMealsStructured.count,
            commonFoodsCount: packet.commonFoods.count,
            missingDataFlagsCount: packet.missingData.missingSignalLabels.count,
            healthIntelligencePresent: packet.healthIntelligence != nil,
            compactionOccurred: compactionOccurred,
            fallbackPacketUsed: fallbackPacketUsed || packet.generationMode == .degraded
        )
    }
}

struct CoachRouteObservabilitySnapshot: Equatable, Sendable {
    var routeSelected: String
    var routeSource: String
    var classifierIntent: String?
    var classifierConfidence: String?
    var modelTier: String?
    var requiresAPI: Bool
    var messageLength: Int
}

struct CoachEndpointObservabilitySnapshot: Equatable, Sendable {
    var endpoint: String
    var validationSuccess: Bool?
    var backendErrorCategory: String?
    var durationMs: Int?
}

struct CoachMutationObservabilitySnapshot: Equatable, Sendable {
    var mutationKind: String
    var success: Bool
    var backendErrorCategory: String?
}

// MARK: - Formatter

enum CoachAccuracyObservabilityLogFormatter {

    static func sizeBucket(byteCount: Int) -> String {
        switch byteCount {
        case ..<4_096: return "<4k"
        case 4_096..<8_192: return "4k-8k"
        case 8_192..<16_384: return "8k-16k"
        case 16_384..<24_576: return "16k-24k"
        default: return ">24k"
        }
    }

    static func fields(from snapshot: CoachContextObservabilitySnapshot) -> [String: String] {
        [
            "contextSchemaVersion": String(snapshot.schemaVersion),
            "contextGenerationMode": snapshot.generationMode,
            "contextSizeBucket": snapshot.sizeBucket,
            "contextEncodedBytes": String(snapshot.encodedByteCount),
            "timelineEventCount": String(snapshot.timelineEventCount),
            "recentMealsCount": String(snapshot.recentMealsCount),
            "commonFoodsCount": String(snapshot.commonFoodsCount),
            "missingDataFlagsCount": String(snapshot.missingDataFlagsCount),
            "healthIntelligencePresent": String(snapshot.healthIntelligencePresent),
            "compactionOccurred": String(snapshot.compactionOccurred),
            "fallbackPacketUsed": String(snapshot.fallbackPacketUsed),
        ]
    }

    static func fields(from snapshot: CoachRouteObservabilitySnapshot) -> [String: String] {
        var fields: [String: String] = [
            "routeSelected": snapshot.routeSelected,
            "routeSource": snapshot.routeSource,
            "requiresAPI": String(snapshot.requiresAPI),
            "messageLength": String(snapshot.messageLength),
        ]
        if let classifierIntent = snapshot.classifierIntent {
            fields["classifierIntent"] = classifierIntent
        }
        if let classifierConfidence = snapshot.classifierConfidence {
            fields["classifierConfidence"] = classifierConfidence
        }
        if let modelTier = snapshot.modelTier {
            fields["modelTier"] = modelTier
        }
        return fields
    }

    static func fields(from snapshot: CoachEndpointObservabilitySnapshot) -> [String: String] {
        var fields: [String: String] = ["endpoint": snapshot.endpoint]
        if let validationSuccess = snapshot.validationSuccess {
            fields["responseValidationSuccess"] = String(validationSuccess)
        }
        if let backendErrorCategory = snapshot.backendErrorCategory {
            fields["backendErrorCategory"] = backendErrorCategory
        }
        if let durationMs = snapshot.durationMs {
            fields["durationMs"] = String(durationMs)
        }
        return fields
    }

    static func fields(from snapshot: CoachMutationObservabilitySnapshot) -> [String: String] {
        var fields: [String: String] = [
            "mutationKind": snapshot.mutationKind,
            "mutationSuccess": String(snapshot.success),
        ]
        if let backendErrorCategory = snapshot.backendErrorCategory {
            fields["backendErrorCategory"] = backendErrorCategory
        }
        return fields
    }

    static func fields(pendingConfirmationCreated kind: String) -> [String: String] {
        [
            "pendingConfirmationCreated": "true",
            "pendingConfirmationKind": kind,
        ]
    }

    /// Redacts JSON snippets for DEBUG traces — strips tokens, images, user text, and context payloads.
    static func redactSensitiveJSONFields(_ raw: String) -> String {
        var sanitized = CoachImageAnalysisDebugLogFormatter.redactSensitiveJSONFields(raw)
        sanitized = sanitized.replacingOccurrences(
            of: #""imageJPEGBase64"\s*:\s*"[^"]*""#,
            with: "\"imageJPEGBase64\":\"<redacted>\"",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #""context"\s*:\s*\{[\s\S]*?\}(?=,\s*"|\s*\})"#,
            with: "\"context\":\"<redacted>\"",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #""text"\s*:\s*"[^"]*""#,
            with: "\"text\":\"<redacted>\"",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #""name"\s*:\s*"[^"]*""#,
            with: "\"name\":\"<redacted>\"",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #""summary"\s*:\s*"[^"]*""#,
            with: "\"summary\":\"<redacted>\"",
            options: .regularExpression
        )
        return sanitized
    }

    /// Privacy-safe production log line — never includes raw user content.
    static func productionLogLine(event: String, fields: [String: String]) -> String {
        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        return "event=\(event) \(fieldLine)"
    }
}

// MARK: - Logger

enum CoachAccuracyObservabilityLogger {

    private static let logger = Logger(subsystem: "Forma", category: "CoachAccuracy")

    static func logContextGenerated(
        _ packet: CoachContextPacketV2,
        compactionOccurred: Bool = false,
        fallbackPacketUsed: Bool = false
    ) {
        let snapshot = CoachContextObservabilitySnapshot.from(
            packet,
            compactionOccurred: compactionOccurred,
            fallbackPacketUsed: fallbackPacketUsed
        )
        emit(event: "context_generated", fields: CoachAccuracyObservabilityLogFormatter.fields(from: snapshot))
        #if DEBUG
        FormaPipelineTracer.event(
            stage: .context,
            level: .info,
            message: "Coach context observability",
            fields: CoachAccuracyObservabilityLogFormatter.fields(from: snapshot)
                .merging(["contextSummary": packet.redactedDebugDescription()]) { _, new in new }
        )
        #endif
    }

    static func logRoute(
        decision: CoachRouteDecision,
        intentResult: CoachIntentResult? = nil
    ) {
        let snapshot = CoachRouteObservabilitySnapshot(
            routeSelected: decision.chosenHandler,
            routeSource: decision.routeSource.rawValue,
            classifierIntent: intentResult?.intent.rawValue ?? decision.intent?.rawValue,
            classifierConfidence: intentResult.map { String(format: "%.2f", $0.confidence) },
            modelTier: decision.modelTier?.rawValue,
            requiresAPI: decision.requiresAPI,
            messageLength: decision.rawMessage.count
        )
        emit(event: "route_selected", fields: CoachAccuracyObservabilityLogFormatter.fields(from: snapshot))
        #if DEBUG
        FormaPipelineTracer.event(
            stage: .routeDecision,
            level: .debug,
            message: "Route observability",
            fields: CoachAccuracyObservabilityLogFormatter.fields(from: snapshot)
        )
        #endif
    }

    static func logEndpoint(_ snapshot: CoachEndpointObservabilitySnapshot) {
        emit(event: "endpoint_called", fields: CoachAccuracyObservabilityLogFormatter.fields(from: snapshot))
        #if DEBUG
        FormaPipelineTracer.event(
            stage: .aiTask,
            level: snapshot.validationSuccess == false ? .warn : .info,
            message: "Endpoint observability",
            fields: CoachAccuracyObservabilityLogFormatter.fields(from: snapshot)
        )
        #endif
    }

    static func logMutation(_ snapshot: CoachMutationObservabilitySnapshot) {
        emit(event: "mutation_executed", fields: CoachAccuracyObservabilityLogFormatter.fields(from: snapshot))
        #if DEBUG
        FormaPipelineTracer.event(
            stage: .aiTask,
            level: snapshot.success ? .info : .warn,
            message: "Mutation observability",
            fields: CoachAccuracyObservabilityLogFormatter.fields(from: snapshot)
        )
        #endif
    }

    static func logPendingConfirmationCreated(kind: String) {
        let fields = CoachAccuracyObservabilityLogFormatter.fields(pendingConfirmationCreated: kind)
        emit(event: "pending_confirmation_created", fields: fields)
        #if DEBUG
        FormaPipelineTracer.event(
            stage: .aiTask,
            level: .info,
            message: "Pending confirmation observability",
            fields: fields
        )
        #endif
    }

    // MARK: - Private

    private static func emit(event: String, fields: [String: String]) {
        let line = CoachAccuracyObservabilityLogFormatter.productionLogLine(event: event, fields: fields)
        logger.info("\(line, privacy: .public)")
    }
}
