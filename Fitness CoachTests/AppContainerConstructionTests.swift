//
//  AppContainerConstructionTests.swift
//  Fitness CoachTests
//
//  Forma — Lightweight checks that AppContainer domain bundles wire correctly.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AppContainerConstructionTests: XCTestCase {

    func testInMemoryContainerConstructsAllDomainBundles() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.authManager)
        XCTAssertNotNil(container.modelContainer)
        XCTAssertNotNil(container.healthIntelligenceEngine)
        XCTAssertNotNil(container.coachTimelineStore)
        XCTAssertNotNil(container.llmClient)
        XCTAssertTrue(container.llmClient is MockLLMClient)
        XCTAssertNotNil(container.accountRestoreCoordinator)
        XCTAssertNotNil(container.actionCenter)
    }

    func testInMemoryContainerBuildsFeatureModels() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.makeRootModel())
        XCTAssertNotNil(container.makeTodayModel())
        XCTAssertNotNil(container.makeCoachModel())
        XCTAssertNotNil(container.makeJourneyModel())
        XCTAssertNotNil(container.makePlanModel())
        XCTAssertNotNil(container.makeOnboardingModel(onCompletion: {}))
    }

    func testInMemoryContainerAcceptsInjectedAnalyticsLoggers() throws {
        let onboardingLogger = NoOpOnboardingAnalyticsLogger()
        let todayLogger = NoOpTodayAnalyticsLogger()

        let container = try AppContainer(
            inMemory: true,
            onboardingAnalyticsLogger: onboardingLogger,
            todayAnalyticsLogger: todayLogger
        )

        XCTAssertTrue(container.onboardingAnalyticsLogger is NoOpOnboardingAnalyticsLogger)
        XCTAssertTrue(container.todayAnalyticsLogger is NoOpTodayAnalyticsLogger)
    }

    func testInMemoryContainerWiresHealthIntelligenceAnalyticsLogger() throws {
        let logger = NoOpHealthIntelligenceAnalyticsLogger()
        let container = try AppContainer(
            inMemory: true,
            healthIntelligenceAnalyticsLogger: logger
        )

        XCTAssertTrue(container.healthIntelligenceAnalyticsLogger is NoOpHealthIntelligenceAnalyticsLogger)
        XCTAssertNotNil(container.makeHealthIntelligenceAnalyticsCoordinator())
    }

    func testBuildAnalyticsDependenciesDelegatesToAnalyticsDependenciesBundle() {
        let bundle = AppContainer.buildAnalyticsDependencies(
            onboardingAnalyticsLogger: NoOpOnboardingAnalyticsLogger(),
            todayAnalyticsLogger: nil,
            planAnalyticsLogger: nil,
            journeyAnalyticsLogger: nil,
            weeklyProgressAnalyticsLogger: nil,
            publicEntryAnalyticsLogger: nil,
            themeAnalyticsLogger: nil,
            settingsAnalyticsLogger: nil,
            healthIntelligenceAnalyticsLogger: nil
        )

        XCTAssertEqual(bundle.configuration, .current)
        XCTAssertTrue(bundle.onboardingAnalyticsLogger is NoOpOnboardingAnalyticsLogger)
    }

    func testBuildAuthDependenciesDelegatesToAuthDependenciesBundle() {
        let defaults = UserDefaults(suiteName: "AuthDependenciesTests.\(UUID().uuidString)")!
        let routing = OnboardingRoutingConfiguration.production

        let bundle = AppContainer.buildAuthDependencies(
            inMemory: true,
            onboardingUserDefaults: defaults,
            onboardingRoutingConfiguration: routing
        )

        XCTAssertNotNil(bundle.authManager)
        XCTAssertEqual(bundle.authUIDCache.currentUserID(), bundle.authManager.currentUID)
        XCTAssertTrue(bundle.onboardingUserDefaults === defaults)
        XCTAssertEqual(bundle.onboardingRoutingConfiguration, routing)
        XCTAssertNotNil(bundle.onboardingDraftStore)
        XCTAssertNotNil(bundle.publicEntrySessionStore)
        XCTAssertNotNil(bundle.onboardingCoachingContextStore)
        XCTAssertNotNil(bundle.refreshCenter)
        XCTAssertNotNil(bundle.accountRestoreSessionState)
    }

    func testInMemoryContainerAcceptsInjectedOnboardingUserDefaults() throws {
        let defaults = UserDefaults(suiteName: "AppContainerConstructionTests.\(UUID().uuidString)")!

        let container = try AppContainer(inMemory: true, onboardingUserDefaults: defaults)

        XCTAssertTrue(container.onboardingUserDefaults === defaults)
    }

    func testBuildHealthDelegatesToHealthDependenciesBundle() {
        let auth = AuthDependencies.build(inMemory: true)

        let bundle = AppContainer.buildHealth(session: auth, inMemory: true)

        XCTAssertNotNil(bundle.healthTrainingService)
        XCTAssertNotNil(bundle.healthDataRepository)
        XCTAssertNotNil(bundle.healthSyncService)
        XCTAssertNotNil(bundle.healthSyncStateStore)
        XCTAssertNotNil(bundle.trainingInsightsStore)
        XCTAssertNotNil(bundle.trainingInsightsModel)
        XCTAssertTrue(bundle.healthIntegrationConnectionStore is LockedHealthIntegrationConnectionStore)
        XCTAssertTrue(bundle.healthSummaryRemoteSyncClient is NoopHealthSummaryRemoteSyncClient)
    }

    func testInMemoryContainerWiresHealthPlatformDependencies() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.healthTrainingService)
        XCTAssertNotNil(container.healthDataRepository)
        XCTAssertNotNil(container.healthSyncStateStore)
        XCTAssertNotNil(container.trainingInsightsStore)
        XCTAssertTrue(container.healthIntegrationConnectionStore is LockedHealthIntegrationConnectionStore)
    }

    func testBuildSyncDependenciesDelegatesToSyncDependenciesBundle() throws {
        let auth = AuthDependencies.build(inMemory: true)
        let health = HealthDependencies.build(session: auth, inMemory: true)
        let persistence = try AppContainer.buildPersistenceDependencies(
            session: auth,
            inMemory: true,
            accountDataRemoteStore: nil
        )

        let bundle = AppContainer.buildSyncDependencies(
            session: auth,
            persistence: persistence,
            health: health,
            inMemory: true
        )

        XCTAssertNotNil(bundle.accountRestoreCoordinator)
        XCTAssertNotNil(bundle.accountInitialRestoreService)
        XCTAssertNotNil(bundle.crossDeviceSyncCoordinator)
        XCTAssertNotNil(bundle.accountDeletionCoordinator)
        XCTAssertNotNil(bundle.accountDataExportService)
        XCTAssertTrue(bundle.accountRealtimeChangeListener is NoOpAccountRealtimeChangeListener)
    }

    func testInMemoryContainerWiresAccountLifecycleDependencies() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.accountRestoreCoordinator)
        XCTAssertNotNil(container.crossDeviceSyncCoordinator)
        XCTAssertNotNil(container.accountDeletionCoordinator)
        XCTAssertNotNil(container.accountDataExportService)
        XCTAssertTrue(container.accountRealtimeChangeListener is NoOpAccountRealtimeChangeListener)
    }

    func testBuildCoachDependenciesDelegatesToCoachPlatformDependencies() throws {
        let auth = AuthDependencies.build(inMemory: true)
        let health = HealthDependencies.build(session: auth, inMemory: true)
        let persistence = try AppContainer.buildPersistenceDependencies(
            session: auth,
            inMemory: true,
            accountDataRemoteStore: nil
        )

        let bundle = AppContainer.buildCoachDependencies(
            session: auth,
            persistence: persistence,
            health: health
        )

        XCTAssertNotNil(bundle.coachTimelineStore)
        XCTAssertNotNil(bundle.coachChatTranscriptStore)
        XCTAssertNotNil(bundle.coachTimelineBackfillService)
        XCTAssertNotNil(bundle.coachTimelineRecorder)
        XCTAssertNotNil(bundle.foodCorrectionMemoryStore)
    }

    func testInMemoryContainerWiresCoachPlatformDependencies() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertNotNil(container.coachTimelineStore)
        XCTAssertNotNil(container.coachChatTranscriptStore)
        XCTAssertNotNil(container.coachTimelineBackfillService)
        XCTAssertNotNil(container.coachTimelineRecorder)
        XCTAssertNotNil(container.foodCorrectionMemoryStore)
        XCTAssertNotNil(container.makeCoachModel())
    }
}
