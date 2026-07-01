//
//  FitnessActionCenter.swift
//  Fitness Coach
//
//  FitPilot AI — Canonical mutation layer for all fitness logging and plan edits.
//
//  Action ownership:
//  - Food / water / weight daily logs → Quick Capture (Today shortcuts, Coach parser)
//  - Training → Apple Health via Training Insights (read-only; Coach redirects workout intents)
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
    private let dailyLogService: DailyLogService
    private let targetService: TargetService
    private let userProfileService: UserProfileService
    private let reviewService: ReviewService
    private let refreshCenter: AppRefreshCenter
    private let profileBootstrapService: ProfileBootstrapService?
    private let cloudUploadFailureNotifier: ProfileCloudUploadFailureNotifier?
    private let currentUIDProvider: (() -> String?)?

    init(
        foodLogService: FoodLogService,
        waterLogService: WaterLogService,
        weightLogService: WeightLogService,
        dailyLogService: DailyLogService,
        targetService: TargetService,
        userProfileService: UserProfileService,
        reviewService: ReviewService,
        refreshCenter: AppRefreshCenter,
        profileBootstrapService: ProfileBootstrapService? = nil,
        cloudUploadFailureNotifier: ProfileCloudUploadFailureNotifier? = nil,
        currentUIDProvider: (() -> String?)? = nil
    ) {
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.dailyLogService = dailyLogService
        self.targetService = targetService
        self.userProfileService = userProfileService
        self.reviewService = reviewService
        self.refreshCenter = refreshCenter
        self.profileBootstrapService = profileBootstrapService
        self.cloudUploadFailureNotifier = cloudUploadFailureNotifier
        self.currentUIDProvider = currentUIDProvider
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
    func createProfile(_ draft: UserProfileDraft, ownerUID: String? = nil) throws -> UserProfile {
        let profile = try userProfileService.createProfile(draft, ownerUID: ownerUID)
        try dailyLogService.syncTodayTargetsFromProfile()
        notifyDataChanged()
        return profile
    }

    @discardableResult
    func updatePlan(_ update: UserProfileUpdate) throws -> UserProfile {
        let profile = try userProfileService.updateProfile(update)
        if update.targets != nil {
            try dailyLogService.syncTodayTargetsFromProfile()
        }
        notifyDataChanged()
        syncProfileToCloudIfPossible()
        return profile
    }

    @discardableResult
    func applyPlanTargets(_ targets: UserTargets) throws -> UserProfile {
        let profile = try targetService.updateCurrentTargets(targets)
        notifyDataChanged()
        syncProfileToCloudIfPossible()
        return profile
    }

    // MARK: - Refresh

    func notifyDataChanged() {
        refreshCenter.notifyDataChanged()
    }

    private func syncProfileToCloudIfPossible() {
        guard let profileBootstrapService, let uid = currentUIDProvider?() else { return }
        Task {
            do {
                try await profileBootstrapService.saveProfileToCloud(
                    uid: uid,
                    intent: .ownedProfileUpdate
                )
            } catch is CloudProfileWriteError {
                ProfileBootstrapDebugLogger.event(
                    "Cloud profile refresh blocked",
                    fields: ["uid": uid]
                )
            } catch {
                ProfileBootstrapDebugLogger.error(
                    "Cloud profile refresh failed",
                    fields: ["uid": uid],
                    underlying: error
                )
                cloudUploadFailureNotifier?.reportFailure(.profileEdit)
            }
        }
    }
}
