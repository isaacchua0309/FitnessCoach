//
//  HealthIntelligencePresentationParityTests.swift
//  Fitness CoachTests
//
//  Golden parity gate for Health Intelligence presentation across Today, Plan, and Journey.
//  Expected values are frozen from characterization fixtures A–E; any unintentional
//  presentation drift should fail here before legacy HI paths are deleted.
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligencePresentationParityTests: XCTestCase {

    private var referenceNow: Date {
        HealthIntelligencePresentationCharacterizationFixtures.referenceNow
    }

    // MARK: - Fixture A: fully ready

    func testParityFixtureA_FullyReady_MatchesGoldenPresentationAcrossSurfaces() {
        let today = requireToday(
            HealthIntelligencePresentationCharacterizationFixtures.buildTodaySection(
                for: .fullyReady,
                now: referenceNow
            )
        )
        let plan = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(
            for: .fullyReady,
            now: referenceNow
        )
        let journey = requireJourney(
            HealthIntelligencePresentationCharacterizationFixtures.buildJourneySection(
                for: .fullyReady,
                now: referenceNow
            )
        )

        assertTodayParity(
            section: today,
            expectation: TodayParityExpectation(
                isVisible: true,
                uiStateKind: .ready,
                recoveryTitle: "Moderate recovery",
                recoveryPhase: .moderate,
                recoveryConfidenceNote: nil,
                visibleHealthCardCount: 3,
                workoutCardTitle: FormaProductCopy.Today.HealthIntelligence.workoutComplete,
                workoutCardSubtitle: "Strength training",
                adaptiveCardVisible: true,
                adaptiveCardTitle: FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.postWorkoutTitle,
                nextBestActionVisible: true,
                nextBestActionTitle: "Log protein",
                nextBestActionCTA: "Log meal",
                nextBestActionDestination: .logMeal,
                fallbackMessage: nil,
                staleDataLabel: nil
            ),
            surface: .today
        )

        assertPlanParity(
            section: plan,
            expectation: PlanParityExpectation(
                isLoading: false,
                uiStateKind: .ready,
                confidenceLabel: FormaProductCopy.PlanHealthIntelligencePresentation.confidenceHigh,
                confidenceScorePercent: 82,
                dataQualityLevel: .strong,
                dataQualityLabel: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualityStrongLabel,
                missingDataActionCount: 0,
                missingDataActionIDs: [],
                fallbackMessage: nil,
                staleDataLabel: nil,
                sectionAccessibilityNonEmpty: true
            ),
            surface: .plan
        )

        assertJourneyParity(
            section: journey,
            expectation: JourneyParityExpectation(
                isVisible: true,
                uiStateKind: .ready,
                weeklyReviewCardPhase: .loaded,
                weeklyReviewCardTitle: "Solid training week",
                weeklyReviewConfidenceLabel: FormaProductCopy.WeeklyReviewPresentation.confidenceModerate,
                weeklyReviewDetailPresent: true,
                recoveryTimelinePhase: .loaded,
                workoutHistoryPhase: .loaded,
                workoutHistoryEmptyKind: nil,
                milestonesPhase: .loaded,
                progressPhase: .loaded,
                connectHealthCTAVisible: false,
                connectHealthCTATitle: nil,
                fallbackMessage: nil,
                staleDataLabel: nil,
                partialSignalsNote: nil,
                weeklyReviewAccessibilityNonEmpty: true
            ),
            surface: .journey
        )
    }

    // MARK: - Fixture B: HealthKit disconnected

    func testParityFixtureB_HealthKitDisconnected_MatchesGoldenPresentationAcrossSurfaces() {
        let today = requireToday(
            HealthIntelligencePresentationCharacterizationFixtures.buildTodaySection(
                for: .healthKitDisconnected,
                now: referenceNow
            )
        )
        let plan = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(
            for: .healthKitDisconnected,
            now: referenceNow
        )
        let journey = requireJourney(
            HealthIntelligencePresentationCharacterizationFixtures.buildJourneySection(
                for: .healthKitDisconnected,
                now: referenceNow
            )
        )

        assertTodayParity(
            section: today,
            expectation: TodayParityExpectation(
                isVisible: true,
                uiStateKind: nil,
                allowedUIStateKinds: [.noHealthPermission, .healthKitUnavailable],
                recoveryTitle: nil,
                recoveryPhase: .unknown,
                recoveryConfidenceNote: nil,
                visibleHealthCardCount: 1,
                workoutCardTitle: nil,
                workoutCardSubtitle: nil,
                adaptiveCardVisible: false,
                adaptiveCardTitle: nil,
                nextBestActionVisible: true,
                nextBestActionTitle: FormaProductCopy.Today.actionConnectAppleHealth,
                nextBestActionCTA: nil,
                nextBestActionDestination: .connectHealth,
                fallbackMessage: FormaProductCopy.Today.HealthIntelligence.connectHealthFallback,
                staleDataLabel: nil,
                recoveryAccessibilityNonEmpty: true
            ),
            surface: .today
        )

        assertPlanParity(
            section: plan,
            expectation: PlanParityExpectation(
                isLoading: false,
                uiStateKind: nil,
                confidenceLabel: FormaProductCopy.PlanHealthIntelligencePresentation.confidenceUnknown,
                confidenceScorePercent: nil,
                dataQualityLevel: .limited,
                dataQualityLabel: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualityLimitedLabel,
                missingDataActionCount: 1,
                missingDataActionIDs: ["connect-health"],
                fallbackMessage: nil,
                staleDataLabel: nil,
                sectionAccessibilityNonEmpty: true,
                connectHealthActionTitle: FormaProductCopy.PlanHealthIntelligencePresentation.actionConnectHealthTitle
            ),
            surface: .plan
        )

        assertJourneyParity(
            section: journey,
            expectation: JourneyParityExpectation(
                isVisible: true,
                uiStateKind: journey.uiState?.kind,
                weeklyReviewCardPhase: nil,
                weeklyReviewCardTitle: nil,
                weeklyReviewConfidenceLabel: nil,
                weeklyReviewDetailPresent: false,
                recoveryTimelinePhase: .empty,
                workoutHistoryPhase: .empty,
                workoutHistoryEmptyKind: .noHealthData,
                milestonesPhase: .empty,
                progressPhase: .empty,
                connectHealthCTAVisible: true,
                connectHealthCTATitle: FormaProductCopy.Journey.HealthIntelligence.connectHealthCTA,
                fallbackMessage: nil,
                staleDataLabel: nil,
                partialSignalsNote: nil,
                connectHealthAccessibilityNonEmpty: true,
                weeklyReviewAccessibilityNonEmpty: false
            ),
            surface: .journey
        )
    }

    // MARK: - Fixture C: stale data

    func testParityFixtureC_StaleData_MatchesGoldenPresentationAcrossSurfaces() {
        let today = requireToday(
            HealthIntelligencePresentationCharacterizationFixtures.buildTodaySection(
                for: .staleData,
                now: referenceNow
            )
        )
        let plan = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(
            for: .staleData,
            now: referenceNow
        )
        let journey = requireJourney(
            HealthIntelligencePresentationCharacterizationFixtures.buildJourneySection(
                for: .staleData,
                now: referenceNow
            )
        )

        assertTodayParity(
            section: today,
            expectation: TodayParityExpectation(
                isVisible: true,
                uiStateKind: .staleData,
                recoveryTitle: "Moderate recovery",
                recoveryPhase: .moderate,
                recoveryConfidenceNote: nil,
                visibleHealthCardCount: 3,
                workoutCardTitle: FormaProductCopy.Today.HealthIntelligence.workoutComplete,
                workoutCardSubtitle: "Strength training",
                adaptiveCardVisible: true,
                adaptiveCardTitle: today.adaptiveNutritionCard?.title,
                nextBestActionVisible: true,
                nextBestActionTitle: "Log protein",
                nextBestActionCTA: "Log meal",
                nextBestActionDestination: .logMeal,
                fallbackMessage: nil,
                staleDataLabel: FormaProductCopy.Today.HealthIntelligence.staleDataLabel
            ),
            surface: .today
        )

        assertPlanParity(
            section: plan,
            expectation: PlanParityExpectation(
                isLoading: false,
                uiStateKind: .staleData,
                confidenceLabel: FormaProductCopy.PlanHealthIntelligencePresentation.confidenceModerate,
                confidenceScorePercent: 62,
                dataQualityLevel: .strong,
                dataQualityLabel: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualityStrongLabel,
                missingDataActionCount: 0,
                missingDataActionIDs: [],
                fallbackMessage: nil,
                staleDataLabel: FormaProductCopy.Today.HealthIntelligence.staleDataLabel,
                sectionAccessibilityNonEmpty: true
            ),
            surface: .plan
        )

        assertJourneyParity(
            section: journey,
            expectation: JourneyParityExpectation(
                isVisible: true,
                uiStateKind: .staleData,
                weeklyReviewCardPhase: .empty,
                weeklyReviewCardTitle: FormaProductCopy.WeeklyReviewPresentation.emptyTitle,
                weeklyReviewConfidenceLabel: FormaProductCopy.Journey.WeeklyConfidence.building,
                weeklyReviewDetailPresent: false,
                recoveryTimelinePhase: .loaded,
                workoutHistoryPhase: .loaded,
                workoutHistoryEmptyKind: nil,
                milestonesPhase: .loaded,
                progressPhase: .loaded,
                connectHealthCTAVisible: false,
                connectHealthCTATitle: nil,
                fallbackMessage: nil,
                staleDataLabel: FormaProductCopy.Journey.HealthIntelligence.staleDataLabel,
                partialSignalsNote: nil,
                recoveryTimelineDayCount: 7,
                weeklyReviewAccessibilityNonEmpty: true
            ),
            surface: .journey
        )
        XCTAssertFalse(journey.recoveryTimeline.days.isEmpty)
    }

    // MARK: - Fixture D: partial signals

    func testParityFixtureD_PartialSignals_MatchesGoldenPresentationAcrossSurfaces() {
        let today = requireToday(
            HealthIntelligencePresentationCharacterizationFixtures.buildTodaySection(
                for: .partialSignals,
                now: referenceNow
            )
        )
        let plan = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(
            for: .partialSignals,
            now: referenceNow
        )
        let journey = requireJourney(
            HealthIntelligencePresentationCharacterizationFixtures.buildJourneySection(
                for: .partialSignals,
                now: referenceNow
            )
        )

        assertTodayParity(
            section: today,
            expectation: TodayParityExpectation(
                isVisible: true,
                uiStateKind: .partialPermission,
                recoveryTitle: "Recovery forming",
                recoveryPhase: .limitedEstimate,
                recoveryConfidenceNote: FormaProductCopy.HealthIntelligence.partialDataLabel,
                visibleHealthCardCount: 1,
                workoutCardTitle: nil,
                workoutCardSubtitle: nil,
                adaptiveCardVisible: false,
                adaptiveCardTitle: nil,
                nextBestActionVisible: false,
                nextBestActionTitle: nil,
                nextBestActionCTA: nil,
                nextBestActionDestination: nil,
                fallbackMessage: nil,
                staleDataLabel: nil
            ),
            surface: .today
        )

        assertPlanParity(
            section: plan,
            expectation: PlanParityExpectation(
                isLoading: false,
                uiStateKind: .partialPermission,
                confidenceLabel: FormaProductCopy.PlanHealthIntelligencePresentation.confidenceModerate,
                confidenceScorePercent: 52,
                dataQualityLevel: .limited,
                dataQualityLabel: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualityLimitedLabel,
                dataQualityExplanation: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualitySummaryPartial,
                missingDataActionCount: 3,
                missingDataActionIDs: ["nutrition", "partial-permissions", "weight"],
                forbiddenMissingDataActionIDs: ["sleep", "heart-metrics"],
                fallbackMessage: nil,
                staleDataLabel: nil,
                sectionAccessibilityNonEmpty: true
            ),
            surface: .plan
        )

        assertJourneyParity(
            section: journey,
            expectation: JourneyParityExpectation(
                isVisible: true,
                uiStateKind: .partialPermission,
                weeklyReviewCardPhase: .empty,
                weeklyReviewCardTitle: FormaProductCopy.WeeklyReviewPresentation.emptyTitle,
                weeklyReviewConfidenceLabel: FormaProductCopy.Journey.WeeklyConfidence.building,
                weeklyReviewDetailPresent: false,
                recoveryTimelinePhase: .loaded,
                workoutHistoryPhase: .empty,
                workoutHistoryEmptyKind: .connectedNoWorkouts,
                milestonesPhase: .loaded,
                progressPhase: .loaded,
                connectHealthCTAVisible: false,
                connectHealthCTATitle: nil,
                fallbackMessage: nil,
                staleDataLabel: nil,
                partialSignalsNote: FormaProductCopy.Journey.Sync.healthDataSyncing,
                weeklyReviewAccessibilityNonEmpty: false
            ),
            surface: .journey
        )
    }

    // MARK: - Fixture E: weekly review unavailable

    func testParityFixtureE_WeeklyReviewUnavailable_MatchesGoldenPresentationAcrossSurfaces() {
        let today = requireToday(
            HealthIntelligencePresentationCharacterizationFixtures.buildTodaySection(
                for: .weeklyReviewUnavailable,
                now: referenceNow
            )
        )
        let plan = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(
            for: .weeklyReviewUnavailable,
            now: referenceNow
        )
        let journey = requireJourney(
            HealthIntelligencePresentationCharacterizationFixtures.buildJourneySection(
                for: .weeklyReviewUnavailable,
                now: referenceNow
            )
        )

        assertTodayParity(
            section: today,
            expectation: TodayParityExpectation(
                isVisible: true,
                uiStateKind: .ready,
                recoveryTitle: "Moderate recovery",
                recoveryPhase: .moderate,
                recoveryConfidenceNote: nil,
                visibleHealthCardCount: 3,
                workoutCardTitle: FormaProductCopy.Today.HealthIntelligence.workoutComplete,
                workoutCardSubtitle: "Strength training",
                adaptiveCardVisible: true,
                adaptiveCardTitle: FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.postWorkoutTitle,
                nextBestActionVisible: true,
                nextBestActionTitle: "Log protein",
                nextBestActionCTA: "Log meal",
                nextBestActionDestination: .logMeal,
                fallbackMessage: nil,
                staleDataLabel: nil
            ),
            surface: .today
        )

        assertPlanParity(
            section: plan,
            expectation: PlanParityExpectation(
                isLoading: false,
                uiStateKind: .ready,
                confidenceLabel: FormaProductCopy.PlanHealthIntelligencePresentation.confidenceHigh,
                confidenceScorePercent: 82,
                dataQualityLevel: .strong,
                dataQualityLabel: FormaProductCopy.PlanHealthIntelligencePresentation.dataQualityStrongLabel,
                missingDataActionCount: 0,
                missingDataActionIDs: [],
                fallbackMessage: nil,
                staleDataLabel: nil,
                sectionAccessibilityNonEmpty: true
            ),
            surface: .plan
        )

        assertJourneyParity(
            section: journey,
            expectation: JourneyParityExpectation(
                isVisible: true,
                uiStateKind: .ready,
                weeklyReviewCardPhase: .empty,
                weeklyReviewCardTitle: FormaProductCopy.WeeklyReviewPresentation.emptyTitle,
                weeklyReviewConfidenceLabel: FormaProductCopy.Journey.WeeklyConfidence.building,
                weeklyReviewDetailPresent: false,
                recoveryTimelinePhase: .loaded,
                workoutHistoryPhase: .loaded,
                workoutHistoryEmptyKind: nil,
                milestonesPhase: .loaded,
                progressPhase: .loaded,
                connectHealthCTAVisible: false,
                connectHealthCTATitle: nil,
                fallbackMessage: nil,
                staleDataLabel: nil,
                partialSignalsNote: nil,
                weeklyReviewAccessibilityNonEmpty: true
            ),
            surface: .journey
        )
    }

    // MARK: - Surface metadata gate

    func testParitySurfaceMetadata_ResolvesExpectedAnalyticsSurfacesForFixtures() {
        let surfaces: [(HealthIntelligenceSurface, String)] = [
            (.today, "today"),
            (.plan, "plan"),
            (.journey, "journey")
        ]

        for (surface, expectedRawValue) in surfaces {
            let uiState = HealthIntelligencePresentationCharacterizationFixtures.resolvedUIState(
                for: .fullyReady,
                surface: surface,
                now: referenceNow
            )
            XCTAssertEqual(surface.rawValue, expectedRawValue)
            XCTAssertEqual(uiState.kind, .ready)
            XCTAssertTrue(uiState.canShowInsight)
        }
    }
}

