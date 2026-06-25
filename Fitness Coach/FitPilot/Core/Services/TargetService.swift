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

    func generateInitialTargets(from input: CalorieTargetInput) -> CalorieTargetResult {
        CalorieTargetCalculator.generateTargets(input: input)
    }

    func generateWaterTarget(bodyWeightKg: Double, isWorkoutDay: Bool) -> Int {
        WaterTargetCalculator.targetMl(bodyWeightKg: bodyWeightKg, isWorkoutDay: isWorkoutDay)
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
