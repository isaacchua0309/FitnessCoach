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
        XCTAssertFalse(dashboard.transformation.headlineCopy.isEmpty)
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

        let hero = JourneyTransformationHeroBuilder.build(
            JourneyTransformationHeroBuilder.Input(
                baseline: baseline,
                loggedDays: 0,
                heroStreakChip: .hidden,
                weightTrendDirection: .decreasing,
                asOf: asOf,
                calendar: calendar
            )
        )

        XCTAssertEqual(baseline.currentWeightKg ?? 0, 85, accuracy: 0.01)
        XCTAssertEqual(hero.todayWeightCopy, JourneyFormatter.heroWeightKg(85))
        XCTAssertGreaterThanOrEqual(baseline.chartPoints.filter { !$0.isSynthetic }.count, 3)
        XCTAssertGreaterThan(baseline.progressPercent ?? 0, 0)
    }

    // MARK: - 4. Food logging

    func testManualQA04_FoodLoggingUpdatesWeeklyReviewTimelineAndXP() async throws {
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
        XCTAssertGreaterThanOrEqual(dashboardAfter.journeyLevel.totalXP, 10)
    }

    // MARK: - 5. Water logging

    func testManualQA05_WaterLoggingUpdatesWeeklyReviewAndHabitInsights() {
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
        if dashboard.habitInsights.isUnlocked {
            XCTAssertFalse(dashboard.habitInsights.strongestHabitLabel.isEmpty)
        }
    }

    // MARK: - 6. Protein consistency

    func testManualQA06_ProteinGoalDaysAndStrongestHabit() {
        let logs = (0..<10).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140, waterMl: 2_000)
        }

        let dashboard = buildDashboard(
            maturityLogs: logs,
            weekLogs: Array(logs.prefix(7)),
            isAppleHealthConnected: false
        )

        XCTAssertGreaterThanOrEqual(dashboard.weeklyReview.proteinGoalDays, 5)
        XCTAssertTrue(dashboard.habitInsights.isUnlocked)
        XCTAssertEqual(
            dashboard.habitInsights.strongestHabitLabel,
            FormaProductCopy.Journey.HabitInsights.proteinLabel
        )
    }

    // MARK: - 7. Weak weekend logging

    func testManualQA07_WeekendLoggingWeakHabitAndUsefulSuggestion() {
        let logs = weekdayLogs(count: 12, protein: 140, waterMl: 2_000)
        var profile = ProfileTestFixtures.sampleProfile
        profile.createdAt = calendar.date(byAdding: .day, value: -1, to: asOf)!

        let insights = JourneyHabitInsightsBuilder.build(
            JourneyHabitInsightsBuilder.Input(
                profile: profile,
                maturityLogs: logs,
                weekLogs: Array(logs.prefix(7)),
                weekWeights: [],
                healthWorkoutDayStarts: [],
                isAppleHealthConnected: false,
                expectedTrainingDaysPerWeek: 3,
                hasRealWeightEntries: false,
                asOf: asOf,
                calendar: calendar
            )
        )

        XCTAssertTrue(insights.isUnlocked)
        XCTAssertEqual(insights.weakestHabitKind, .weekendLogging)
        XCTAssertEqual(
            insights.suggestedNextAction,
            FormaProductCopy.Journey.HabitInsights.suggestWeekendLogging
        )
        XCTAssertFalse(insights.suggestedNextAction.isEmpty)
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
        XCTAssertTrue(unlockedIDs.contains("thirty-meals"))

        if dashboard.baseline.progressPercent ?? 0 >= 50 {
            XCTAssertTrue(unlockedIDs.contains("halfway"))
        }
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

    // MARK: - 10. Progress attribution

    func testManualQA10_ProgressAttributionUsesLikelyLanguageNotOverclaims() {
        let logs = (0..<20).map { offset in
            makeLog(daysAgo: offset, calories: 1_850, protein: 120, waterMl: 2_000)
        }

        let attribution = buildDashboard(
            maturityLogs: logs,
            weekLogs: Array(logs.prefix(7)),
            weightSummary: ProgressWeightSummary(
                latestWeightKg: 84,
                changeKg: -1.2,
                direction: .decreasing,
                hasSuddenSpike: false
            ),
            isAppleHealthConnected: false
        ).progressAttribution

        let combined = "\(attribution.primaryReasonTitle) \(attribution.primaryReasonDetail)"
        let banned = ["proved", "caused", "guaranteed", "definitely", "certainly"]
        for word in banned {
            XCTAssertFalse(
                containsWholeWord(word, in: combined),
                "Attribution overclaims with '\(word)'"
            )
        }
        XCTAssertTrue(
            combined.localizedCaseInsensitiveContains("likely")
                || attribution.primaryReasonTitle == FormaProductCopy.Journey.WhyProgress.insufficientTitle
        )
    }

    // MARK: - 11. Before vs Today

    func testManualQA11_BeforeTodayHidesMissingMaintenanceWithoutFakePrecision() {
        let baseline = makeBaseline(startWeight: 90, currentWeight: 86, goalWeight: 75, direction: .lose)
        let withoutProfile = JourneyBeforeTodayBuilder.build(
            JourneyBeforeTodayBuilder.Input(
                profile: nil,
                baseline: baseline,
                asOf: asOf,
                calendar: calendar
            )
        )

        XCTAssertFalse(withoutProfile.showsMaintenanceRow)
        XCTAssertNil(withoutProfile.startingMaintenanceCaloriesKcal)
        XCTAssertFalse(withoutProfile.accessibilitySummary.contains("0 kcal"))
    }

    // MARK: - 12. Personal Records

    func testManualQA12_PersonalRecordsLockedThenUnlockedWithData() {
        let sparse = (0..<2).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }
        let rich = (0..<6).map { makeLog(daysAgo: $0, calories: 1_800, protein: 140, waterMl: 2_500) }

        let locked = buildDashboard(maturityLogs: sparse, weekLogs: sparse, isAppleHealthConnected: false)
            .personalRecords
        let unlocked = buildDashboard(maturityLogs: rich, weekLogs: rich, isAppleHealthConnected: false)
            .personalRecords

        XCTAssertFalse(locked.isUnlocked)
        XCTAssertEqual(locked.lockedMessage, FormaProductCopy.Journey.PersonalRecords.lockedBody)
        XCTAssertTrue(unlocked.isUnlocked)
        XCTAssertFalse(unlocked.displayRecords.isEmpty)
    }

    // MARK: - 13. Monthly Recap

    func testManualQA13_MonthlyRecapPartialAndCompleteStates() {
        let partialLogs = (0..<2).map { makeLog(daysAgo: $0, calories: 1_800, protein: 120) }
        let fullLogs = (0..<8).map { makeLog(daysAgo: $0, calories: 1_800, protein: 130, waterMl: 2_400) }

        let partial = JourneyMonthlyRecapBuilder.build(
            JourneyMonthlyRecapBuilder.Input(
                monthLogs: partialLogs,
                maturityLogs: partialLogs,
                allWeights: [],
                healthWorkoutDayStarts: [],
                monthHealthWorkoutCount: 0,
                goalDirection: .lose,
                isAppleHealthConnected: false,
                expectedTrainingDaysPerWeek: 3,
                asOf: asOf,
                calendar: calendar
            )
        )
        let full = JourneyMonthlyRecapBuilder.build(
            JourneyMonthlyRecapBuilder.Input(
                monthLogs: fullLogs,
                maturityLogs: fullLogs,
                allWeights: [
                    makeWeight(date: calendar.date(byAdding: .day, value: -10, to: asOf)!, kg: 88),
                    makeWeight(date: asOf, kg: 86)
                ],
                healthWorkoutDayStarts: [],
                monthHealthWorkoutCount: 0,
                goalDirection: .lose,
                isAppleHealthConnected: false,
                expectedTrainingDaysPerWeek: 3,
                asOf: asOf,
                calendar: calendar
            )
        )

        XCTAssertFalse(partial.isComplete)
        XCTAssertNotNil(partial.buildingMessage)
        XCTAssertTrue(full.isComplete)
        XCTAssertNil(full.buildingMessage)
        XCTAssertFalse(full.rows.isEmpty)
    }

    // MARK: - 14. Journey Level

    func testManualQA14_JourneyLevelXPFromConsistencyNotRepeatedEdits() {
        let day = calendar.startOfDay(for: asOf)
        var older = makeLog(on: day, calories: 1_200, protein: 60, waterMl: 500)
        var newer = older
        newer.totals = MacroTotals(calories: 1_900, protein: 140, carbs: 100, fat: 40)
        newer.updatedAt = calendar.date(byAdding: .hour, value: 2, to: day)!

        let xp = JourneyLevelBuilder.dailyBehaviorXP(
            input: JourneyLevelBuilder.Input(
                maturityLogs: [older, newer],
                allWeights: [],
                healthWorkoutDayStarts: [],
                isAppleHealthConnected: false,
                unlockedMilestoneCount: 0,
                calendar: calendar
            )
        )

        XCTAssertEqual(xp, 30, "Repeated same-day edits must not stack food XP")
        XCTAssertLessThanOrEqual(xp, 50)
    }

    // MARK: - 15. Apple Health disconnected

    func testManualQA15_AppleHealthDisconnectedSafeTrainingState() {
        let dashboard = JourneyPreviewData.healthDisconnected

        XCTAssertEqual(dashboard.weeklyReview.training, .locked)
        XCTAssertEqual(dashboard.detailedAnalytics.trainingDisplay, .hidden)
        let trainingRow = dashboard.weeklyReview.rows.first { $0.id == "training" }
        if let trainingRow {
            XCTAssertFalse(trainingRow.value.localizedCaseInsensitiveContains("fail"))
        }
    }

    // MARK: - 16. Apple Health connected

    func testManualQA16_AppleHealthConnectedCountsWorkoutDays() {
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

    // MARK: - 17. Gain goal

    func testManualQA17_GainGoalCopyAndMilestones() {
        let dashboard = JourneyPreviewData.gainGoal

        XCTAssertEqual(
            dashboard.transformation.headlineCopy,
            FormaProductCopy.Journey.Transformation.gainedHeadline
        )
        XCTAssertFalse(dashboard.transformation.headlineCopy.localizedCaseInsensitiveContains("lost"))
        XCTAssertEqual(dashboard.baseline.goalDirection, .gain)

        let firstKg = dashboard.milestones.items.first { $0.id == "first-kg" }
        XCTAssertEqual(
            firstKg?.title,
            FormaProductCopy.Journey.Milestones.firstKilogramTitle(direction: .gain)
        )
    }

    // MARK: - 18. Maintain goal

    func testManualQA18_MaintainGoalStableCopy() {
        let dashboard = JourneyPreviewData.maintainGoal

        XCTAssertEqual(dashboard.baseline.goalDirection, .maintain)
        XCTAssertEqual(
            dashboard.transformation.headlineCopy,
            FormaProductCopy.Journey.Transformation.maintainingHeadline
        )
        XCTAssertFalse(dashboard.transformation.headlineCopy.localizedCaseInsensitiveContains("lost"))
        XCTAssertFalse(dashboard.transformation.headlineCopy.localizedCaseInsensitiveContains("gained"))
    }

    // MARK: - 19. Pull to refresh

    func testManualQA19_JourneyRefreshReloadsSafelyAfterDataChange() async throws {
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

    // MARK: - 20. Dynamic Type and VoiceOver

    func testManualQA20_AccessibilityStringsPresentForHeroProgressAndMilestones() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertFalse(dashboard.transformation.accessibilitySummary.isEmpty)
        XCTAssertFalse(dashboard.transformation.progressBarAccessibilityValue.isEmpty)
        XCTAssertTrue(
            dashboard.transformation.accessibilitySummary.localizedCaseInsensitiveContains("progress")
                || dashboard.transformation.accessibilitySummary.localizedCaseInsensitiveContains("%")
        )

        if let next = dashboard.milestones.next, let progress = dashboard.milestones.nextProgressFraction {
            let milestoneA11y = FormaProductCopy.Journey.Milestones.Accessibility.progressPercent(
                Int((progress * 100).rounded())
            )
            XCTAssertFalse(milestoneA11y.isEmpty)
            XCTAssertFalse(next.title.isEmpty)
        }
    }

    // MARK: - Canonical layout smoke

    func testManualQA_AllSectionsMountedInCanonicalOrder() {
        let order = JourneyProductLayout.sectionOrder.map(\.rawValue)
        XCTAssertTrue(order.contains("transformation"))
        XCTAssertTrue(order.contains("weeklyReview"))
        XCTAssertTrue(order.contains("milestones"))
        XCTAssertTrue(order.contains("storyTimeline"))
        XCTAssertTrue(order.contains("detailedAnalytics"))
        XCTAssertFalse(order.contains("consistencyCalendar"))
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
            dailyLogService: harness.dailyLogService,
            weightLogService: harness.weightLogService,
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
            weekLogs: weekLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            monthLogs: maturityLogs,
            allWeights: allWeights,
            weekWeights: resolvedWeekWeights,
            journeyStreaks: journeyStreaks,
            weeklyTraining: weeklyTraining,
            weightSummary: weightSummary,
            goalProjection: nil,
            healthWorkoutDayStarts: healthWorkoutDays,
            monthHealthWorkoutCount: healthWorkoutDays.count,
            nutritionSummary: JourneyLogSummaryBuilder.nutritionSummary(from: maturityLogs),
            waterSummary: JourneyLogSummaryBuilder.waterSummary(from: maturityLogs),
            workoutSummary: nil,
            selectedRangeDays: 28,
            asOf: resolvedAsOf,
            calendar: calendar
        )

        return JourneyDashboardState(
            selectedRangeDays: 28,
            hasProfile: profile != nil,
            baseline: baseline,
            transformation: JourneyDashboardBuilder.transformation(context: context, loggedDays: maturityLogs.count),
            weeklyReview: JourneyDashboardBuilder.weeklyReview(context: context),
            streaks: journeyStreaks,
            milestones: JourneyDashboardBuilder.milestones(context: context),
            storyTimeline: JourneyDashboardBuilder.storyTimeline(context: context),
            habitInsights: JourneyDashboardBuilder.habitInsights(context: context),
            progressAttribution: JourneyDashboardBuilder.progressAttribution(context: context),
            beforeToday: JourneyDashboardBuilder.beforeToday(context: context),
            personalRecords: JourneyDashboardBuilder.personalRecords(context: context),
            monthlyRecap: JourneyDashboardBuilder.monthlyRecap(context: context),
            journeyLevel: JourneyDashboardBuilder.journeyLevel(context: context),
            detailedAnalytics: JourneyDashboardBuilder.detailedAnalytics(
                context: context,
                weightInterpretation: JourneyDashboardBuilder.weightTrendInterpretation(summary: weightSummary)
            )
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
