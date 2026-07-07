//
//  JourneyUnlockStateTests.swift
//  Fitness CoachTests
//
//  Forma — Positive unlock state presentation tests for Journey.
//

import XCTest
@testable import Fitness_Coach

final class JourneyUnlockStateTests: XCTestCase {

    private var calendar: Calendar { WeeklyProgressFixtures.calendar }
    private var asOf: Date { WeeklyProgressFixtures.asOf }

    func testBrandNewUserShowsProminentNextActionAndChecklist() {
        let dashboard = JourneyPreviewData.brandNewUser
        let unlock = dashboard.screenPresentation.unlockDashboard

        XCTAssertTrue(unlock.showsProminentNextActionCard)
        XCTAssertNotNil(unlock.nextActionCard)
        XCTAssertNotNil(unlock.checklist)
        XCTAssertEqual(
            unlock.nextActionCard?.title,
            FormaProductCopy.Journey.NextBestAction.logFirstMeal
        )
        XCTAssertEqual(
            unlock.nextActionCard?.progressLabel,
            "0 / 1 meals"
        )
        XCTAssertEqual(
            unlock.nextActionCard?.detail,
            FormaProductCopy.Journey.Unlock.firstMealUnlockDetail
        )
        XCTAssertFalse(dashboard.showsMilestonesSection)
    }

    func testOneWorkoutOneWeighInZeroMealsCelebratesProgressAndAsksForMeal() {
        let workoutDay = calendar.startOfDay(for: asOf)
        let presentation = buildPresentation(
            maturityLogs: [
                WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 0)
            ],
            weights: [WeeklyProgressFixtures.makeWeight(daysAgo: 0, kg: 80)],
            healthWorkoutDayStarts: [workoutDay]
        )
        let unlock = presentation.unlockDashboard
        let checklist = unlock.checklist!

