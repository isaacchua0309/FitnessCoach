//
//  AnalyticsInfrastructureTests.swift
//  Fitness CoachTests
//
//  Forma — Analytics sink wiring, privacy, and NoOp safety tests.
//

import XCTest
@testable import Fitness_Coach

final class AnalyticsInfrastructureTests: XCTestCase {

    // MARK: - AppContainer sink selection

    @MainActor
    func testAppContainerDefaultAnalyticsLoggersMatchBuildConfiguration() throws {
        let container = try AppContainer(inMemory: true)

        #if DEBUG
        XCTAssertTrue(container.todayAnalyticsLogger is OSLogTodayAnalyticsLogger)
        XCTAssertTrue(container.journeyAnalyticsLogger is OSLogJourneyAnalyticsLogger)
        XCTAssertTrue(container.planAnalyticsLogger is OSLogPlanAnalyticsLogger)
        XCTAssertTrue(container.onboardingAnalyticsLogger is OSLogOnboardingAnalyticsLogger)
        XCTAssertTrue(container.settingsAnalyticsLogger is OSLogSettingsAnalyticsLogger)
        XCTAssertTrue(container.publicEntryAnalyticsLogger is OSLogPublicEntryAnalyticsLogger)
        XCTAssertTrue(container.themeAnalyticsLogger is OSLogThemeAnalyticsLogger)
        XCTAssertTrue(container.healthIntelligenceAnalyticsLogger is OSLogHealthIntelligenceAnalyticsLogger)
        #else
        XCTAssertTrue(container.todayAnalyticsLogger is NoOpTodayAnalyticsLogger)
        XCTAssertTrue(container.journeyAnalyticsLogger is NoOpJourneyAnalyticsLogger)
        XCTAssertTrue(container.planAnalyticsLogger is NoOpPlanAnalyticsLogger)
        XCTAssertTrue(container.onboardingAnalyticsLogger is NoOpOnboardingAnalyticsLogger)
        XCTAssertTrue(container.settingsAnalyticsLogger is NoOpSettingsAnalyticsLogger)
        XCTAssertTrue(container.publicEntryAnalyticsLogger is NoOpPublicEntryAnalyticsLogger)
        XCTAssertTrue(container.themeAnalyticsLogger is NoOpThemeAnalyticsLogger)
        XCTAssertTrue(container.healthIntelligenceAnalyticsLogger is NoOpHealthIntelligenceAnalyticsLogger)
        #endif
    }

    @MainActor
    func testHealthIntelligenceCoordinatorUsesContainerLogger() throws {
        let capturing = CapturingHealthIntelligenceAnalyticsLogger()
        let container = try AppContainer(
            inMemory: true,
            healthIntelligenceAnalyticsLogger: capturing
        )

        let coordinator = container.makeHealthIntelligenceAnalyticsCoordinator()
        coordinator.logSnapshotLoaded(
            surface: .today,
            context: HealthIntelligencePresentationContext(
                isLoading: false,
                availability: nil,
                snapshot: HealthIntelligenceSnapshot.previewConnected(),
                isAppleHealthConnected: true,
                cachedDayCount: 7
            )
        )

        XCTAssertEqual(capturing.lastEvent, .snapshotLoaded)
        XCTAssertEqual(capturing.lastProperties?["health_data_state"], "full")
    }

    // MARK: - Event naming

    func testAnalyticsEventNamesFollowSnakeCaseConvention() {
        let events: [String] = TodayAnalyticsEvent.allCases.map(\.rawValue)
            + JourneyAnalyticsEvent.allCases.map(\.rawValue)
            + PlanAnalyticsEvent.allCases.map(\.rawValue)
            + OnboardingAnalyticsEvent.allCases.map(\.rawValue)
            + SettingsAnalyticsEvent.allCases.map(\.rawValue)
            + HealthIntelligenceAnalyticsEvent.allCases.map(\.rawValue)
            + PublicEntryAnalyticsEvent.allCases.map(\.rawValue)
            + ThemeAnalyticsEvent.allCases.map(\.rawValue)
            + CoachAnalyticsEvent.allCases.map(\.rawValue)

        for name in events {
            XCTAssertTrue(
                AnalyticsLoggingSupport.isValidEventName(name),
                "Invalid analytics event name: \(name)"
            )
        }
    }

    // MARK: - Privacy-safe properties

