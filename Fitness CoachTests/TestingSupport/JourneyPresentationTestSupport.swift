//
//  JourneyPresentationTestSupport.swift
//  Fitness CoachTests
//
//  Deterministic Journey dashboard builders and copy assertions for production mapping tests.
//

import XCTest
@testable import Fitness_Coach

enum JourneyPresentationTestSupport {

    static let calendar = WeeklyProgressFixtures.calendar
    static let asOf = WeeklyProgressFixtures.asOf

    // MARK: - Forbidden copy

    static let forbiddenCopyPhrases: [String] = [
        "remote sync",
        "Limited est",
        "Not enough data yet",
        "Maintenance estimate building",
        "Log weight to see weekly change",
        "Missing signals:",
        "Limited confidence",
        "Requires: 7 days",
        "debug",
        "DEBUG",
        "TODO",
        "FIXME",
    ]

    static let forbiddenPrimaryStateTitles: [String] = [
        "Not enough data yet",
        FormaProductCopy.Health.signalUnavailable,
    ]

    // MARK: - Dashboard builder

    struct DashboardInput {
        var maturityLogs: [DailyLog]
        var allWeights: [WeightEntry] = []
        var healthWorkoutDayStarts: Set<Date> = []
        var isAppleHealthConnected: Bool = false
        var profile: UserProfile? = ProfileTestFixtures.sampleProfile
        var asOf: Date = WeeklyProgressFixtures.asOf
    }

    static func buildDashboard(_ input: DashboardInput) -> JourneyDashboardState {
        let baseline = JourneyBaselineResolver.resolve(
            JourneyBaselineResolver.Input(
                profile: input.profile,
                allWeights: input.allWeights,
                maturityLogs: input.maturityLogs,
                goalProjection: nil,
                asOf: input.asOf,
                calendar: calendar
            )
        )

        let streakSummary = StreakCalculator.calculate(
            logs: input.maturityLogs,
            workoutDates: input.healthWorkoutDayStarts,
            asOf: input.asOf,
            calendar: calendar
        )

        let weeklyTraining: JourneyWeeklyTrainingStatus = input.isAppleHealthConnected
            ? .connected(
                workoutDays: input.healthWorkoutDayStarts.count,
                averageCaloriesBurned: nil,
                averageTrainingDurationMinutes: nil
            )
            : .locked

        let context = JourneyDashboardBuilder.Context(
            profile: input.profile,
            baseline: baseline,
            maturityLogs: input.maturityLogs,
            monthLogs: input.maturityLogs,
            weekLogs: input.maturityLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            allWeights: input.allWeights,
            weekWeights: input.allWeights,
            journeyStreaks: JourneyStreakBuilder.build(
                JourneyStreakBuilder.Input(
                    streakSummary: streakSummary,
                    maturityLogs: input.maturityLogs,
                    workoutDates: input.healthWorkoutDayStarts,
                    isAppleHealthConnected: input.isAppleHealthConnected,
                    asOf: input.asOf,
                    calendar: calendar
                )
            ),
            weeklyTraining: weeklyTraining,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: input.allWeights.last?.weightKg ?? baseline.currentWeightKg,
                changeKg: baseline.totalChangeKg,
                direction: .insufficientData,
                hasSuddenSpike: false
            ),
            goalProjection: nil,
            healthWorkoutDayStarts: input.healthWorkoutDayStarts,
            monthHealthWorkoutCount: input.healthWorkoutDayStarts.count,
            asOf: input.asOf,
            calendar: calendar
        )

