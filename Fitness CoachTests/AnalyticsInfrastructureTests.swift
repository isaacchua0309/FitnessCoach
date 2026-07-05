//
//  AnalyticsInfrastructureTests.swift
//  Fitness CoachTests
//
//  Forma — Analytics sink wiring, privacy, and NoOp safety tests.
//

import XCTest
@testable import Fitness_Coach

final class AnalyticsInfrastructureTests: XCTestCase {

    // MARK: - Configuration

    func testReleaseDefaultConfigurationDisablesProductionSink() {
        XCTAssertFalse(FormaAnalyticsConfiguration.releaseDefault.isProductionSinkEnabled)
        XCTAssertFalse(FormaAnalyticsConfiguration.debug.isProductionSinkEnabled)
        XCTAssertFalse(FormaAnalyticsConfiguration.testing.isProductionSinkEnabled)
    }

    func testCurrentConfigurationMatchesBuildIntent() {
        #if DEBUG
        XCTAssertEqual(FormaAnalyticsConfiguration.current, .debug)
        #else
        XCTAssertEqual(FormaAnalyticsConfiguration.current, .releaseDefault)
        #endif
    }

    func testEnablingProductionSinkRequiresExplicitConfiguration() {
        let explicit = FormaAnalyticsConfiguration(isProductionSinkEnabled: true)
        XCTAssertTrue(explicit.isProductionSinkEnabled)
        XCTAssertNotEqual(explicit, FormaAnalyticsConfiguration.releaseDefault)

        let loggers = AnalyticsLoggerFactory.makeAppLoggers(configuration: .releaseDefault)
        #if DEBUG
        XCTAssertTrue(loggers.today is OSLogTodayAnalyticsLogger)
        #else
        XCTAssertTrue(loggers.today is NoOpTodayAnalyticsLogger)
        #endif
    }

    func testProductionSinkFlagWithoutAdapterStillDefaultsToNoOpInRelease() {
        let configuration = FormaAnalyticsConfiguration(isProductionSinkEnabled: true)
        let loggers = AnalyticsLoggerFactory.makeAppLoggers(configuration: configuration)

        #if DEBUG
        XCTAssertTrue(loggers.today is OSLogTodayAnalyticsLogger)
        #else
        XCTAssertTrue(loggers.today is NoOpTodayAnalyticsLogger)
        #endif
    }

    func testCompositeTodayAnalyticsLoggerForwardsToConfiguredChildren() {
        let first = CapturingTodayAnalyticsLogger()
        let second = CapturingTodayAnalyticsLogger()
        let composite = CompositeTodayAnalyticsLogger(loggers: [first, second])

        let properties = TodayAnalyticsProperties(dayStage: "afternoon", action: "test")
        composite.log(.viewed, properties: properties)

        XCTAssertEqual(first.events.count, 1)
        XCTAssertEqual(second.events.count, 1)
        XCTAssertEqual(first.events.last?.event, .viewed)
        XCTAssertEqual(second.events.last?.event, .viewed)
    }

