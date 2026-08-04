//
//  OnboardingWelcomeExitNavigationTests.swift
//  Fitness CoachTests
//
//  Welcome-exit transaction: suppress + destination before model clear.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class OnboardingWelcomeExitNavigationTests: XCTestCase {

    private var analytics: CapturingPublicEntryAnalyticsLogger!
    private var container: AppContainer!
    private var coordinator: AuthGateCoordinator!

    override func setUp() async throws {
        analytics = CapturingPublicEntryAnalyticsLogger()
        container = try AppContainer(
            inMemory: true,
            publicEntryAnalyticsLogger: analytics
        )
        coordinator = AuthGateCoordinator(container: container)
        container.authManager.applyTestingAuthState(.signedOut)
    }

    override func tearDown() {
        coordinator = nil
        container = nil
        analytics = nil
        super.tearDown()
    }

    func testReturnToWelcomeSuppressesAutomaticResumeAndClearsSession() throws {
        var formState = OnboardingFormState()
        seedForm(&formState)
        container.onboardingDraftStore.saveDraft(
            OnboardingDraft(formState: formState, step: .review)
        )
        coordinator.startPreAuthOnboarding()
        XCTAssertEqual(coordinator.effectiveRoute, .onboardingStart)
        XCTAssertNotNil(coordinator.onboardingModel)

        coordinator.returnToWelcomeFromOnboarding()

        XCTAssertEqual(coordinator.publicEntryDestination, .welcome)
        XCTAssertNil(coordinator.onboardingModel)
        XCTAssertFalse(container.onboardingDraftStore.hasDraft)
        XCTAssertTrue(container.publicEntrySessionStore.suppressAutomaticPublicEntryResume)
        XCTAssertEqual(coordinator.effectiveRoute, .welcome)
    }

    func testBootstrapAfterWelcomeExitDoesNotRecreateOnboarding() throws {
        var formState = OnboardingFormState()
        seedForm(&formState)
        container.onboardingDraftStore.saveDraft(
            OnboardingDraft(formState: formState, step: .activityLevel)
        )
        coordinator.startPreAuthOnboarding()
        XCTAssertEqual(coordinator.onboardingModel?.currentStep, .activityLevel)

        coordinator.returnToWelcomeFromOnboarding()
        coordinator.bootstrapOnboardingIfNeeded()

        XCTAssertNil(coordinator.onboardingModel)
        XCTAssertEqual(coordinator.effectiveRoute, .welcome)
    }

    func testWelcomeExitWinsOverAwaitingSignInBypass() throws {
        _ = try container.userProfileService.createProfile(minimalUnsignedDraft())
        XCTAssertTrue(container.profileBootstrapService.localProfileAwaitingSignIn())
        coordinator.startPreAuthOnboarding()
        XCTAssertEqual(coordinator.effectiveRoute, .onboardingStart)

        coordinator.returnToWelcomeFromOnboarding()
        coordinator.bootstrapOnboardingIfNeeded()

        XCTAssertEqual(coordinator.effectiveRoute, .welcome)
        XCTAssertNil(coordinator.onboardingModel)
    }

    func testReentryAfterWelcomeExitStartsAtIntroProof() {
        coordinator.startPreAuthOnboarding()
        coordinator.onboardingModel?.goNext()
        XCTAssertEqual(coordinator.onboardingModel?.currentStep, .heightWeight)

        coordinator.returnToWelcomeFromOnboarding()
        XCTAssertEqual(coordinator.effectiveRoute, .welcome)

        coordinator.startPreAuthOnboarding()
        XCTAssertEqual(coordinator.effectiveRoute, .onboardingStart)
        XCTAssertEqual(coordinator.onboardingModel?.currentStep, .introProof)
        XCTAssertFalse(container.publicEntrySessionStore.suppressAutomaticPublicEntryResume)
    }

    private func seedForm(_ formState: inout OnboardingFormState) {
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &formState)
        formState.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &formState)
        formState.selectPaceChoice(.moderate)
    }

    private func minimalUnsignedDraft() -> UserProfileDraft {
        UserProfileDraft(
            name: "Alex",
            age: 30,
            sex: .female,
            heightCm: 165,
            currentWeightKg: 68,
            goalWeightKg: 62,
            estimatedBodyFatPercentage: nil,
            activityLevel: .lightlyActive,
            trainingFrequencyPerWeek: 4,
            averageSteps: 7000,
            dietPreference: nil,
            unitSystem: .metric,
            targets: UserTargets(
                calorieTarget: 1800,
                proteinTarget: 130,
                carbTarget: 170,
                fatTarget: 55,
                waterTargetMl: 2400,
                expectedWeeklyWeightLossKg: 0.34,
                aggressiveness: .moderate
            )
        )
    }
}
