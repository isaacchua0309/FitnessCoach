//
//  HealthIntelligencePhase11IntegrationTests.swift
//  Fitness CoachTests
//
//  End-to-end state and integration tests for Phase 11–15 Health Intelligence UI.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

// MARK: - Scenario 1: Feature flag off

@MainActor
final class HealthIntelligencePhase11FlagOffIntegrationTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: Phase11TrackingSnapshotService!
    private var weeklyReviewService: Phase11TrackingWeeklyReviewService!
    private var healthRepository: Phase11MockHealthDataRepository!
    private var baselineProvider: Phase11MockBaselineProvider!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = Phase11TrackingSnapshotService()
        weeklyReviewService = Phase11TrackingWeeklyReviewService()
        healthRepository = Phase11MockHealthDataRepository(
            availability: HealthIntelligencePhase11IntegrationTestSupport.availability(connected: true, cachedDayCount: 7)
        )
        baselineProvider = Phase11MockBaselineProvider()
        snapshotProvider.snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .fullHealth,
            on: harness.today
        )
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        weeklyReviewService = nil
        healthRepository = nil
        baselineProvider = nil
        super.tearDown()
    }

    func testTodayUnchangedWhenHealthIntelligenceDisabled() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let flags = HealthIntelligencePhase11FlagPreset.off
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeTodayModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider
        )

        await model.loadToday()

        XCTAssertNil(model.healthIntelligenceSectionState)
        XCTAssertEqual(snapshotProvider.loadCallCount, 0)
        XCTAssertFalse(
            TodayReadOnlyCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: flags.uiEnabled,
                sectionState: TodayHealthIntelligencePreviewData.readyDay
            )
        )
        XCTAssertTrue(
            TodayReadOnlyCompositionPolicy.showsLegacyNextBestAction(
                isUIEnabled: flags.uiEnabled,
                sectionState: nil
            )
        )
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testJourneyUnchangedWhenHealthIntelligenceDisabled() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let flags = HealthIntelligencePhase11FlagPreset.off
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeJourneyModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            weeklyReviewService: weeklyReviewService,
            healthRepository: healthRepository
        )

        await model.refresh()

        XCTAssertNil(model.journeyHealthIntelligenceSectionState)
        XCTAssertEqual(snapshotProvider.loadCallCount, 0)
        XCTAssertFalse(
            JourneyDashboardCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: flags.uiEnabled,
                sectionState: JourneyHealthIntelligencePreviewData.strongWeek
            )
        )
        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard")
        }
    }

    func testPlanUnchangedWhenHealthIntelligenceDisabled() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let flags = HealthIntelligencePhase11FlagPreset.off
        let model = HealthIntelligencePhase11IntegrationTestSupport.makePlanModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            baselineProvider: baselineProvider,
            healthRepository: healthRepository
        )

        await model.loadProfile()

        XCTAssertNil(model.planHealthIntelligenceSectionState)
        XCTAssertEqual(snapshotProvider.loadCallCount, 0)
        XCTAssertFalse(
            PlanDashboardCompositionPolicy.showsHealthIntelligenceSection(
                isUIEnabled: flags.uiEnabled,
                sectionState: PlanHealthIntelligencePresentationPreviewData.strongFit
            )
        )
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testCoachWorksNormallyWhenHealthIntelligenceDisabled() async {
        snapshotProvider.snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .fullHealth,
            on: harness.today
        )

        let activity = await CoachAIActivityContextResolver.resolve(
            date: harness.today,
            snapshotProvider: snapshotProvider,
            healthActivityQuery: harness.healthActivityQuery,
            loadHealthIntelligence: { false }
        )

        XCTAssertEqual(snapshotProvider.loadCallCount, 0)
        XCTAssertNil(activity.healthIntelligence)
        XCTAssertFalse(activity.healthIntelligenceAwarenessAvailable)
        XCTAssertFalse(
            CoachCompositionPolicy.suppressesLegacyWorkoutSignals(
                isCoachContextEnabled: false,
                healthIntelligenceAwarenessAvailable: false
            )
        )
    }
}

// MARK: - Scenario 2: Full health data rollout

