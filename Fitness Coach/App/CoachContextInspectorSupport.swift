//
//  CoachContextInspectorSupport.swift
//  Fitness Coach
//
//  Forma — DEBUG-only Coach context inspection hooks for Settings developer tools.
//

#if DEBUG
import Foundation

struct CoachContextDebugActions: Sendable {
    var inspect: @Sendable () async -> CoachContextInspectionReport
    var runBackfill: @Sendable () async -> Void
    var clearDebugTimelineArtifacts: @Sendable () async throws -> Int
}

extension AppContainer {

    func makeCoachContextDebugActions() -> CoachContextDebugActions {
        CoachContextDebugActions(
            inspect: { [self] in
                await self.inspectCoachContextPacket()
            },
            runBackfill: { [self] in
                await self.coachTimelineBackfillService.runBackfill()
            },
            clearDebugTimelineArtifacts: { [self] in
                let localDate = CoachContextMeta.make(generatedAt: Date()).localDate
                return try await self.coachTimelineStore.deleteDebugArtifactEvents(forLocalDate: localDate)
            }
        )
    }

    func inspectCoachContextPacket() async -> CoachContextInspectionReport {
        let messages = coachChatTranscriptStore.loadMessages()
        let builder = makeCoachContextPacketBuilder()
        let packet = await builder.makeContext(recentMessages: messages, mode: .live)
        let validation = CoachContextCorrectnessValidator.validateAndCorrect(packet)
        let report = CoachContextInspector.buildReport(
            packet: validation.correctedPacket,
            validation: validation,
            preCompactionTimelineCount: packet.sourceAttribution?.timelineEventCount
        )
        CoachContextInspector.log(report)
        return report
    }

    private func makeCoachContextPacketBuilder() -> CoachContextPacketV2Builder {
        CoachContextPacketV2Builder(
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            userProfileService: userProfileService,
            healthActivityQuery: healthActivityQueryService,
            healthIntelligenceSnapshotProvider: healthIntelligenceSnapshotService,
            healthIntelligenceContextBuilder: healthIntelligenceContextBuilder,
            trainingLoadEngine: trainingLoadEngine,
            timelineStore: coachTimelineStore,
            timelineBackfillService: coachTimelineBackfillService,
            timelineRecorder: coachTimelineRecorder
        )
    }
}
#endif
