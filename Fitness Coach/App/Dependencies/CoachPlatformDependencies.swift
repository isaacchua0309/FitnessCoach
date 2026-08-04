//
//  CoachPlatformDependencies.swift
//  Fitness Coach
//
//  Coach platform persistence construction for AppContainer.
//  See Docs/Architecture/DependencyInjectionMap.md
//
//  Note: distinct from `Features/Coach/Model/CoachDependencies` (feature assembly).
//  Filename must stay unique in the target (avoids CoachDependencies.stringsdata clash).
//

import Foundation

extension AppContainer {

    struct CoachDependenciesBundle {
        let coachTimelineStore: SwiftDataCoachTimelineStore
        let coachChatTranscriptStore: SwiftDataCoachChatTranscriptStore
        let coachTimelineBackfillService: CoachTimelineBackfillService
        let coachTimelineRecorder: DefaultCoachTimelineRecorder
        let foodCorrectionMemoryStore: FileFoodCorrectionMemoryStore
    }

    static func buildCoachDependencies(
        session: AuthDependenciesBundle,
        persistence: PersistenceDependenciesBundle,
        health: HealthBundle
    ) -> CoachDependenciesBundle {
        let authManager = session.authManager
        let coachTimelineStore = SwiftDataCoachTimelineStore(
            store: persistence.store,
            userIdProvider: { [weak authManager] in authManager?.currentUID }
        )
        let coachChatTranscriptStore = SwiftDataCoachChatTranscriptStore(
            store: persistence.store,
            userIdProvider: { [weak authManager] in authManager?.currentUID }
        )
        let coachTimelineBackfillService = CoachTimelineBackfillService(
            timelineStore: coachTimelineStore,
            foodLogService: persistence.foodLogService,
            waterLogService: persistence.waterLogService,
            weightLogService: persistence.weightLogService,
            healthActivityQuery: health.healthActivityQueryService
        )
        let coachTimelineRecorder = DefaultCoachTimelineRecorder(store: coachTimelineStore)
        let foodCorrectionMemoryStore = FileFoodCorrectionMemoryStore(
            userIdProvider: { [weak authManager] in authManager?.currentUID }
        )

        Task { @MainActor [coachTimelineBackfillService] in
            await coachTimelineBackfillService.runBackfill()
        }

        return CoachDependenciesBundle(
            coachTimelineStore: coachTimelineStore,
            coachChatTranscriptStore: coachChatTranscriptStore,
            coachTimelineBackfillService: coachTimelineBackfillService,
            coachTimelineRecorder: coachTimelineRecorder,
            foodCorrectionMemoryStore: foodCorrectionMemoryStore
        )
    }
}
