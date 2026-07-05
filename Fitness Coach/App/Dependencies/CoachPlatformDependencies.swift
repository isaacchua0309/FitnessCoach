//
//  CoachPlatformDependencies.swift
//  Fitness Coach
//
//  Typed Coach platform store bundle for AppContainer init-time wiring.
//  Feature assembly uses `CoachDependencies` in AppContainer+FeatureFactories.swift.
//

import Foundation

/// Resolved Coach timeline, transcript, backfill, and correction-memory infrastructure.
struct CoachPlatformDependencies {
    let coachTimelineStore: SwiftDataCoachTimelineStore
    let coachChatTranscriptStore: SwiftDataCoachChatTranscriptStore
    let coachTimelineBackfillService: CoachTimelineBackfillService
    let coachTimelineRecorder: DefaultCoachTimelineRecorder
    let foodCorrectionMemoryStore: FileFoodCorrectionMemoryStore

    /// Builds shared Coach platform dependencies for `AppContainer`.
    static func build(
        session: AuthDependencies,
        persistence: PersistenceDependencies,
        health: HealthDependencies
    ) -> CoachPlatformDependencies {
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

        return CoachPlatformDependencies(
            coachTimelineStore: coachTimelineStore,
            coachChatTranscriptStore: coachChatTranscriptStore,
            coachTimelineBackfillService: coachTimelineBackfillService,
            coachTimelineRecorder: coachTimelineRecorder,
            foodCorrectionMemoryStore: foodCorrectionMemoryStore
        )
    }
}
