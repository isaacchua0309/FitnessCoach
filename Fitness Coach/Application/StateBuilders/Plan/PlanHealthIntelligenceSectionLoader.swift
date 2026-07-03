//
//  PlanHealthIntelligenceSectionLoader.swift
//  Fitness Coach
//
//  Forma — Loads Health Intelligence inputs for Plan presentation.
//

import Foundation

enum PlanHealthIntelligenceSectionLoader {

    private static let nutritionLoggingMinimumDays = 3

    static func loadSectionState(
        profile: UserProfile,
        context: PlanDashboardContext,
        isAppleHealthConnected: Bool,
        snapshotProvider: any HealthIntelligenceSnapshotServing,
        baselineService: any HealthBaselineProviding,
        healthDataRepository: any HealthDataRepositorying,
        calendar: Calendar = .current
    ) async -> PlanHealthIntelligenceSectionState {
        let referenceDate = context.asOf

        async let snapshotTask = snapshotProvider.loadTodaySnapshot(
            for: referenceDate,
            calendar: calendar
        )
        async let baselineTask = baselineService.buildContext(
            for: referenceDate,
            calendar: calendar
        )
        async let availabilityTask = healthDataRepository.getHealthDataAvailability()

        let snapshot = await snapshotTask
        let baselineContext = await baselineTask
        let availability = await availabilityTask

        let userPlan = UserPlanContext.from(
            profile: profile,
            isAppleHealthConnected: isAppleHealthConnected
        )
        let hasNutritionLogging = JourneyLogMetrics.foodLoggedDays(in: context.weekLogs)
            >= nutritionLoggingMinimumDays
        let hasRecentWeightLog = PlanConfidenceStateBuilder.hasRecentWeightLog(
            in: context.allWeights,
            asOf: referenceDate,
            calendar: calendar
        )

        if let snapshot {
            return PlanHealthIntelligencePresentationBuilder.buildSection(
                input: .from(
                    snapshot: snapshot,
                    baselineContext: baselineContext,
                    userPlan: userPlan,
                    healthAvailability: availability,
                    hasNutritionLogging: hasNutritionLogging,
                    hasRecentWeightLog: hasRecentWeightLog
                ),
                calendar: calendar
            )
        }

        return PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: .unknown,
                baselineContext: baselineContext,
                recovery: .unknown,
                userPlan: userPlan,
                healthConnection: PlanHealthConnectionState.resolve(
                    isAppleHealthConnected: isAppleHealthConnected,
                    availability: availability
                ),
                hasNutritionLogging: hasNutritionLogging,
                hasRecentWeightLog: hasRecentWeightLog
            ),
            calendar: calendar
        )
    }
}
