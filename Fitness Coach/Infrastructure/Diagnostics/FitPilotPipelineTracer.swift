//
//  FitPilotPipelineTracer.swift
//  Fitness Coach
//
//  DEBUG-only correlated tracing for the Coach AI pipeline.
//

import Foundation
import OSLog

// MARK: - Shared types (visible to diagnostics UI in DEBUG)

enum PipelineTraceStage: String, Sendable, CaseIterable {
    case appWiring
    case coachSend
    case coachEnd
    case context
    case localGuard
    case classify
    case classifyDedup
    case routeDecision
    case intentRoute
    case aiTask
    case httpRequest
    case httpResponse
    case authToken
    case mockLLM
    case error
}

enum PipelineTraceLevel: String, Sendable, CaseIterable {
    case debug
    case info
    case warn
    case error
}

struct PipelineTraceEvent: Identifiable, Sendable, Equatable {
    let id: UUID
    let traceId: UUID
    let timestamp: Date
    let stage: PipelineTraceStage
    let level: PipelineTraceLevel
    let message: String
    let fields: [String: String]
}

struct PipelineTraceSummary: Identifiable, Sendable, Equatable {
    let traceId: UUID
    let userMessage: String
    let startedAt: Date
    var endedAt: Date?
    var outcome: String?
    var hasError: Bool

    var id: UUID { traceId }
}

#if DEBUG

@MainActor
enum FitPilotPipelineTracer {

    static let traceHeaderName = "X-FitPilot-Trace-Id"
    private static let maxEvents = 300
    private static let maxPersistedErrors = 50
    private static let logger = Logger(subsystem: "FitPilot", category: "PipelineTrace")

    private static var events: [PipelineTraceEvent] = []
    private static var summaries: [UUID: PipelineTraceSummary] = [:]
    private static var traceStartTimes: [UUID: Date] = [:]
    private static var activeTraceId: UUID?

