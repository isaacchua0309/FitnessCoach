//
//  UserProfileEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

extension UserProfileEntity {

    convenience init(model: UserProfile) {
        self.init(
            id: model.id,
            ownerUID: model.ownerUID,
            name: model.name,
            birthDate: model.birthDate,
            age: model.age,
            sexRawValue: model.sex.rawValue,
            heightCm: model.heightCm,
            currentWeightKg: model.currentWeightKg,
            goalWeightKg: model.goalWeightKg,
            estimatedBodyFatPercentage: model.estimatedBodyFatPercentage,
            activityLevelRawValue: model.activityLevel.rawValue,
            trainingFrequencyPerWeek: model.trainingFrequencyPerWeek,
            averageSteps: model.averageSteps,
            dietPreference: model.dietPreference,
            unitSystemRawValue: model.unitSystem.rawValue,
            calorieTarget: model.targets.calorieTarget,
            proteinTarget: model.targets.proteinTarget,
            carbTarget: model.targets.carbTarget,
            fatTarget: model.targets.fatTarget,
            waterTargetMl: model.targets.waterTargetMl,
            expectedWeeklyWeightLossKg: model.targets.expectedWeeklyWeightLossKg,
            aggressivenessRawValue: model.targets.aggressiveness.rawValue,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            lastPlanUpdateReasonRawValue: model.lastPlanUpdateReason?.rawValue
        )
    }

    func toModel() -> UserProfile {
        UserProfile(
            id: id,
            ownerUID: ownerUID,
            name: name,
            birthDate: birthDate,
            age: age,
            sex: Sex(rawValue: sexRawValue) ?? .preferNotToSay,
            heightCm: heightCm,
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            estimatedBodyFatPercentage: estimatedBodyFatPercentage,
            activityLevel: ActivityLevel(rawValue: activityLevelRawValue) ?? .moderatelyActive,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek,
            averageSteps: averageSteps,
            dietPreference: dietPreference,
            unitSystem: UnitSystem(rawValue: unitSystemRawValue) ?? .metric,
            targets: UserTargets(
                calorieTarget: calorieTarget,
                proteinTarget: proteinTarget,
                carbTarget: carbTarget,
                fatTarget: fatTarget,
                waterTargetMl: waterTargetMl,
                expectedWeeklyWeightLossKg: expectedWeeklyWeightLossKg,
                aggressiveness: CalorieAggressiveness(rawValue: aggressivenessRawValue) ?? .moderate
            ),
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastPlanUpdateReason: lastPlanUpdateReasonRawValue.flatMap(PlanLastUpdateReason.init(rawValue:))
        )
    }
}