    func testResolveSinkComposesDebugAndProductionSinksWhenBothPresent() {
        let debug = CapturingTodayAnalyticsLogger()
        let production = CapturingTodayAnalyticsLogger()
        let configuration = FormaAnalyticsConfiguration(isProductionSinkEnabled: true)

        let logger = AnalyticsLoggerFactory.resolve(
            nil as (any TodayAnalyticsLogging)?,
            configuration: configuration,
            debugSink: { debug },
            noOpSink: { NoOpTodayAnalyticsLogger() },
            productionSink: { production },
            composite: { CompositeTodayAnalyticsLogger(loggers: $0) }
        )

        XCTAssertTrue(logger is CompositeTodayAnalyticsLogger)
        logger.log(.viewed, properties: TodayAnalyticsProperties(dayStage: "morning"))

        #if DEBUG
        XCTAssertEqual(debug.events.count, 1)
        XCTAssertEqual(production.events.count, 1)
        #else
        XCTAssertEqual(debug.events.count, 0)
        XCTAssertEqual(production.events.count, 1)
        #endif
    }

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

extension TodayAnalyticsEvent: CaseIterable {
    public static var allCases: [TodayAnalyticsEvent] {
        [
            .viewed, .missionViewed, .primaryCTATapped, .nextBestActionViewed,
            .nextBestActionTapped, .quickActionTapped, .mealAddTapped, .mealEditTapped,
            .dailyVictoryViewed, .smartCoachViewed, .endOfDayWrapViewed, .logMealSaved,
            .mealEditSaved, .mealDeleted, .waterAdded, .weightLogged, .scanFoodTapped,
            .goalConnectionTapped
        ]
    }
}

extension JourneyAnalyticsEvent: CaseIterable {
    public static var allCases: [JourneyAnalyticsEvent] { [
        .viewed, .heroViewed, .projectionViewed, .milestoneViewed, .milestoneCTATapped,
        .weeklyConsistencyViewed, .storyViewed, .insightsViewed, .monthlyRecapViewed,
        .chapterViewed, .goToTodayTapped, .weightCTATapped, .coachCTATapped
    ] }
}

extension PlanAnalyticsEvent: CaseIterable {
    public static var allCases: [PlanAnalyticsEvent] { [
        .viewed, .strategyViewed, .statusViewed, .confidenceViewed, .adjustCTATapped,
        .calculationTapped, .activityUpdateTapped, .adjustStarted, .editSaved,
        .targetsRegenerated, .healthConnectTapped, .todayTapped
    ] }
}

extension OnboardingAnalyticsEvent: CaseIterable {
    public static var allCases: [OnboardingAnalyticsEvent] { [
        .started, .stepViewed, .stepCompleted, .planGenerated, .planRevealed,
        .profileSavedLocal, .signInStarted, .signInCompleted, .signInCancelled,
        .completed, .appleHealthPromptViewed, .appleHealthOnboardingViewed,
        .appleHealthConnectTapped, .appleHealthSkipTapped, .appleHealthPermissionRequested,
        .appleHealthPermissionResult
    ] }
}

extension SettingsAnalyticsEvent: CaseIterable {
    public static var allCases: [SettingsAnalyticsEvent] { [
        .settingsViewed, .settingsRowTapped, .accountViewed, .appleHealthSettingsViewed,
        .themeSettingsViewed, .unitsSettingsViewed, .bodyStatsViewed, .privacyPolicyTapped,
        .termsTapped, .supportTapped, .logoutTapped, .logoutConfirmed
    ] }
}

extension HealthIntelligenceAnalyticsEvent: CaseIterable {
    public static var allCases: [HealthIntelligenceAnalyticsEvent] { [
        .snapshotLoaded, .snapshotFailed, .todayRecoveryCardViewed, .todayNextBestActionTapped,
        .coachHealthContextUsed, .journeyRecoveryTimelineViewed, .journeyWorkoutHistoryViewed,
        .weeklyReviewCardViewed, .weeklyReviewDetailOpened, .planHealthConfidenceViewed,
        .healthPermissionCTATapped, .healthPermissionConnected, .healthPermissionPartial,
        .healthLocalSyncSuccess, .healthLocalSyncFailed, .healthSnapshotComposed,
        .healthRemoteSyncSuccess, .healthRemoteSyncFailed, .coachHealthContextAvailable,
        .coachHealthContextPartial
    ] }
}

extension PublicEntryAnalyticsEvent: CaseIterable {
    public static var allCases: [PublicEntryAnalyticsEvent] { [
        .welcomeViewed, .welcomeCreatePlanTapped, .welcomeSignInTapped,
        .existingSignInViewed, .existingSignInStarted, .existingSignInSucceeded,
        .existingSignInFailed, .existingSignInNoProfileFound, .noExistingProfileViewed,
        .noExistingProfileStartOnboardingTapped, .noExistingProfileUseAnotherAccountTapped,
        .logoutCompletedPublicEntryShown
    ] }
}

extension ThemeAnalyticsEvent: CaseIterable {
    public static var allCases: [ThemeAnalyticsEvent] { [
        .settingsViewed, .appearanceModeChanged, .paletteChanged
    ] }
}

extension CoachAnalyticsEvent: CaseIterable {
    public static var allCases: [CoachAnalyticsEvent] { [
        .nutritionEstimateCardShown, .nutritionComparisonCardShown,
        .nutritionEstimateJSONParseFailed, .nutritionEstimateActionTapped,
        .nutritionEstimateLogStarted, .nutritionEstimateLogConfirmed,
        .nutritionEstimateLogCancelled
    ] }
}