@MainActor
final class HealthIntelligencePhase11FullDataIntegrationTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: Phase11TrackingSnapshotService!
    private var weeklyReviewService: Phase11TrackingWeeklyReviewService!
    private var healthRepository: Phase11MockHealthDataRepository!
    private var baselineProvider: Phase11MockBaselineProvider!
    private let flags = HealthIntelligencePhase11FlagPreset.fullRollout

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = Phase11TrackingSnapshotService()
        weeklyReviewService = Phase11TrackingWeeklyReviewService()
        healthRepository = Phase11MockHealthDataRepository(
            availability: HealthIntelligencePhase11IntegrationTestSupport.availability(connected: true, cachedDayCount: 28)
        )
        baselineProvider = Phase11MockBaselineProvider()
        snapshotProvider.snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .fullHealth,
            on: harness.today
        )
        weeklyReviewService.latestReview = HealthIntelligencePhase11IntegrationTestSupport.completedWeeklyReview(
            endingOn: harness.today
        )
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        weeklyReviewService = nil
        healthRepository = nil
        baselineProvider = nil
        super.tearDown()
    }

    func testTodayShowsRecoveryDailyMissionAndNextBestAction() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeTodayModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider
        )

        await model.loadToday()

        let section = try XCTUnwrap(model.healthIntelligenceSectionState)
        XCTAssertEqual(section.recoveryCard.title, "Ready to train")
        XCTAssertEqual(
            section.dailyMission.sectionTitle,
            FormaProductCopy.Today.HealthIntelligence.DailyMission.sectionTitle
        )
        XCTAssertTrue(section.nextBestAction.isVisible)
        XCTAssertNotNil(section.workoutCard)
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testCoachReceivesHealthContextWhenEnabled() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")

        let activity = await CoachAIActivityContextResolver.resolve(
            date: harness.today,
            snapshotProvider: snapshotProvider,
            healthActivityQuery: harness.healthActivityQuery,
            loadHealthIntelligence: { flags.coachContextEnabled },
            calendar: HealthIntelligencePhase11IntegrationTestSupport.makeCalendar()
        )

        XCTAssertEqual(snapshotProvider.loadCallCount, 1)
        XCTAssertNotNil(activity.healthIntelligence)
        XCTAssertTrue(activity.healthIntelligenceAwarenessAvailable)
        XCTAssertEqual(activity.healthIntelligence?.nextBestActionTitle, "Log protein")
    }

    func testJourneyShowsRecoveryTimelineWorkoutHistoryAndWeeklyReviewDetail() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let workout = HealthWorkoutRecord(
            id: UUID(),
            activityName: "Strength training",
            startDate: harness.today.addingTimeInterval(3_600),
            endDate: harness.today.addingTimeInterval(6_600),
            durationMinutes: 45,
            activeCalories: 320
        )
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeJourneyModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            weeklyReviewService: weeklyReviewService,
            healthRepository: healthRepository,
            workouts: [workout]
        )

        await model.refresh()

        let section = try XCTUnwrap(model.journeyHealthIntelligenceSectionState)
        XCTAssertEqual(section.recoveryTimeline.phase, .loaded)
        XCTAssertEqual(section.workoutHistory.phase, .loaded)
        XCTAssertEqual(section.weeklyReviewCard?.phase, .loaded)
        XCTAssertNotNil(section.weeklyReviewDetail)
        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard")
        }
    }

    func testPlanShowsHealthConfidenceAndAssumptions() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        baselineProvider.context = makeStrongBaseline(on: harness.today)
        let model = HealthIntelligencePhase11IntegrationTestSupport.makePlanModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            baselineProvider: baselineProvider,
            healthRepository: healthRepository
        )

        await model.loadProfile()

        let section = try XCTUnwrap(model.planHealthIntelligenceSectionState)
        XCTAssertEqual(section.confidenceCard.phase, .loaded)
        XCTAssertEqual(
            section.confidenceCard.confidenceLabel,
            FormaProductCopy.PlanHealthIntelligencePresentation.confidenceHigh
        )
        XCTAssertFalse(section.assumptions.items.isEmpty)
        XCTAssertTrue(model.viewState.isLoaded)
    }

    private func makeStrongBaseline(on day: Date) -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: day,
            averageSteps7d: 8_450,
            averageSteps28d: 7_900,
            averageActiveEnergy7d: 420,
            averageActiveEnergy28d: 390,
            averageSleepDuration7d: 426,
            averageSleepDuration28d: 408,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 52,
            averageWorkoutLoad28d: 180,
            workoutDays7d: 4,
            workoutDays28d: 12,
            availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv, .workoutLoad],
            missingSignals: []
        )
    }
}

