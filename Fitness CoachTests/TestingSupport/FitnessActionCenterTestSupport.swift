//
//  FitnessActionCenterTestSupport.swift
//  Fitness CoachTests
//
//  In-memory harness for FitnessActionCenter mutation tests (no Firebase / HealthKit / OpenAI).
//

import Foundation
@testable import Fitness_Coach

@MainActor
enum FitnessActionCenterTestSupport {

    @MainActor
    struct Harness {
        let base: DailyLogServiceTestSupport.Harness
        let weightLogService: WeightLogService
        let targetService: TargetService
        let refreshCenter: AppRefreshCenter
        let cloudStore: MockCloudUserProfileStore
        let profileBootstrapService: ProfileBootstrapService
        let syncStore: ProfileCloudSyncStore
        let cloudUploadFailureNotifier: ProfileCloudUploadFailureNotifier
        let healthActivityQuery: HealthActivityQueryService
        let actionCenter: FitnessActionCenter
        let cloudUID: String?

        var store: SwiftDataStore { base.store }
        var profileService: UserProfileService { base.profileService }
        var dailyLogService: DailyLogService { base.dailyLogService }
        var today: Date { base.today }

        @discardableResult
        func seedProfile(
            targets: UserTargets = ProfileTestFixtures.sampleTargets,
            ownerUID: String? = nil
        ) throws -> UserProfile {
            let profile = try base.seedProfile(targets: targets)
            let resolvedOwner = ownerUID ?? cloudUID
            if let resolvedOwner {
                return try profileService.assignOwnerUID(resolvedOwner)
            }
            return profile
        }

        func waitForCloudSave(maxYields: Int = 100) async {
            _ = await AsyncTestSupport.waitUntil(maxYields: maxYields) {
                cloudStore.saveCallCount > 0
            }
        }

        func waitForPendingCloudWork(maxYields: Int = 80) async {
            await AsyncTestSupport.drainMainActorTasks(maxYields: maxYields)
        }
    }

    static func makeHarness(
        referenceNow: Date = DailyLogServiceTestSupport.referenceNow,
        cloudUID: String? = "test-user-1"
    ) throws -> Harness {
        let base = try DailyLogServiceTestSupport.makeHarness(referenceNow: referenceNow)
        let weightLogService = WeightLogService(
            store: base.store,
            dailyLogService: base.dailyLogService,
            dateProvider: base.dateProvider
        )
        let targetService = TargetService(
            userProfileService: base.profileService,
            dailyLogService: base.dailyLogService
        )
        let refreshCenter = AppRefreshCenter(now: referenceNow)
        let cloudStore = MockCloudUserProfileStore()
        let syncStore = ProfileCloudSyncStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let profileBootstrapService = ProfileBootstrapService(
            userProfileService: base.profileService,
            cloudStore: cloudStore,
            cloudSyncStore: syncStore
        )
        let cloudUploadFailureNotifier = ProfileCloudUploadFailureNotifier(syncStore: syncStore)
        let healthActivityQuery = HealthActivityQueryService(
            workoutReader: MockHealthKitWorkoutReader(workouts: []),
            stepReader: MockHealthKitStepReader(stepCount: 0)
        )
        let reviewService = ReviewService(
            store: base.store,
            dailyLogService: base.dailyLogService,
            foodLogService: base.foodLogService,
            waterLogService: base.waterLogService,
            weightLogService: weightLogService,
            healthActivityQuery: healthActivityQuery,
            userProfileService: base.profileService,
            aiService: AIService(llmClient: MockLLMClient())
        )

        let actionCenter = FitnessActionCenter(
            foodLogService: base.foodLogService,
            waterLogService: base.waterLogService,
            weightLogService: weightLogService,
            dailyLogService: base.dailyLogService,
            targetService: targetService,
            userProfileService: base.profileService,
            reviewService: reviewService,
            refreshCenter: refreshCenter,
            profileBootstrapService: cloudUID == nil ? nil : profileBootstrapService,
            cloudUploadFailureNotifier: cloudUID == nil ? nil : cloudUploadFailureNotifier,
            currentUIDProvider: cloudUID.map { uid in { uid } }
        )

        return Harness(
            base: base,
            weightLogService: weightLogService,
            targetService: targetService,
            refreshCenter: refreshCenter,
            cloudStore: cloudStore,
            profileBootstrapService: profileBootstrapService,
            syncStore: syncStore,
            cloudUploadFailureNotifier: cloudUploadFailureNotifier,
            healthActivityQuery: healthActivityQuery,
            actionCenter: actionCenter,
            cloudUID: cloudUID
        )
    }
}
