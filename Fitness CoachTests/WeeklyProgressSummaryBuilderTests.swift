//
//  WeeklyProgressSummaryBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for WeeklyProgressSummaryBuilder assembly behavior.
//

import XCTest
@testable import Fitness_Coach

final class WeeklyProgressSummaryBuilderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private var referenceDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 12))!
    }

    private var builder: WeeklyProgressSummaryBuilder {
        WeeklyProgressSummaryBuilder(calendar: calendar, now: { [self] in self.referenceDate })
    }

    private var profile: UserProfile {
        PlanMissionControlFixtures.loseProfile
    }

    // MARK: - Confidence tiers

    func testBuildsInsufficientDataSummaryForEmptyLogs() {
        let summary = builder.buildSummary(
            asOf: referenceDate,
            profile: profile,
            dailyLogs: [],
            weightEntries: [],
            trainingDayStarts: nil
        )

        XCTAssertEqual(summary.verdict, .notEnoughData)
        XCTAssertEqual(summary.confidence, .unavailable)
        XCTAssertEqual(summary.nextAction, .keepLogging)
        XCTAssertEqual(summary.foodLoggedDays, 0)
    }

    func testBuildsLowConfidenceSummaryForSevenDayWindow() {
        let logs = makeSpanLogs(
            spanDays: 7,
            foodLoggedDays: 6,
            referenceDate: referenceDate,
            targets: profile.targets
        )
        let weights = makeGradualWeightEntries(
            referenceDate: referenceDate,
            count: 3,
            startKg: 80,
            weeklyChangeKg: -0.4
        )

        let summary = buildSummary(logs: logs, weights: weights)

        XCTAssertEqual(summary.confidence, .low)
        XCTAssertTrue(summary.maintenanceEstimate.sufficiency.isEligibleForMaintenanceEstimate)
        XCTAssertFalse(summary.maintenanceEstimate.sufficiency.isEligibleForKcalMaintenanceDisplay)
    }

    func testBuildsMediumConfidenceSummaryForFourteenDayWindow() {
        let logs = makeSpanLogs(
            spanDays: 14,
            foodLoggedDays: 10,
            referenceDate: referenceDate,
            targets: profile.targets
        )
        let weights = makeGradualWeightEntries(
            referenceDate: referenceDate,
            count: 4,
            startKg: 80,
            weeklyChangeKg: -0.5
        )

        let summary = buildSummary(logs: logs, weights: weights)

        XCTAssertEqual(summary.confidence, .medium)
        XCTAssertTrue(summary.maintenanceEstimate.sufficiency.isEligibleForKcalMaintenanceDisplay)
    }

    func testBuildsHighConfidenceSummaryForTwentyEightDayWindow() {
        let logs = makeSpanLogs(
            spanDays: 28,
            foodLoggedDays: 20,
            referenceDate: referenceDate,
            targets: profile.targets
        )
        let weights = makeGradualWeightEntries(
            referenceDate: referenceDate,
            count: 5,
            startKg: 80,
            weeklyChangeKg: -0.5
        )

        let summary = buildSummary(logs: logs, weights: weights)

        XCTAssertEqual(summary.confidence, .high)
        XCTAssertTrue(summary.maintenanceEstimate.sufficiency.isEligibleForKcalMaintenanceDisplay)
    }

    // MARK: - Metric counting

    func testCountsFoodLoggedDaysCorrectly() {
        let targets = profile.targets
        let logs = [
            makeLog(dayOffset: -7, calories: 2_000, protein: 150, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -5, calories: 2_100, protein: 150, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -3, calories: 1_900, protein: 150, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -1, calories: 2_050, protein: 150, waterMl: 3_000, targets: targets)
        ]

        let summary = buildSummary(
            logs: logs,
            weights: makeGradualWeightEntries(referenceDate: referenceDate, count: 3, startKg: 80, weeklyChangeKg: -0.3)
        )

        XCTAssertEqual(summary.foodLoggedDays, 4)
    }

    func testCountsProteinHitDaysCorrectly() {
        let targets = profile.targets
        let hitProtein = Int(Double(targets.proteinTarget) * JourneyLogMetrics.proteinHitThreshold)
        let belowProtein = hitProtein - 10

        let logs = [
            makeLog(dayOffset: -7, calories: 2_000, protein: hitProtein, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -6, calories: 2_000, protein: belowProtein, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -5, calories: 2_000, protein: hitProtein, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -4, calories: 2_000, protein: hitProtein, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -3, calories: 2_000, protein: hitProtein, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -2, calories: 2_000, protein: hitProtein, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -1, calories: 2_000, protein: hitProtein, waterMl: 3_000, targets: targets)
        ]

        let summary = buildSummary(
            logs: logs,
            weights: makeGradualWeightEntries(referenceDate: referenceDate, count: 3, startKg: 80, weeklyChangeKg: -0.3)
        )

        XCTAssertEqual(summary.proteinHitDays, 6)
    }

    func testCountsCalorieTargetHitDaysCorrectly() {
        let targets = profile.targets
        let onTarget = targets.calorieTarget
        let offTarget = Int(Double(targets.calorieTarget) * 1.25)

        let logs = (0..<7).map { offset in
            let calories = offset.isMultiple(of: 2) ? onTarget : offTarget
            return makeLog(
                dayOffset: -(7 - offset),
                calories: calories,
                protein: 150,
                waterMl: 3_000,
                targets: targets
            )
        }

        let summary = buildSummary(
            logs: logs,
            weights: makeGradualWeightEntries(referenceDate: referenceDate, count: 3, startKg: 80, weeklyChangeKg: -0.3)
        )

        XCTAssertEqual(summary.calorieTargetHitDays, 4)
    }

    func testCountsWaterTargetHitDaysCorrectly() {
        let targets = profile.targets
        let hitWater = Int(Double(targets.waterTargetMl) * JourneyLogMetrics.waterHitThreshold)
        let belowWater = hitWater - 200

        let logs = (0..<7).map { offset in
            let water = offset.isMultiple(of: 2) ? hitWater : belowWater
            return makeLog(
                dayOffset: -(7 - offset),
                calories: 2_000,
                protein: 150,
                waterMl: water,
                targets: targets
            )
        }

        let summary = buildSummary(
            logs: logs,
            weights: makeGradualWeightEntries(referenceDate: referenceDate, count: 3, startKg: 80, weeklyChangeKg: -0.3)
        )

        XCTAssertEqual(summary.waterTargetHitDays, 4)
    }

    func testTreatsMissingFoodAsMissingNotZero() {
        let targets = profile.targets
        let logs = [
            makeLog(dayOffset: -7, calories: 2_000, protein: 150, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -6, calories: 0, protein: 0, waterMl: 0, targets: targets),
            makeLog(dayOffset: -5, calories: 2_000, protein: 150, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -4, calories: 2_000, protein: 150, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -3, calories: 2_000, protein: 150, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -2, calories: 2_000, protein: 150, waterMl: 3_000, targets: targets),
            makeLog(dayOffset: -1, calories: 2_000, protein: 150, waterMl: 3_000, targets: targets)
        ]

        let summary = buildSummary(
            logs: logs,
            weights: makeGradualWeightEntries(referenceDate: referenceDate, count: 3, startKg: 80, weeklyChangeKg: -0.3)
        )

        XCTAssertEqual(summary.foodLoggedDays, 6)
        XCTAssertNotEqual(summary.averageDailyCalories, 0)
    }

    // MARK: - Targets

    func testUsesFrozenDailyTargetsWhenAvailable() {
        let frozenTargets = UserTargets(
            calorieTarget: 1_800,
            proteinTarget: 200,
            carbTarget: 150,
            fatTarget: 50,
            waterTargetMl: 4_000,
            expectedWeeklyWeightLossKg: 0.8,
            aggressiveness: .aggressive
        )
        let hitProtein = Int(Double(frozenTargets.proteinTarget) * JourneyLogMetrics.proteinHitThreshold)

        let logs = (0..<7).map { offset in
            makeLog(
                dayOffset: -(7 - offset),
                calories: frozenTargets.calorieTarget,
                protein: hitProtein,
                waterMl: frozenTargets.waterTargetMl,
                targets: frozenTargets
            )
        }

        let summary = buildSummary(
            logs: logs,
            weights: makeGradualWeightEntries(referenceDate: referenceDate, count: 3, startKg: 80, weeklyChangeKg: -0.3)
        )

        XCTAssertEqual(summary.proteinHitDays, 7)
        XCTAssertEqual(summary.calorieTargetHitDays, 7)
        XCTAssertEqual(summary.waterTargetHitDays, 7)
    }

    func testFallsBackToProfileTargetsWhenDailyTargetsMissing() {
        let emptyTargets = UserTargets(
            calorieTarget: 0,
            proteinTarget: 0,
            carbTarget: 0,
            fatTarget: 0,
            waterTargetMl: 0,
            expectedWeeklyWeightLossKg: nil,
            aggressiveness: .moderate
        )
        let hitProtein = Int(Double(profile.targets.proteinTarget) * JourneyLogMetrics.proteinHitThreshold)

        let logs = (0..<7).map { offset in
            makeLog(
                dayOffset: -(7 - offset),
                calories: profile.targets.calorieTarget,
                protein: hitProtein,
                waterMl: profile.targets.waterTargetMl,
                targets: emptyTargets
            )
        }

        let summary = buildSummary(
            logs: logs,
            weights: makeGradualWeightEntries(referenceDate: referenceDate, count: 3, startKg: 80, weeklyChangeKg: -0.3)
        )

        XCTAssertEqual(summary.proteinHitDays, 7)
        XCTAssertEqual(summary.calorieTargetHitDays, 7)
    }

    // MARK: - Caveats & actions

    func testIncludesWeightSpikeCaveat() {
        let logs = makeSpanLogs(
            spanDays: 14,
            foodLoggedDays: 10,
            referenceDate: referenceDate,
            targets: profile.targets
        )
        let weekEnd = calendar.date(byAdding: .day, value: -1, to: referenceDate)!
        let weights = [
            WeightEntry(id: UUID(), date: calendar.date(byAdding: .day, value: -3, to: weekEnd)!, weightKg: 80.0, note: nil, createdAt: weekEnd),
            WeightEntry(id: UUID(), date: calendar.date(byAdding: .day, value: -2, to: weekEnd)!, weightKg: 81.5, note: nil, createdAt: weekEnd),
            WeightEntry(id: UUID(), date: calendar.date(byAdding: .day, value: -1, to: weekEnd)!, weightKg: 81.4, note: nil, createdAt: weekEnd),
            WeightEntry(id: UUID(), date: weekEnd, weightKg: 81.2, note: nil, createdAt: weekEnd)
        ]

        let summary = buildSummary(logs: logs, weights: weights)

        XCTAssertTrue(summary.hasSuddenSpike)
        XCTAssertTrue(
            summary.caveats.contains {
                $0.contains(FormaProductCopy.WeightSpikeEducation.shortBody)
                    || summary.maintenanceEstimate.shouldShowWaterWeightDisclaimer
            }
            || summary.maintenanceEstimate.shouldShowWaterWeightDisclaimer
        )
    }

    func testBuildsHoldSteadyNextActionWhenOnTrack() {
        let logs = makeSpanLogs(
            spanDays: 14,
            foodLoggedDays: 10,
            referenceDate: referenceDate,
            targets: profile.targets,
            calories: profile.targets.calorieTarget
        )
        let weights = makeGradualWeightEntries(
            referenceDate: referenceDate,
            count: 4,
            startKg: 80,
            weeklyChangeKg: -0.5
        )

        let summary = buildSummary(logs: logs, weights: weights)

        XCTAssertEqual(summary.verdict, .onTrack)
        XCTAssertEqual(summary.nextAction, .holdSteady)
    }

    func testBuildsImproveConsistencyNextActionWhenLogsAreSparse() {
        let targets = profile.targets
        let intake = targets.calorieTarget
        let hitProtein = Int(Double(targets.proteinTarget) * JourneyLogMetrics.proteinHitThreshold)
        let hitWater = Int(Double(targets.waterTargetMl) * JourneyLogMetrics.waterHitThreshold)

        let sparseOffsets = [-13, -12, -11, -3, -2]
        let logs = sparseOffsets.map { offset in
            makeLog(
                dayOffset: offset,
                calories: intake,
                protein: hitProtein,
                waterMl: hitWater,
                targets: targets
            )
        }
        let weights = makeGradualWeightEntries(
            referenceDate: referenceDate,
            count: 3,
            startKg: 80,
            weeklyChangeKg: -0.3
        )

        let summary = buildSummary(logs: logs, weights: weights)

        XCTAssertEqual(summary.verdict, .needsConsistencyFirst)
        XCTAssertEqual(summary.nextAction, .improveLoggingConsistency)
    }

    func testDoesNotRequireHealthKitForCoreSummary() {
        let logs = makeSpanLogs(
            spanDays: 7,
            foodLoggedDays: 6,
            referenceDate: referenceDate,
            targets: profile.targets
        )
        let weights = makeGradualWeightEntries(
            referenceDate: referenceDate,
            count: 3,
            startKg: 80,
            weeklyChangeKg: -0.4
        )

        let summary = builder.buildSummary(
            asOf: referenceDate,
            profile: profile,
            dailyLogs: logs,
            weightEntries: weights,
            trainingDayStarts: nil
        )

        XCTAssertNotEqual(summary.verdict, .notEnoughData)
        XCTAssertNil(summary.trainingDays)
    }

    // MARK: - Helpers

    private func buildSummary(
        logs: [DailyLog],
        weights: [WeightEntry]
    ) -> WeeklyProgressSummary {
        builder.buildSummary(
            asOf: referenceDate,
            profile: profile,
            dailyLogs: logs,
            weightEntries: weights,
            trainingDayStarts: []
        )
    }

    private func makeSpanLogs(
        spanDays: Int,
        foodLoggedDays: Int,
        referenceDate: Date,
        targets: UserTargets,
        calories: Int? = nil,
        logEveryDayInReviewWeek: Bool = true
    ) -> [DailyLog] {
        let intake = calories ?? targets.calorieTarget
        let hitProtein = Int(Double(targets.proteinTarget) * JourneyLogMetrics.proteinHitThreshold)
        let hitWater = Int(Double(targets.waterTargetMl) * JourneyLogMetrics.waterHitThreshold)

        let reviewWeekEnd = calendar.date(byAdding: .day, value: -1, to: referenceDate)!
        let reviewWeekStart = calendar.date(byAdding: .day, value: -6, to: reviewWeekEnd)!
        let spanStart = calendar.date(byAdding: .day, value: -(spanDays - 1), to: referenceDate)!

        var foodDaysRemaining = foodLoggedDays
        var logs: [DailyLog] = []
        var day = calendar.startOfDay(for: spanStart)

        while day <= calendar.startOfDay(for: referenceDate) {
            let isInReviewWeek = day >= reviewWeekStart && day <= reviewWeekEnd
            let shouldHaveFood: Bool

            if isInReviewWeek && logEveryDayInReviewWeek {
                shouldHaveFood = true
            } else if foodDaysRemaining > 0 {
                shouldHaveFood = true
                foodDaysRemaining -= 1
            } else {
                shouldHaveFood = false
            }

            let dayOffset = calendar.dateComponents([.day], from: referenceDate, to: day).day ?? 0
            logs.append(
                makeLog(
                    dayOffset: dayOffset,
                    calories: shouldHaveFood ? intake : 0,
                    protein: shouldHaveFood ? hitProtein : 0,
                    waterMl: shouldHaveFood ? hitWater : 0,
                    targets: targets
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
        }

        return logs
    }

    private func makeLog(
        dayOffset: Int,
        calories: Int,
        protein: Int,
        waterMl: Int,
        targets: UserTargets,
        weightKg: Double? = nil
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate)!
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: weightKg,
            targets: targets,
            totals: MacroTotals(
                calories: calories,
                protein: Double(protein),
                carbs: 0,
                fat: 0,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    private func makeGradualWeightEntries(
        referenceDate: Date,
        count: Int,
        startKg: Double,
        weeklyChangeKg: Double
    ) -> [WeightEntry] {
        let weekEnd = calendar.date(byAdding: .day, value: -1, to: referenceDate)!
        return (0..<count).map { index in
            let dayOffset = -((count - 1 - index) * 2)
            let date = calendar.date(byAdding: .day, value: dayOffset, to: weekEnd)!
            let progress = Double(index) / Double(max(count - 1, 1))
            let weight = startKg + (weeklyChangeKg * progress)
            return WeightEntry(
                id: UUID(),
                date: date,
                weightKg: weight,
                note: nil,
                createdAt: date
            )
        }
    }
}
