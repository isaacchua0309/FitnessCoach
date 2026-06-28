//
//  OnboardingStructureTests.swift
//  Fitness CoachTests
//
//  Forma — Canonical onboarding flow structure tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingStructureTests: XCTestCase {

    func testFlowOrder() {
        XCTAssertEqual(OnboardingStep.flow, [
            .introProof,
            .heightWeight,
            .targetWeight,
            .targetEncouragement,
            .birthday,
            .activityLevel,
            .appleHealth,
            .almostThere,
            .formaProof,
            .review,
            .generatingPlan,
            .planReveal,
            .savePlan
        ])
    }

    func testSignedOutEntryStartsAtIntroProof() {
        XCTAssertEqual(OnboardingEntry.initialStep(for: .preAuth), .introProof)
    }

    func testSignedInIncompleteProfileEntryStartsAtHeightWeight() {
        XCTAssertEqual(OnboardingEntry.initialStep(for: .postAuth), .heightWeight)
    }

    func testPlanRevealAndSaveHideProgressHeader() {
        XCTAssertFalse(OnboardingStep.planReveal.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.savePlan.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.introProof.showsProgressHeader)
        XCTAssertTrue(OnboardingStep.heightWeight.showsProgressHeader)
    }

    func testDraftStoresCanonicalStepRawValues() {
        let draft = OnboardingDraft(formState: OnboardingFormState(), step: .heightWeight)
        XCTAssertEqual(draft.currentStepRawValue, OnboardingStep.heightWeight.rawValue)
        XCTAssertEqual(draft.step, .heightWeight)
    }

    func testDraftStepResolverRestoresIntroFromLegacyLanding() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.landing.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .introProof)
    }

    func testDraftStepResolverRestoresSavePlanFromLegacySavePlan() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.savePlan.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .savePlan)
    }

    func testLegacyWelcomeDraftMigratesToIntroProof() {
        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.welcome.rawValue,
            formState: OnboardingFormState(),
            flow: OnboardingStep.flow
        )
        XCTAssertEqual(restored, .introProof)
    }

    func testLegacyPreferencesDraftMigratesToNearestRequiredStep() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.preferences.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restored, .targetWeight)
    }

    func testFlowDoesNotIncludeRemovedDataCollectionSteps() {
        let flowRawValues = Set(OnboardingStep.flow.map(\.rawValue))
        let removedSteps: [OnboardingLegacyPersistedStep] = [
            .welcome,
            .motivation,
            .preferences,
            .planPreview
        ]

        for step in removedSteps {
            XCTAssertFalse(flowRawValues.contains(step.rawValue))
        }
    }
}