// MARK: - Scenario 3: Partial health data

final class HealthIntelligencePhase11PartialDataIntegrationTests: XCTestCase {

    private var calendar: Calendar!
    private var day: Date!

    override func setUp() {
        super.setUp()
        calendar = HealthIntelligencePhase11IntegrationTestSupport.makeCalendar()
        day = HealthIntelligencePhase11IntegrationTestSupport.referenceDay(calendar: calendar)
    }

    func testPartialNoSleepNoHRVMappedToLimitedEstimate() {
        let snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .partialNoSleepNoHRV,
            on: day,
            calendar: calendar
        )
        let context = HealthIntelligencePresentationContext(
            availability: HealthIntelligencePhase11IntegrationTestSupport.availability(
                connected: true,
                cachedDayCount: 7
            ),
            snapshot: snapshot,
            isAppleHealthConnected: true,
            cachedDayCount: 7
        )

        XCTAssertEqual(
            HealthIntelligencePresentationStateMapper.resolve(context),
            .limitedEstimate
        )
        XCTAssertTrue(snapshot.recovery.missingSignals.contains(.sleep))
        XCTAssertTrue(snapshot.recovery.missingSignals.contains(.hrv))
        XCTAssertTrue(snapshot.workout?.hasWorkout == true)

        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            isUIEnabled: true
        )
        XCTAssertNotNil(section?.recoveryCard.confidenceNote)
    }

    func testWorkoutsOnlyScenarioSurfacesWorkoutCardWithoutSteps() {
        let snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .workoutsOnly,
            on: day,
            calendar: calendar
        )

        XCTAssertNil(snapshot.activity.steps)
        XCTAssertTrue(snapshot.workout?.hasWorkout == true)

        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            isUIEnabled: true
        )
        XCTAssertNotNil(section?.workoutCard)
    }

    func testStepsOnlyScenarioSurfacesActivityWithoutWorkoutCard() {
        let snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .stepsOnly,
            on: day,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.activity.steps, 11_500)
        XCTAssertNil(snapshot.workout)

        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            isUIEnabled: true
        )
        XCTAssertNil(section?.workoutCard)
        XCTAssertNotNil(section?.recoveryCard)
    }

    func testPartialAvailabilityMapsToPartialHealthDataState() {
        let context = HealthIntelligencePresentationContext(
            availability: HealthIntelligencePhase11IntegrationTestSupport.stepsOnlyAvailability(),
            snapshot: HealthIntelligencePhase11IntegrationTestSupport.snapshot(
                .stepsOnly,
                on: day,
                calendar: calendar
            ),
            isAppleHealthConnected: true,
            cachedDayCount: 7
        )

        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(context)
        let dataState = HealthIntelligenceAnalyticsContextBuilder.healthDataState(from: lifecycle)
        XCTAssertEqual(dataState, .partial)
    }
}

// MARK: - Scenario 4: No health data

@MainActor
final class HealthIntelligencePhase11NoDataIntegrationTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: Phase11TrackingSnapshotService!
    private let flags = HealthIntelligencePhase11FlagPreset.fullRollout

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = Phase11TrackingSnapshotService()
        snapshotProvider.snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .noHealthData,
            on: harness.today
        )
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        super.tearDown()
    }

    func testNoHealthDataShowsFallbackWithoutCrashing() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeTodayModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider
        )

        await model.loadToday()

        let section = try XCTUnwrap(model.healthIntelligenceSectionState)
        XCTAssertNotNil(section.fallbackMessage)
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testNutritionLoggingStillWorksWithNoHealthData() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        _ = try harness.actionCenter.ensureTodayLog()

        let entry = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(
                name: "Greek yogurt",
                calories: 180,
                protein: 15,
                carbs: 12,
                fat: 4
            ),
            date: harness.today
        )

        XCTAssertEqual(entry.name, "Greek yogurt")
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)

        let model = HealthIntelligencePhase11IntegrationTestSupport.makeTodayModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider
        )
        await model.loadToday()
        XCTAssertTrue(model.viewState.isLoaded)
    }
}

