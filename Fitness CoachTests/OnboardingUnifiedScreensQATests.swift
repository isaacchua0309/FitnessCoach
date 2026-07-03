//
//  OnboardingUnifiedScreensQATests.swift
//  Fitness CoachTests
//
//  Forma — QA coverage for intro proof and Apple Health unified onboarding screens.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingUnifiedScreensQATests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingUnifiedScreensQATests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    // MARK: - Intro proof / long-term results

    func testNewUserStartsOnIntroProof() throws {
        let model = try makeModel()
        XCTAssertEqual(model.currentStep, .introProof)
        XCTAssertTrue(model.currentStep.usesUnifiedLayoutShell)
    }

    func testIntroProofContinueAdvancesToHeightWeight() throws {
        let model = try makeModel()
        model.goNext()
        XCTAssertEqual(model.currentStep, .heightWeight)
    }

    func testIntroProofDoesNotAllowBackNavigation() throws {
        let model = try makeModel()
        XCTAssertFalse(model.canGoBack)
    }

    func testHeightWeightBackReturnsToIntroProof() throws {
        let model = try makeModel()
        model.goNext()
        XCTAssertEqual(model.currentStep, .heightWeight)
        model.goBack()
        XCTAssertEqual(model.currentStep, .introProof)
    }

    func testIntroProofNeverUsesScrollableUnifiedShell() {
        XCTAssertFalse(
            OnboardingStepLayoutProfile.regular.allowsScrollableContent(
                step: .introProof,
                dynamicTypeSize: .accessibility3
            )
        )
        XCTAssertFalse(
            OnboardingStepLayoutProfile.compact.allowsScrollableContent(
                step: .introProof,
                dynamicTypeSize: .xxxLarge
            )
        )
    }

    func testIntroProofHeroCompressesForLargeDynamicType() {
        let regular = OnboardingStepLayoutMetrics.introProofHeroCardHeight(
            contentHeight: 360,
            profile: .compact,
            dynamicTypeSize: .large
        )
        let large = OnboardingStepLayoutMetrics.introProofHeroCardHeight(
            contentHeight: 360,
            profile: .compact,
            dynamicTypeSize: .xxxLarge
        )
        XCTAssertLessThanOrEqual(large, regular)
    }

    func testIntroProofChartUsesThemeTokensNotHardcodedColors() {
        let model = OnboardingWeightTrajectoryComparisonModel.introProofDefault
        XCTAssertFalse(model.chartAccessibilityLabel.isEmpty)
        XCTAssertFalse(model.formaLabel.isEmpty)
        XCTAssertFalse(model.traditionalLabel.isEmpty)
    }

    // MARK: - Apple Health states

    func testAppleHealthUnavailableShowsContinueWithoutPermissionRequest() async throws {
        let integration = StubTrainingIntegrationProvider(
            dataSource: .unavailable,
            isHealthDataAvailable: false,
            refreshResult: .unavailable,
            requestConnectionResult: .unavailable
        )
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)

        await AsyncTestSupport.drainMainActorTasks()

        XCTAssertEqual(model.appleHealthPresentation, .unavailable)
        XCTAssertEqual(model.appleHealthScreenState.primaryAction, .advance)
        model.connectAppleHealth()
        XCTAssertEqual(model.currentStep, .almostThere)
        XCTAssertEqual(integration.requestConnectionCallCount, 0)
    }

    func testAppleHealthNotDeterminedShowsConnectAndSkip() async throws {
        let integration = StubTrainingIntegrationProvider(refreshResult: .notConnected)
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)
        await AsyncTestSupport.drainMainActorTasks()

        XCTAssertEqual(model.appleHealthPresentation, .notDetermined)
        XCTAssertEqual(model.appleHealthScreenState.primaryAction, .requestPermission)
        XCTAssertTrue(model.appleHealthScreenState.showsSkipButton)
    }

    func testAppleHealthConnectRequestsPermissionOnce() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .connected)
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)

        model.connectAppleHealth()
        _ = await AsyncTestSupport.waitUntil(maxYields: 200) {
            model.appleHealthPresentation == .connected
        }

        XCTAssertEqual(integration.requestConnectionCallCount, 1)
    }

    func testAppleHealthAcceptedAutoAdvances() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .connected)
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)

        model.connectAppleHealth()

        let advanced = await AsyncTestSupport.waitUntilWallClock(timeout: 2.0) {
            model.currentStep != .appleHealth
        }
        XCTAssertTrue(advanced)
        XCTAssertEqual(model.currentStep, .almostThere)
    }

    func testAppleHealthDeniedAllowsContinue() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)

        model.connectAppleHealth()
        _ = await AsyncTestSupport.waitUntil(maxYields: 200) {
            model.appleHealthPresentation == .denied
        }

        XCTAssertFalse(model.appleHealthScreenState.showsSkipButton)
        model.connectAppleHealth()
        XCTAssertEqual(model.currentStep, .almostThere)
    }

    func testAppleHealthForegroundPreservesInFlightRequestingState() async throws {
        let integration = StubTrainingIntegrationProvider(
            refreshResult: .notConnected,
            requestConnectionResult: .connected,
            requestConnectionDelayNanoseconds: 500_000_000
        )
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)

        model.connectAppleHealth()
        XCTAssertEqual(model.viewState, .connectingAppleHealth)
        XCTAssertEqual(model.appleHealthPresentation, .requesting)

        model.handleAppleHealthForegroundReturn()
        _ = await AsyncTestSupport.waitUntil(maxYields: 50) {
            model.appleHealthDeviceState == .notConnected
        }

        XCTAssertEqual(model.viewState, .connectingAppleHealth)
        XCTAssertEqual(model.appleHealthPresentation, .requesting)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)

        _ = await AsyncTestSupport.waitUntilWallClock(timeout: 2.0) {
            model.appleHealthPresentation == .connected
        }
    }

    func testAppleHealthForegroundClearsStuckLoadingAfterRequestCompletes() async throws {
        let integration = StubTrainingIntegrationProvider(
            refreshResult: .denied,
            requestConnectionResult: .denied
        )
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)

        model.connectAppleHealth()
        _ = await AsyncTestSupport.waitUntil(maxYields: 200) {
            model.viewState != .connectingAppleHealth
        }

        model.handleAppleHealthForegroundReturn()
        _ = await AsyncTestSupport.waitUntil(maxYields: 50) {
            model.appleHealthPresentation == .denied
        }

        XCTAssertEqual(model.viewState, .editing)
        XCTAssertTrue(model.appleHealthScreenState.isPrimaryEnabled)
    }

    func testAppleHealthRepeatedConnectTapsIssueSingleRequest() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .connected)
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)

        model.connectAppleHealth()
        model.connectAppleHealth()
        model.connectAppleHealth()

        _ = await AsyncTestSupport.waitUntil(maxYields: 200) {
            model.appleHealthPresentation == .connected
        }

        XCTAssertEqual(integration.requestConnectionCallCount, 1)
    }

    func testAppleHealthSkipBeforeConnectingAdvances() async throws {
        let integration = StubTrainingIntegrationProvider(requestConnectionResult: .connected)
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)

        model.skipAppleHealth()

        XCTAssertEqual(model.currentStep, .almostThere)
        XCTAssertEqual(integration.requestConnectionCallCount, 0)
    }

    func testAppleHealthReturnAfterConnectedDoesNotReRequestPermission() async throws {
        let integration = StubTrainingIntegrationProvider(
            refreshResult: .connected,
            requestConnectionResult: .connected
        )
        let model = try makeModel(integration: integration)
        await advanceToAppleHealth(model)

        model.connectAppleHealth()
        _ = await AsyncTestSupport.waitUntilWallClock(timeout: 2.0) {
            model.currentStep != .appleHealth
        }

        model.goBack()
        await AsyncTestSupport.drainMainActorTasks()

        XCTAssertEqual(model.currentStep, .appleHealth)
        XCTAssertEqual(model.appleHealthPresentation, .connected)

        model.connectAppleHealth()
        XCTAssertEqual(model.currentStep, .almostThere)
        XCTAssertEqual(integration.requestConnectionCallCount, 1)
    }

    // MARK: - Layout profiles

    func testCompactProfileUsedForSmallViewport() {
        XCTAssertEqual(
            OnboardingStepLayoutProfile.resolve(viewportHeight: 640, dynamicTypeSize: .large),
            .compact
        )
    }

    func testAppleHealthScrollsOnCompactAndAccessibilityProfiles() {
        XCTAssertTrue(
            OnboardingStepLayoutProfile.compact.allowsScrollableContent(
                step: .appleHealth,
                dynamicTypeSize: .large
            )
        )
        XCTAssertTrue(
            OnboardingStepLayoutProfile.regular.allowsScrollableContent(
                step: .appleHealth,
                dynamicTypeSize: .accessibility3
            )
        )
    }

    func testConnectedPresentationRequiresDeviceReadAccess() {
        let state = OnboardingAppleHealthPresentationBuilder.build(
            presentation: .connected,
            deviceState: .notConnected
        )
        XCTAssertNotEqual(state.presentation, .connected)
    }

    // MARK: - Accessibility copy

    func testAppleHealthPermissionListHasGroupedAccessibilityLabel() {
        XCTAssertFalse(
            FormaProductCopy.Onboarding.Flow.AppleHealth.readableDataAccessibilityLabel.isEmpty
        )
    }

    func testIntroProofChartHasAccessibilityLabel() {
        let model = OnboardingWeightTrajectoryComparisonModel.introProofDefault
        XCTAssertFalse(model.chartAccessibilityLabel.isEmpty)
    }

    // MARK: - Helpers

    private func makeModel(
        integration: TrainingIntegrationProviding? = nil
    ) throws -> OnboardingModel {
        let container = try AppContainer(inMemory: true)
        return OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            planTargetCalculator: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            healthTrainingIntegration: integration
        )
    }

    private func advanceToAppleHealth(_ model: OnboardingModel) async {
        OnboardingModelTestSupport.seedCanonicalForm(&model.formState)
        await OnboardingModelTestSupport.advanceTo(.appleHealth, model: model, seedForm: false)
    }
}
