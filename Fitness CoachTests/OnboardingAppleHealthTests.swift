//
//  OnboardingAppleHealthTests.swift
//  Fitness CoachTests
//
//  Forma — Apple Health permission flow, analytics, and configuration tests.
//

import XCTest
@testable import Fitness_Coach

#if canImport(HealthKit) && os(iOS)
import HealthKit
#endif

final class OnboardingAppleHealthFlowTests: XCTestCase {

    func testAnalyticsResultMappingForAllAuthorizationOutcomes() {
        XCTAssertEqual(
            OnboardingAppleHealthFlow.analyticsResult(for: .connected),
            "authorized"
        )
        XCTAssertEqual(
            OnboardingAppleHealthFlow.analyticsResult(for: .denied),
            "denied"
        )
        XCTAssertEqual(
            OnboardingAppleHealthFlow.analyticsResult(for: .unavailable),
            "unavailable"
        )
        XCTAssertEqual(
            OnboardingAppleHealthFlow.analyticsResult(for: .failed(message: "HealthKit error")),
            "failed"
        )
        XCTAssertEqual(
            OnboardingAppleHealthFlow.analyticsResult(for: .notConnected),
            "not_connected"
        )
    }

    func testRequestPermissionUsesIntegrationProvider() async {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .connected)

        let state = await OnboardingAppleHealthFlow.requestPermission(using: integration)

        XCTAssertEqual(state, .connected)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
    }

    func testRequestPermissionReturnsDeniedWithoutBlockingFlow() async {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)

        let state = await OnboardingAppleHealthFlow.requestPermission(using: integration)

        XCTAssertEqual(state, .denied)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
    }

    func testRequestPermissionReturnsUnavailableOnSimulatorLikeDevice() async {
        let integration = StubTrainingIntegrationProvider(
            dataSource: .unavailable,
            refreshResult: .unavailable,
            requestConnectionResult: .unavailable
        )

        let state = await OnboardingAppleHealthFlow.requestPermission(using: integration)

        XCTAssertEqual(state, .unavailable)
    }

    func testRequestPermissionReturnsFailedState() async {
        let integration = StubTrainingIntegrationProvider(
            requestConnectionResult: .failed(message: "HealthKit unavailable")
        )

        let state = await OnboardingAppleHealthFlow.requestPermission(using: integration)

        if case .failed(let message) = state {
            XCTAssertEqual(message, "HealthKit unavailable")
        } else {
            XCTFail("Expected failed integration state")
        }
    }

    @MainActor
    func testRequestPermissionUsesTrainingInsightsStore() async {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .connected)
        let store = TrainingInsightsStore(integration: integration)

        let state = await OnboardingAppleHealthFlow.requestPermission(trainingInsightsStore: store)

        XCTAssertEqual(state, .connected)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
        XCTAssertEqual(store.integrationState, .connected)
    }

    func testAppleHealthRoutesNextToAlmostThere() {
        let flow = OnboardingStep.flow
        XCTAssertEqual(OnboardingStep.appleHealth.next(in: flow), .almostThere)
    }

    func testAppleHealthStepUsesDedicatedCopy() {
        XCTAssertEqual(
            OnboardingStep.appleHealth.title,
            "Connect Apple Health"
        )
        XCTAssertEqual(
            OnboardingStep.appleHealth.subtitle,
            "Sync workouts and activity to improve your progress insights."
        )
    }

    func testAppleHealthReadableDataRowsUseCompactSummaryCopy() {
        let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self
        XCTAssertEqual(copy.summaryCardTitle, "What Forma can read")
        XCTAssertEqual(copy.readableDataRows, [
            "Workouts and duration",
            "Active calories",
            "Training consistency"
        ])
        XCTAssertEqual(
            copy.readableDataAccessibilityLabel,
            "What Forma can read: workouts and duration, active calories, training consistency."
        )
    }

    func testAppleHealthCopyHasSingleTitleReference() {
        let copy = FormaProductCopy.Onboarding.Flow.AppleHealth.self
        XCTAssertEqual(copy.title, OnboardingStep.appleHealth.title)
        XCTAssertEqual(copy.subtitle, OnboardingStep.appleHealth.subtitle)
    }

    func testAppleHealthStepUsesFixedViewportShell() {
        XCTAssertTrue(OnboardingStep.appleHealth.usesFixedViewportShell)
    }

    func testHealthKitAuthorizationRequestsReadOnlyTypes() {
        #if canImport(HealthKit) && os(iOS)
        XCTAssertTrue(SystemHealthKitTrainingAuthorization.writeTypes.isEmpty)
        XCTAssertFalse(SystemHealthKitTrainingAuthorization.readTypes.isEmpty)
        XCTAssertTrue(
            SystemHealthKitTrainingAuthorization.readTypes.contains(HKObjectType.workoutType())
        )
        #else
        throw XCTSkip("HealthKit read-type assertions require iOS HealthKit")
        #endif
    }

    func testProjectHealthShareUsageDescriptionConfigured() throws {
        let projectURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fitness Coach.xcodeproj/project.pbxproj")
        let projectContents = try String(contentsOf: projectURL, encoding: .utf8)

        XCTAssertTrue(
            projectContents.contains("INFOPLIST_KEY_NSHealthShareUsageDescription"),
            "NSHealthShareUsageDescription must be configured for HealthKit read access"
        )
        XCTAssertFalse(
            projectContents.contains("INFOPLIST_KEY_NSHealthUpdateUsageDescription"),
            "Forma should not request HealthKit write/update usage descriptions"
        )
    }

    func testHealthEntitlementsIncludeHealthKitCapability() throws {
        let entitlementsURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fitness Coach/Fitness Coach.entitlements")
        let entitlements = try String(contentsOf: entitlementsURL, encoding: .utf8)

        XCTAssertTrue(entitlements.contains("com.apple.developer.healthkit"))
    }
}