// MARK: - Golden expectation models

private struct TodayParityExpectation {
    var isVisible: Bool
    var uiStateKind: HealthIntelligenceUIStateKind?
    var allowedUIStateKinds: [HealthIntelligenceUIStateKind] = []
    var recoveryTitle: String?
    var recoveryPhase: TodayRecoveryCardPhase
    var recoveryConfidenceNote: String?
    var visibleHealthCardCount: Int
    var workoutCardTitle: String?
    var workoutCardSubtitle: String?
    var adaptiveCardVisible: Bool
    var adaptiveCardTitle: String?
    var nextBestActionVisible: Bool
    var nextBestActionTitle: String?
    var nextBestActionCTA: String?
    var nextBestActionDestination: TodayHealthNextBestActionDestination?
    var fallbackMessage: String?
    var staleDataLabel: String?
    var recoveryAccessibilityNonEmpty: Bool = true
}

private struct PlanParityExpectation {
    var isLoading: Bool
    var uiStateKind: HealthIntelligenceUIStateKind?
    var confidenceLabel: String
    var confidenceScorePercent: Int?
    var dataQualityLevel: PlanHealthDataQualityLevel
    var dataQualityLabel: String?
    var dataQualityExplanation: String?
    var missingDataActionCount: Int
    var missingDataActionIDs: [String]
    var forbiddenMissingDataActionIDs: [String] = []
    var fallbackMessage: String?
    var staleDataLabel: String?
    var sectionAccessibilityNonEmpty: Bool
    var connectHealthActionTitle: String?
}