        XCTAssertTrue(checklist.items.first(where: { $0.id == "first-weigh-in" })?.isCompleted == true)
        XCTAssertTrue(checklist.items.first(where: { $0.id == "first-workout" })?.isCompleted == true)
        XCTAssertFalse(checklist.items.first(where: { $0.id == "first-meal" })?.isCompleted == true)
        XCTAssertEqual(presentation.nextBestAction.kind, .logFirstMeal)
    }

    func testMealsLoggedWithoutWeightAsksForWeighIns() {
        let presentation = buildPresentation(
            maturityLogs: (0..<3).map {
                WeeklyProgressFixtures.makeLog(daysAgo: $0, calories: 1_800)
            },
            weights: []
        )

        XCTAssertEqual(presentation.nextBestAction.kind, .logWeightMoreOften)
        XCTAssertEqual(
            presentation.unlockDashboard.nextActionCard?.title,
            FormaProductCopy.Journey.NextBestAction.logWeightMoreOften
        )
    }

    func testStrongMomentumHidesProminentUnlockCard() {
        let dashboard = JourneyPreviewData.strongMomentum
        let unlock = dashboard.screenPresentation.unlockDashboard

        XCTAssertFalse(unlock.showsProminentNextActionCard)
        XCTAssertNil(unlock.checklist)
        XCTAssertTrue(dashboard.showsMilestonesSection)
    }

    func testThisWeekCardSuppressesDuplicateCTAWhenProminentCardVisible() {
        let dashboard = JourneyPreviewData.brandNewUser
        let unified = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertTrue(unified.isInsufficientData)
        XCTAssertTrue(unified.suppressDuplicateUnlockCTA)
        XCTAssertNotNil(unified.unlockChecklist)
        XCTAssertNotNil(unified.primaryCTA)
    }

    func testBannedNegativeUnlockCopyIsNotUsedInJourneyPresentation() {
        let personas: [JourneyDashboardState] = [
            JourneyPreviewData.brandNewUser,
            JourneyPreviewData.weekOne,
            JourneyPreviewData.sparseData,
            JourneyPreviewData.foodLogsOnly,
        ]

        let banned = [
            "Not enough data yet",
            "Maintenance estimate building",
            "Log weight to see weekly change",
            "Requires: 7 days",
            "Missing signals:",
            "Limited confidence",
        ]

        for dashboard in personas {
            let copy = allCopy(from: dashboard)
            for phrase in banned {
                XCTAssertFalse(
                    copy.localizedCaseInsensitiveContains(phrase),
                    "Found banned phrase '\(phrase)'"
                )
            }
        }
    }

    func testPartialSignalsNoteUsesSyncCopyOrNil() {
        let uiState = HealthIntelligenceUIState(
            kind: .partialPermission,
            title: "Partial",
            message: "Partial",
            primaryActionTitle: nil,
            secondaryActionTitle: nil,
            primaryAction: .none,
            secondaryAction: .none,
            severity: .info,
            canShowInsight: true,
            confidenceLabel: nil,
            missingSignals: [
                HealthInsightAvailability(kind: .recoveryBaseline, isAvailable: false),
                HealthInsightAvailability(kind: .remoteSync, isAvailable: false),
            ],
            fallbackReason: .partialPermissions
        )

        let note = HealthIntelligencePresentationPolicy.partialSignalsNote(
            for: uiState,
            surface: .journey
        )
        XCTAssertEqual(note, FormaProductCopy.Journey.Sync.healthDataSyncing)

        let remoteOnly = HealthIntelligenceUIState(
            kind: .partialPermission,
            title: "Partial",
            message: "Partial",
            primaryActionTitle: nil,
            secondaryActionTitle: nil,
            primaryAction: .none,
            secondaryAction: .none,
            severity: .info,
            canShowInsight: true,
            confidenceLabel: nil,
            missingSignals: [
                HealthInsightAvailability(kind: .remoteSync, isAvailable: false),
            ],
            fallbackReason: .partialPermissions
        )
        XCTAssertNil(
            HealthIntelligencePresentationPolicy.partialSignalsNote(
                for: remoteOnly,
                surface: .journey
            )
        )
    }

    // MARK: - Helpers

    private func buildPresentation(
        maturityLogs: [DailyLog],
        weights: [WeightEntry] = [],
        healthWorkoutDayStarts: Set<Date> = []
    ) -> JourneyScreenPresentationState {
        let baseline = makeBaseline()
        let streakSummary = StreakCalculator.calculate(
            logs: maturityLogs,
            workoutDates: Array(healthWorkoutDayStarts),
            asOf: asOf,
            calendar: calendar
        )

        let context = JourneyDashboardBuilder.Context(
            profile: ProfileFixtures.sampleProfile,
            baseline: baseline,
            maturityLogs: maturityLogs,
            monthLogs: maturityLogs,
            weekLogs: maturityLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            allWeights: weights,
            weekWeights: weights,
            journeyStreaks: JourneyStreakBuilder.build(
                JourneyStreakBuilder.Input(
                    streakSummary: streakSummary,
                    maturityLogs: maturityLogs,
                    workoutDates: Array(healthWorkoutDayStarts),
                    isAppleHealthConnected: !healthWorkoutDayStarts.isEmpty,
                    asOf: asOf,
                    calendar: calendar
                )
            ),
            weeklyTraining: .connectedEmpty,
            weightSummary: ProgressWeightSummary(
                latestWeightKg: weights.last?.weightKg,
                changeKg: nil,
                direction: .insufficientData,
                hasSuddenSpike: false
            ),
            goalProjection: nil,
            healthWorkoutDayStarts: healthWorkoutDayStarts,
            monthHealthWorkoutCount: healthWorkoutDayStarts.count,
            asOf: asOf,
            calendar: calendar
        )

        let summary = JourneyDashboardBuilder.weeklyProgressSummary(context: context)
        return JourneyScreenPresentationBuilder.build(
            JourneyScreenPresentationBuilder.Input(
                context: context,
                weeklyProgressSummary: summary,
                chapter: JourneyChapterBuilder.build(
                    JourneyChapterBuilder.Input(
                        maturityLogs: maturityLogs,
                        allWeights: weights,
                        healthWorkoutDayStarts: healthWorkoutDayStarts,
                        isAppleHealthConnected: !healthWorkoutDayStarts.isEmpty,
                        unlockedMilestoneCount: 0,
                        calendar: calendar
                    )
                ),
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
                goalProjection: JourneyGoalProjectionBuilder.build(
                    JourneyGoalProjectionBuilder.Input(
                        baseline: baseline,
                        allWeights: weights,
                        asOf: asOf,
                        calendar: calendar
                    )
                ),
                freshnessInput: nil
            )
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

    private func allCopy(from dashboard: JourneyDashboardState) -> String {
        let presentation = dashboard.screenPresentation
        let unified = dashboard.unifiedWeeklyReview
        let strings = [
            presentation.copy.emptyState?.headline,
            presentation.copy.emptyState?.requirement,
            presentation.unlockDashboard.nextActionCard?.detail,
            presentation.unlockDashboard.checklist?.title,
            unified.cardSummary,
            unified.cardStateTitle,
            unified.confidenceLabel,
            unified.maintenanceBlock?.title,
            unified.maintenanceBlock?.explanation,
            unified.weightTrendBlock?.accessibilityLabel,
        ]
        return strings.compactMap { $0 }.joined(separator: " ")
    }
}

private extension JourneyUnlockChecklistItem {
    var isCompleted: Bool {
        if case .completed = status { return true }
        return false
    }
}
