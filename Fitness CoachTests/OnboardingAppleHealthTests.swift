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
            FormaProductCopy.Onboarding.Flow.AppleHealth.title
        )
        XCTAssertEqual(
            OnboardingStep.appleHealth.subtitle,
            FormaProductCopy.Onboarding.Flow.AppleHealth.subtitle
        )
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

    }

    func testAppleHealthContinueLogsPermissionEventsAndAdvancesDespiteDenial() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeOnboardingModel(integration: integration)
        advanceModelToAppleHealth(model)

        XCTAssertTrue(analytics.contains(.appleHealthPromptViewed, step: "apple_health"))

        model.goNext()

        for _ in 0..<50 {
            if model.currentStep == .almostThere { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(model.currentStep, .almostThere)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
        XCTAssertTrue(analytics.contains(.appleHealthPermissionRequested, step: "apple_health"))
        XCTAssertTrue(analytics.contains(.appleHealthPermissionResult, step: "apple_health"))
        XCTAssertEqual(
            analytics.lastProperties(for: .appleHealthPermissionResult)?["permissionResult"],
            "denied"
        )
        XCTAssertTrue(analytics.contains(.stepCompleted, step: "apple_health"))
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

    private func advanceModelToAppleHealth(_ model: OnboardingModel) {
        seedValidOnboardingForm(&model.formState)

        model.goNext() // introProof -> heightWeight
        model.goNext() // heightWeight
        model.goNext() // targetWeight
        model.goNext() // targetEncouragement
        model.goNext() // birthday
        model.goNext() // activityLevel
        XCTAssertEqual(model.currentStep, .appleHealth)
    }

    private func seedValidOnboardingForm(_ formState: inout OnboardingFormState) {
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &formState)
        formState.sex = .female
        formState.activityLevel = .moderatelyActive
        OnboardingActivityLevelValues.applyDefaultsIfNeeded(to: &formState)
    }
}

private final class CapturingOnboardingAnalyticsLogger: OnboardingAnalyticsLogging, @unchecked Sendable {

    struct Record: Sendable {
        let event: OnboardingAnalyticsEvent
        let properties: OnboardingAnalyticsProperties
    }

    private let lock = NSLock()
    private var records: [Record] = []

    func log(_ event: OnboardingAnalyticsEvent, properties: OnboardingAnalyticsProperties) {
        lock.lock()
        records.append(Record(event: event, properties: properties))
        lock.unlock()
    }

    func contains(_ event: OnboardingAnalyticsEvent, step: String? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return records.contains { record in
            guard record.event == event else { return false }
            if let step, record.properties.step != step { return false }
            return true
        }
    }

    func lastProperties(for event: OnboardingAnalyticsEvent) -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        guard let record = records.last(where: { $0.event == event }) else { return nil }
        return record.properties.asParameters()
    }
}

private extension OnboardingAnalyticsProperties {
    subscript(key: String) -> String? {
        asParameters()[key]
    }
}