private struct JourneyParityExpectation {
    var isVisible: Bool
    var uiStateKind: HealthIntelligenceUIStateKind?
    var weeklyReviewCardPhase: WeeklyReviewContentPhase?
    var weeklyReviewCardTitle: String?
    var weeklyReviewConfidenceLabel: String?
    var weeklyReviewDetailPresent: Bool
    var recoveryTimelinePhase: JourneyHealthIntelligenceContentPhase
    var workoutHistoryPhase: JourneyHealthIntelligenceContentPhase
    var workoutHistoryEmptyKind: JourneyHealthIntelligenceEmptyKind?
    var milestonesPhase: JourneyHealthIntelligenceContentPhase
    var progressPhase: JourneyHealthIntelligenceContentPhase
    var connectHealthCTAVisible: Bool
    var connectHealthCTATitle: String?
    var fallbackMessage: String?
    var staleDataLabel: String?
    var partialSignalsNote: String?
    var recoveryTimelineDayCount: Int?
    var connectHealthAccessibilityNonEmpty: Bool = false
    var weeklyReviewAccessibilityNonEmpty: Bool
}

// MARK: - Assertion helpers

private extension HealthIntelligencePresentationParityTests {

    func requireToday(_ section: TodayHealthIntelligenceSectionState?) -> TodayHealthIntelligenceSectionState {
        guard let section else {
            XCTFail("Expected Today section")
            return TodayHealthIntelligenceSectionState(
                recoveryCard: .loading,
                dailyMission: .loading,
                nextBestAction: .loading,
                workoutCard: nil,
                adaptiveNutritionCard: nil,
                isLoading: false,
                fallbackMessage: nil,
                uiState: nil,
                staleDataLabel: nil
            )
        }
        return section
    }

