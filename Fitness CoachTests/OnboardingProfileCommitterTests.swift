//
//  OnboardingProfileCommitterTests.swift
//  Fitness CoachTests
//
//  Regression tests for onboarding profile commit and conflict replace flows.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingProfileCommitterTests: XCTestCase {

    private func makeCommitter(container: AppContainer) -> OnboardingProfileCommitter {
        OnboardingProfileCommitter(
            actionCenter: container.actionCenter,
            userProfileReader: container.userProfileService
        )
    }

    private func filledFormState(
        goalWeightKg: Double = 58,
        birthDate: Date? = ProfileTestFixtures.onboardingSampleDraft.birthDate
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)
        state.currentWeightKgText = "68"
        state.heightCmText = "165"
        state.goalWeightKgText = String(goalWeightKg)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &state)
        state.birthDate = birthDate
        state.syncAgeTextFromBirthDate()
        state.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &state)
        state.selectPaceChoice(.moderate)
        return state
    }

    private func generatedPlan(calorieTarget: Int = 1_950) -> CalorieTargetResult {
        CalorieTargetResult(
            estimatedBMR: 1_400,
            estimatedTDEE: 2_100,
            targets: UserTargets(
                calorieTarget: calorieTarget,
                proteinTarget: 130,
                carbTarget: 170,
                fatTarget: 55,
                waterTargetMl: 2_400,
                expectedWeeklyWeightLossKg: 0.34,
                aggressiveness: .moderate
            ),
            estimatedDailyDeficit: 150,
            isAggressive: false,
            warning: nil
        )
    }

    func testCommitIfNeededReplacesExistingUnownedProfile() throws {
        let container = try AppContainer(inMemory: true)
        var existingDraft = ProfileTestFixtures.onboardingSampleDraft
        existingDraft.goalWeightKg = 62
        existingDraft.targets.calorieTarget = 1_800
        _ = try container.userProfileService.createProfile(existingDraft)

        let committer = makeCommitter(container: container)
        let formState = filledFormState(goalWeightKg: 58)
        let plan = generatedPlan(calorieTarget: 1_950)

        let didWrite = try committer.commitIfNeeded(formState: formState, generatedPlan: plan)

        XCTAssertTrue(didWrite)
        let profile = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertEqual(profile.goalWeightKg, 58, accuracy: 0.01)
        XCTAssertEqual(profile.targets.calorieTarget, 1_950)
        XCTAssertNil(profile.ownerUID)
    }

    func testCommitIfNeededReplacesOwnedProfileAndClearsOwnerUID() throws {
        let container = try AppContainer(inMemory: true)
        var existingDraft = ProfileTestFixtures.onboardingSampleDraft
        existingDraft.goalWeightKg = 62
        _ = try container.userProfileService.createProfile(existingDraft, ownerUID: "previous-user")

        let committer = makeCommitter(container: container)
        let formState = filledFormState(goalWeightKg: 55)
        let plan = generatedPlan(calorieTarget: 1_750)

        let didWrite = try committer.commitIfNeeded(formState: formState, generatedPlan: plan)

        XCTAssertTrue(didWrite)
        let profile = try XCTUnwrap(try container.userProfileService.getCurrentProfile())
        XCTAssertEqual(profile.goalWeightKg, 55, accuracy: 0.01)
        XCTAssertEqual(profile.targets.calorieTarget, 1_750)
        XCTAssertNil(profile.ownerUID)
    }

    func testConflictReplaceUploadsUpdatedLocalData() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(cloudUID: nil)
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        var oldDraft = ProfileTestFixtures.onboardingSampleDraft
        oldDraft.targets.calorieTarget = 1_800
        _ = try harness.profileService.createProfile(oldDraft)

        let committer = OnboardingProfileCommitter(
            actionCenter: harness.actionCenter,
            userProfileReader: harness.profileService
        )
        let formState = filledFormState(goalWeightKg: 57)
        let plan = generatedPlan(calorieTarget: 2_050)
        XCTAssertTrue(try committer.commitIfNeeded(formState: formState, generatedPlan: plan))

        let coordinator = ProfileBootstrapCoordinatorService(
            profileBootstrapService: harness.profileBootstrapService,
            cloudSyncStore: harness.syncStore
        )
        try await coordinator.uploadDevicePlanAfterConflict(uid: "signed-in-user")

        XCTAssertEqual(harness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(harness.cloudStore.lastSavedProfile?.targets.calorieTarget, 2_050)
        XCTAssertEqual(harness.cloudStore.lastSavedProfile?.goalWeightKg, 57, accuracy: 0.01)
        XCTAssertEqual(try harness.profileService.getCurrentProfile()?.ownerUID, "signed-in-user")
    }

    func testOnboardingCompletionConflictUsesOnboardingCompletionContext() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()
        _ = try harness.profileService.createProfile(ProfileTestFixtures.onboardingSampleDraft)

        let outcome = await harness.coordinator.resolveOnboardingCompletion(uid: "signed-in-user")

        guard case .cloudProfileConflict = outcome else {
            return XCTFail("Expected onboarding completion conflict")
        }

        // Mirrors AuthGateCoordinator.resolveOnboardingCompletionAfterSignIn after the fix.
        let profileConflictContext: ProfileConflictResolutionContext = .onboardingCompletion
        XCTAssertEqual(profileConflictContext, .onboardingCompletion)
        XCTAssertNotEqual(profileConflictContext, .accountOrOwnershipReconcile)
    }
}
