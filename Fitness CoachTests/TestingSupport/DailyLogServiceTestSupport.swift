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
        func seedWorkoutEntry(
            date: Date? = nil,
            estimatedCaloriesBurned: Int = 250,
            name: String = "Run"
        ) throws -> WorkoutEntry {
            let workoutDate = date ?? today
            let log = try dailyLogService.getOrCreateLogEntity(for: workoutDate)
            let now = Date()
            let workoutId = UUID()
            let workout = WorkoutEntry(
                id: workoutId,
                dailyLogId: log.id,
                name: name,
                durationMinutes: 30,
                estimatedCaloriesBurned: estimatedCaloriesBurned,
                intensity: .moderate,
                recoveryDemand: nil,
                notes: nil,
                createdAt: now,
                updatedAt: now
            )
            let entity = WorkoutEntryEntity(model: workout)
            entity.dailyLog = log
            try store.insert(entity)
            _ = try dailyLogService.recalculateDailyTotals(for: workoutDate)
            return workout
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
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider
        )
        let foodLogService = FoodLogService(store: store, dailyLogService: dailyLogService)
        let waterLogService = WaterLogService(store: store, dailyLogService: dailyLogService)

        return Harness(
            store: store,
            profileService: profileService,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
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
