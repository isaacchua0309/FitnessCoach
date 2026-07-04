//
//  DailyLogServiceTestSupport.swift
//  Fitness CoachTests
//
//  In-memory SwiftData harness for DailyLogService tests (no Firebase / HealthKit / OpenAI).
//

import Foundation
@testable import Fitness_Coach

@MainActor
enum DailyLogServiceTestSupport {

    @MainActor
    struct Harness {
        let store: SwiftDataStore
        let profileService: UserProfileService
        let dailyLogService: DailyLogService
        let foodLogService: FoodLogService
        let waterLogService: WaterLogService
        let dateProvider: FixedDailyLogTestDateProvider
        let accountSyncOutboxStore: SwiftDataAccountSyncOutboxStore?
        let accountLocalMutationTracker: AccountLocalMutationTracker?

        var today: Date { dateProvider.now }

        func day(offset: Int) -> Date {
            dateProvider.calendar.date(byAdding: .day, value: offset, to: today)!
        }

        @discardableResult
        func seedProfile(
            targets: UserTargets = ProfileTestFixtures.sampleTargets
        ) throws -> UserProfile {
            var draft = ProfileTestFixtures.sampleDraft
            draft.targets = targets
            return try profileService.createProfile(draft)
        }

        @discardableResult
        func seedWorkoutCaloriesBurned(
            date: Date? = nil,
            calories: Int = 250
        ) throws -> DailyLog {
            let workoutDate = date ?? today
            let log = try dailyLogService.getOrCreateLogEntity(for: workoutDate)
            log.workoutCaloriesBurned = calories
            try store.save()
            return try dailyLogService.recalculateDailyTotals(for: workoutDate)
        }
    }

    static let referenceNow = TestDateFixtures.referenceEpoch

    static var alternateTargets: UserTargets {
        UserTargets(
            calorieTarget: 2_100,
            proteinTarget: 145,
            carbTarget: 185,
            fatTarget: 62,
            waterTargetMl: 2_800,
            expectedWeeklyWeightLossKg: 0.52,
            aggressiveness: .aggressive
        )
    }

    static func makeHarness(
        referenceNow: Date = DailyLogServiceTestSupport.referenceNow,
        ownerUID: String? = nil
    ) throws -> Harness {
        let dateProvider = FakeClock(now: referenceNow)
        let container = try InMemorySwiftDataTestStore.makeContainer()
        let store = SwiftDataStore(container: container)
        let outbox = SwiftDataAccountSyncOutboxStore(store: store)
        let mutationTracker = ownerUID.map { uid in
            AccountLocalMutationTracker(
                outbox: outbox,
                ownerUIDProvider: { uid }
            )
        }
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider,
            mutationTracker: mutationTracker
        )
        let foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: mutationTracker
        )
        let waterLogService = WaterLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: mutationTracker
        )

        return Harness(
            store: store,
            profileService: profileService,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            dateProvider: dateProvider,
            accountSyncOutboxStore: outbox,
            accountLocalMutationTracker: mutationTracker
        )
    }

    static func foodDraft(
        name: String,
        calories: Int,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double? = nil,
        sodium: Double? = nil
    ) -> FoodDraft {
        CoachFoodFixtures.foodDraft(
            name: name,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sodium: sodium
        )
    }
}
