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
        let workoutLogService: WorkoutLogService
        let dateProvider: FixedDailyLogTestDateProvider

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
    }

    static let referenceNow = ProfileTestFixtures.referenceDate

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
        referenceNow: Date = DailyLogServiceTestSupport.referenceNow
    ) throws -> Harness {
        let dateProvider = FixedDailyLogTestDateProvider(now: referenceNow)
        let container = try FitPilotModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider
        )
        let foodLogService = FoodLogService(store: store, dailyLogService: dailyLogService)
        let waterLogService = WaterLogService(store: store, dailyLogService: dailyLogService)
        let workoutLogService = WorkoutLogService(
            store: store,
            dailyLogService: dailyLogService,
            userProfileService: profileService
        )

        return Harness(
            store: store,
            profileService: profileService,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            workoutLogService: workoutLogService,
            dateProvider: dateProvider
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
        FoodDraft(
            mealType: .lunch,
            name: name,
            quantity: 1,
            unit: "serving",
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sodium: sodium,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil
        )
    }

    static func workoutDraft(
        name: String = "Run",
        durationMinutes: Int = 30,
        estimatedCaloriesBurned: Int = 250
    ) -> WorkoutDraft {
        WorkoutDraft(
            name: name,
            durationMinutes: durationMinutes,
            estimatedCaloriesBurned: estimatedCaloriesBurned,
            intensity: .moderate,
            recoveryDemand: nil,
            notes: nil,
            exerciseSets: []
        )
    }
}

struct FixedDailyLogTestDateProvider: DateProviding {
    let now: Date
    let calendar: Calendar

    init(now: Date, calendar: Calendar = .current) {
        self.now = calendar.startOfDay(for: now)
        self.calendar = calendar
    }

    func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
