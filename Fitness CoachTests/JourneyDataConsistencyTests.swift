//
//  JourneyDataConsistencyTests.swift
//  Fitness CoachTests
//
//  Forma — Production trust tests for Journey presentation consistency.
//

import XCTest
@testable import Fitness_Coach

final class JourneyDataConsistencyTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }()

    private let asOf = WeeklyProgressFixtures.asOf

    // MARK: - Meal copy

    func testZeroMealsDoesNotProduceFewMoreMealsCopy() {
        let presentation = buildPresentation(maturityLogs: [
            WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0, waterMl: 500)
        ])

        XCTAssertFalse(presentation.copy.allowsFewMoreMealsCopy)
        XCTAssertNotEqual(
            presentation.nextBestAction.title,
            FormaProductCopy.Journey.NextBestAction.logMealsConsistently
        )

        let allCopy = journeyUserFacingCopy(from: presentation)
        XCTAssertFalse(
            allCopy.contains(where: { $0.localizedCaseInsensitiveContains("few more meal") }),
            "Unexpected few-more-meals copy: \(allCopy)"
        )
    }

    func testZeroMealsShowsLogYourFirstMeal() {
        let presentation = buildPresentation(maturityLogs: [])

        XCTAssertEqual(
            presentation.nextBestAction.title,
            FormaProductCopy.Journey.NextBestAction.logFirstMeal
        )
        XCTAssertEqual(
            presentation.nextBestAction.detail,
            FormaProductCopy.Journey.NextBestAction.logFirstMealDetail
        )
    }

    func testInsufficientMealsUsesFewMoreMealsCopyOnlyWhenMealsLogged() {
        let presentation = buildPresentation(maturityLogs: [
            WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 1_800),
            WeeklyProgressFixtures.makeLog(daysAgo: 1, calories: 1_800)
        ])

        XCTAssertTrue(presentation.copy.allowsFewMoreMealsCopy)
        XCTAssertEqual(
            presentation.nextBestAction.title,
            FormaProductCopy.Journey.NextBestAction.logMealsConsistently
        )
        XCTAssertEqual(
            presentation.nextBestAction.detail,
            FormaProductCopy.Journey.NextBestAction.logMealsConsistentlyDetail
        )
    }

    // MARK: - Streaks

    func testMealStreakHiddenWhenMealDaysAreZero() {
        let logs = [WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0, waterMl: 500)]
        let presentation = buildPresentation(maturityLogs: logs)

        XCTAssertFalse(presentation.streaks.showsMealStreak)
        XCTAssertEqual(presentation.streaks.mealLoggingStreakDays, 0)
        XCTAssertTrue(presentation.streaks.showsCheckInStreak)
        XCTAssertEqual(
            presentation.streaks.primaryMomentumLabel,
            FormaProductCopy.Journey.Streaks.checkInStreak(days: presentation.streaks.checkInStreakDays)
        )
    }

    func testCheckInStreakCanShowIndependentlyWhenLabeled() {
        let logs = [WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0, waterMl: 500)]
        let presentation = buildPresentation(maturityLogs: logs)

        XCTAssertEqual(presentation.streaks.primaryMomentumKind, .checkIn)
        XCTAssertTrue(
            presentation.streaks.primaryMomentumLabel.localizedCaseInsensitiveContains("check-in streak")
        )
    }

    func testMealStreakLabelUsesMealStreakWording() {
        let logs = (0..<3).map { WeeklyProgressFixtures.makeLog(daysAgo: $0, calories: 1_800) }
        let presentation = buildPresentation(maturityLogs: logs)

        XCTAssertTrue(presentation.streaks.showsMealStreak)
        XCTAssertEqual(
            presentation.streaks.primaryMomentumLabel,
            FormaProductCopy.Journey.Streaks.mealStreak(days: presentation.streaks.mealLoggingStreakDays)
        )
        XCTAssertFalse(presentation.streaks.primaryMomentumLabel.localizedCaseInsensitiveContains("logging streak"))
    }

    // MARK: - Weekly date range

    func testWeeklyDateRangeSharedAcrossWeeklyCards() {
        let dashboard = JourneyPreviewData.strongMomentum

        XCTAssertEqual(
            dashboard.screenPresentation.weekly.dateRangeText,
            dashboard.unifiedWeeklyReview.dateRangeText
        )
        XCTAssertFalse(dashboard.screenPresentation.weekly.dateRangeText.isEmpty)
        XCTAssertTrue(dashboard.screenPresentation.weekly.dateRangeText.contains("–"))
    }

    // MARK: - Workout dates

    func testFirstWorkoutStoryDateEqualsFirstWorkoutDate() {
        let workoutDate = calendar.date(byAdding: .day, value: -3, to: asOf)!
        let misleadingDayStart = calendar.date(byAdding: .day, value: -1, to: asOf)!
        let healthRecord = HealthWorkoutRecord(
            id: UUID(),
            activityName: "Run",
            startDate: workoutDate,
            endDate: workoutDate.addingTimeInterval(3_600),
            durationMinutes: 45,
            activeCalories: 320
        )

        let timeline = JourneyTimelineBuilder.build(
            JourneyTimelineBuilder.Input(
                profile: ProfileTestFixtures.sampleProfile,
                baseline: makeBaseline(),
                maturityLogs: [],
                allWeights: [],
                healthWorkoutDayStarts: [calendar.startOfDay(for: misleadingDayStart)],
                healthWorkoutRecords: [healthRecord],
                isAppleHealthConnected: true,
                unlockedMilestoneCount: 0,
                asOf: asOf,
                calendar: calendar
            )
        )

        let workoutEvent = timeline.events.first { $0.type == .firstWorkoutLogged }
        XCTAssertNotNil(workoutEvent)
        XCTAssertEqual(
            calendar.startOfDay(for: workoutEvent!.date),
            calendar.startOfDay(for: workoutDate)
        )

        let cardDate = JourneyHealthIntelligencePresentationBuilder.workoutItem(
            from: JourneyHealthIntelligenceWorkoutRecordInput(from: healthRecord),
            calendar: calendar
        ).date
        XCTAssertEqual(cardDate, calendar.startOfDay(for: workoutDate))
    }

    // MARK: - Copy hygiene

    func testJourneyUserFacingCopyDoesNotContainRemoteSync() {
        let dashboards = [
            JourneyPreviewData.brandNewUser,
            JourneyPreviewData.sparseData,
            JourneyPreviewData.strongMomentum
        ]

        for dashboard in dashboards {
            let copy = journeyUserFacingCopy(from: dashboard.screenPresentation)
                + [dashboard.unifiedWeeklyReview.dateRangeText]
                + dashboard.unifiedWeeklyReview.caveats
                + [dashboard.unifiedWeeklyReview.freshness?.cardMessage ?? ""]
                + [dashboard.unifiedWeeklyReview.freshness?.detailMessage ?? ""]
                + [dashboard.screenPresentation.sync.healthSyncNotice ?? ""]

            for text in copy where !text.isEmpty {
                XCTAssertFalse(
                    text.localizedCaseInsensitiveContains("remote sync"),
                    "Found remote sync in: \(text)"
                )
            }
        }
    }

    func testJourneyFreshnessUsesHealthDataSyncingCopy() {
        let freshness = WeeklyProgressFreshnessBuilder.build(
            WeeklyProgressFreshnessInput(
                isRestoringAccount: false,
                isCrossDeviceRefreshing: true,
                pendingUploadCount: nil,
                lastRefreshAt: nil,
                recentlyRestoredAt: nil,
                now: asOf
            ),
            surface: .journey
        )

        XCTAssertEqual(
            freshness?.cardMessage,
            FormaProductCopy.Journey.Sync.healthDataSyncing
        )
    }

    func testJourneyUserFacingCopyDoesNotContainDuplicatedSentenceFragments() {
        let presentation = buildPresentation(
            maturityLogs: [WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 1_800)]
        )
        let strings = journeyUserFacingCopy(from: presentation)

        for text in strings where text.contains(". ") {
            let sentences = text
                .split(separator: ".")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let unique = Set(sentences)
            XCTAssertEqual(
                sentences.count,
                unique.count,
                "Duplicated sentence fragments in: \(text)"
            )
        }
    }

    func testEmptyStateExplainsWhatIsBuildingAndNeeded() {
        let presentation = buildPresentation(maturityLogs: [])

        XCTAssertEqual(
            presentation.copy.emptyState?.headline,
            FormaProductCopy.Journey.EmptyState.buildingFirstTrend
        )
        XCTAssertNotNil(presentation.copy.emptyState?.requirement)
        XCTAssertEqual(presentation.copy.emptyState?.nextActionTitle, presentation.nextBestAction.title)
    }

    // MARK: - Helpers

    private func buildPresentation(maturityLogs: [DailyLog]) -> JourneyScreenPresentationState {
        let context = makeContext(maturityLogs: maturityLogs)
        let summary = JourneyDashboardBuilder.weeklyProgressSummary(context: context)
        let chapter = JourneyChapterBuilder.build(
            JourneyChapterBuilder.Input(
                profile: ProfileTestFixtures.sampleProfile,
                maturityLogs: maturityLogs,
                allWeights: [],
                healthWorkoutDayStarts: [],
                isAppleHealthConnected: false,
                unlockedMilestoneCount: 0,
                checkInStreakDays: 0,
                weeklyReviewUnlocked: false,
                calendar: calendar
            )
        )

        return JourneyScreenPresentationBuilder.build(
            JourneyScreenPresentationBuilder.Input(
                context: context,
                weeklyProgressSummary: summary,
                chapter: chapter,
                storyEvents: [],
                insight: JourneyInsightState(
                    isVisible: true,
                    sectionTitle: FormaProductCopy.Journey.PersonalizedInsights.sectionTitle,
                    showsLearningState: true,
                    learningTitle: FormaProductCopy.Journey.PersonalizedInsights.learningTitle,
                    learningDetail: FormaProductCopy.Journey.PersonalizedInsights.learningDetail,
                    insights: [],
                    accessibilitySummary: ""
                ),
                goalProjection: JourneyGoalProjectionState(
                    sectionTitle: FormaProductCopy.Journey.GoalProjection.sectionTitle,
                    status: .hidden,
                    accessibilitySummary: ""
                ),
                freshnessInput: nil
            )
        )
    }

    private func makeContext(maturityLogs: [DailyLog]) -> JourneyDashboardBuilder.Context {
        let baseline = makeBaseline()
        let streakSummary = StreakCalculator.calculate(
            logs: maturityLogs,
            workoutDates: [],
            asOf: asOf,
            calendar: calendar
        )

        return JourneyDashboardBuilder.Context(
            profile: ProfileTestFixtures.sampleProfile,
            baseline: baseline,
            maturityLogs: maturityLogs,
            monthLogs: maturityLogs,
            weekLogs: maturityLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            allWeights: [],
            weekWeights: [],
            journeyStreaks: JourneyStreakBuilder.build(
                JourneyStreakBuilder.Input(
                    streakSummary: streakSummary,
                    maturityLogs: maturityLogs,
                    workoutDates: [],
                    isAppleHealthConnected: false,
                    asOf: asOf,
                    calendar: calendar
                )
            ),
            weeklyTraining: .connectedEmpty,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: baseline.currentWeightKg,
                changeKg: baseline.totalChangeKg,
                direction: .insufficientData,
                hasSuddenSpike: false
            ),
            goalProjection: nil,
            healthWorkoutDayStarts: [],
            asOf: asOf,
            calendar: calendar
        )
    }

    private func makeBaseline() -> JourneyBaseline {
        JourneyBaseline(
            startWeightKg: 80,
            startDate: calendar.date(byAdding: .day, value: -30, to: asOf) ?? asOf,
            currentWeightKg: 78,
            goalWeightKg: 72,
            goalDirection: .lose,
            totalChangeKg: -2,
            remainingChangeKg: 6,
            progressPercent: 25,
            estimatedCompletionDate: nil,
            estimatedCompletionMonthLabel: nil,
            hasRealWeightEntries: false,
            usesSyntheticBaselinePoint: true,
            onboardingBaselineWeightKg: 80,
            chartPoints: [],
            showsWeightChart: true
        )
    }

    private func journeyUserFacingCopy(from presentation: JourneyScreenPresentationState) -> [String] {
        var copy = [
            presentation.streaks.primaryMomentumLabel,
            presentation.streaks.momentumDetail,
            presentation.streaks.keepStreakAliveCopy,
            presentation.nextBestAction.title,
            presentation.nextBestAction.detail,
            presentation.copy.confidenceLabel,
            presentation.copy.insufficientDataSummary,
            presentation.copy.emptyState?.headline,
            presentation.copy.emptyState?.requirement,
            presentation.copy.emptyState?.nextActionTitle,
            presentation.copy.emptyState?.nextActionDetail,
            presentation.copy.emptyState?.progressLabel,
            presentation.sync.healthSyncNotice,
            presentation.weekly.dateRangeText
        ]
        return copy.compactMap { $0 }.filter { !$0.isEmpty }
    }
}