    func requireJourney(_ section: JourneyHealthIntelligenceSectionState?) -> JourneyHealthIntelligenceSectionState {
        guard let section else {
            XCTFail("Expected Journey section")
            return JourneyHealthIntelligenceSectionState(
                weeklyReviewCard: nil,
                weeklyReviewDetail: nil,
                recoveryTimeline: .loading,
                workoutHistory: .loading,
                milestones: .loading,
                progress: .loading,
                connectHealthCTA: nil,
                isLoading: false,
                errorMessage: nil,
                fallbackMessage: nil,
                staleDataLabel: nil,
                partialSignalsNote: nil,
                uiState: nil
            )
        }
        return section
    }

    func assertTodayParity(
        section: TodayHealthIntelligenceSectionState,
        expectation: TodayParityExpectation,
        surface: HealthIntelligenceSurface,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(section.isVisible, expectation.isVisible, file: file, line: line)
        assertUIStateKind(
            actual: section.uiState?.kind,
            expected: expectation.uiStateKind,
            allowed: expectation.allowedUIStateKinds,
            surface: surface,
            file: file,
            line: line
        )

        if let recoveryTitle = expectation.recoveryTitle {
            XCTAssertEqual(section.recoveryCard.title, recoveryTitle, file: file, line: line)
        }
        XCTAssertEqual(section.recoveryCard.phase, expectation.recoveryPhase, file: file, line: line)
        XCTAssertEqual(section.recoveryCard.confidenceNote, expectation.recoveryConfidenceNote, file: file, line: line)
        if expectation.recoveryAccessibilityNonEmpty {
            XCTAssertFalse(section.recoveryCard.accessibilityLabel.isEmpty, file: file, line: line)
        }

        let visibleHealthCards = 1
            + (section.workoutCard == nil ? 0 : 1)
            + ((section.adaptiveNutritionCard?.isVisible == true) ? 1 : 0)
        XCTAssertEqual(visibleHealthCards, expectation.visibleHealthCardCount, file: file, line: line)

        if let workoutCardTitle = expectation.workoutCardTitle {
            XCTAssertEqual(section.workoutCard?.title, workoutCardTitle, file: file, line: line)
        } else {
            XCTAssertNil(section.workoutCard, file: file, line: line)
        }
        XCTAssertEqual(section.workoutCard?.subtitle, expectation.workoutCardSubtitle, file: file, line: line)

        XCTAssertEqual(section.adaptiveNutritionCard?.isVisible == true, expectation.adaptiveCardVisible, file: file, line: line)
        if let adaptiveCardTitle = expectation.adaptiveCardTitle {
            XCTAssertEqual(section.adaptiveNutritionCard?.title, adaptiveCardTitle, file: file, line: line)
        }

        XCTAssertEqual(section.nextBestAction.isVisible, expectation.nextBestActionVisible, file: file, line: line)
        if let nextBestActionTitle = expectation.nextBestActionTitle {
            XCTAssertEqual(section.nextBestAction.title, nextBestActionTitle, file: file, line: line)
        }
        if let nextBestActionCTA = expectation.nextBestActionCTA {
            XCTAssertEqual(section.nextBestAction.ctaTitle, nextBestActionCTA, file: file, line: line)
        }
        if let nextBestActionDestination = expectation.nextBestActionDestination {
            XCTAssertEqual(section.nextBestAction.destination, nextBestActionDestination, file: file, line: line)
        }
        if expectation.nextBestActionVisible {
            XCTAssertFalse(section.nextBestAction.accessibilityLabel.isEmpty, file: file, line: line)
        }

        XCTAssertEqual(section.fallbackMessage, expectation.fallbackMessage, file: file, line: line)
        XCTAssertEqual(section.staleDataLabel, expectation.staleDataLabel, file: file, line: line)

        if let uiState = section.uiState {
            XCTAssertEqual(
                HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
                section.fallbackMessage,
                file: file,
                line: line
            )
        }
    }

