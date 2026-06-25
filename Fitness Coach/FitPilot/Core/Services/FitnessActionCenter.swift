//
//  FitnessActionCenter.swift
//  Fitness Coach
//
//  FitPilot AI — Canonical mutation layer for all fitness logging and plan edits.
//
//  Action ownership:
//  - Food / water / weight daily logs → Quick Capture (Today shortcuts, Coach parser)
//  - Workouts → Training flow (Today shortcuts route to Training)
//  - Plan targets & profile baseline → Plan screen only
//  - Progress reads → Journey (read-only; no mutations here)
//
//  Feature models and Coach call these methods instead of mutating services directly.
//  Every successful mutation notifies AppRefreshCenter so all surfaces stay in sync.
//

import Foundation

@MainActor
final class FitnessActionCenter {

    private let foodLogService: FoodLogService
    private let waterLogService: WaterLogService
    private let weightLogService: WeightLogService
    private let workoutLogService: WorkoutLogService
    private let dailyLogService: DailyLogService
    private let targetService: TargetService
    private let userProfileService: UserProfileService
    private let reviewService: ReviewService
    private let refreshCenter: AppRefreshCenter

    init(
        foodLogService: FoodLogService,
        waterLogService: WaterLogService,
        weightLogService: WeightLogService,
        workoutLogService: WorkoutLogService,
        dailyLogService: DailyLogService,
        targetService: TargetService,
        userProfileService: UserProfileService,
        reviewService: ReviewService,
        refreshCenter: AppRefreshCenter
    ) {
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.workoutLogService = workoutLogService
        self.dailyLogService = dailyLogService
        self.targetService = targetService
        self.userProfileService = userProfileService
        self.reviewService = reviewService
        self.refreshCenter = refreshCenter
    }

    // MARK: - Food (canonical: Coach + food capture flow)

    @discardableResult
    func logFood(_ draft: FoodDraft, date: Date = Date()) throws -> FoodEntry {
        let entry = try foodLogService.addFoodEntry(draft, date: date)
        notifyDataChanged()
        return entry
    }

    @discardableResult
    func editFoodEntry(id: UUID, update: FoodEntryUpdate) throws -> FoodEntry {
        let entry = try foodLogService.editFoodEntry(id: id, update: update)
        notifyDataChanged()
        return entry
    }

    func deleteFoodEntry(id: UUID) throws {
        try foodLogService.deleteFoodEntry(id: id)
        notifyDataChanged()
    }

    func getFoodEntries(for date: Date = Date()) throws -> [FoodEntry] {
        try foodLogService.getFoodEntries(for: date)
    }

    func undoLastFoodEntry(date: Date = Date()) throws -> FoodEntry? {
        let entry = try foodLogService.undoLastFoodEntry(date: date)
        notifyDataChanged()
        return entry
    }

    // MARK: - Water (canonical: Quick Capture)

    @discardableResult
    func logWater(amountMl: Int, date: Date = Date()) throws -> WaterEntry {
        let entry = try waterLogService.addWater(amountMl: amountMl, date: date)
        notifyDataChanged()
        return entry
    }

    @discardableResult
    func logWater(_ draft: WaterDraft, date: Date = Date()) throws -> WaterEntry {
        let entry = try waterLogService.addWater(draft, date: date)
        notifyDataChanged()
        return entry
    }

    func undoLastWaterEntry(date: Date = Date()) throws -> WaterEntry? {
        let entry = try waterLogService.undoLastWaterEntry(date: date)
        notifyDataChanged()
        return entry
    }

    func deleteWaterEntry(id: UUID) throws {
        try waterLogService.deleteWaterEntry(id: id)
        notifyDataChanged()
    }

    // MARK: - Weight (canonical: daily weigh-in — not Plan baseline edits)

    @discardableResult
    func logDailyWeight(_ weightKg: Double, date: Date = Date()) throws -> WeightEntry {
        let entry = try weightLogService.logWeight(weightKg, date: date)
        notifyDataChanged()
        return entry
    }

    @discardableResult
    func logDailyWeight(_ draft: WeightDraft, date: Date = Date()) throws -> WeightEntry {
        let entry = try weightLogService.logWeight(draft, date: date)
        notifyDataChanged()
        return entry
    }

    // MARK: - Workout (canonical: Training flow)

    @discardableResult
    func logWorkout(_ draft: WorkoutDraft, date: Date = Date()) throws -> WorkoutEntry {
        let entry = try workoutLogService.addWorkout(draft, date: date)
        notifyDataChanged()
        return entry
    }

    func deleteWorkout(id: UUID) throws {
        try workoutLogService.deleteWorkout(id: id)
        notifyDataChanged()
    }

    // MARK: - Day lifecycle

    @discardableResult
    func ensureTodayLog() throws -> DailyLog {
        try dailyLogService.ensureTodayLog()
    }

    // MARK: - Reviews

    func generateDailyReview(for date: Date = Date()) async throws -> DailyReview {
        let review = try await reviewService.generateDailyReview(for: date)
        notifyDataChanged()
        return review
    }

    // MARK: - Plan (canonical: Plan screen only — strategy, not daily logs)

    @discardableResult
    func updatePlan(_ update: UserProfileUpdate) throws -> UserProfile {
        let profile = try userProfileService.updateProfile(update)
        if update.targets != nil {
            try dailyLogService.syncTodayTargetsFromProfile()
        }
        notifyDataChanged()
        return profile
    }

    @discardableResult
    func applyPlanTargets(_ targets: UserTargets) throws -> UserProfile {
        let profile = try targetService.updateCurrentTargets(targets)
        notifyDataChanged()
        return profile
    }

    // MARK: - Refresh

    func notifyDataChanged() {
        refreshCenter.notifyDataChanged()
    }
}
