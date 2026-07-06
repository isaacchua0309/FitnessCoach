//
//  RestoreAwareTestSupport.swift
//  Fitness CoachTests
//

import Foundation
import XCTest
@testable import Fitness_Coach

@MainActor
final class StubAccountLocalDataInspector: AccountLocalDataInspecting {
    let isEffectivelyEmpty: Bool

    init(isEffectivelyEmpty: Bool) {
        self.isEffectivelyEmpty = isEffectivelyEmpty
    }

    func inspectLocalData(for uid: String) async throws -> AccountLocalDataStatus {
        AccountLocalDataStatus(
            uid: uid,
            hasProfile: true,
            hasAnyDailyLogs: !isEffectivelyEmpty,
            hasTodayDailyLog: !isEffectivelyEmpty,
            foodEntryCount: isEffectivelyEmpty ? 0 : 1,
            waterEntryCount: 0,
            weightEntryCount: 0,
            dailyReviewCount: 0,
            pendingMutationCount: 0,
            failedMutationCount: 0,
            newestLocalUpdatedAt: nil,
            oldestLocalDate: nil,
            newestLocalDate: nil,
            isEffectivelyEmpty: isEffectivelyEmpty,
            needsInitialRestore: isEffectivelyEmpty
        )
    }
}

enum RestoreAwareTestSupport {

    static let ownerUID = "test-user-1"

    static func makeRestoreSummary(
        uid: String = ownerUID,
        status: AccountRestoreStatus,
        mode: AccountRestoreMode = .blockingInitial
    ) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: .afterSignIn,
            mode: mode,
            status: status,
            startedAt: ProfileFixtures.referenceDate,
            endedAt: ProfileFixtures.referenceDate,
            profileRestored: true,
            dailyLogsRestored: status == .completed ? 1 : 0,
            foodEntriesRestored: status == .completed ? 1 : 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: status == .partial ? 1 : 0,
            isPartial: status == .partial,
            userFacingMessage: nil
        )
    }

    @MainActor
    static func makeTodayHydrationContext(
        harness: FitnessActionCenterTestSupport.Harness,
        ownerUID: String = ownerUID
    ) throws -> TodayHydrationContext {
        try XCTUnwrap(
            TodayHydrationGate.resolve(
                authState: .signedIn(uid: ownerUID),
                profile: try harness.profileService.getCurrentProfile(),
                calendar: Calendar.current,
                now: harness.today
            ),
            "Expected signed-in hydration context"
        )
    }

    @MainActor
    static func makeTodayModel(
        harness: FitnessActionCenterTestSupport.Harness,
        session: AccountRestoreSessionState,
        isEffectivelyEmpty: Bool,
        ownerUID: String = ownerUID
    ) throws -> TodayModel {
        let context = try makeTodayHydrationContext(harness: harness, ownerUID: ownerUID)
        return TodayModel(
            dailyLogReader: harness.dailyLogService,
            foodLogReader: harness.base.foodLogService,
            weightLogReader: harness.weightLogService,
            dailyReviewReader: makeReviewService(harness: harness),
            userProfileReader: harness.profileService,
            healthActivityQuery: harness.healthActivityQuery,
            hydrationContextProvider: { context },
            authStateProvider: { .signedIn(uid: ownerUID) },
            restoreSessionState: session,
            localDataInspector: StubAccountLocalDataInspector(isEffectivelyEmpty: isEffectivelyEmpty),
            ownerUIDProvider: { ownerUID }
        )
    }

    @MainActor
    static func makeJourneyModel(
        harness: FitnessActionCenterTestSupport.Harness,
        session: AccountRestoreSessionState,
        isEffectivelyEmpty: Bool,
        ownerUID: String = ownerUID
    ) -> JourneyModel {
        let trainingStore = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: .notConnected)
        )
        return JourneyModel(
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            userProfileReader: harness.profileService,
            trainingInsightsStore: trainingStore,
            restoreSessionState: session,
            localDataInspector: StubAccountLocalDataInspector(isEffectivelyEmpty: isEffectivelyEmpty),
            ownerUIDProvider: { ownerUID }
        )
    }

    @MainActor
    static func makePlanModel(harness: FitnessActionCenterTestSupport.Harness) -> PlanModel {
        PlanModel(
            actionCenter: harness.actionCenter,
            userProfileReader: harness.profileService,
            planTargetCalculator: harness.targetService,
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            trainingInsightsStore: TrainingInsightsStore(
                integration: StubTrainingIntegrationProvider(refreshResult: .notConnected)
            ),
            healthBaselineService: StubHealthBaselineProvider(),
            healthIntelligenceLoadEnabled: { false }
        )
    }

    @MainActor
    private static func makeReviewService(
        harness: FitnessActionCenterTestSupport.Harness
    ) -> ReviewService {
        ReviewService(
            store: harness.store,
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.base.foodLogService,
            waterLogService: harness.base.waterLogService,
            weightLogService: harness.weightLogService,
            healthActivityQuery: harness.healthActivityQuery,
            userProfileService: harness.profileService,
            aiService: AIService(llmClient: MockLLMClient()),
            mutationTracker: harness.base.accountLocalMutationTracker
        )
    }
}
