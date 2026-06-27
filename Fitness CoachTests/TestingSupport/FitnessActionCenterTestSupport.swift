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
        let actionCenter: FitnessActionCenter

        var store: SwiftDataStore { base.store }
        var profileService: UserProfileService { base.profileService }
        var dailyLogService: DailyLogService { base.dailyLogService }
        var today: Date { base.today }

        @discardableResult
        func seedProfile(
            targets: UserTargets = ProfileTestFixtures.sampleTargets
        ) throws -> UserProfile {
            try base.seedProfile(targets: targets)
        }

        func waitForCloudSave(timeoutNanoseconds: UInt64 = 500_000_000) async throws {
            let step: UInt64 = 10_000_000
            var elapsed: UInt64 = 0
            while cloudStore.saveCallCount == 0, elapsed < timeoutNanoseconds {
                try await Task.sleep(nanoseconds: step)
                elapsed += step
            }
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
        let profileBootstrapService = ProfileBootstrapService(
            userProfileService: base.profileService,
            cloudStore: cloudStore
        )
        let reviewService = ReviewService(
            store: base.store,
            dailyLogService: base.dailyLogService,
            foodLogService: base.foodLogService,
            waterLogService: base.waterLogService,
            weightLogService: weightLogService,
            workoutLogService: base.workoutLogService,
            userProfileService: base.profileService,
            aiService: AIService(llmClient: MockLLMClient())
        )

        let actionCenter = FitnessActionCenter(
            foodLogService: base.foodLogService,
            waterLogService: base.waterLogService,
            weightLogService: weightLogService,
            workoutLogService: base.workoutLogService,
            dailyLogService: base.dailyLogService,
            targetService: targetService,
            userProfileService: base.profileService,
            reviewService: reviewService,
            refreshCenter: refreshCenter,
            profileBootstrapService: cloudUID == nil ? nil : profileBootstrapService,
            currentUIDProvider: cloudUID.map { uid in { uid } }
        )

        return Harness(
            base: base,
            weightLogService: weightLogService,
            targetService: targetService,
            refreshCenter: refreshCenter,
            cloudStore: cloudStore,
            profileBootstrapService: profileBootstrapService,
            actionCenter: actionCenter
        )
    }
}