    func assertPlanParity(
        section: PlanHealthIntelligenceSectionState,
        expectation: PlanParityExpectation,
        surface: HealthIntelligenceSurface,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(section.isLoading, expectation.isLoading, file: file, line: line)
        assertUIStateKind(
            actual: section.uiState?.kind,
            expected: expectation.uiStateKind,
            surface: surface,
            file: file,
            line: line
        )

        XCTAssertEqual(section.confidenceCard.phase, .loaded, file: file, line: line)
        XCTAssertEqual(section.confidenceCard.confidenceLabel, expectation.confidenceLabel, file: file, line: line)
        XCTAssertEqual(section.confidenceCard.scorePercent, expectation.confidenceScorePercent, file: file, line: line)
        XCTAssertFalse(section.confidenceCard.accessibilityLabel.isEmpty, file: file, line: line)

        XCTAssertEqual(section.dataQuality.qualityLevel, expectation.dataQualityLevel, file: file, line: line)
        if let dataQualityLabel = expectation.dataQualityLabel {
            XCTAssertEqual(section.dataQuality.qualityLabel, dataQualityLabel, file: file, line: line)
        }
        if let explanation = expectation.dataQualityExplanation {
            XCTAssertEqual(section.dataQuality.explanation, explanation, file: file, line: line)
        }
        XCTAssertFalse(section.dataQuality.accessibilityLabel.isEmpty, file: file, line: line)

        XCTAssertEqual(section.missingDataActions.count, expectation.missingDataActionCount, file: file, line: line)
        XCTAssertEqual(
            section.missingDataActions.map(\.id).sorted(),
            expectation.missingDataActionIDs.sorted(),
            file: file,
            line: line
        )
        for forbiddenID in expectation.forbiddenMissingDataActionIDs {
            XCTAssertFalse(
                section.missingDataActions.contains { $0.id == forbiddenID },
                "Unexpected missing-data action \(forbiddenID)",
                file: file,
                line: line
            )
        }
        for action in section.missingDataActions {
            XCTAssertFalse(action.accessibilityLabel.isEmpty, file: file, line: line)
        }
        if let connectHealthActionTitle = expectation.connectHealthActionTitle {
            XCTAssertEqual(
                section.missingDataActions.first(where: { $0.id == "connect-health" })?.title,
                connectHealthActionTitle,
                file: file,
                line: line
            )
        }

        XCTAssertEqual(section.fallbackMessage, expectation.fallbackMessage, file: file, line: line)
        XCTAssertEqual(section.staleDataLabel, expectation.staleDataLabel, file: file, line: line)
        XCTAssertEqual(section.accessibilityLabel.isEmpty, !expectation.sectionAccessibilityNonEmpty, file: file, line: line)

        if let uiState = section.uiState {
            XCTAssertEqual(
                HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
                section.fallbackMessage,
                file: file,
                line: line
            )
        }
    }

