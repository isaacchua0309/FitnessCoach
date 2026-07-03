//
//  PlanHealthIntelligencePresentationPreviewData.swift
//  Fitness Coach
//
//  Forma — Preview fixtures for Plan Health Intelligence presentation states.
//

import Foundation

#if DEBUG
enum PlanHealthIntelligencePresentationPreviewData {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private static var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        )
    }

    static var strongFit: PlanHealthIntelligenceSectionState {
        PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: PlanHealthConfidence(score: 0.82, label: "High"),
                baselineContext: strongBaseline,
                recovery: strongRecovery,
                userPlan: connectedPlan,
                healthConnection: .connected,
                hasNutritionLogging: true,
                hasRecentWeightLog: true
            ),
            calendar: calendar
        )
    }

    static var sparseSignals: PlanHealthIntelligenceSectionState {
        PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: PlanHealthConfidence(score: 0.42, label: "Limited"),
                baselineContext: sparseBaseline,
                recovery: .unknown,
                userPlan: connectedPlan,
                healthConnection: .partial,
                hasNutritionLogging: false,
                hasRecentWeightLog: false
            ),
            calendar: calendar
        )
    }

    static var disconnected: PlanHealthIntelligenceSectionState {
        PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: .unknown,
                baselineContext: .empty(for: referenceDay),
                recovery: .unknown,
                userPlan: UserPlanContext(calorieTarget: 2_100, proteinTargetGrams: 150),
                healthConnection: .disconnected,
                hasNutritionLogging: false,
                hasRecentWeightLog: false
            ),
            calendar: calendar
        )
    }

    static var loading: PlanHealthIntelligenceSectionState {
        PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(isLoading: true),
            calendar: calendar
        )
    }

    private static var connectedPlan: UserPlanContext {
        UserPlanContext(
            calorieTarget: 2_200,
            proteinTargetGrams: 165,
            isAppleHealthConnected: true
        )
    }

    private static var strongBaseline: HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 8_450,
            averageSteps28d: 7_900,
            averageActiveEnergy7d: 420,
            averageActiveEnergy28d: 390,
            averageSleepDuration7d: 7.1 * 60,
            averageSleepDuration28d: 6.8 * 60,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 52,
            averageWorkoutLoad28d: 180,
            workoutDays7d: 4,
            workoutDays28d: 12,
            availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv, .workoutLoad],
            missingSignals: []
        )
    }

    private static var sparseBaseline: HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 5_200,
            averageSteps28d: nil,
            averageActiveEnergy7d: nil,
            averageActiveEnergy28d: nil,
            averageSleepDuration7d: nil,
            averageSleepDuration28d: nil,
            averageRestingHeartRate28d: nil,
            averageHRV28d: nil,
            averageWorkoutLoad28d: nil,
            workoutDays7d: 1,
            workoutDays28d: 2,
            availableSignals: [.steps, .workoutLoad],
            missingSignals: [.sleep, .hrv, .restingHeartRate, .activeEnergy]
        )
    }

    private static var strongRecovery: RecoverySummary {
        RecoverySummary(
            score: 74,
            status: .moderate,
            title: "Moderate recovery",
            explanation: "Recovery is acceptable after recent training.",
            recommendedTraining: "Train based on how you feel.",
            recommendedNutrition: "Stay on your usual plan.",
            confidence: .moderate,
            contributingFactors: [],
            missingSignals: []
        )
    }
}
#endif
