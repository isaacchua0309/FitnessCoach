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
}