    func testDomainPropertyBuildersExcludeSensitiveValues() {
        let today = TodayAnalyticsProperties.from(
            snapshot: TodayAnalyticsSnapshot(
                dayStage: TodayAnalyticsDayStage.afternoon.rawValue,
                nextActionType: "log_protein",
                hasMealLogged: true,
                proteinStatus: TodayAnalyticsNutrientStatus.behind.rawValue,
                waterStatus: TodayAnalyticsNutrientStatus.onTrack.rawValue,
                calorieStatus: TodayAnalyticsCalorieStatus.under.rawValue,
                workoutStatus: TodayAnalyticsWorkoutStatus.none.rawValue,
                healthConnected: true
            ),
            waterAmountBucket: "medium"
        ).privacySafeParameters()
        XCTAssertTrue(AnalyticsLoggingSupport.isPrivacySafe(today))
        XCTAssertFalse(today.values.contains(where: { $0.localizedCaseInsensitiveContains("chicken") }))

        let journey = JourneyAnalyticsContextBuilder.properties(
            from: JourneyAnalyticsContextBuilder.snapshot(
                from: JourneyPreviewData.state,
                healthConnected: true
            )
        ).privacySafeParameters()
        XCTAssertTrue(AnalyticsLoggingSupport.isPrivacySafe(journey))

        let hi = HealthIntelligenceAnalyticsContextBuilder.properties(
            from: HealthIntelligenceSnapshot.previewConnected(),
            surface: .today
        ).privacySafeParameters()
        XCTAssertTrue(AnalyticsLoggingSupport.isPrivacySafe(hi))
    }

    func testPrivacySafeParametersStripInjectedSensitiveFields() {
        let contaminated: [String: String] = [
            "day_stage": "afternoon",
            "food_name": "Secret Salmon Bowl",
            "user_message": "log my lunch",
            "weight_kg": "72.4"
        ]
        let sanitized = AnalyticsLoggingSupport.privacySafeParameters(contaminated)

        XCTAssertEqual(sanitized["day_stage"], "afternoon")
        XCTAssertNil(sanitized["food_name"])
        XCTAssertNil(sanitized["user_message"])
        XCTAssertNil(sanitized["weight_kg"])
        XCTAssertTrue(AnalyticsLoggingSupport.isPrivacySafe(sanitized))
    }

    // MARK: - NoOp safety

    func testNoOpAnalyticsLoggersAcceptAllEventsWithoutCrashing() {
        let sensitiveToday = TodayAnalyticsProperties(
            dayStage: "afternoon",
            action: "log_private_meal"
        )
        NoOpTodayAnalyticsLogger().log(.logMealSaved, properties: sensitiveToday)

        let sensitiveJourney = JourneyAnalyticsProperties(
            milestoneType: "first-meal",
            ctaType: "log_food"
        )
        NoOpJourneyAnalyticsLogger().log(.viewed, properties: sensitiveJourney)

        let sensitiveHI = HealthIntelligenceAnalyticsProperties(
            healthDataState: "full",
            recoveryStatus: "moderate",
            surface: "today"
        )
        NoOpHealthIntelligenceAnalyticsLogger().log(.snapshotLoaded, properties: sensitiveHI)

        let sensitiveCoach = CoachAnalyticsProperties(
            confidenceLevel: "high",
            hasMacros: true,
            actionType: "log"
        )
        NoOpCoachAnalyticsLogger().log(.nutritionEstimateLogConfirmed, properties: sensitiveCoach)
    }

    func testCapturingLoggersRecordPrivacySafeParameters() {
        let logger = CapturingPlanAnalyticsLogger()
        logger.log(
            .viewed,
            properties: PlanAnalyticsProperties(
                planType: "cut",
                confidenceBucket: "moderate",
                appleHealthConnected: true
            )
        )

        let parameters = logger.events.last?.properties.privacySafeParameters() ?? [:]
        XCTAssertEqual(parameters["plan_type"], "cut")
        XCTAssertEqual(parameters["confidence_bucket"], "moderate")
        XCTAssertTrue(AnalyticsLoggingSupport.isPrivacySafe(parameters))
    }
}

