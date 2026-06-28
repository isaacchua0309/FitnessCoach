//
//  OnboardingCompletionSignInTests.swift
//  Fitness CoachTests
//
//  Forma — Onboarding save-plan sign-in uploads and routing.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingCompletionSignInPolicyTests: XCTestCase {

    private let uid = "device-a-user"

    func testOnboardingSignInUploadsNewProfileWhenCloudMissing() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: uid,
                pendingOnboardingCompletion: true,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: .missing
            )
        )

        XCTAssertEqual(decision, .syncLocalProfileToCloud(uid: uid))
        XCTAssertNotEqual(decision, .presentMissingCloudProfile(uid: uid))
    }

    func testOnboardingCompletionIntentBeatsExistingUserRestore() {
        XCTAssertEqual(
            ProfileBootstrapCoordinator.profileSignInIntent(
                for: SignedInProfileReconcileInput(
                    uid: uid,
                    pendingOnboardingCompletion: true,
                    pendingExistingUserSignIn: true,
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    isFreshSignIn: true,
                    rootState: .loading,
                    isSyncedForCurrentUID: false
                )
            ),
            .onboardingCompletion
        )
    }

    func testOnboardingCompletionCloudFailureDoesNotUpload() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: uid,
                pendingOnboardingCompletion: true,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: .failed
            )
        )

        XCTAssertEqual(decision, .showCloudFetchFailed(uid: uid))
        XCTAssertNotEqual(decision, .syncLocalProfileToCloud(uid: uid))
    }
}

@MainActor
final class OnboardingCompletionSignInIntegrationTests: XCTestCase {

    private var draftDefaults: UserDefaults!
    private var draftStore: OnboardingDraftStore!

    override func setUp() {
        super.setUp()
        draftDefaults = UserDefaults(suiteName: "OnboardingCompletionSignInTests.\(UUID().uuidString)")!
        draftStore = OnboardingDraftStore(userDefaults: draftDefaults)
    }

    override func tearDown() {
        draftStore.clearDraft()
        draftDefaults.removePersistentDomain(forName: draftDefaults.description)
        draftDefaults = nil
        draftStore = nil
        super.tearDown()
    }

    func testPreAuthSavePlanSetsSignInIntent() async throws {
        let container = try AppContainer(inMemory: true)
        var formState = OnboardingFormState()
        OnboardingModelTestSupport.seedCanonicalForm(&formState)
        draftStore.saveDraft(OnboardingDraft(formState: formState, step: .review))

        let model = OnboardingModel(
            userProfileService: container.userProfileService,
            targetService: container.targetService,
            onCompletion: {},
            draftStore: draftStore,
            analyticsEntry: .preAuth,
            generationDelay: ImmediateOnboardingGenerationDelayProvider(),
            healthTrainingIntegration: StubTrainingIntegrationProvider(requestConnectionResult: .denied)
        )

        model.goNext()
        await model.flushPendingGenerationForTesting()
        model.goNext()
        XCTAssertEqual(model.currentStep, .savePlan)
        XCTAssertTrue(model.hasCommittedLocalProfile)

        model.goNext()
        XCTAssertEqual(model.pendingCompletionIntent, .signIn)
    }

    func testOnboardingCompletionUploadsProfileToCloud() async throws {
        let harness = try ProfileBootstrapTestSupport.makeHarness()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.makeCoordinator().resolveOnboardingCompletion(uid: "device-a-user")

        XCTAssertEqual(outcome, .uploadedToCloud)
        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(harness.cloudStore.lastSavedUID, "device-a-user")
        XCTAssertEqual(try harness.profileService.getCurrentProfile()?.ownerUID, "device-a-user")
        XCTAssertTrue(harness.syncStore.isSyncedForUID("device-a-user"))
    }

    func testOnboardingCompletionDoesNotUploadWhenCloudProfileExists() async throws {
        let harness = try ProfileBootstrapTestSupport.makeHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.makeCoordinator().resolveOnboardingCompletion(uid: "device-a-user")

        guard case .cloudProfileConflict = outcome else {
            return XCTFail("Expected cloud profile conflict")
        }
        XCTAssertEqual(harness.cloudStore.saveCallCount, 0)
    }
}