// MARK: - Scenario 5: Permission denied

@MainActor
final class HealthIntelligencePhase11PermissionDeniedIntegrationTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: Phase11TrackingSnapshotService!
    private var weeklyReviewService: Phase11TrackingWeeklyReviewService!
    private var healthRepository: Phase11MockHealthDataRepository!
    private var baselineProvider: Phase11MockBaselineProvider!
    private let flags = HealthIntelligencePhase11FlagPreset.fullRollout

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = Phase11TrackingSnapshotService()
        snapshotProvider.snapshot = nil
        weeklyReviewService = Phase11TrackingWeeklyReviewService()
        healthRepository = Phase11MockHealthDataRepository(
            availability: HealthIntelligencePhase11IntegrationTestSupport.deniedAvailability()
        )
        baselineProvider = Phase11MockBaselineProvider()
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        weeklyReviewService = nil
        healthRepository = nil
        baselineProvider = nil
        super.tearDown()
    }

    func testJourneyShowsConnectHealthCTAWhenPermissionDenied() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeJourneyModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            weeklyReviewService: weeklyReviewService,
            healthRepository: healthRepository,
            trainingConnected: false
        )

        await model.refresh()

        XCTAssertNotNil(model.journeyHealthIntelligenceSectionState?.connectHealthCTA)
        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard")
        }
    }

    func testPlanShowsConnectHealthActionWhenDisconnected() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makePlanModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            baselineProvider: baselineProvider,
            healthRepository: healthRepository,
            trainingConnected: false
        )

        await model.loadProfile()

        let section = try XCTUnwrap(model.planHealthIntelligenceSectionState)
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "connect-health" })
        XCTAssertTrue(model.viewState.isLoaded)
    }

    func testTodaySupplementalConnectActionAppearsWhenHealthActionRequiresIt() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        snapshotProvider.snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .noHealthData,
            on: harness.today
        )
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeTodayModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider
        )

        await model.loadToday()

        let section = try XCTUnwrap(model.healthIntelligenceSectionState)
        XCTAssertTrue(section.nextBestAction.isVisible || section.fallbackMessage != nil)
        XCTAssertTrue(model.viewState.isLoaded)
    }
}

// MARK: - Scenario 6: Snapshot composition failure

@MainActor
final class HealthIntelligencePhase11SnapshotFailureIntegrationTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: Phase11TrackingSnapshotService!
    private var weeklyReviewService: Phase11TrackingWeeklyReviewService!
    private var healthRepository: Phase11MockHealthDataRepository!
    private var baselineProvider: Phase11MockBaselineProvider!
    private let flags = HealthIntelligencePhase11FlagPreset.fullRollout

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = Phase11TrackingSnapshotService()
        snapshotProvider.shouldFailLoad = true
        weeklyReviewService = Phase11TrackingWeeklyReviewService()
        healthRepository = Phase11MockHealthDataRepository(
            availability: HealthIntelligencePhase11IntegrationTestSupport.availability(connected: true, cachedDayCount: 3)
        )
        baselineProvider = Phase11MockBaselineProvider()
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        weeklyReviewService = nil
        healthRepository = nil
        baselineProvider = nil
        super.tearDown()
    }

    func testTodayStillRendersLoadedDashboardWhenSnapshotFails() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeTodayModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider
        )

        await model.refresh()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Today dashboard despite snapshot failure")
        }
        XCTAssertNotNil(model.healthIntelligenceSectionState)
    }

    func testJourneyStillRendersLoadedDashboardWhenSnapshotFails() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeJourneyModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            weeklyReviewService: weeklyReviewService,
            healthRepository: healthRepository
        )

        await model.refresh()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Journey dashboard despite snapshot failure")
        }
        XCTAssertNotNil(model.journeyHealthIntelligenceSectionState)
    }

    func testPlanStillRendersLoadedDashboardWhenSnapshotFails() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makePlanModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            baselineProvider: baselineProvider,
            healthRepository: healthRepository
        )

        await model.refresh()

        guard case .loaded = model.viewState else {
            return XCTFail("Expected loaded Plan dashboard despite snapshot failure")
        }
        XCTAssertNotNil(model.planHealthIntelligenceSectionState)
    }

    func testCoachStillResolvesActivityWhenSnapshotUnavailable() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")

        let activity = await CoachAIActivityContextResolver.resolve(
            date: harness.today,
            snapshotProvider: snapshotProvider,
            healthActivityQuery: harness.healthActivityQuery,
            loadHealthIntelligence: { true }
        )

        XCTAssertEqual(snapshotProvider.loadCallCount, 1)
        XCTAssertNil(activity.healthIntelligence)
        XCTAssertFalse(activity.healthIntelligenceAwarenessAvailable)
    }
}