    static var debugRecordHandler: ((DebugRecord) -> Void)?

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_PIPELINE_TRACE"] != "0"
    }

    static var isVerbose: Bool {
        ProcessInfo.processInfo.environment["FITPILOT_PIPELINE_TRACE_VERBOSE"] == "1"
    }

    static var usesExtendedHTTPTimeout: Bool {
        isEnabled
    }

    static var currentTraceId: UUID? {
        activeTraceId
    }

    static var recentEvents: [PipelineTraceEvent] {
        events
    }

    static var recentSummaries: [PipelineTraceSummary] {
        summaries.values.sorted { $0.startedAt > $1.startedAt }
    }

    static func events(for traceId: UUID) -> [PipelineTraceEvent] {
        events.filter { $0.traceId == traceId }.sorted { $0.timestamp < $1.timestamp }
    }

    static func clear() {
        events.removeAll()
        summaries.removeAll()
        traceStartTimes.removeAll()
        activeTraceId = nil
    }

    @discardableResult
    static func beginTrace(userMessage: String) -> UUID {
        guard isEnabled else { return UUID() }

        let traceId = UUID()
        activeTraceId = traceId
        let now = Date()
        traceStartTimes[traceId] = now
        summaries[traceId] = PipelineTraceSummary(
            traceId: traceId,
            userMessage: userMessage,
            startedAt: now,
            endedAt: nil,
            outcome: nil,
            hasError: false
        )

        record(
            traceId: traceId,
            stage: .coachSend,
            level: .info,
            message: "Coach message send started",
            fields: ["userMessage": userMessage]
        )
        return traceId
    }

    static func endTrace(traceId: UUID, outcome: String, durationMs: Int? = nil) {
        guard isEnabled else { return }

        var fields = ["outcome": outcome]
        if let durationMs {
            fields["durationMs"] = String(durationMs)
        } else if let started = traceStartTimes[traceId] {
            fields["durationMs"] = String(Int(Date().timeIntervalSince(started) * 1_000))
        }

        if var summary = summaries[traceId] {
            summary.endedAt = Date()
            summary.outcome = outcome
            summaries[traceId] = summary
        }

        record(
            traceId: traceId,
            stage: .coachEnd,
            level: .info,
            message: "Coach message completed",
            fields: fields
        )
        if activeTraceId == traceId {
            activeTraceId = nil
        }
        traceStartTimes.removeValue(forKey: traceId)
    }

    static func event(
        traceId: UUID? = nil,
        stage: PipelineTraceStage,
        level: PipelineTraceLevel = .info,
        message: String,
        fields: [String: String] = [:]
    ) {
        guard isEnabled else { return }
        let resolvedTraceId = traceId ?? activeTraceId ?? UUID()
        record(traceId: resolvedTraceId, stage: stage, level: level, message: message, fields: fields)
    }

    static func logError(
        traceId: UUID? = nil,
        stage: PipelineTraceStage,
        message: String,
        fields: [String: String] = [:]
    ) {
        guard isEnabled else { return }
        let resolvedTraceId = traceId ?? activeTraceId ?? UUID()

        if var summary = summaries[resolvedTraceId] {
            summary.hasError = true
            summaries[resolvedTraceId] = summary
        }

        var merged = fields
        merged["stage"] = stage.rawValue
        record(
            traceId: resolvedTraceId,
            stage: .error,
            level: .error,
            message: message,
            fields: merged
        )

        persistErrorIfNeeded(traceId: resolvedTraceId, stage: stage, message: message, fields: merged)
    }

    static func exportTrace(traceId: UUID) -> String {
        let summary = summaries[traceId]
        var lines: [String] = []
        if let summary {
            lines.append("traceId=\(summary.traceId.uuidString)")
            lines.append("userMessage=\(summary.userMessage)")
            lines.append("startedAt=\(summary.startedAt)")
            if let endedAt = summary.endedAt {
                lines.append("endedAt=\(endedAt)")
            }
            if let outcome = summary.outcome {
                lines.append("outcome=\(outcome)")
            }
            lines.append("hasError=\(summary.hasError)")
            lines.append("")
        }
        for event in events(for: traceId) {
            let fieldText = event.fields
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            lines.append(
                "[\(event.timestamp)] \(event.stage.rawValue) \(event.level.rawValue) \(event.message) \(fieldText)"
            )
        }
        return lines.joined(separator: "\n")
    }

    static func sanitizedJSONSnippet(_ data: Data) -> String? {
        guard isVerbose else { return nil }
        let limit = 2_048
        let raw = String(data: data.prefix(limit), encoding: .utf8) ?? "<non-utf8>"
        let sanitized = raw
            .replacingOccurrences(of: #"Bearer\s+\S+"#, with: "Bearer <redacted>", options: .regularExpression)
            .replacingOccurrences(of: #""Authorization"\s*:\s*"[^"]*""#, with: "\"Authorization\":\"<redacted>\"", options: .regularExpression)
        if data.count > limit {
            return sanitized + "…(truncated)"
        }
        return sanitized
    }

    // MARK: - Private

    private static func record(
        traceId: UUID,
        stage: PipelineTraceStage,
        level: PipelineTraceLevel,
        message: String,
        fields: [String: String]
    ) {
        let event = PipelineTraceEvent(
            id: UUID(),
            traceId: traceId,
            timestamp: Date(),
            stage: stage,
            level: level,
            message: message,
            fields: fields
        )
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }

        NotificationCenter.default.post(name: .pipelineTraceDidUpdate, object: nil)

        let fieldLine = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\( $0.value)" }
            .joined(separator: " ")
        let logLine = "traceId=\(traceId.uuidString) stage=\(stage.rawValue) level=\(level.rawValue) \(message) \(fieldLine)"

        switch level {
        case .debug:
            logger.debug("\(logLine, privacy: .public)")
        case .info:
            logger.info("\(logLine, privacy: .public)")
        case .warn:
            logger.warning("\(logLine, privacy: .public)")
        case .error:
            logger.error("\(logLine, privacy: .public)")
        }
    }

    private static func persistErrorIfNeeded(
        traceId: UUID,
        stage: PipelineTraceStage,
        message: String,
        fields: [String: String]
    ) {
        guard stage == .httpResponse || stage == .classify || stage == .aiTask || stage == .error else {
            return
        }
        guard let handler = debugRecordHandler else { return }

        var context = fields
        context["traceId"] = traceId.uuidString
        context["stage"] = stage.rawValue

        let record = DebugRecord(
            id: UUID(),
            category: .aiParsingFailure,
            message: message,
            context: context,
            createdAt: Date()
        )
        handler(record)
    }
}

#else

enum FitPilotPipelineTracer {
    static let traceHeaderName = "X-FitPilot-Trace-Id"
    static var isEnabled: Bool { false }
    static var isVerbose: Bool { false }
    static var usesExtendedHTTPTimeout: Bool { false }
    static var currentTraceId: UUID? { nil }

    @discardableResult
    static func beginTrace(userMessage: String) -> UUID { UUID() }
    static func endTrace(traceId: UUID, outcome: String, durationMs: Int? = nil) {}
    static func event(
        traceId: UUID? = nil,
        stage: PipelineTraceStage,
        level: PipelineTraceLevel = .info,
        message: String,
        fields: [String: String] = [:]
    ) {}
    static func logError(
        traceId: UUID? = nil,
        stage: PipelineTraceStage,
        message: String,
        fields: [String: String] = [:]
    ) {}
    static func sanitizedJSONSnippet(_ data: Data) -> String? { nil }
    static func exportTrace(traceId: UUID) -> String { "" }
    static func clear() {}
}

#endif

extension Notification.Name {
    static let pipelineTraceDidUpdate = Notification.Name("FitPilotPipelineTraceDidUpdate")
}
