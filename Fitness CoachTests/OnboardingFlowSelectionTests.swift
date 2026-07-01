//
//  OnboardingFlowSelectionTests.swift
//  Fitness CoachTests
//
//  Forma — Single-flow onboarding entry and shell routing tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingFlowSelectionTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingFlowSelectionTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testProductionRoutingConfigurationIsDefault() {
        XCTAssertEqual(OnboardingRoutingConfiguration.production, OnboardingRoutingConfiguration())
    }

    func testNewSignedOutUserStartsAtIntroProof() throws {
        let container = try AppContainer(inMemory: true)
        let model = container.makeOnboardingModel(onCompletion: {})

        XCTAssertEqual(model.currentStep, .introProof)
        XCTAssertEqual(model.flowFloor, .introProof)
        XCTAssertTrue(model.requiresGoogleSignInAtSavePlan)
    }

    func testSignedInIncompleteProfileStartsAtHeightWeight() throws {
        let container = try AppContainer(inMemory: true)
        let model = container.makeOnboardingModel(entry: .postAuth, onCompletion: {})

        XCTAssertEqual(model.currentStep, .heightWeight)
        XCTAssertEqual(model.flowFloor, .heightWeight)
        XCTAssertFalse(model.requiresGoogleSignInAtSavePlan)
        XCTAssertFalse(model.canGoBack)
    }

    func testIncompleteDraftResumesAtSavedStep() throws {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        draftStore.saveDraft(
            OnboardingDraft(formState: formState, step: .targetWeight)
        )

        let container = try AppContainer(inMemory: true)
        let model = OnboardingModel(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService,
            planTargetCalculator: container.targetService,
            onCompletion: {},
            draftStore: draftStore
        )

        XCTAssertEqual(model.currentStep, .targetWeight)
    }

    func testExistingCompleteProfileSkipsOnboardingShell() async throws {
        let cloudStore = MockCloudUserProfileStore()
        cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let harness = try DailyLogServiceTestSupport.makeHarness()
        let service = ProfileBootstrapService(
            userProfileService: harness.profileService,
            cloudStore: cloudStore
        )

        let bootstrapResult = try await service.resolve(uid: "restored-user")
        let rootState = RootProfileRouteResolver.resolve(bootstrapResult: bootstrapResult)
        let shellRoute = AppRouteResolver.resolve(
            authState: .signedIn(uid: "restored-user"),
            rootState: rootState
        )

        XCTAssertEqual(bootstrapResult, .main)
        XCTAssertEqual(rootState, .main)
        XCTAssertEqual(shellRoute, .main)
    }

    func testSignedOutUsersWithoutProfileRouteToWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false
            ),
            .welcome
        )
    }
}