@MainActor
final class OnboardingAppleHealthAnalyticsTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private let analytics = CapturingOnboardingAnalyticsLogger()

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingAppleHealthAnalyticsTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testAppleHealthContinueLogsPermissionEventsAndAllowsSkipAfterDenial() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(integration: integration)
        await advanceModelToAppleHealth(model)

        XCTAssertTrue(analytics.contains(.appleHealthPromptViewed, step: "apple_health"))
        XCTAssertTrue(analytics.contains(.appleHealthOnboardingViewed, step: "apple_health"))

        model.connectAppleHealth()

        _ = await AsyncTestSupport.waitUntil(maxYields: 200) {
            model.viewState != .connectingAppleHealth
        }

        XCTAssertEqual(model.appleHealthPresentation, .denied)
        XCTAssertEqual(model.currentStep, .appleHealth)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
        XCTAssertTrue(analytics.contains(.appleHealthConnectTapped, step: "apple_health"))
        XCTAssertTrue(analytics.contains(.appleHealthPermissionRequested, step: "apple_health"))
        XCTAssertTrue(analytics.contains(.appleHealthPermissionResult, step: "apple_health"))
        XCTAssertEqual(
            analytics.lastProperties(for: .appleHealthPermissionResult)?["permissionResult"],
            "denied"
        )

        model.skipAppleHealth()

        XCTAssertEqual(model.currentStep, .almostThere)
        XCTAssertTrue(analytics.contains(.appleHealthSkipTapped, step: "apple_health"))
        XCTAssertTrue(analytics.contains(.stepCompleted, step: "apple_health"))
    }

    func testAppleHealthSkipRoutesForwardWithoutRequestingPermission() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .connected)
        let model = try makeOnboardingModel(integration: integration)
        await advanceModelToAppleHealth(model)

        model.skipAppleHealth()

        XCTAssertEqual(model.currentStep, .almostThere)
        XCTAssertEqual(integration.requestConnectionCallCount, 0)
        XCTAssertTrue(analytics.contains(.appleHealthSkipTapped, step: "apple_health"))
    }

    func testAppleHealthAuthorizedAutoAdvances() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .connected)
        let model = try makeOnboardingModel(integration: integration)
        await advanceModelToAppleHealth(model)

        model.connectAppleHealth()

        let advanced = await AsyncTestSupport.waitUntilWallClock(timeout: 2.0) {
            model.currentStep != .appleHealth
        }
        XCTAssertTrue(advanced, "Expected auto-advance after Apple Health authorization")

        XCTAssertEqual(model.currentStep, .almostThere)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
    }

    func testAppleHealthUnavailableStillAllowsSkip() async throws {
        let integration = StubTrainingIntegrationProvider(
            dataSource: .unavailable,
            refreshResult: .unavailable,
            requestConnectionResult: .unavailable
        )
        let model = try makeOnboardingModel(integration: integration)
        await advanceModelToAppleHealth(model)

        model.prepareAppleHealthStep()
        _ = await AsyncTestSupport.waitUntil(maxYields: 200) {
            model.appleHealthDeviceState == .unavailable
        }

        XCTAssertEqual(model.appleHealthPresentation, .unavailable)
        model.skipAppleHealth()
        XCTAssertEqual(model.currentStep, .almostThere)
    }

    func testAppleHealthStepDoesNotShowProgressHeaderInShell() {
        XCTAssertFalse(OnboardingStep.appleHealth.showsProgressHeader)
    }

    private func makeOnboardingModel(
        integration: TrainingIntegrationProviding
    ) throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsLogger: analytics,
            analyticsEntry: .preAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: integration
        )
    }

    private func advanceModelToAppleHealth(_ model: OnboardingModel) async {
        OnboardingModelTestSupport.seedCanonicalForm(&model.formState)
        await OnboardingModelTestSupport.advanceTo(.appleHealth, model: model, seedForm: false)
    }
}