// MARK: - Scenario 7: Theme change

final class HealthIntelligencePhase11ThemeIntegrationTests: XCTestCase {

    private let hiSourcePaths = HealthIntelligencePhase11IntegrationTestSupport.healthIntelligenceProductionSourcePaths()

    override func tearDown() async throws {
        await MainActor.run {
            ThemeTestSupport.resetThemeAccessToProductDefault()
        }
        try await super.tearDown()
    }

    func testHealthIntelligenceCardsUseThemeReactiveModifier() throws {
        let root = ThemeTestSupport.repositoryRoot()
        var missing: [String] = []

        for relativePrefix in hiSourcePaths {
            let url = root.appendingPathComponent(relativePrefix)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                let files = try FileManager.default.subpathsOfDirectory(atPath: url.path)
                    .filter { $0.hasSuffix(".swift") }
                for file in files {
                    let source = try String(
                        contentsOf: url.appendingPathComponent(file),
                        encoding: .utf8
                    )
                    let usesThemeTokens = source.contains("FormaTokens")
                        || source.contains("FormaPlanTokens")
                        || source.contains("JourneyTypography")
                    if usesThemeTokens,
                       source.contains("struct "),
                       !source.contains(".formaThemeReactive()") {
                        missing.append("\(relativePrefix)\(file)")
                    }
                }
            } else {
                let source = try String(contentsOf: url, encoding: .utf8)
                let usesThemeTokens = source.contains("FormaTokens") || source.contains("FormaPlanTokens")
                if usesThemeTokens, source.contains("struct "), !source.contains(".formaThemeReactive()") {
                    missing.append(relativePrefix)
                }
            }
        }

        XCTAssertTrue(
            missing.isEmpty,
            "Themed Health Intelligence UI files must call .formaThemeReactive() for live theme updates:\n\(missing.joined(separator: "\n"))"
        )
    }

    func testHealthIntelligenceTokensTrackPaletteChangesWithoutRestart() async {
        await MainActor.run {
            FormaThemeAccess.update(
                resolved: ThemeTestSupport.makeResolved(palette: .blossomPink, systemColorScheme: .dark)
            )
            let pinkPrimary = FormaTokens.Theme.primary
            let pinkCanvas = FormaTokens.Color.canvas

            FormaThemeAccess.update(
                resolved: ThemeTestSupport.makeResolved(palette: .emeraldGreen, systemColorScheme: .dark)
            )

            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(pinkPrimary, FormaTokens.Theme.primary), 0.08)
            XCTAssertGreaterThan(ThemeTestSupport.colorDistance(pinkCanvas, FormaTokens.Color.canvas), 0.02)
        }
    }
}

// MARK: - Scenario 8: Pull to refresh