    func assertJourneyParity(
        section: JourneyHealthIntelligenceSectionState,
        expectation: JourneyParityExpectation,
        surface: HealthIntelligenceSurface,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(section.isVisible, expectation.isVisible, file: file, line: line)
        assertUIStateKind(
            actual: section.uiState?.kind,
            expected: expectation.uiStateKind,
            surface: surface,
            file: file,
            line: line
        )

        if let weeklyReviewCardPhase = expectation.weeklyReviewCardPhase {
            XCTAssertEqual(section.weeklyReviewCard?.phase, weeklyReviewCardPhase, file: file, line: line)
        } else {
            XCTAssertNil(section.weeklyReviewCard, file: file, line: line)
        }
        XCTAssertEqual(section.weeklyReviewCard?.title, expectation.weeklyReviewCardTitle, file: file, line: line)
        XCTAssertEqual(section.weeklyReviewCard?.confidenceLabel, expectation.weeklyReviewConfidenceLabel, file: file, line: line)
        XCTAssertEqual(section.weeklyReviewDetail != nil, expectation.weeklyReviewDetailPresent, file: file, line: line)
        if expectation.weeklyReviewAccessibilityNonEmpty {
            XCTAssertFalse(section.weeklyReviewCard?.accessibilityLabel.isEmpty ?? true, file: file, line: line)
        }

        XCTAssertEqual(section.recoveryTimeline.phase, expectation.recoveryTimelinePhase, file: file, line: line)
        if let dayCount = expectation.recoveryTimelineDayCount {
            XCTAssertEqual(section.recoveryTimeline.days.count, dayCount, file: file, line: line)
        }
        XCTAssertFalse(section.recoveryTimeline.accessibilityLabel.isEmpty, file: file, line: line)

        XCTAssertEqual(section.workoutHistory.phase, expectation.workoutHistoryPhase, file: file, line: line)
        XCTAssertEqual(section.workoutHistory.emptyKind, expectation.workoutHistoryEmptyKind, file: file, line: line)
        XCTAssertFalse(section.workoutHistory.accessibilityLabel.isEmpty, file: file, line: line)

        XCTAssertEqual(section.milestones.phase, expectation.milestonesPhase, file: file, line: line)
        XCTAssertFalse(section.milestones.accessibilityLabel.isEmpty, file: file, line: line)

        XCTAssertEqual(section.progress.phase, expectation.progressPhase, file: file, line: line)
        XCTAssertFalse(section.progress.accessibilityLabel.isEmpty, file: file, line: line)

        XCTAssertEqual(section.connectHealthCTA != nil, expectation.connectHealthCTAVisible, file: file, line: line)
        XCTAssertEqual(section.connectHealthCTA?.ctaTitle, expectation.connectHealthCTATitle, file: file, line: line)
        if expectation.connectHealthAccessibilityNonEmpty {
            XCTAssertFalse(section.connectHealthCTA?.accessibilityLabel.isEmpty ?? true, file: file, line: line)
        }

        XCTAssertEqual(section.fallbackMessage, expectation.fallbackMessage, file: file, line: line)
        XCTAssertEqual(section.staleDataLabel, expectation.staleDataLabel, file: file, line: line)
        XCTAssertEqual(section.partialSignalsNote, expectation.partialSignalsNote, file: file, line: line)

        if let uiState = section.uiState {
            XCTAssertEqual(
                HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
                section.fallbackMessage,
                file: file,
                line: line
            )
        }
    }

    func assertUIStateKind(
        actual: HealthIntelligenceUIStateKind?,
        expected: HealthIntelligenceUIStateKind?,
        allowed: [HealthIntelligenceUIStateKind] = [],
        surface: HealthIntelligenceSurface,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if let expected {
            XCTAssertEqual(actual, expected, "Unexpected uiState.kind for \(surface.rawValue)", file: file, line: line)
            return
        }
        if !allowed.isEmpty {
            XCTAssertTrue(
                allowed.contains(actual ?? .unknown),
                "Expected one of \(allowed) for \(surface.rawValue), got \(String(describing: actual))",
                file: file,
                line: line
            )
            return
        }
        if let actual {
            XCTAssertNotNil(actual, file: file, line: line)
        }
    }
}
