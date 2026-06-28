//
//  OnboardingV4AppleHealthTests.swift
//  Fitness CoachTests
//
//  Forma — V4 Apple Health permission flow, analytics, and configuration tests.
//

import XCTest
@testable import Fitness_Coach

#if canImport(HealthKit) && os(iOS)
import HealthKit
#endif

final class OnboardingV4AppleHealthFlowTests: XCTestCase {

    func testAnalyticsResultMappingForAllAuthorizationOutcomes() {
        XCTAssertEqual(
            OnboardingV4AppleHealthFlow.analyticsResult(for: .connected),
            "authorized"
        )
        XCTAssertEqual(
            OnboardingV4AppleHealthFlow.analyticsResult(for: .denied),
            "denied"
        )
        XCTAssertEqual(
            OnboardingV4AppleHealthFlow.analyticsResult(for: .unavailable),
            "unavailable"
        )
        XCTAssertEqual(
            OnboardingV4AppleHealthFlow.analyticsResult(for: .failed(message: "HealthKit error")),
            "failed"
        )
        XCTAssertEqual(
            OnboardingV4AppleHealthFlow.analyticsResult(for: .notConnected),
            "not_connected"
        )
    }

    func testRequestPermissionUsesIntegrationProvider() async {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .connected)

        let state = await OnboardingV4AppleHealthFlow.requestPermission(using: integration)

        XCTAssertEqual(state, .connected)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
    }

    func testRequestPermissionReturnsDeniedWithoutBlockingFlow() async {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)

        let state = await OnboardingV4AppleHealthFlow.requestPermission(using: integration)

        XCTAssertEqual(state, .denied)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
    }

    func testRequestPermissionReturnsUnavailableOnSimulatorLikeDevice() async {
        let integration = StubTrainingIntegrationProvider(
            dataSource: .unavailable,
            refreshResult: .unavailable,
            requestConnectionResult: .unavailable
        )

        let state = await OnboardingV4AppleHealthFlow.requestPermission(using: integration)

        XCTAssertEqual(state, .unavailable)
    }

    func testRequestPermissionReturnsFailedState() async {
        let integration = StubTrainingIntegrationProvider(
            requestConnectionResult: .failed(message: "HealthKit unavailable")
        )

        let state = await OnboardingV4AppleHealthFlow.requestPermission(using: integration)

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

        let state = await OnboardingV4AppleHealthFlow.requestPermission(trainingInsightsStore: store)

        XCTAssertEqual(state, .connected)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
        XCTAssertEqual(store.integrationState, .connected)
    }

    func testAppleHealthRoutesNextToAlmostThere() {
        let flow = OnboardingV4Step.fullFlow
        XCTAssertEqual(OnboardingV4Step.appleHealth.next(in: flow), .almostThere)
    }

    func testAppleHealthStepUsesDedicatedCopy() {
        XCTAssertEqual(
            OnboardingV4Step.appleHealth.title,
            FormaProductCopy.Onboarding.V4.AppleHealth.title
        )
        XCTAssertEqual(
            OnboardingV4Step.appleHealth.subtitle,
            FormaProductCopy.Onboarding.V4.AppleHealth.subtitle
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
final class OnboardingV4AppleHealthAnalyticsTests: XCTestCase {

    private var v2FlagPrevious = false
    private var v3FlagPrevious: Bool?
    private var v4FlagPrevious: Bool?
    private var draftSuiteName: String!
    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!
    private var analytics: CapturingOnboardingAnalyticsLogger!

    override func setUp() async throws {
        try await super.setUp()
        v2FlagPrevious = UserDefaults.standard.bool(forKey: OnboardingV2FeatureFlag.enabledKey)
        v3FlagPrevious = UserDefaults.standard.object(forKey: OnboardingV3FeatureFlag.enabledKey) as? Bool
        v4FlagPrevious = UserDefaults.standard.object(forKey: OnboardingV4FeatureFlag.enabledKey) as? Bool

        UserDefaults.standard.set(true, forKey: OnboardingV2FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV3FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV4FeatureFlag.enabledKey)

        draftSuiteName = "OnboardingV4AppleHealthAnalyticsTests.\(UUID().uuidString)"
        draftDefaults = UserDefaults(suiteName: draftSuiteName)!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
        draftStore.clearDraft()
        analytics = CapturingOnboardingAnalyticsLogger()
    }

    override func tearDown() async throws {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftSuiteName)
        UserDefaults.standard.set(v2FlagPrevious, forKey: OnboardingV2FeatureFlag.enabledKey)
        if let v3FlagPrevious {
            UserDefaults.standard.set(v3FlagPrevious, forKey: OnboardingV3FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV3FeatureFlag.enabledKey)
        }
        if let v4FlagPrevious {
            UserDefaults.standard.set(v4FlagPrevious, forKey: OnboardingV4FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV4FeatureFlag.enabledKey)
        }
        try await super.tearDown()
    }

    func testAppleHealthContinueLogsPermissionEventsAndAdvancesDespiteDenial() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeV4Model(integration: integration)
        advanceModelToAppleHealth(model)

        XCTAssertTrue(analytics.contains(.appleHealthPromptViewed, step: "appleHealth"))

        model.goNext()

        for _ in 0..<50 {
            if model.currentV4Step == .almostThere { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(model.currentV4Step, .almostThere)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
        XCTAssertTrue(analytics.contains(.appleHealthPermissionRequested, step: "appleHealth"))
        XCTAssertTrue(analytics.contains(.appleHealthPermissionResult, step: "appleHealth"))
        XCTAssertEqual(
            analytics.lastProperties(for: .appleHealthPermissionResult)?["permissionResult"],
            "denied"
        )
        XCTAssertTrue(analytics.contains(.stepCompleted, step: "appleHealth"))
    }

    private func makeV4Model(
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
            flowScope: .v2Full,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: integration
        )
    }

    private func advanceModelToAppleHealth(_ model: OnboardingModel) {
        seedValidV4Form(&model.formState)

        model.goNext() // introProof -> heightWeight
        model.goNext() // heightWeight
        model.goNext() // targetWeight
        model.goNext() // targetEncouragement
        model.goNext() // birthday
        model.goNext() // activityLevel
        XCTAssertEqual(model.currentV4Step, .appleHealth)
    }

    private func seedValidV4Form(_ formState: inout OnboardingFormState) {
        OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingV4TargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingV4BirthdayValues.applyDefaultsIfNeeded(to: &formState)
        formState.sex = .female
        formState.activityLevel = .moderatelyActive
        OnboardingV4ActivityLevelValues.applyDefaultsIfNeeded(to: &formState)
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
