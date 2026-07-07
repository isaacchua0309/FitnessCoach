//
//  TodayDependencies.swift
//  Fitness Coach
//
//  Typed Today tab shared action surface for AppContainer wiring.
//

import Foundation

/// Resolved review and action-center dependencies for `AppContainer`.
struct TodayDependencies {
    let reviewService: ReviewService
    let actionCenter: FitnessActionCenter

    static func build(
        auth: AuthDependencies,
        persistence: PersistenceDependencies,
        health: HealthDependencies,
        ai: AIDependencies,
        refreshCenter: AppRefreshCenter
    ) -> TodayDependencies {
        let reviewService = ReviewService(
            store: persistence.store,
            dailyLogService: persistence.dailyLogService,
            foodLogService: persistence.foodLogService,
            waterLogService: persistence.waterLogService,
            weightLogService: persistence.weightLogService,
            healthActivityQuery: health.healthActivityQueryService,
            userProfileService: persistence.userProfileService,
            aiService: ai.aiService,
            mutationTracker: persistence.accountLocalMutationTracker
        )

        let actionCenter = FitnessActionCenter(
            foodLogService: persistence.foodLogService,
            waterLogService: persistence.waterLogService,
            weightLogService: persistence.weightLogService,
            dailyLogService: persistence.dailyLogService,
            targetService: persistence.targetService,
            userProfileService: persistence.userProfileService,
            reviewService: reviewService,
            refreshCenter: refreshCenter,
            profileBootstrapService: persistence.profileBootstrapService,
            cloudUploadFailureNotifier: persistence.cloudUploadFailureNotifier,
            currentUIDProvider: { [authManager = auth.authManager] in authManager.currentUID },
            scheduleAccountSyncAfterMutation: { [authManager = auth.authManager, accountSyncCoordinator = persistence.accountSyncCoordinator] in
                AccountSyncLifecycle.scheduleAfterLocalMutation(
                    coordinator: accountSyncCoordinator,
                    uidProvider: { authManager.currentUID }
                )
            }
        )

        return TodayDependencies(
            reviewService: reviewService,
            actionCenter: actionCenter
        )
    }
}