private extension TodayAnalyticsEvent: CaseIterable {
    static var allCases: [TodayAnalyticsEvent] {
        [
            .viewed, .missionViewed, .primaryCTATapped, .nextBestActionViewed,
            .nextBestActionTapped, .quickActionTapped, .mealAddTapped, .mealEditTapped,
            .dailyVictoryViewed, .smartCoachViewed, .endOfDayWrapViewed, .logMealSaved,
            .mealEditSaved, .mealDeleted, .waterAdded, .weightLogged, .scanFoodTapped,
            .goalConnectionTapped
        ]
    }
}

private extension JourneyAnalyticsEvent: CaseIterable {
    static var allCases: [JourneyAnalyticsEvent] { [
        .viewed, .heroViewed, .projectionViewed, .milestoneViewed, .milestoneCTATapped,
        .weeklyConsistencyViewed, .storyViewed, .insightsViewed, .monthlyRecapViewed,
        .chapterViewed, .goToTodayTapped, .weightCTATapped, .coachCTATapped
    ] }
}

private extension PlanAnalyticsEvent: CaseIterable {
    static var allCases: [PlanAnalyticsEvent] { [
        .viewed, .strategyViewed, .statusViewed, .confidenceViewed, .adjustCTATapped,
        .calculationTapped, .activityUpdateTapped, .adjustStarted, .editSaved,
        .targetsRegenerated, .healthConnectTapped, .todayTapped
    ] }
}

private extension OnboardingAnalyticsEvent: CaseIterable {
    static var allCases: [OnboardingAnalyticsEvent] { [
        .started, .stepViewed, .stepCompleted, .planGenerated, .planRevealed,
        .profileSavedLocal, .signInStarted, .signInCompleted, .signInCancelled,
        .completed, .appleHealthPromptViewed, .appleHealthOnboardingViewed,
        .appleHealthConnectTapped, .appleHealthSkipTapped, .appleHealthPermissionRequested,
        .appleHealthPermissionResult
    ] }
}

private extension SettingsAnalyticsEvent: CaseIterable {
    static var allCases: [SettingsAnalyticsEvent] { [
        .settingsViewed, .settingsRowTapped, .accountViewed, .appleHealthSettingsViewed,
        .themeSettingsViewed, .unitsSettingsViewed, .bodyStatsViewed, .privacyPolicyTapped,
        .termsTapped, .supportTapped, .logoutTapped, .logoutConfirmed
    ] }
}

private extension HealthIntelligenceAnalyticsEvent: CaseIterable {
    static var allCases: [HealthIntelligenceAnalyticsEvent] { [
        .snapshotLoaded, .snapshotFailed, .todayRecoveryCardViewed, .todayNextBestActionTapped,
        .coachHealthContextUsed, .journeyRecoveryTimelineViewed, .journeyWorkoutHistoryViewed,
        .weeklyReviewCardViewed, .weeklyReviewDetailOpened, .planHealthConfidenceViewed,
        .healthPermissionCTATapped, .healthPermissionConnected, .healthPermissionPartial,
        .healthLocalSyncSuccess, .healthLocalSyncFailed, .healthSnapshotComposed,
        .healthRemoteSyncSuccess, .healthRemoteSyncFailed, .coachHealthContextAvailable,
        .coachHealthContextPartial
    ] }
}

private extension PublicEntryAnalyticsEvent: CaseIterable {
    static var allCases: [PublicEntryAnalyticsEvent] { [
        .welcomeViewed, .welcomeCreatePlanTapped, .welcomeSignInTapped,
        .existingSignInViewed, .existingSignInStarted, .existingSignInSucceeded,
        .existingSignInFailed, .existingSignInNoProfileFound, .noExistingProfileViewed,
        .noExistingProfileStartOnboardingTapped, .noExistingProfileUseAnotherAccountTapped,
        .logoutCompletedPublicEntryShown
    ] }
}

private extension ThemeAnalyticsEvent: CaseIterable {
    static var allCases: [ThemeAnalyticsEvent] { [
        .settingsViewed, .appearanceModeChanged, .paletteChanged
    ] }
}

private extension CoachAnalyticsEvent: CaseIterable {
    static var allCases: [CoachAnalyticsEvent] { [
        .nutritionEstimateCardShown, .nutritionComparisonCardShown,
        .nutritionEstimateJSONParseFailed, .nutritionEstimateActionTapped,
        .nutritionEstimateLogStarted, .nutritionEstimateLogConfirmed,
        .nutritionEstimateLogCancelled
    ] }
}
