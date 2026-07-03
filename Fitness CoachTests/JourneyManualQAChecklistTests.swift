//
//  JourneyManualQAChecklistTests.swift
//  Fitness CoachTests
//
//  Executable manual QA checklist for the redesigned Journey dashboard.
//  Each test maps 1:1 to a product QA scenario.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class JourneyManualQAChecklistTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    private let asOf = ProfileTestFixtures.referenceDate

    // MARK: - 1. New user after onboarding

    func testManualQA01_NewUserAfterOnboarding() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertTrue(dashboard.hasProfile)
        XCTAssertNotNil(dashboard.baseline.startWeightKg)
        XCTAssertEqual(dashboard.baseline.startWeightKg ?? 0, 82, accuracy: 0.01)
        XCTAssertTrue(dashboard.baseline.usesSyntheticBaselinePoint)
        XCTAssertTrue(dashboard.baseline.showsWeightChart)
        XCTAssertGreaterThanOrEqual(dashboard.baseline.chartPoints.count, 1)
        XCTAssertFalse(dashboard.transformation.primaryMessage.isEmpty)
        XCTAssertFalse(dashboard.transformation.accessibilitySummary.isEmpty)
    }

    // MARK: - 2. One weight log

    func testManualQA02_OneWeightLogShowsBaselineToTodayWithoutDuplicatePoints() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 90
        profile.goalWeightKg = 80

        let logDate = calendar.date(byAdding: .day, value: -3, to: asOf)!
        let weights = [makeWeight(date: logDate, kg: 88)]

        let baseline = JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: profile,
                allWeights: weights,
                maturityLogs: [],
                goalProjection: nil,
                asOf: asOf,
                calendar: calendar
            )
        )

        XCTAssertEqual(baseline.currentWeightKg ?? 0, 88, accuracy: 0.01)
        XCTAssertNotNil(baseline.progressPercent)
        XCTAssertTrue(baseline.showsWeightChart)

        let dayKeys = baseline.chartPoints.map { calendar.startOfDay(for: $0.date) }
        XCTAssertEqual(dayKeys.count, Set(dayKeys).count, "Chart must not duplicate same-day points")
        XCTAssertTrue(baseline.showsWeightChart)
        XCTAssertNotNil(baseline.progressPercent)
    }

    // MARK: - 3. Two or more weight logs

    func testManualQA03_MultipleWeightLogsShowTrendAndLatestHeroWeight() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 90
        profile.goalWeightKg = 80

        let weights = [
            makeWeight(date: calendar.date(byAdding: .day, value: -14, to: asOf)!, kg: 90),
            makeWeight(date: calendar.date(byAdding: .day, value: -7, to: asOf)!, kg: 87),
            makeWeight(date: asOf, kg: 85)
        ]

        let baseline = JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: profile,
                allWeights: weights,
                maturityLogs: [],
                goalProjection: nil,
                asOf: asOf,
                calendar: calendar
            )
        )

        XCTAssertEqual(baseline.currentWeightKg ?? 0, 85, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(baseline.chartPoints.filter { !$0.isSynthetic }.count, 3)
        XCTAssertGreaterThan(baseline.progressPercent ?? 0, 0)

        let hero = JourneyHeroBuilder.build(
            JourneyHeroBuilder.Input(
                baseline: baseline,
                loggedDays: 0,
                journeyStreaks: JourneyStreakState(
                    currentLoggingStreakDays: 0,
                    longestLoggingStreakDays: 0,
                    currentProteinStreakDays: 0,
                    currentWaterStreakDays: 0,
                    currentTrainingStreakWeeks: nil,
                    isTodayLogged: false,
                    heroStreakChip: .hidden,
                    weeklyConsistencyHeadline: "",
                    weeklyConsistencyDetail: nil,
                    keepStreakAliveCopy: nil
                ),
                hasProfile: true,
                asOf: asOf,
                calendar: calendar
            )
        )
        XCTAssertEqual(hero.variant, .newUser)
    }

    // MARK: - 4. Food logging

    func testManualQA04_FoodLoggingUpdatesWeeklyReviewAndTimeline() async throws {
        let now = Date()
        let harness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: now)
        _ = try harness.seedProfile()

        let logsBefore = try harness.dailyLogService.getLogs(
            from: calendar.date(byAdding: .day, value: -6, to: now)!,
            to: now
        )
        let dashboardBefore = buildDashboard(
            maturityLogs: try harness.dailyLogService.getLogs(
                from: calendar.date(byAdding: .day, value: -365, to: now)!,
                to: now
            ),
            weekLogs: logsBefore,
            isAppleHealthConnected: false,
            asOf: now
        )
        XCTAssertEqual(dashboardBefore.weeklyReview.foodLoggedDays, 0)

        _ = try harness.base.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Lunch", calories: 650, protein: 40),
            date: now
        )

        let logsAfter = try harness.dailyLogService.getLogs(
            from: calendar.date(byAdding: .day, value: -6, to: now)!,
            to: now
        )
        let maturityAfter = try harness.dailyLogService.getLogs(
            from: calendar.date(byAdding: .day, value: -365, to: now)!,
            to: now
        )
        let dashboardAfter = buildDashboard(
            maturityLogs: maturityAfter,
            weekLogs: logsAfter,
            isAppleHealthConnected: false,
            asOf: now
        )

        XCTAssertEqual(dashboardAfter.weeklyReview.foodLoggedDays, 1)
        XCTAssertTrue(
            dashboardAfter.storyTimeline.displayEvents.contains { $0.type == .firstMealLogged }
                || dashboardAfter.storyTimeline.events.contains { $0.type == .firstMealLogged }
        )
    }

    // MARK: - 5. Water logging

    func testManualQA05_WaterLoggingUpdatesWeeklyReview() {
        let logs = (0..<6).map { offset in
            makeLog(
                daysAgo: offset,
                calories: 1_800,
                protein: 80,
                waterMl: offset == 0 ? 2_500 : 500
            )
        }

        let dashboard = buildDashboard(
            maturityLogs: logs,
            weekLogs: Array(logs.prefix(7)),
            isAppleHealthConnected: false
        )

        XCTAssertGreaterThan(dashboard.weeklyReview.waterGoalDays, 0)
    }

    // MARK: - 8. Milestones

    func testManualQA08_KeyMilestonesUnlockInOrder() {
        var profile = ProfileTestFixtures.sampleProfile
        profile.currentWeightKg = 90
        profile.goalWeightKg = 80

        let logs = (0..<30).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 130, waterMl: 2_400)
        }
        let weights = [
            makeWeight(date: calendar.date(byAdding: .day, value: -30, to: asOf)!, kg: 90),
            makeWeight(date: asOf, kg: 88.5)
        ]

        let dashboard = buildDashboard(
            profile: profile,
            maturityLogs: logs,
            weekLogs: Array(logs.prefix(7)),
            allWeights: weights,
            isAppleHealthConnected: false
        )

        let unlockedIDs = Set(dashboard.milestones.unlocked.map(\.id))
        XCTAssertTrue(unlockedIDs.contains("first-meal"))
        XCTAssertTrue(unlockedIDs.contains("first-week"))
        XCTAssertTrue(unlockedIDs.contains("first-kg"))
        XCTAssertTrue(unlockedIDs.contains("protein-three-week"))
        XCTAssertTrue(unlockedIDs.contains("water-three-week"))
        XCTAssertTrue(dashboard.milestone.isVisible)
        XCTAssertFalse(dashboard.milestones.items.contains(where: { $0.status == .upcoming }))
    }

    // MARK: - 9. Story Timeline

    func testManualQA09_StoryTimelineOrderedWithoutDuplicates() {
        let logs = (0..<10).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 120, waterMl: 2_000)
        }

        let timeline = buildDashboard(
            maturityLogs: logs,
            weekLogs: Array(logs.prefix(7)),
            isAppleHealthConnected: false
        ).storyTimeline

        let display = timeline.displayEvents
        XCTAssertFalse(display.isEmpty)

        let ids = display.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)

        let rawDates = timeline.events.map(\.date)
        XCTAssertEqual(rawDates, rawDates.sorted(by: >), "Raw timeline events should be newest-first")

        if let anchorIndex = display.firstIndex(where: { $0.type == .onboardingStarted }),
           anchorIndex == display.count - 1 {
            let nonAnchorDates = display.dropLast().map(\.date)
            XCTAssertEqual(nonAnchorDates, nonAnchorDates.sorted(by: >))
        }

        for event in display {
            XCTAssertFalse(event.title.isEmpty)
            XCTAssertFalse(event.icon.isEmpty)
        }
    }

    // MARK: - 10. Apple Health disconnected

    func testManualQA10_AppleHealthDisconnectedSafeTrainingState() {
        let dashboard = JourneyPreviewData.healthDisconnected

        XCTAssertEqual(dashboard.weeklyReview.training, .locked)
        let trainingRow = dashboard.weeklyReview.rows.first { $0.id == "training" }
        if let trainingRow {
            XCTAssertFalse(trainingRow.value.localizedCaseInsensitiveContains("fail"))
        }
    }

    // MARK: - 11. Apple Health connected

    func testManualQA11_AppleHealthConnectedCountsWorkoutDays() {
        let workoutDay = calendar.startOfDay(for: asOf)
        let logs = (0..<5).map { makeLog(daysAgo: $0, calories: 1_800, protein: 120) }

        let dashboard = buildDashboard(
            maturityLogs: logs,
            weekLogs: logs,
            healthWorkoutDays: [workoutDay],
            isAppleHealthConnected: true
        )

        XCTAssertEqual(dashboard.weeklyReview.trainingDays, 1)
        XCTAssertTrue(dashboard.weeklyReview.training.showsWorkoutRow)
    }

    // MARK: - 12. Gain goal

    func testManualQA12_GainGoalCopyAndMilestones() {
        let dashboard = JourneyPreviewData.gainGoal

        XCTAssertNotEqual(dashboard.transformation.variant, .weightLossProgress)
        XCTAssertFalse(dashboard.transformation.primaryMessage.localizedCaseInsensitiveContains("lost"))
        XCTAssertFalse(dashboard.transformation.primaryMessage.contains("0 kg"))
        XCTAssertEqual(dashboard.baseline.goalDirection, .gain)

        let firstKg = dashboard.milestones.items.first { $0.id == "first-kg" }
        XCTAssertEqual(
            firstKg?.title,
            FormaProductCopy.Journey.Milestones.NextAchievement.firstKgGainTitle
        )
    }

    // MARK: - 13. Maintain goal

    func testManualQA13_MaintainGoalStableCopy() {
        let dashboard = JourneyPreviewData.maintainGoal

        XCTAssertEqual(dashboard.baseline.goalDirection, .maintain)
        XCTAssertFalse(dashboard.transformation.primaryMessage.localizedCaseInsensitiveContains("lost"))
        XCTAssertFalse(dashboard.transformation.primaryMessage.localizedCaseInsensitiveContains("0 kg"))
    }

    // MARK: - 14. Pull to refresh

    func testManualQA14_JourneyRefreshReloadsSafelyAfterDataChange() async throws {
        let now = Date()
        let harness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: now)
        _ = try harness.seedProfile()

        let model = makeJourneyModel(harness: harness, trainingConnected: false)
        await model.loadProgress()
        await model.refresh()

        if case .error = model.viewState {
            XCTFail("Refresh must not surface error on empty profile")
        }

        _ = try harness.base.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Snack", calories: 200, protein: 10),
            date: now
        )
        await model.refresh()

        if case .error = model.viewState {
            XCTFail("Refresh must not surface error after local log")
        }
        if case .loaded(let state) = model.viewState {
            XCTAssertGreaterThanOrEqual(state.weeklyReview.foodLoggedDays, 1)
        }
    }

    // MARK: - 15. Dynamic Type and VoiceOver

    func testManualQA15_AccessibilityStringsPresentForHeroProgressAndMilestones() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertFalse(dashboard.transformation.accessibilitySummary.isEmpty)
        XCTAssertFalse(dashboard.transformation.progressBarAccessibilityValue.isEmpty)
        XCTAssertTrue(
            dashboard.transformation.accessibilitySummary.localizedCaseInsensitiveContains("progress")
                || dashboard.transformation.accessibilitySummary.localizedCaseInsensitiveContains("%")
        )

        XCTAssertFalse(dashboard.milestone.accessibilitySummary.isEmpty)
        XCTAssertFalse(dashboard.milestone.title.isEmpty)
        XCTAssertFalse(dashboard.milestone.progressText.isEmpty)
    }

    // MARK: - Canonical layout smoke

    func testManualQA_LeanLayoutMountsOnlyRevampSections() {
        let order = JourneyProductLayout.sectionOrder.map(\.rawValue)
        XCTAssertEqual(order.first, "header")
        XCTAssertTrue(order.contains("transformation"))
        XCTAssertTrue(order.contains("goalProjection"))
        XCTAssertTrue(order.contains("healthIntelligence"))
        XCTAssertTrue(order.contains("weeklyReview"))
        XCTAssertTrue(order.contains("insights"))
        XCTAssertTrue(order.contains("milestones"))
        XCTAssertTrue(order.contains("storyTimeline"))
        XCTAssertTrue(order.contains("monthlyRecap"))
        XCTAssertTrue(order.contains("chapters"))
        XCTAssertEqual(order.last, "startingEmptyState")
        XCTAssertFalse(order.contains("detailedAnalytics"))
        XCTAssertFalse(order.contains("consistencyCalendar"))
        XCTAssertFalse(order.contains("beforeToday"))
        XCTAssertFalse(order.contains("journeyLevel"))
    }

    // MARK: - Helpers

    private func makeJourneyModel(
        harness: FitnessActionCenterTestSupport.Harness,
        trainingConnected: Bool
    ) -> JourneyModel {
        let integration = StubTrainingIntegrationProvider(
            refreshResult: trainingConnected ? .connected : .notConnected
        )
        let trainingStore = TrainingInsightsStore(integration: integration)
        return JourneyModel(
            dailyLogReader: harness.dailyLogService,
            weightLogReader: harness.weightLogService,
            userProfileReader: harness.profileService,
            trainingInsightsStore: trainingStore,
            workoutReader: MockHealthKitWorkoutReader(workouts: [])
        )
    }

    private func loadDashboard(
        harness: FitnessActionCenterTestSupport.Harness,
        trainingConnected: Bool
    ) async throws -> JourneyDashboardState {
        let model = makeJourneyModel(harness: harness, trainingConnected: trainingConnected)
        await model.refresh()
        guard case .loaded(let state) = model.viewState else {
            throw ServiceError.invalidInput("Journey did not load")
        }
        return state
    }

    private func buildDashboard(
        profile: UserProfile? = ProfileTestFixtures.sampleProfile,
        maturityLogs: [DailyLog],
        weekLogs: [DailyLog],
        allWeights: [WeightEntry] = [],
        weekWeights: [WeightEntry]? = nil,
        healthWorkoutDays: Set<Date> = [],
        weightSummary: ProgressWeightSummary = ProgressWeightSummary(
            latestWeightKg: nil,
            changeKg: nil,
            direction: .insufficientData,
            hasSuddenSpike: false
        ),
        isAppleHealthConnected: Bool,
        asOf: Date? = nil
    ) -> JourneyDashboardState {
        let resolvedAsOf = asOf ?? self.asOf
        let resolvedWeekWeights = weekWeights ?? allWeights
        let baseline = JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: profile,
                allWeights: allWeights,
                maturityLogs: maturityLogs,
                goalProjection: nil,
                asOf: resolvedAsOf,
                calendar: calendar
            )
        )

        let streakSummary = StreakCalculator.calculate(
            logs: maturityLogs,
            workoutDates: healthWorkoutDays,
            asOf: resolvedAsOf,
            calendar: calendar
        )
        let journeyStreaks = JourneyStreakBuilder.build(
            JourneyStreakBuilder.Input(
                streakSummary: streakSummary,
                maturityLogs: maturityLogs,
                workoutDates: healthWorkoutDays,
                isAppleHealthConnected: isAppleHealthConnected,
                asOf: resolvedAsOf,
                calendar: calendar
            )
        )

        let weeklyTraining: JourneyWeeklyTrainingStatus = isAppleHealthConnected
            ? .connected(
                workoutDays: healthWorkoutDays.count,
                averageCaloriesBurned: nil,
                averageTrainingDurationMinutes: nil
            )
            : .locked

        let context = JourneyDashboardBuilder.Context(
            profile: profile,
            baseline: baseline,
            maturityLogs: maturityLogs,
            monthLogs: weekLogs,
            weekLogs: weekLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            allWeights: allWeights,
            weekWeights: resolvedWeekWeights,
            journeyStreaks: journeyStreaks,
            weeklyTraining: weeklyTraining,
            weightSummary: weightSummary,
            goalProjection: nil,
            healthWorkoutDayStarts: healthWorkoutDays,
            monthHealthWorkoutCount: healthWorkoutDays.count,
            asOf: resolvedAsOf,
            calendar: calendar
        )

        return JourneyPresentationBuilder.buildDashboard(
            hasProfile: profile != nil,
            context: context,
            loggedDays: maturityLogs.count
        )
    }

    private func makeBaseline(
        startWeight: Double,
        currentWeight: Double,
        goalWeight: Double,
        direction: JourneyGoalDirection
    ) -> JourneyBaseline {
        JourneyBaseline(
            startWeightKg: startWeight,
            startDate: calendar.date(byAdding: .day, value: -30, to: asOf)!,
            currentWeightKg: currentWeight,
            goalWeightKg: goalWeight,
            goalDirection: direction,
            totalChangeKg: currentWeight - startWeight,
            remainingChangeKg: abs(currentWeight - goalWeight),
            progressPercent: 25,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: true,
            usesSyntheticBaselinePoint: false,
            onboardingBaselineWeightKg: startWeight,
            chartPoints: [],
            showsWeightChart: true
        )
    }

    private func makeLog(
        daysAgo: Int,
        calories: Int,
        protein: Double,
        waterMl: Int = 2_000
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return makeLog(on: date, calories: calories, protein: protein, waterMl: waterMl)
    }

    private func makeLog(
        on date: Date,
        calories: Int,
        protein: Double,
        waterMl: Int = 2_000
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(
                calories: calories,
                protein: protein,
                carbs: 100,
                fat: 40,
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

    private func makeWeight(date: Date, kg: Double) -> WeightEntry {
        WeightEntry(
            id: UUID(),
            date: date,
            weightKg: kg,
            note: nil,
            createdAt: date
        )
    }

    private func weekdayLogs(count: Int, protein: Double, waterMl: Int) -> [DailyLog] {
        var logs: [DailyLog] = []
        var daysAgo = 0
        while logs.count < count {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf) else { break }
            let weekday = calendar.component(.weekday, from: date)
            if (2...6).contains(weekday) {
                logs.append(makeLog(daysAgo: daysAgo, calories: 1_800, protein: protein, waterMl: waterMl))
            }
            daysAgo += 1
        }
        return logs
    }

    private func containsWholeWord(_ word: String, in text: String) -> Bool {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
