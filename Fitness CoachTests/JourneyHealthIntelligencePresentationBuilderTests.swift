//
//  JourneyHealthIntelligencePresentationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyHealthIntelligencePresentationBuilderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
    }

    // MARK: - Feature flag

    func testBuildSectionReturnsNilWhenUIEnabledIsFalse() {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(currentSnapshot: makeCurrentSnapshot()),
            isUIEnabled: false
        )

        XCTAssertNil(section)
    }

    // MARK: - Loading / empty / error

    func testLoadingSectionUsesLoadingPlaceholders() {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(isLoading: true),
            calendar: calendar,
            isUIEnabled: true
        )

        XCTAssertNotNil(section)
        XCTAssertTrue(section?.isLoading == true)
        XCTAssertEqual(section?.recoveryTimeline.phase, .loading)
        XCTAssertEqual(section?.workoutHistory.phase, .loading)
        XCTAssertEqual(section?.milestones.phase, .loading)
        XCTAssertEqual(section?.progress.phase, .loading)
    }

    func testUnavailableSectionUsesEmptyStates() {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(),
            calendar: calendar,
            isUIEnabled: true
        )

        XCTAssertNotNil(section)
        XCTAssertEqual(section?.recoveryTimeline.phase, .empty)
        XCTAssertEqual(section?.workoutHistory.phase, .empty)
        XCTAssertNotNil(section?.errorMessage)
    }

    func testErrorSectionMapsErrorMessage() {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(errorMessage: "Network unavailable"),
            calendar: calendar,
            isUIEnabled: true
        )

        XCTAssertEqual(section?.errorMessage, "Network unavailable")
        XCTAssertEqual(section?.recoveryTimeline.phase, .error)
        XCTAssertEqual(section?.progress.errorMessage, "Network unavailable")
    }

    // MARK: - Recovery timeline

    func testRecoveryTimelineMapsDisplayFriendlyDayStates() {
        let timeline = JourneyHealthIntelligencePresentationBuilder.recoveryTimeline(
            from: historicalSnapshots,
            calendar: calendar
        )

        XCTAssertEqual(timeline.phase, .loaded)
        XCTAssertEqual(timeline.days.count, 7)
        XCTAssertFalse(timeline.days.first?.accessibilityLabel.isEmpty ?? true)
        XCTAssertFalse(timeline.days.contains { $0.shortExplanation?.lowercased().contains("hrv") == true })
    }

    func testRecoveryDaySanitizesRiskyMetricLanguage() {
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 55,
                status: .low,
                title: "Recovery is low",
                explanation: "HRV was below your recent baseline and sleep was short.",
                recommendedTraining: "Keep today lighter.",
                recommendedNutrition: "Fuel steadily.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )

        let day = JourneyHealthIntelligencePresentationBuilder.recoveryDay(
            from: snapshot,
            calendar: calendar
        )

        XCTAssertEqual(day.statusLabel, "Low")
        XCTAssertFalse(day.shortExplanation?.lowercased().contains("hrv") ?? true)
        XCTAssertFalse(day.shortExplanation?.contains("baseline") ?? true)
    }

    // MARK: - Workout history

    func testWorkoutHistoryMapsDurationAndDemandLabels() {
        let history = JourneyHealthIntelligencePresentationBuilder.workoutHistory(
            from: historicalSnapshots,
            calendar: calendar
        )

        XCTAssertEqual(history.phase, .loaded)
        XCTAssertFalse(history.items.isEmpty)
        XCTAssertTrue(history.items.contains { $0.durationLabel.contains("min") })
        XCTAssertTrue(history.items.contains { $0.demandLabel == "High demand" })
    }

    func testWorkoutHistoryEmptyWhenNoWorkouts() {
        let snapshots = historicalSnapshots.map { snapshot in
            HealthIntelligenceSnapshot(
                date: snapshot.date,
                recovery: snapshot.recovery,
                workout: nil,
                activity: snapshot.activity,
                nutritionAdjustment: snapshot.nutritionAdjustment,
                weeklyReview: snapshot.weeklyReview,
                planConfidence: snapshot.planConfidence,
                nextBestAction: snapshot.nextBestAction
            )
        }

        let history = JourneyHealthIntelligencePresentationBuilder.workoutHistory(
            from: snapshots,
            calendar: calendar
        )

        XCTAssertEqual(history.phase, .empty)
        XCTAssertTrue(history.items.isEmpty)
    }

    // MARK: - Milestones

    func testMilestonesMapWeeklyReviewWinsAndFocus() {
        let milestones = JourneyHealthIntelligencePresentationBuilder.milestones(
            from: makeWeeklyReview()
        )

        XCTAssertEqual(milestones.phase, .loaded)
        XCTAssertEqual(milestones.items.count, 4)
        XCTAssertTrue(milestones.items.contains { $0.status == .achieved })
        XCTAssertTrue(milestones.items.contains { $0.status == .inProgress })
    }

    // MARK: - Progress

    func testProgressMapsWeeklyStatsWithoutRawMetrics() {
        let progress = JourneyHealthIntelligencePresentationBuilder.progress(
            from: makeWeeklyReview()
        )

        XCTAssertEqual(progress.phase, .loaded)
        XCTAssertTrue(progress.detailLines.contains { $0.contains("4 workouts") })
        XCTAssertTrue(progress.metrics.contains { $0.id == "workouts" })
        XCTAssertFalse(progress.accessibilityLabel.lowercased().contains("hrv"))
    }

    // MARK: - Weekly review preview

    func testWeeklyReviewPreviewMapsWeekRangeAndSummary() {
        let preview = JourneyHealthIntelligencePresentationBuilder.weeklyReviewPreview(
            from: makeWeeklyReview(),
            calendar: calendar
        )

        XCTAssertNotNil(preview)
        XCTAssertEqual(preview?.title, "Solid training week")
        XCTAssertFalse(preview?.weekRangeLabel.isEmpty ?? true)
        XCTAssertEqual(preview?.winLines.count, 2)
        XCTAssertEqual(preview?.focusLines.count, 2)
    }

    // MARK: - Section integration

    func testStrongWeekSectionIncludesAllSubsections() {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(
                currentSnapshot: makeCurrentSnapshot(),
                historicalSnapshots: historicalSnapshots
            ),
            calendar: calendar,
            isUIEnabled: true
        )

        XCTAssertNotNil(section)
        XCTAssertNotNil(section?.weeklyReviewPreview)
        XCTAssertEqual(section?.recoveryTimeline.phase, .loaded)
        XCTAssertEqual(section?.workoutHistory.phase, .loaded)
        XCTAssertEqual(section?.milestones.phase, .loaded)
        XCTAssertEqual(section?.progress.phase, .loaded)
    }

    func testCodableRoundTripForSectionState() throws {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(
                currentSnapshot: makeCurrentSnapshot(),
                historicalSnapshots: historicalSnapshots
            ),
            calendar: calendar,
            isUIEnabled: true
        )!

        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(JourneyHealthIntelligenceSectionState.self, from: data)

        XCTAssertEqual(decoded, section)
    }

    // MARK: - Fixtures

    private func makeCurrentSnapshot() -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 74,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable after recent training.",
                recommendedTraining: "You can train, but avoid stacking intensity tonight.",
                recommendedNutrition: "Prioritize protein and hydration after your workout.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .strength,
                title: "Strength training",
                workoutCount: 1,
                totalDurationMinutes: 50,
                totalActiveCalories: 320,
                intensity: .moderate,
                demand: .high,
                latestWorkoutStart: referenceDay,
                latestWorkoutEnd: referenceDay,
                nutritionAdvice: "Aim for 30–40g protein in your next meal.",
                hydrationAdviceMl: 700,
                explanation: "Strength training added meaningful load today.",
                confidence: .high,
                sourceSummary: "Synced workout."
            ),
            activity: ActivitySummary(steps: 9_120, activeEnergyKcal: 560, exerciseMinutes: 52),
            nutritionAdjustment: .none,
            weeklyReview: makeWeeklyReview(),
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            nextBestAction: .none
        )
    }

    private func makeWeeklyReview() -> WeeklyHealthReview {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: referenceDay)!
        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: referenceDay,
            title: "Solid training week",
            summary: "You logged consistent workouts and kept protein on track most days.",
            stats: WeeklyStats(
                totalWorkouts: 4,
                totalWorkoutMinutes: 210,
                totalActiveCalories: 1_420,
                averageSteps: 8_200,
                totalSteps: 57_400,
                proteinHitDays: 5,
                calorieTargetHitDays: 4,
                waterHitDays: 3,
                averageRecoveryScore: 68,
                lowRecoveryDays: 1,
                weightChangeKg: -0.3,
                loggingConsistencyDays: 6
            ),
            wins: ["4 workouts logged", "Protein on target 5 days"],
            risks: ["Hydration dipped mid-week"],
            nextWeekFocus: ["Front-load water", "Keep one rest day lighter"],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: referenceDay
        )
    }

    private var historicalSnapshots: [HealthIntelligenceSnapshot] {
        (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: referenceDay) else {
                return nil
            }
            let hasWorkout = offset == 0 || offset == 2
            return HealthIntelligenceSnapshot(
                date: day,
                recovery: RecoverySummary(
                    score: offset == 1 ? 52 : 72,
                    status: offset == 1 ? .low : .moderate,
                    title: offset == 1 ? "Recovery is low" : "Moderate recovery",
                    explanation: offset == 1
                        ? "Sleep was short and recent training load is elevated."
                        : "Recovery is acceptable after recent training.",
                    recommendedTraining: "Train based on how you feel.",
                    recommendedNutrition: "Stay on your usual plan.",
                    confidence: .moderate,
                    contributingFactors: [],
                    missingSignals: []
                ),
                workout: hasWorkout
                    ? WorkoutSummary(
                        hasWorkout: true,
                        primaryWorkoutType: .strength,
                        title: "Strength training",
                        workoutCount: 1,
                        totalDurationMinutes: 45 + offset * 2,
                        totalActiveCalories: 300,
                        intensity: .moderate,
                        demand: .high,
                        latestWorkoutStart: day,
                        latestWorkoutEnd: day,
                        nutritionAdvice: "",
                        hydrationAdviceMl: 0,
                        explanation: "Meaningful training load logged.",
                        confidence: .high,
                        sourceSummary: ""
                    )
                    : nil,
                activity: ActivitySummary(steps: 7_000 + offset * 200, activeEnergyKcal: 400, exerciseMinutes: 30),
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: .unknown,
                nextBestAction: .none
            )
        }
    }
}
