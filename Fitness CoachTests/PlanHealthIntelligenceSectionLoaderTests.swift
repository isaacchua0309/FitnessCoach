//
//  PlanHealthIntelligenceSectionLoaderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanHealthIntelligenceSectionLoaderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        )
    }

    func testLoaderBuildsSectionFromSnapshotBaselineAndLoggingSignals() async {
        let context = makeContext(
            weekLogs: makeActiveWeekLogs(),
            allWeights: makeActiveWeights()
        )
        let snapshot = makeSnapshot(on: referenceDay)
        let baseline = makeBaseline(on: referenceDay)

        let loadResult = await PlanHealthIntelligenceSectionLoader.loadSection(
            profile: context.profile,
            context: context,
            isAppleHealthConnected: true,
            snapshotProvider: LoaderSnapshotService(snapshot: snapshot),
            baselineService: LoaderBaselineProvider(context: baseline),
            healthDataRepository: LoaderRepository(connected: true),
            calendar: calendar
        )
        let section = loadResult.sectionState

        XCTAssertNotNil(loadResult.snapshot)
        XCTAssertTrue(loadResult.availability.isHealthDataAvailable)

        XCTAssertEqual(section.confidenceCard.phase, .loaded)
        XCTAssertEqual(
            section.confidenceCard.confidenceLabel,
            FormaProductCopy.PlanHealthIntelligencePresentation.confidenceModerate
        )
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .appleHealthWorkouts })
        XCTAssertTrue(section.assumptions.items.contains { $0.id == "calorie-target" && !$0.isLimited })
    }

    func testLoaderFallsBackWhenSnapshotMissing() async {
        let context = makeContext()
        let baseline = HealthBaselineContext.empty(for: referenceDay)

        let loadResult = await PlanHealthIntelligenceSectionLoader.loadSection(
            profile: context.profile,
            context: context,
            isAppleHealthConnected: false,
            snapshotProvider: LoaderSnapshotService(snapshot: nil),
            baselineService: LoaderBaselineProvider(context: baseline),
            healthDataRepository: LoaderRepository(connected: false),
            calendar: calendar
        )
        let section = loadResult.sectionState

        XCTAssertEqual(section.dataQuality.qualityLevel, .limited)
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "connect-health" })
    }

    private func makeContext(
        weekLogs: [DailyLog] = [],
        allWeights: [WeightEntry] = []
    ) -> PlanDashboardContext {
        PlanDashboardContext(
            profile: PlanMissionControlFixtures.loseProfile,
            weekLogs: weekLogs,
            allWeights: allWeights,
            integrationState: .connected,
            dataSource: .appleHealth,
            asOf: referenceDay,
            calendar: calendar
        )
    }

    private func makeActiveWeekLogs() -> [DailyLog] {
        (0..<5).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: referenceDay)!
            return DailyLog(
                id: UUID(),
                date: date,
                weightKg: nil,
                targets: PlanMissionControlFixtures.loseProfile.targets,
                totals: MacroTotals(
                    calories: 2_200,
                    protein: 170,
                    carbs: 175,
                    fat: 55,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: 3_000,
                steps: nil,
                workoutCaloriesBurned: 0,
                dailyReviewId: nil,
                createdAt: date,
                updatedAt: date
            )
        }
    }

    private func makeActiveWeights() -> [WeightEntry] {
        [
            WeightEntry(
                id: UUID(),
                date: referenceDay,
                weightKg: 88.5,
                note: nil,
                createdAt: referenceDay
            )
        ]
    }

    private func makeSnapshot(on day: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 74,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable after recent training.",
                recommendedTraining: "Train based on how you feel.",
                recommendedNutrition: "Stay on your usual plan.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_450, activeEnergyKcal: 420, exerciseMinutes: 38),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            nextBestAction: .none
        )
    }

    private func makeBaseline(on day: Date) -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: day,
            averageSteps7d: 8_450,
            averageSteps28d: 7_900,
            averageActiveEnergy7d: 420,
            averageActiveEnergy28d: 390,
            averageSleepDuration7d: 426,
            averageSleepDuration28d: 408,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 52,
            averageWorkoutLoad28d: 180,
            workoutDays7d: 4,
            workoutDays28d: 12,
            availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv, .workoutLoad],
            missingSignals: []
        )
    }
}

// MARK: - Mocks

private struct LoaderSnapshotService: HealthIntelligenceSnapshotServing {
    let snapshot: HealthIntelligenceSnapshot?

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        snapshot
    }
}

private struct LoaderBaselineProvider: HealthBaselineProviding {
    let context: HealthBaselineContext

    func buildContext(for targetDate: Date, calendar: Calendar) async -> HealthBaselineContext {
        context
    }
}

private struct LoaderRepository: HealthDataRepositorying {
    let connected: Bool

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] { [] }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        .empty(for: date)
    }

    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] {
        []
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { [] }

    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] {
        []
    }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }

    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] {
        []
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }

    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] {
        []
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: connected,
            permissionStatus: connected
                ? .uniform(.available, isHealthDataAvailable: true)
                : .uniform(.denied, isHealthDataAvailable: true),
            cachedDayCount: connected ? 1 : 0
        )
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: 0, refreshedAt: Date())
    }
}
