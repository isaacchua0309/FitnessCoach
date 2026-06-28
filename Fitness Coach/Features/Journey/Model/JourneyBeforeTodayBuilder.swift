//
//  JourneyBeforeTodayBuilder.swift
//  Fitness Coach
//
//  Forma — Started vs today profile snapshot for Journey.
//

import Foundation

enum JourneyBeforeTodayBuilder {

    struct Input: Equatable {
        var profile: UserProfile?
        var baseline: JourneyBaseline
        var asOf: Date
        var calendar: Calendar
    }

    private static let adaptedTargetToleranceKcal = 25

    static func build(_ input: Input) -> JourneyBeforeTodayState {
        let baseline = input.baseline
        let profile = input.profile

        let daysOnJourney = max(
            input.calendar.dateComponents(
                [.day],
                from: input.calendar.startOfDay(for: baseline.startDate),
                to: input.calendar.startOfDay(for: input.asOf)
            ).day ?? 0,
            0
        )

        let startingMaintenance = estimatedMaintenance(
            profile: profile,
            weightKg: baseline.startWeightKg,
            referenceDate: baseline.startDate
        )
        let currentMaintenance = estimatedMaintenance(
            profile: profile,
            weightKg: baseline.currentWeightKg,
            referenceDate: input.asOf
        )

        let startingTarget = estimatedCalorieTarget(
            profile: profile,
            weightKg: baseline.startWeightKg,
            referenceDate: baseline.startDate
        )
        let currentTarget = currentCalorieTarget(profile: profile)

        let showsMaintenanceRow = startingMaintenance != nil && currentMaintenance != nil
        let showsTargetRow = startingTarget != nil && currentTarget != nil
        let showsAdaptedTargetCopy = showsTargetRow
            && abs((startingTarget ?? 0) - (currentTarget ?? 0)) > adaptedTargetToleranceKcal

        return JourneyBeforeTodayState(
            startedWeightKg: baseline.startWeightKg,
            currentWeightKg: baseline.currentWeightKg,
            startingMaintenanceCaloriesKcal: showsMaintenanceRow ? startingMaintenance : nil,
            currentMaintenanceCaloriesKcal: showsMaintenanceRow ? currentMaintenance : nil,
            startingTargetCaloriesKcal: showsTargetRow ? startingTarget : nil,
            currentTargetCaloriesKcal: showsTargetRow ? currentTarget : nil,
            goalWeightKg: baseline.goalWeightKg,
            daysOnJourney: daysOnJourney,
            showsMaintenanceRow: showsMaintenanceRow,
            showsTargetRow: showsTargetRow,
            showsAdaptedTargetCopy: showsAdaptedTargetCopy
        )
    }

    // MARK: - Estimation

    private static func estimatedMaintenance(
        profile: UserProfile?,
        weightKg: Double?,
        referenceDate: Date
    ) -> Int? {
        guard let profile, let weightKg, weightKg > 0 else { return nil }

        let bmr = EnergyCalculator.bmrKcal(
            weightKg: weightKg,
            heightCm: profile.heightCm,
            ageYears: profile.resolvedAge(referenceDate: referenceDate),
            sex: profile.sex
        )

        return EnergyCalculator.tdeeKcal(
            bmrKcal: bmr,
            activityLevel: profile.activityLevel,
            averageStepsPerDay: profile.averageSteps,
            trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek
        )
    }

    private static func estimatedCalorieTarget(
        profile: UserProfile?,
        weightKg: Double?,
        referenceDate: Date
    ) -> Int? {
        guard let profile, let weightKg, weightKg > 0 else { return nil }

        let input = PlanCalculationInput(
            ageYears: profile.resolvedAge(referenceDate: referenceDate),
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: weightKg,
            goalWeightKg: profile.goalWeightKg,
            activityLevel: profile.activityLevel,
            trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek,
            averageStepsPerDay: profile.averageSteps,
            bodyFatPercent: profile.estimatedBodyFatPercentage,
            dietPreference: profile.dietPreference,
            weightLossPace: PlanCalculationBridge.resolvedWeightLossPace(for: profile),
            referenceDate: referenceDate,
            isWorkoutDay: false
        )

        guard let result = try? FormaCalculationEngine.calculate(input),
              result.calorieTargetKcal > 0 else {
            return nil
        }

        return result.calorieTargetKcal
    }

    private static func currentCalorieTarget(profile: UserProfile?) -> Int? {
        guard let target = profile?.targets.calorieTarget, target > 0 else { return nil }
        return target
    }
}
