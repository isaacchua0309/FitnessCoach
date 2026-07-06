//
//  PlanHealthIntelligenceSectionLoader.swift
//  Fitness Coach
//
//  Forma — Loads Health Intelligence inputs for Plan presentation.
//

import Foundation

enum PlanHealthIntelligenceSectionLoader {

    private static let nutritionLoggingMinimumDays = 3

    static func loadSection(
        profile: UserProfile,
        context: PlanDashboardContext,
        isAppleHealthConnected: Bool,
        snapshotProvider: any HealthIntelligenceSnapshotServing,
        baselineService: any HealthBaselineProviding,
        healthDataRepository: any HealthDataRepositorying,
        syncPhase: HealthSyncPhase? = nil,
        lastSuccessfulLocalSyncAt: Date? = nil,
        isRemoteSyncCapabilityEnabled: Bool = false,
        remoteSyncConsentDecision: HealthSummarySyncConsentDecision = .notDetermined,
        errorMessage: String? = nil,
        calendar: Calendar = .current
    ) async -> PlanHealthIntelligenceLoadResult {
        let referenceDate = context.asOf

        async let baselineTask = baselineService.buildContext(
            for: referenceDate,
            calendar: calendar
        )
        let snapshotAvailability = await HealthIntelligenceSectionLoaderCore.loadTodaySnapshotAndAvailability(
            referenceDate: referenceDate,
            snapshotProvider: snapshotProvider,
            healthDataRepository: healthDataRepository,
            calendar: calendar
        )

        let snapshot = snapshotAvailability.snapshot
        let baselineContext = await baselineTask
        let availability = snapshotAvailability.availability

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

        let buildInput = PlanHealthIntelligenceBuildInput(
            planConfidence: snapshot?.planConfidence ?? .unknown,
            baselineContext: baselineContext,
            recovery: snapshot?.recovery ?? .unknown,
            userPlan: userPlan,
            healthConnection: PlanHealthConnectionState.resolve(
                isAppleHealthConnected: isAppleHealthConnected,
                availability: availability
            ),
            healthAvailability: availability,
            hasNutritionLogging: hasNutritionLogging,
            hasRecentWeightLog: hasRecentWeightLog,
            cachedDayCount: availability.cachedDayCount,
            errorMessage: errorMessage,
            syncPhase: syncPhase,
            lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
            remoteSyncConsentDecision: remoteSyncConsentDecision
        )

        let sectionState = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: buildInput,
            calendar: calendar
        )

        return PlanHealthIntelligenceLoadResult(
            sectionState: sectionState,
            snapshot: snapshot,
            availability: availability
        )
    }
}
