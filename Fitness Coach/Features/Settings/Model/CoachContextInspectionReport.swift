//
//  CoachContextInspectionReport.swift
//  Fitness Coach
//
//  Forma — DEBUG-only safe summary of an assembled CoachContextPacketV2.
//

#if DEBUG
import Foundation

struct CoachContextInspectionReport: Equatable, Sendable {
    let schemaVersion: Int
    let generationMode: String
    let localDate: String
    let timezoneIdentifier: String
    let estimatedByteCount: Int
    let timelineEventCount: Int
    let compactedTimelineEventCount: Int
    let recentMealsStructuredCount: Int
    let commonFoodsCount: Int
    let missingDataLabels: [String]
    let stepsSource: String?
    let stepsAsOfDescription: String?
    let workoutsToday: Int?
    let recoveryStatus: String?
    let trainingLoad: String?
    let lastEventSummaries: [String]
    let validationWarnings: [String]
    let isDegraded: Bool
    let coachContextV2TransportOnly: Bool
    let redactedJSON: String
    let compactSummary: String
    let errorMessage: String?

    static func failure(_ message: String) -> CoachContextInspectionReport {
        CoachContextInspectionReport(
            schemaVersion: CoachContextPacketV2.schemaVersion,
            generationMode: "unknown",
            localDate: "—",
            timezoneIdentifier: "—",
            estimatedByteCount: 0,
            timelineEventCount: 0,
            compactedTimelineEventCount: 0,
            recentMealsStructuredCount: 0,
            commonFoodsCount: 0,
            missingDataLabels: [],
            stepsSource: nil,
            stepsAsOfDescription: nil,
            workoutsToday: nil,
            recoveryStatus: nil,
            trainingLoad: nil,
            lastEventSummaries: [],
            validationWarnings: [],
            isDegraded: false,
            coachContextV2TransportOnly: true,
            redactedJSON: "{}",
            compactSummary: "Inspection failed.",
            errorMessage: message
        )
    }
}

enum CoachContextInspector {

    static func buildReport(
        packet: CoachContextPacketV2,
        validation: CoachContextValidationResult,
        preCompactionTimelineCount: Int? = nil
    ) -> CoachContextInspectionReport {
        let corrected = validation.correctedPacket
        let beforeCompact = preCompactionTimelineCount ?? corrected.sourceAttribution?.timelineEventCount ?? corrected.timeline.recentEvents.count
        let afterCompact = corrected.timeline.recentEvents.count

        let redactedJSON = (try? CoachContextPacketV2DebugRedactor.redactedJSONString(from: corrected)) ?? "{}"
        let compactSummary = corrected.redactedDebugDescription()

        let warnings = validation.issues.map { issue in
            "[\(issue.rule.rawValue)] \(issue.message)"
        }

        let summaries = corrected.timeline.recentEvents
            .suffix(10)
            .map { event in
                let linked = event.linkedEntryId.map { " linked=\($0.uuidString.prefix(8))" } ?? ""
                return "\(event.type): \(truncate(event.summary, maxLength: 80))\(linked)"
            }

        return CoachContextInspectionReport(
            schemaVersion: corrected.meta.schemaVersion,
            generationMode: corrected.generationMode.rawValue,
            localDate: corrected.meta.localDate,
            timezoneIdentifier: corrected.meta.timezoneIdentifier,
            estimatedByteCount: corrected.estimatedEncodedByteCount(),
            timelineEventCount: beforeCompact,
            compactedTimelineEventCount: afterCompact,
            recentMealsStructuredCount: corrected.recentMealsStructured.count,
            commonFoodsCount: corrected.commonFoods.count,
            missingDataLabels: corrected.missingData.missingSignalLabels,
            stepsSource: corrected.today?.steps?.source,
            stepsAsOfDescription: corrected.today?.steps?.asOf.map(formatTimestamp),
            workoutsToday: corrected.training?.workoutsToday,
            recoveryStatus: corrected.training?.recoveryStatus ?? corrected.healthIntelligence?.recoveryStatus,
            trainingLoad: corrected.training?.trainingLoad ?? corrected.healthIntelligence?.trainingLoadStatus,
            lastEventSummaries: summaries,
            validationWarnings: warnings,
            isDegraded: corrected.generationMode == .degraded,
            coachContextV2TransportOnly: true,
            redactedJSON: redactedJSON,
            compactSummary: compactSummary,
            errorMessage: nil
        )
    }

    static func log(_ report: CoachContextInspectionReport) {
        FormaPipelineTracer.event(
            stage: .context,
            level: .info,
            message: "CoachContextPacketV2 debug inspection",
            fields: [
                "schemaVersion": String(report.schemaVersion),
                "generationMode": report.generationMode,
                "localDate": report.localDate,
                "bytes": String(report.estimatedByteCount),
                "timelineEvents": String(report.timelineEventCount),
                "compactedTimelineEvents": String(report.compactedTimelineEventCount),
                "meals": String(report.recentMealsStructuredCount),
                "missing": report.missingDataLabels.joined(separator: ","),
                "degraded": String(report.isDegraded),
                "validationWarnings": String(report.validationWarnings.count),
                "summary": report.compactSummary
            ]
        )
    }

    private static func formatTimestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func truncate(_ value: String, maxLength: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]) + "…"
    }
}
#endif
