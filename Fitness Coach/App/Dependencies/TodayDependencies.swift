//
//  TodayDependencies.swift
//  Fitness Coach
//
//  ReviewService and FitnessActionCenter construction for AppContainer.
//  See Docs/Architecture/DependencyInjectionMap.md
//

import Foundation

extension AppContainer {

    struct TodayDependenciesBundle {
        let reviewService: ReviewService
        let actionCenter: FitnessActionCenter
    }

    static func buildTodayDependencies(
        auth: AuthDependenciesBundle,
        persistence: PersistenceDependenciesBundle,
        health: HealthBundle,
        ai: AIBundle,
        refreshCenter: AppRefreshCenter
    ) -> TodayDependenciesBundle {
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

        return TodayDependenciesBundle(
            reviewService: reviewService,
            actionCenter: actionCenter
        )
    }
}