        return JourneyPresentationBuilder.buildDashboard(
            hasProfile: input.profile != nil,
            context: context,
            loggedDays: input.maturityLogs.count
        )
    }

    // MARK: - Copy collection

    static func userFacingCopy(from dashboard: JourneyDashboardState) -> [String] {
        let presentation = dashboard.screenPresentation
        let unified = dashboard.unifiedWeeklyReview
        let hero = dashboard.dashboardHero
        let progress = dashboard.progressSection

        var strings: [String] = [
            presentation.phase.chapterTitle,
            presentation.phase.chapterSubtitle,
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
            presentation.weekly.dateRangeText,
            presentation.unlockDashboard.nextActionCard?.title,
            presentation.unlockDashboard.nextActionCard?.detail,
            presentation.unlockDashboard.nextActionCard?.progressLabel,
            presentation.unlockDashboard.checklist?.title,
            hero.weekLabel,
            hero.chapterTitle,
            hero.encouragingSentence,
            progress.sectionTitle,
            unified.weekTitle,
            unified.dateRangeText,
            unified.cardStateTitle,
            unified.cardSummary,
            unified.confidenceLabel,
            unified.maintenanceBlock?.title,
            unified.maintenanceBlock?.explanation,
            unified.weightTrendBlock?.changeLabel,
            unified.weightTrendBlock?.weeklyChangeLabel,
            unified.freshness?.cardMessage,
            unified.freshness?.detailMessage,
        ]

        strings.append(contentsOf: hero.compactStats.map(\.label))
        strings.append(contentsOf: progress.rows.map { "\($0.title) \($0.value)" })
        strings.append(contentsOf: presentation.unlockDashboard.checklist?.items.map(\.title) ?? [])
        strings.append(contentsOf: presentation.story.events.map { "\($0.title) \($0.dayLabel)" })
        strings.append(contentsOf: dashboard.storyTimeline.displayEvents.map(\.title))
        strings.append(contentsOf: unified.caveats)
        strings.append(contentsOf: unified.compactStats.map(\.label))

        return strings.compactMap { $0 }.filter { !$0.isEmpty }
    }

    static func joinedUserFacingCopy(from dashboard: JourneyDashboardState) -> String {
        userFacingCopy(from: dashboard).joined(separator: " ")
    }

    // MARK: - Assertions

    static func assertNoForbiddenCopy(
        in dashboard: JourneyDashboardState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let copy = joinedUserFacingCopy(from: dashboard)
        for phrase in forbiddenCopyPhrases {
            XCTAssertFalse(
                copy.localizedCaseInsensitiveContains(phrase),
                "Forbidden Journey copy '\(phrase)' found",
                file: file,
                line: line
            )
        }
    }

    static func assertPrimaryStateIsNotNegativeEmpty(
        _ dashboard: JourneyDashboardState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let title = dashboard.unifiedWeeklyReview.cardStateTitle
        for forbidden in forbiddenPrimaryStateTitles {
            XCTAssertNotEqual(
                title,
                forbidden,
                file: file,
                line: line
            )
            XCTAssertFalse(
                title.localizedCaseInsensitiveContains(forbidden),
                "Primary state title must not be '\(forbidden)', got '\(title)'",
                file: file,
                line: line
            )
        }
    }

    static func assertCanonicalDateRangeIsShared(
        _ dashboard: JourneyDashboardState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let presentationRange = dashboard.screenPresentation.weekly.dateRangeText
        let unifiedRange = dashboard.unifiedWeeklyReview.dateRangeText

        XCTAssertFalse(presentationRange.isEmpty, file: file, line: line)
        XCTAssertEqual(presentationRange, unifiedRange, file: file, line: line)
        XCTAssertTrue(presentationRange.contains("–"), file: file, line: line)
    }

    static func assertNoDuplicateWeeklySections(
        _ dashboard: JourneyDashboardState,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let sections = JourneyDashboardSectionSupport.visibleSections(for: dashboard)
        XCTAssertEqual(
            sections.filter { $0 == .weeklyProgress }.count,
            1,
            file: file,
            line: line
        )
        XCTAssertFalse(
            sections.contains(.highlights)
                && sections.filter { $0 == .weeklyProgress }.isEmpty,
            file: file,
            line: line
        )
    }

    static func assertScrollClearanceExceedsTabBar(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let inset = JourneyLayout.scrollBottomInset(
            bottomSafeArea: FormaTokens.Layout.homeIndicatorSafeAreaEstimate,
            dynamicTypeSize: .large
        )
        XCTAssertGreaterThan(
            inset,
            FormaTokens.Layout.floatingTabBarHeight,
            file: file,
            line: line
        )
    }
}
