//
//  UserProfileEntity.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData persistence entity.
//

import Foundation
import SwiftData

@Model
final class UserProfileEntity {

    // MARK: Identity

    @Attribute(.unique) var id: UUID
    /// Firebase UID that owns this on-device profile, when known.
    var ownerUID: String?

    // MARK: Baseline

    var name: String?
    var birthDate: Date?
    var age: Int
    var sexRawValue: String
    var heightCm: Double
    var currentWeightKg: Double
    var goalWeightKg: Double
    var estimatedBodyFatPercentage: Double?

    // MARK: Activity

    var activityLevelRawValue: String
    var trainingFrequencyPerWeek: Int
    var averageSteps: Int

    // MARK: Preferences

    var dietPreference: String?
    var unitSystemRawValue: String

    // MARK: Targets (flattened from UserTargets)

    var calorieTarget: Int
    var proteinTarget: Double
    var carbTarget: Double
    var fatTarget: Double
    var waterTargetMl: Int
    var expectedWeeklyWeightLossKg: Double?
    var aggressivenessRawValue: String

    // MARK: Metadata

    var createdAt: Date
    var updatedAt: Date
    var lastPlanUpdateReasonRawValue: String?

    init(
        id: UUID,
        ownerUID: String? = nil,
        name: String?,
        birthDate: Date? = nil,
        age: Int,
        sexRawValue: String,
        heightCm: Double,
        currentWeightKg: Double,
        goalWeightKg: Double,
        estimatedBodyFatPercentage: Double?,
        activityLevelRawValue: String,
        trainingFrequencyPerWeek: Int,
        averageSteps: Int,
        dietPreference: String?,
        unitSystemRawValue: String,
        calorieTarget: Int,
        proteinTarget: Double,
        carbTarget: Double,
        fatTarget: Double,
        waterTargetMl: Int,
        expectedWeeklyWeightLossKg: Double?,
        aggressivenessRawValue: String,
        createdAt: Date,
        updatedAt: Date,
        lastPlanUpdateReasonRawValue: String? = nil
    ) {
        self.id = id
        self.ownerUID = ownerUID
        self.name = name
        self.birthDate = birthDate
        self.age = age
        self.sexRawValue = sexRawValue
        self.heightCm = heightCm
        self.currentWeightKg = currentWeightKg
        self.goalWeightKg = goalWeightKg
        self.estimatedBodyFatPercentage = estimatedBodyFatPercentage
        self.activityLevelRawValue = activityLevelRawValue
        self.trainingFrequencyPerWeek = trainingFrequencyPerWeek
        self.averageSteps = averageSteps
        self.dietPreference = dietPreference
        self.unitSystemRawValue = unitSystemRawValue
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.carbTarget = carbTarget
        self.fatTarget = fatTarget
        self.waterTargetMl = waterTargetMl
        self.expectedWeeklyWeightLossKg = expectedWeeklyWeightLossKg
        self.aggressivenessRawValue = aggressivenessRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastPlanUpdateReasonRawValue = lastPlanUpdateReasonRawValue
    }
}
