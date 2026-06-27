//
//  TargetService.swift
//  Fitness Coach
//
//  FitPilot AI — Generates and updates calorie, macro, and water targets.
//

import Foundation

@MainActor
final class TargetService {

    private let userProfileService: UserProfileService
    private let dailyLogService: DailyLogService

    init(userProfileService: UserProfileService, dailyLogService: DailyLogService) {
        self.userProfileService = userProfileService
        self.dailyLogService = dailyLogService
    }

    // MARK: Generation

    /// Generates plan targets via `FormaCalculationEngine` (see `Docs/FormaCalculationSpec.md`).
    /// Existing stored profiles are unchanged until the user saves or regenerates a plan.
    func generateInitialTargets(from input: CalorieTargetInput) throws -> CalorieTargetResult {
        try PlanCalculationBridge.calorieTargetResult(from: input)
    }

    func generateWaterTarget(
        bodyWeightKg: Double,
        activityLevel: ActivityLevel = .moderatelyActive,
        averageStepsPerDay: Int = FormaCalculationConstants.stepBaselinePerDay,
        isWorkoutDay: Bool = false
    ) -> Int {
        PlanCalculationBridge.waterTargetMl(
            bodyWeightKg: bodyWeightKg,
            activityLevel: activityLevel,
            averageStepsPerDay: averageStepsPerDay,
            isWorkoutDay: isWorkoutDay
        )
    }

    // MARK: Current Targets

    func updateCurrentTargets(_ targets: UserTargets) throws -> UserProfile {
        let profile = try userProfileService.updateTargets(targets)
        try dailyLogService.syncTodayTargetsFromProfile()
        return profile
    }

    func getCurrentTargets() throws -> UserTargets {
        guard let profile = try userProfileService.getCurrentProfile() else {
            throw ServiceError.missingUserProfile
        }
        return profile.targets
    }
}