@MainActor
final class HealthIntelligencePhase11PullToRefreshIntegrationTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: Phase11TrackingSnapshotService!
    private var weeklyReviewService: Phase11TrackingWeeklyReviewService!
    private var healthRepository: Phase11MockHealthDataRepository!
    private var baselineProvider: Phase11MockBaselineProvider!
    private let flags = HealthIntelligencePhase11FlagPreset.fullRollout

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = Phase11TrackingSnapshotService()
        snapshotProvider.snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .fullHealth,
            on: harness.today
        )
        weeklyReviewService = Phase11TrackingWeeklyReviewService()
        weeklyReviewService.latestReview = HealthIntelligencePhase11IntegrationTestSupport.completedWeeklyReview(
            endingOn: harness.today
        )
        healthRepository = Phase11MockHealthDataRepository(
            availability: HealthIntelligencePhase11IntegrationTestSupport.availability(connected: true, cachedDayCount: 14)
        )
        baselineProvider = Phase11MockBaselineProvider()
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        weeklyReviewService = nil
        healthRepository = nil
        baselineProvider = nil
        super.tearDown()
    }

    func testTodayRefreshReloadsHealthIntelligenceSnapshot() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeTodayModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider
        )

        await model.loadToday()
        let firstCount = snapshotProvider.loadCallCount
        await model.refresh()

        XCTAssertGreaterThan(snapshotProvider.loadCallCount, firstCount)
        XCTAssertNotNil(model.healthIntelligenceSectionState)
    }

    func testJourneyRefreshReloadsHealthIntelligenceSnapshot() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeJourneyModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            weeklyReviewService: weeklyReviewService,
            healthRepository: healthRepository
        )

        await model.refresh()
        let firstCount = snapshotProvider.loadCallCount
        await model.refresh()

        XCTAssertGreaterThan(snapshotProvider.loadCallCount, firstCount)
        XCTAssertNotNil(model.journeyHealthIntelligenceSectionState)
    }

    func testPlanRefreshReloadsHealthIntelligenceSnapshot() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makePlanModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            baselineProvider: baselineProvider,
            healthRepository: healthRepository
        )

        await model.loadProfile()
        let firstCount = snapshotProvider.loadCallCount
        await model.refresh()

        XCTAssertGreaterThan(snapshotProvider.loadCallCount, firstCount)
        XCTAssertNotNil(model.planHealthIntelligenceSectionState)
    }
}

// MARK: - Scenario 9: Weekly review cache

@MainActor
final class HealthIntelligencePhase11WeeklyReviewCacheIntegrationTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var snapshotProvider: Phase11TrackingSnapshotService!
    private var weeklyReviewService: Phase11TrackingWeeklyReviewService!
    private var healthRepository: Phase11MockHealthDataRepository!
    private let flags = HealthIntelligencePhase11FlagPreset.fullRollout

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        snapshotProvider = Phase11TrackingSnapshotService()
        snapshotProvider.snapshot = HealthIntelligencePhase11IntegrationTestSupport.snapshot(
            .fullHealth,
            on: harness.today
        )
        weeklyReviewService = Phase11TrackingWeeklyReviewService()
        weeklyReviewService.latestReview = HealthIntelligencePhase11IntegrationTestSupport.completedWeeklyReview(
            endingOn: harness.today
        )
        healthRepository = Phase11MockHealthDataRepository(
            availability: HealthIntelligencePhase11IntegrationTestSupport.availability(connected: true, cachedDayCount: 14)
        )
    }

    override func tearDown() {
        harness = nil
        snapshotProvider = nil
        weeklyReviewService = nil
        healthRepository = nil
        super.tearDown()
    }

    func testWeeklyReviewUsesCacheWithoutRegenerationOnNormalRefresh() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeJourneyModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            weeklyReviewService: weeklyReviewService,
            healthRepository: healthRepository
        )

        await model.refresh()
        await model.refresh()

        XCTAssertEqual(weeklyReviewService.getLatestCallCount, 2)
        XCTAssertEqual(weeklyReviewService.generateCallCount, 0)
        XCTAssertEqual(model.journeyHealthIntelligenceSectionState?.weeklyReviewCard?.phase, .loaded)
    }

    func testWeeklyReviewForceRefreshRegeneratesReview() async throws {
        _ = try harness.seedProfile(ownerUID: "test-user-1")
        let model = HealthIntelligencePhase11IntegrationTestSupport.makeJourneyModel(
            harness: harness,
            flags: flags,
            snapshotProvider: snapshotProvider,
            weeklyReviewService: weeklyReviewService,
            healthRepository: healthRepository
        )

        await model.refresh(forceWeeklyReviewRefresh: true)

        XCTAssertEqual(weeklyReviewService.generateCallCount, 1)
        XCTAssertTrue(weeklyReviewService.lastForceRefresh)
        XCTAssertNotNil(model.journeyHealthIntelligenceSectionState?.weeklyReviewDetail)
    }
}

// MARK: - View state helpers

private extension TodayViewState {
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}

private extension PlanViewState {
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}
