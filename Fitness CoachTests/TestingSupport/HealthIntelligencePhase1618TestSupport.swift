//
//  HealthIntelligencePhase1618TestSupport.swift
//  Fitness CoachTests
//
//  Shared factories for Phase 16–18 Health Intelligence automated tests.
//

import Foundation
@testable import Fitness_Coach

enum HealthIntelligencePhase1618PermissionPreset: Equatable {
    case full
    case partialStepsAndWorkouts
    case partialStepsOnly
    case partialWorkoutsOnly
    case denied
    case unavailable
    case unknown
}

enum HealthIntelligencePhase1618TestSupport {

    static func makeCalendar(timeZone: TimeZone = TimeZone(secondsFromGMT: 0)!) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func referenceNow(calendar: Calendar = makeCalendar()) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
    }

    static func referenceDay(calendar: Calendar = makeCalendar()) -> Date {
        calendar.startOfDay(for: referenceNow(calendar: calendar))
    }

    static func permissionStatus(
        _ preset: HealthIntelligencePhase1618PermissionPreset,
        resolvedAt: Date = Date()
    ) -> HealthPermissionStatus {
        switch preset {
        case .full:
            return .uniform(.available, isHealthDataAvailable: true, resolvedAt: resolvedAt)

        case .partialStepsAndWorkouts:
            var access = Dictionary(uniqueKeysWithValues: HealthSignalKind.allCases.map { ($0, HealthSignalAccess.denied) })
            access[.stepCount] = .available
            access[.workout] = .available
            return HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: access,
                resolvedAt: resolvedAt
            )

        case .partialStepsOnly:
            return HealthIntelligencePipelineFixtures.stepsOnlyAvailability().permissionStatus

        case .partialWorkoutsOnly:
            return HealthIntelligencePipelineFixtures.workoutsOnlyAvailability().permissionStatus

        case .denied:
            return .uniform(.denied, isHealthDataAvailable: true, resolvedAt: resolvedAt)

        case .unavailable:
            return .unavailable(resolvedAt: resolvedAt)

        case .unknown:
            return .uniform(.unknown, isHealthDataAvailable: true, resolvedAt: resolvedAt)
        }
    }

    static func availability(
        _ preset: HealthIntelligencePhase1618PermissionPreset,
        cachedDayCount: Int = 7,
        resolvedAt: Date = Date()
    ) -> HealthDataAvailability {
        let permission = permissionStatus(preset, resolvedAt: resolvedAt)
        return HealthDataAvailability(
            isHealthDataAvailable: permission.isHealthDataAvailable,
            permissionStatus: permission,
            cachedDayCount: cachedDayCount
        )
    }

    static func uiContext(
        preset: HealthIntelligencePhase1618PermissionPreset = .full,
        snapshot: HealthIntelligenceSnapshot? = nil,
        baseline: HealthBaselineContext? = nil,
        cachedDayCount: Int = 7,
        isAppleHealthConnected: Bool = true,
        lastSuccessfulLocalSyncAt: Date? = nil,
        syncPhase: HealthSyncPhase? = nil,
        explicitErrorMessage: String? = nil,
        surface: HealthIntelligenceSurface = .today,
        now: Date? = nil,
        calendar: Calendar = makeCalendar()
    ) -> HealthIntelligenceUIContext {
        let resolvedNow = now ?? referenceNow(calendar: calendar)
        return HealthIntelligenceUIContext(
            isLoading: false,
            explicitErrorMessage: explicitErrorMessage,
            syncPhase: syncPhase,
            lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
            availability: availability(preset, cachedDayCount: cachedDayCount, resolvedAt: resolvedNow),
            snapshot: snapshot,
            baseline: baseline,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount,
            surface: surface,
            now: resolvedNow
        )
    }

    static func activitySnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 60,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Activity available.",
                recommendedTraining: "Train steadily.",
                recommendedNutrition: "Prioritize protein.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: .noWorkout,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 30),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: .none
        )
    }

    static func connectHealthSnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: .unknown,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: NextBestAction(
                id: "connect-health",
                title: "Connect Apple Health",
                message: "Enable Apple Health",
                ctaTitle: "Connect",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: day,
                expiresAt: nil
            )
        )
    }

    static func sparseSnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery forming",
                explanation: "Limited signals.",
                recommendedTraining: "Use how you feel.",
                recommendedNutrition: "Stay on plan.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 4_500, activeEnergyKcal: nil, exerciseMinutes: nil),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )
    }

    static func workoutsOnlySnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 70,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Workout logged.",
                recommendedTraining: "Steady pacing.",
                recommendedNutrition: "Refuel with protein.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .strength,
                title: "Strength training",
                workoutCount: 1,
                totalDurationMinutes: 45,
                totalActiveCalories: 300,
                intensity: .moderate,
                demand: .moderate,
                latestWorkoutStart: day,
                latestWorkoutEnd: day,
                nutritionAdvice: "Refuel with protein.",
                hydrationAdviceMl: 500,
                explanation: "Synced workout.",
                confidence: .high,
                sourceSummary: "Apple Health"
            ),
            activity: ActivitySummary(steps: nil, activeEnergyKcal: nil, exerciseMinutes: nil),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: .none
        )
    }

    static func stepsOnlySnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 60,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Activity only.",
                recommendedTraining: "Steady pacing.",
                recommendedNutrition: "Prioritize protein.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: .noWorkout,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 30),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: .none
        )
    }

    static func limitedRecoverySnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 72,
                status: .ready,
                title: "Ready to train",
                explanation: "Limited signals.",
                recommendedTraining: "Train as planned.",
                recommendedNutrition: "Stay on plan.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.hrv]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 7_000, activeEnergyKcal: 350, exerciseMinutes: 25),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )
    }

    static func baselineWithoutWorkouts(on day: Date) -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: day,
            averageSteps7d: 8_000,
            averageSteps28d: 7_500,
            averageActiveEnergy7d: 400,
            averageActiveEnergy28d: 380,
            averageSleepDuration7d: 7.5,
            averageSleepDuration28d: 7.2,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 45,
            averageWorkoutLoad28d: nil,
            workoutDays7d: 0,
            workoutDays28d: 0,
            availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv],
            missingSignals: [.workoutLoad]
        )
    }

    static func baselineMissingSleepAndHeart(on day: Date) -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: day,
            averageSteps7d: 8_000,
            averageSteps28d: 7_500,
            averageActiveEnergy7d: 400,
            averageActiveEnergy28d: 380,
            averageSleepDuration7d: nil,
            averageSleepDuration28d: nil,
            averageRestingHeartRate28d: nil,
            averageHRV28d: nil,
            averageWorkoutLoad28d: 120,
            workoutDays7d: 2,
            workoutDays28d: 8,
            availableSignals: [.steps, .activeEnergy, .workoutLoad],
            missingSignals: [.sleep, .restingHeartRate, .hrv]
        )
    }

    static func coachResolverInput(
        snapshot: HealthIntelligenceSnapshot?,
        preset: HealthIntelligencePhase1618PermissionPreset = .full,
        baseline: HealthBaselineContext? = nil,
        lastHealthSyncAt: Date? = nil,
        awarenessAvailable: Bool = true,
        now: Date? = nil,
        calendar: Calendar = makeCalendar()
    ) -> CoachHealthContextStatusResolver.Input {
        let resolvedNow = now ?? referenceNow(calendar: calendar)
        return CoachHealthContextStatusResolver.Input(
            snapshot: snapshot,
            availability: availability(preset, resolvedAt: resolvedNow),
            baseline: baseline,
            lastHealthSyncAt: lastHealthSyncAt,
            isAppleHealthConnected: awarenessAvailable,
            awarenessAvailable: awarenessAvailable,
            now: resolvedNow
        )
    }

    static func crossMidnightWorkout(
        startingOn day: Date,
        calendar: Calendar = makeCalendar()
    ) -> NormalizedWorkout {
        let start = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: day)!
        let end = calendar.date(byAdding: .minute, value: 60, to: start)!
        return NormalizedWorkout(
            id: HealthStableIdentifier.workoutID(
                sourceName: "Apple Watch",
                startDate: start,
                endDate: end,
                durationMinutes: 60,
                category: .running
            ),
            category: .running,
            activityLabel: "Late run",
            startDate: start,
            endDate: end,
            durationMinutes: 60,
            activeEnergyKcal: 420,
            sourceName: "Apple Watch"
        )
    }

    static func makeMappingContext(
        calendar: Calendar = makeCalendar(),
        userId: String = "phase1618-user"
    ) -> HealthSummarySyncMappingContext {
        HealthSummaryRemoteSyncTestSupport.makeMappingContext(userId: userId, calendar: calendar)
    }
}
